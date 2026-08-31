import Foundation

// MARK: - 紀錄頁的分組／篩選型別
//
// 這三個型別只有紀錄頁在用，且都是 **presentation 投影**（分組標題、小計、
// 相對日期都是畫面語彙，不是後端交出來的事實），所以放在這個 ViewModel 檔，
// 不進 `App2Models.swift`（那裡放的是端點交出來的 domain 形狀）。

/// 清單上的一筆紀錄 ＝ 已格式化的卡片內容（`App2WorkoutRow`）＋ 分組／小計需要的原始量。
///
/// `App2WorkoutRow` 只帶已格式化的字串（`8/22`、`12.4 km`），分組要的是 `Date`、
/// 小計要的是數值 —— 從字串反推是錯的方向，所以在這裡把原始量一起帶著走。
struct App2RecordItem: Identifiable, Equatable {
    var id: String { row.id }
    let row: App2WorkoutRow
    /// 裝置當地時區的實際發生時刻。樣本資料沒有時間 → nil。
    let date: Date?
    /// 這筆的距離（km），給每組小計加總用。nil = 不確定，不計入小計。
    let distanceKm: Double?
    /// 設計 frame-10 的 `r.when`（「今天 08:07」／「3 天前」）。
    /// 走既有的 `DateFormatterHelper.formatRelativeForWorkoutCard`，三語已齊。
    let whenLabel: String
    /// 這筆的後端原始紀錄 —— 點進訓練詳情要拿它去建 1.4 的
    /// `WorkoutDetailViewModelV2`。樣本資料沒有原始紀錄 → nil，那一列就不可點
    /// （不做點下去什麼都沒有的死列）。
    let workout: WorkoutV2?
}

/// 日期分組 ＋ 該組小計（設計 frame-10 的 `g.group` / `g.count` / `g.sum`）。
struct App2RecordGroup: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let items: [App2RecordItem]

    var count: Int { items.count }
    /// 小計距離；沒有任何一筆帶得出距離時是 0（畫面就不顯示這一欄）。
    var totalKm: Double { items.compactMap(\.distanceKm).reduce(0, +) }
}

/// 課型篩選 chip（設計 frame-10 的 `recTabs`）。
///
/// **過濾條件是結構化的 `DayType` 集合，不是顯示字**。同一個顯示名可能對應多個
/// raw value（`easy` 與 `easy_run` 都是「輕鬆跑」），所以一顆 chip 帶一組 `DayType`。
struct App2RecordFilter: Identifiable, Equatable {
    /// 空集合 ＝「全部」。
    let types: Set<DayType>
    /// 顯示字。課型走 `DayType.localizedName`（三語已齊），「全部」走既有的
    /// `record.filter.all` —— 1.x 的紀錄頁已經有這顆，不再開第二份。
    let label: String

    var isAll: Bool { types.isEmpty }
    var id: String { isAll ? "all" : types.map(\.rawValue).sorted().joined(separator: "+") }

    static var all: App2RecordFilter {
        App2RecordFilter(types: [], label: L10n.Record.Filter.all.localized)
    }
}

/// `groups(_:)` 的內部分桶鍵。宣告在 file scope 是為了讓 `Hashable` 合成成立。
private enum App2RecordBucket: Hashable {
    case today
    case yesterday
    case earlierThisWeek
    case lastWeek
    /// 更早：以「該月的月初」當鍵。**算出來的 `Date` 當 key 一定先正規化**
    /// （`AGENTS.md` 陷阱 1）。
    case month(Date)
    /// 沒有時間的紀錄（樣本資料）。
    case undated
}

// MARK: - App2RecordsViewModel
/// Presentation Layer — 2.0 紀錄頁（`DESIGN-app2-decision-chain-api.md` §3.6）。
///
/// 三個 bucket 一次拿完：30 天滾動視窗、近 8 週跑量序列、當地年 YTD，全部來自
/// `GET /v2/workouts/stats`（T-0304 把 `weekly_series`／`year_to_date` 做實）。
/// 清單另走 `GET /v2/workouts`；課型標籤在 row 的 `training_type`（後端已抬到頂層）。
@MainActor
final class App2RecordsViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var records: App2Sourced<App2Records>?
    /// 清單的分組／篩選來源。`records.value.recentWorkouts` 是它的卡片內容，
    /// 這裡多帶時間與距離原始量 —— 不是第二份清單。
    @Published private(set) var items: [App2RecordItem] = []
    /// 目前資料裡真的存在的課型 chip（含「全部」）。只有一種課型時是空的。
    @Published private(set) var filters: [App2RecordFilter] = []
    @Published private(set) var selectedFilterID = "all"
    /// 捲到底往更舊載入中（sentinel 的 spinner 狀態）。
    @Published private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    /// 目前取回的全部列（依後端排序，最新在前）。清單只顯示前 `visibleCount` 筆。
    private var rows: [WorkoutV2] = []
    private var lastStats: WorkoutStatsResponse?
    /// 後端分頁游標與「還有更舊」旗標（`GET /v2/workouts` 的 pagination）。
    private var nextCursor: String?
    private var backendHasMore = false
    private var visibleCount = App2RecordsViewModel.listPageSize

    nonisolated let taskRegistry = TaskRegistry()

    private let workoutDataSource: WorkoutStatsDataSourceProtocol
    /// 冷啟快照。
    private let snapshots: any App2SnapshotStoring

    init(
        workoutDataSource: WorkoutStatsDataSourceProtocol? = nil,
        snapshots: (any App2SnapshotStoring)? = nil
    ) {
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
        self.snapshots = snapshots ?? App2FileSnapshotStore.shared

        // workout_processed 推播（T-0359）與其他 workouts 失效：紀錄列表要立即
        // 換新，不能等 60 秒 SWR 視窗（清快取而不重驗＝畫面停留舊資料）。
        CacheEventBus.shared.subscribe(forIdentifier: "App2RecordsViewModel.workouts") { [weak self] reason in
            if case .dataChanged(.workouts) = reason {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastLoadedAt = nil
                    if self.hasLoaded { await self.revalidate() }
                }
            }
        }
    }

    deinit {
        cancelAllTasks()
    }

    func revalidate() async {
        // 冷啟第一輪：先把上一次的清單與統計渲染出來，這一輪的網路變成背景刷新。
        if !hasLoaded { hydrateFromSnapshot() }
        isLoading = !hasLoaded && records == nil
        // 被取消的那一輪**不算載過**：只收 spinner，不標 hasLoaded／lastLoadedAt，
        // 下次進頁的 SWR 會重試（2026-08-29 外審 E03）。
        defer { isLoading = false }

        do {
            let stats = try await workoutDataSource.fetchWorkoutStats(days: 30, weeks: 8)
            // 月比要看到「上個月」，所以取回的筆數比清單顯示的多。
            // `/v2/workouts/stats` 只給滾動視窗（days）與 YTD，沒有日曆月的分桶，
            // 月量與月比在 client 端從同一批紀錄算，不新增端點。
            do {
                let page = try await workoutDataSource.fetchWorkoutsPage(
                    pageSize: Self.aggregationPageSize, cursor: nil
                )
                // 兩支都收齊才落快照——stats 先落、page 中途被收掉會留下
                // 半新半舊的快照組（外審 E03）。
                snapshots.save(stats, for: .workoutStats)
                if !page.workouts.isEmpty { snapshots.save(page.workouts, for: .recentWorkouts) }
                nextCursor = page.pagination.nextCursor
                backendHasMore = page.pagination.hasMore
                apply(stats: stats, rows: page.workouts)
            } catch {
                // 清單失敗但 stats 成功：**保留既有清單**（SWR），只更新統計。
                // 之前 `try?` 把失敗折成空清單再當 live 發布——畫面宣稱「沒有紀錄」，
                // 其實是「沒取到」（2026-08-29 外審 D04/D07）。
                guard !error.isCancellationError else { return }
                Logger.debug("[App2RecordsVM] workouts page 取得失敗，保留既有清單: \(error)")
                // 一筆舊資料都沒有就沒東西可保留 —— 交給外層的整體失敗路徑
                //（stub ＋ offline 徽章），不畫一個假的空清單。
                guard !rows.isEmpty else { throw error }
                snapshots.save(stats, for: .workoutStats)
                apply(stats: stats, rows: rows)
            }
            hasLoaded = true
            lastLoadedAt = Date()
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）—— 下拉刷新的 task 被收掉時
            // in-flight 請求會回 -999。
            guard !error.isCancellationError else { return }
            Logger.debug("[App2RecordsVM] stats 取得失敗,退樣本: \(error)")
            // 真失敗（非取消）仍算「這一輪回過話」——標記已載，SWR 窗內不重打。
            hasLoaded = true
            lastLoadedAt = Date()
            guard records == nil else { return }    // SWR：重驗失敗時保留舊資料
            let stub = App2StubFixtures.records
            // 樣本沒有時間戳 → date/distanceKm 為 nil，全部落在「更早」那一組、
            // 不參與小計。畫面上同時掛 stub 徽章，不會被誤讀成真資料。
            apply(items: stub.recentWorkouts.map {
                App2RecordItem(
                    row: $0,
                    date: nil,
                    distanceKm: nil,
                    whenLabel: $0.dateLabel,
                    workout: nil
                )
            })
            records = App2Sourced(stub, origin: .stub(pendingSection: App2StubFixtures.Section.offline))
        }
    }

    /// 統計 ＋ 清單的組裝。網路回應與冷啟快照都走這一支。
    private func apply(stats: WorkoutStatsResponse, rows newRows: [WorkoutV2]) {
        lastStats = stats
        rows = newRows
        render()
    }

    /// 從目前的 `rows`／`visibleCount` 重繪（初載與 loadMore 共用）。
    private func render() {
        guard let stats = lastStats else { return }
        let month = Self.monthlyTotals(rows)
        let listItems = rows.prefix(visibleCount).map(Self.map(item:))
        apply(items: listItems)

        records = App2Sourced(
            App2Records(
                monthDistanceKm: month.distanceKm,
                monthWorkouts: month.workouts,
                monthDeltaKm: month.deltaKm,
                ytdYear: stats.data.yearToDate?.year,
                ytdDistanceKm: stats.data.yearToDate?.distanceKm,
                ytdWorkouts: stats.data.yearToDate?.workoutCount,
                weeklySeries: (stats.data.weeklySeries ?? []).map(Self.map(entry:)),
                recentWorkouts: listItems.map(\.row)
            ),
            origin: .live(endpoint: "GET /v2/workouts/stats + GET /v2/workouts")
        )
    }

    /// 冷啟：統計與清單兩份快照都在才渲染 —— 只有其中一份會讓卡片頭與清單各說各話。
    private func hydrateFromSnapshot() {
        guard let stats = snapshots.load(WorkoutStatsResponse.self, for: .workoutStats)?.value,
              let rows = snapshots.load([WorkoutV2].self, for: .recentWorkouts)?.value else { return }
        apply(stats: stats, rows: rows)
    }

    // MARK: - 往更舊分頁（捲到底載入）

    /// 還有更舊的可以載：本地已取回但未顯示，或後端還有下一頁。樣本資料不分頁。
    var canLoadMore: Bool {
        guard let records, !records.origin.isStub else { return false }
        return visibleCount < rows.count || (backendHasMore && nextCursor != nil)
    }

    /// 捲到底：先展開已取回的列；用完才拿游標向後端要更舊的一頁。
    /// 單次失敗不推進游標——sentinel 再次出現時自動重試。
    func loadMore() async {
        guard !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        if visibleCount >= rows.count, backendHasMore, let cursor = nextCursor {
            guard let page = try? await workoutDataSource.fetchWorkoutsPage(
                pageSize: Self.aggregationPageSize, cursor: cursor
            ) else { return }
            let known = Set(rows.map(\.id))
            rows.append(contentsOf: page.workouts.filter { !known.contains($0.id) })
            nextCursor = page.pagination.nextCursor
            backendHasMore = page.pagination.hasMore
        }
        visibleCount = min(visibleCount + Self.listPageSize, max(rows.count, visibleCount))
        render()
    }

    // MARK: - 篩選

    func select(filterID: String) {
        guard filters.contains(where: { $0.id == filterID }) else { return }
        selectedFilterID = filterID
    }

    /// 套用目前 chip 後的分組清單。View 直接 render 這個，不自己算。
    var visibleGroups: [App2RecordGroup] {
        let filter = filters.first { $0.id == selectedFilterID }
        return Self.groups(Self.filtered(items, by: filter))
    }

    private func apply(items newItems: [App2RecordItem]) {
        items = newItems
        filters = Self.filters(for: newItems)
        // 資料換了之後原本選的課型可能不存在了 —— 退回「全部」，不要停在空清單。
        if !filters.contains(where: { $0.id == selectedFilterID }) {
            selectedFilterID = "all"
        }
    }

    // MARK: - 月量與月比

    /// 清單顯示筆數。
    private static let listPageSize = 20
    /// 為了算「較上月」而取回的筆數 —— 要涵蓋兩個完整日曆月。
    private static let aggregationPageSize = 100

    struct MonthlyTotals {
        let distanceKm: Double
        let workouts: Int
        let deltaKm: Double?
    }

    /// 以裝置當地日曆切月。`start_time_utc` 是 UTC instant，換算成當地時間再分桶。
    ///
    /// `deltaKm` 只在**確定看得到整個上個月**時才給值：取回的最舊一筆比上月月初還早，
    /// 或這次根本沒取滿（代表已經是全部）。否則回 nil —— 分不出「上月沒跑」與
    /// 「上月的紀錄沒被取回來」，就不要畫那一列。
    static func monthlyTotals(_ workouts: [WorkoutV2], now: Date = Date()) -> MonthlyTotals {
        let calendar = Calendar.current
        guard let thisMonth = calendar.dateInterval(of: .month, for: now),
              let lastMonthAnchor = calendar.date(byAdding: .month, value: -1, to: thisMonth.start),
              let lastMonth = calendar.dateInterval(of: .month, for: lastMonthAnchor)
        else {
            return MonthlyTotals(distanceKm: 0, workouts: 0, deltaKm: nil)
        }

        let runs: [(date: Date, km: Double)] = workouts.compactMap { workout in
            guard workout.activityType.lowercased().contains("run"),
                  let date = parseDate(workout.startTimeUtc) else { return nil }
            return (date, (workout.distanceMeters ?? 0) / 1000)
        }

        let thisMonthRuns = runs.filter { thisMonth.contains($0.date) }
        let lastMonthKm = runs.filter { lastMonth.contains($0.date) }.reduce(0) { $0 + $1.km }
        let thisMonthKm = thisMonthRuns.reduce(0) { $0 + $1.km }

        let oldestFetched = runs.map(\.date).min()
        let coversLastMonth = workouts.count < aggregationPageSize
            || (oldestFetched.map { $0 < lastMonth.start } ?? false)

        return MonthlyTotals(
            distanceKm: thisMonthKm,
            workouts: thisMonthRuns.count,
            deltaKm: coversLastMonth ? thisMonthKm - lastMonthKm : nil
        )
    }

    private static func parseDate(_ isoDateTime: String?) -> Date? {
        App2WeekCalendar.parseISO8601(isoDateTime)
    }

    // MARK: - chip 列（設計 `recTabs`）

    /// 只交出**目前資料裡真的存在**的課型 —— 沒有間歇就不出現間歇 chip。
    ///
    /// 同一個顯示名可能對應多個 `DayType` raw value（`easy`／`easy_run` 都是
    /// 「輕鬆跑」），所以同名的合成一顆 chip、帶一組 `DayType`。這是對顯示字做
    /// **相等去重**，不是拿顯示字做關鍵字比對 —— 過濾條件仍然是結構化的 `DayType`。
    /// 順序沿用 `DayType.allCases`（＝ taxonomy 的宣告順序），不隨資料抖動。
    static func filters(for items: [App2RecordItem]) -> [App2RecordFilter] {
        let present = Set(items.compactMap { $0.row.dayType })
        guard present.count > 1 else { return [] }  // 只有一種課型時，chip 列沒有作用

        var order: [String] = []
        var buckets: [String: Set<DayType>] = [:]
        for type in DayType.allCases where present.contains(type) {
            let label = type.localizedName
            if buckets[label] == nil {
                order.append(label)
                buckets[label] = []
            }
            buckets[label]?.insert(type)
        }

        return [.all] + order.map { App2RecordFilter(types: buckets[$0] ?? [], label: $0) }
    }

    /// nil 或「全部」＝不過濾。沒有 `dayType` 的紀錄在選了課型後不出現。
    static func filtered(_ items: [App2RecordItem], by filter: App2RecordFilter?) -> [App2RecordItem] {
        guard let filter, !filter.isAll else { return items }
        return items.filter { item in
            guard let type = item.row.dayType else { return false }
            return filter.types.contains(type)
        }
    }

    // MARK: - 日期分組（設計 `g.group` / `g.count` / `g.sum`）

    /// 今天／昨天／本週稍早／上週／各月份。分組標題與小計格式沿用 1.x 紀錄頁
    /// 既有的 `record.group.*`（`TrainingRecordView` 也用這一組），不開第二份字串。
    ///
    /// 用裝置當地日曆；月份桶的 key 正規化到「月初」再當 Dictionary key。
    static func groups(
        _ items: [App2RecordItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [App2RecordGroup] {
        let sorted = items.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            default:           return false
            }
        }

        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        let lastWeek = thisWeek
            .flatMap { calendar.date(byAdding: .weekOfYear, value: -1, to: $0.start) }
            .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)

        var order: [App2RecordBucket] = []
        var buckets: [App2RecordBucket: [App2RecordItem]] = [:]

        for item in sorted {
            let bucket: App2RecordBucket
            if let date = item.date {
                if calendar.isDate(date, inSameDayAs: now) {
                    bucket = .today
                } else if let yesterday, calendar.isDate(date, inSameDayAs: yesterday) {
                    bucket = .yesterday
                } else if let thisWeek, thisWeek.contains(date) {
                    bucket = .earlierThisWeek
                } else if let lastWeek, lastWeek.contains(date) {
                    bucket = .lastWeek
                } else {
                    bucket = .month(calendar.dateInterval(of: .month, for: date)?.start ?? date)
                }
            } else {
                bucket = .undated
            }

            if buckets[bucket] == nil {
                order.append(bucket)
                buckets[bucket] = []
            }
            buckets[bucket]?.append(item)
        }

        return order.compactMap { bucket in
            guard let items = buckets[bucket], !items.isEmpty else { return nil }
            return App2RecordGroup(title: title(for: bucket, calendar: calendar), items: items)
        }
    }

    private static func title(for bucket: App2RecordBucket, calendar: Calendar) -> String {
        switch bucket {
        case .today:            return L10n.Record.Group.today.localized
        case .yesterday:        return L10n.Record.Group.yesterday.localized
        case .earlierThisWeek:  return L10n.Record.Group.earlierThisWeek.localized
        case .lastWeek:         return L10n.Record.Group.lastWeek.localized
        case .undated:          return L10n.Record.Group.older.localized
        case .month(let start):
            let parts = calendar.dateComponents([.year, .month], from: start)
            guard let year = parts.year, let month = parts.month else {
                return L10n.Record.Group.older.localized
            }
            return L10n.Record.Group.monthGroupFormat.localized(with: year, month)
        }
    }

    // MARK: - Mapping

    private static func map(item workout: WorkoutV2) -> App2RecordItem {
        let date = parseDate(workout.startTimeUtc)
        return App2RecordItem(
            row: map(workout: workout),
            date: date,
            distanceKm: workout.distanceMeters.map { $0 / 1000 },
            whenLabel: date.map(DateFormatterHelper.formatRelativeForWorkoutCard) ?? "—",
            workout: workout
        )
    }

    private static func map(entry: WorkoutStatsWeeklyEntry) -> App2WeeklyBar {
        App2WeeklyBar(
            weekStart: entry.weekStart,
            distanceKm: entry.distanceKm,
            isCurrentWeek: entry.isCurrentWeek,
            shortLabel: App2DateLabel.short(isoDate: entry.weekStart)
        )
    }

    private static func map(workout: WorkoutV2) -> App2WorkoutRow {
        let distanceKm = (workout.distanceMeters ?? 0) / 1000
        let dayType = workout.advancedMetrics?.trainingType
            .flatMap { DayType(rawValue: $0.lowercased()) }
        return App2WorkoutRow(
            id: workout.id,
            dateLabel: Self.shortLabel(isoDateTime: workout.startTimeUtc),
            // `training_type` 是後端識別字（`easy`／`interval`）。顯示字與顏色都走既有的
            // `DayType`，不把識別字直接印出來，也不對顯示字做詞表比對。
            tag: dayType?.localizedName ?? workout.advancedMetrics?.trainingType,
            dayType: dayType,
            distance: String(format: "%.1f km", distanceKm),
            pace: workout.basicMetrics?.avgPaceSPerKm.map(Self.paceLabel(secondsPerKm:)),
            duration: TimeFormatting.formatTime(workout.durationSeconds),
            vdot: workout.advancedMetrics?.dynamicVdot.map { String(format: "%.1f", $0) }
        )
    }

    // MARK: - Formatting

    /// workout 的 `start_time_utc` 是 UTC instant → 換成裝置當地日期再顯示。
    private static func shortLabel(isoDateTime: String?) -> String {
        guard let date = parseDate(isoDateTime) else { return "—" }
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return "—" }
        return "\(month)/\(day)"
    }

    /// 配速跟著用戶的單位制走（`/km`／`/mi`）。這裡原本寫死 `/km` 且不換算，
    /// 英制用戶看到的是公里配速掛著 `/km`（2026-08-26 架構收斂順修）。
    private static func paceLabel(secondsPerKm: Double) -> String {
        UnitManager.shared.formatPace(secondsPerKm: secondsPerKm)
    }
}
