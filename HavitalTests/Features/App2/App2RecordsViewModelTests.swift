import XCTest
@testable import paceriz_dev

/// 紀錄頁：月量／月比投影 ＋ SWR 載入語意（`App2Revalidating`）。
///
/// SWR 用 `App2RecordsViewModel` 當代表（它的依賴只有一個兩方法的 protocol，
/// 是四個 2.0 ViewModel 裡最能單獨立起來的一個）。鎖住的是：
/// 首載會打、60 秒內不重打、超過門檻重打、下拉刷新無視門檻、重驗失敗保留舊資料。
@MainActor
final class App2RecordsViewModelTests: XCTestCase {

    // MARK: - Fake

    /// 記憶體版的冷啟快照。
    ///
    /// **測試一定要注入它。** 不注入就會落到 `App2FileSnapshotStore.shared`，
    /// 那支讀的是這台裝置／模擬器上這個帳號真正的落地檔 —— 於是「首載失敗要退樣本」
    /// 這種斷言會因為機器上剛好有快照而變成綠燈假象（2026-08-26 實際踩到）。
    private final class InMemorySnapshotStore: App2SnapshotStoring {
        private var storage: [App2SnapshotKey: Data] = [:]

        func load<Value: Decodable>(_ type: Value.Type, for key: App2SnapshotKey) -> App2Snapshot<Value>? {
            guard let data = storage[key], let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return nil
            }
            return App2Snapshot(value: value, fetchedAt: Date())
        }

        func save<Value: Encodable>(_ value: Value, for key: App2SnapshotKey) {
            storage[key] = try? JSONEncoder().encode(value)
        }

        func invalidate(_ keys: Set<App2SnapshotKey>) { keys.forEach { storage[$0] = nil } }
        func clearAll() { storage.removeAll() }
    }

    private func makeViewModel(
        _ source: WorkoutStatsDataSourceProtocol,
        snapshots: App2SnapshotStoring? = nil
    ) -> App2RecordsViewModel {
        App2RecordsViewModel(
            workoutDataSource: source,
            snapshots: snapshots ?? InMemorySnapshotStore()
        )
    }

    private final class FakeStatsSource: WorkoutStatsDataSourceProtocol {
        var statsJSON = """
        { "data": { "total_workouts": 3, "total_distance_km": 30.0,
                    "provider_distribution": {}, "activity_type_distribution": {},
                    "period_days": 30,
                    "weekly_series": [ { "week_start": "2026-08-17", "week_end": "2026-08-23",
                                         "distance_km": 12.5, "is_current_week": false } ],
                    "year_to_date": { "year": 2026, "start_date": "2026-01-01",
                                      "through_date": "2026-08-25",
                                      "distance_km": 530.0, "workout_count": 61 } } }
        """
        var workouts: [WorkoutV2] = []
        var statsError: Error?
        private(set) var statsCallCount = 0

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            statsCallCount += 1
            if let statsError { throw statsError }
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(statsJSON.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] {
            workouts
        }

        /// cursor nil ＝ 回 `workouts`；有 cursor ＝ 回 `olderPages[cursor]`（更舊的一頁）。
        var olderPages: [String: [WorkoutV2]] = [:]
        var nextCursorAfterFirstPage: String?

        var pageError: Error?

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            if let pageError { throw pageError }
            let pageWorkouts = cursor.map { olderPages[$0] ?? [] } ?? workouts
            let next = cursor == nil ? nextCursorAfterFirstPage : nil
            return WorkoutListResponse(
                workouts: pageWorkouts,
                pagination: PaginationInfo(
                    nextCursor: next,
                    prevCursor: nil,
                    hasMore: next != nil,
                    hasNewer: false,
                    oldestId: nil,
                    newestId: nil,
                    totalItems: nil,
                    pageSize: pageSize
                )
            )
        }
    }

    // MARK: - Helpers

    /// 這個月的第 n 天中午（避免測試在月初／月底跨月飄動）。
    private func dayOfThisMonth(_ day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? Date()
    }

    private func run(id: String, at date: Date, km: Double, type: String = "running") -> WorkoutV2 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return WorkoutV2(
            id: id, provider: "garmin", activityType: type,
            startTimeUtc: formatter.string(from: date), endTimeUtc: nil,
            durationSeconds: 3000, distanceMeters: km * 1000,
            distanceDisplay: nil, distanceUnit: nil, deviceName: nil,
            basicMetrics: nil, advancedMetrics: nil, createdAt: nil,
            schemaVersion: nil, storagePath: nil, dailyPlanSummary: nil,
            aiSummary: nil, shareCardContent: nil
        )
    }

    // MARK: - 月量與月比

    func test_monthlyTotals_emptyHistory_isZeroWithNoDelta() {
        let totals = App2RecordsViewModel.monthlyTotals([])
        XCTAssertEqual(totals.distanceKm, 0)
        XCTAssertEqual(totals.workouts, 0)
        // 一筆都沒有 ＝ 已經看完全部 → 上月也是 0，差為 0（不是「不知道」）。
        XCTAssertEqual(totals.deltaKm, 0)
    }

    func test_monthlyTotals_sumsThisMonthAndComparesToLastMonth() throws {
        let calendar = Calendar.current
        let thisMonth = dayOfThisMonth(1)
        let lastMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: thisMonth))

        let totals = App2RecordsViewModel.monthlyTotals([
            run(id: "a", at: thisMonth, km: 10),
            run(id: "b", at: thisMonth, km: 8),
            run(id: "c", at: lastMonth, km: 12)
        ])
        XCTAssertEqual(totals.distanceKm, 18, accuracy: 0.001)
        XCTAssertEqual(totals.workouts, 2)
        XCTAssertEqual(try XCTUnwrap(totals.deltaKm), 6, accuracy: 0.001)
    }

    /// 非跑步的活動不計入跑量。
    func test_monthlyTotals_ignoresNonRunActivities() {
        let totals = App2RecordsViewModel.monthlyTotals([
            run(id: "a", at: dayOfThisMonth(2), km: 10),
            run(id: "b", at: dayOfThisMonth(3), km: 30, type: "cycling")
        ])
        XCTAssertEqual(totals.distanceKm, 10, accuracy: 0.001)
        XCTAssertEqual(totals.workouts, 1)
    }

    /// 沒有 `start_time_utc` 的紀錄直接略過，不 crash、不算進任何一個月。
    func test_monthlyTotals_skipsWorkoutsWithoutStartTime() {
        let broken = WorkoutV2(
            id: "x", provider: "garmin", activityType: "running",
            startTimeUtc: nil, endTimeUtc: nil, durationSeconds: 100,
            distanceMeters: 99_000, distanceDisplay: nil, distanceUnit: nil,
            deviceName: nil, basicMetrics: nil, advancedMetrics: nil,
            createdAt: nil, schemaVersion: nil, storagePath: nil,
            dailyPlanSummary: nil, aiSummary: nil, shareCardContent: nil
        )
        let totals = App2RecordsViewModel.monthlyTotals([broken])
        XCTAssertEqual(totals.distanceKm, 0)
        XCTAssertEqual(totals.workouts, 0)
    }

    // MARK: - 分組／小計／篩選（設計 frame-10 的 recTabs 與 g.group/g.count/g.sum）

    /// 固定一個週三中午當「現在」，讓分組邊界不隨執行日飄動。
    private var fixedNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 26      // 週三
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }

    private func item(
        id: String,
        daysBeforeNow: Int,
        km: Double?,
        type: DayType? = nil
    ) -> App2RecordItem {
        let date = Calendar.current.date(byAdding: .day, value: -daysBeforeNow, to: fixedNow)
        return App2RecordItem(
            row: App2WorkoutRow(
                id: id,
                dateLabel: "8/\(26 - daysBeforeNow)",
                tag: type?.localizedName,
                dayType: type,
                distanceKm: km ?? 0,
                paceSecondsPerKm: nil,
                duration: "30:00",
                vdot: nil
            ),
            date: date,
            distanceKm: km,
            whenLabel: "—",
            // 分組／小計不看原始紀錄，這裡不需要它。
            workout: nil
        )
    }

    /// 週界測試要指定確切日期，不能用「幾天前」——那樣會跟著 `fixedNow` 走。
    private func item(id: String, date: Date, km: Double?) -> App2RecordItem {
        App2RecordItem(
            row: App2WorkoutRow(
                id: id,
                dateLabel: "—",
                tag: nil,
                dayType: nil,
                distanceKm: km ?? 0,
                paceSecondsPerKm: nil,
                duration: "30:00",
                vdot: nil
            ),
            date: date,
            distanceKm: km,
            whenLabel: "—",
            workout: nil
        )
    }

    /// `fixedNow` 是 8/26 週三，本週一是 8/24：前天（8/24）還在本週，不得標成「上週」，
    /// 它歸 8 月桶；6 天前（8/20）才是上一個日曆週。月份桶排在「上週」之後。
    func test_groups_splitsTodayYesterdayAndLastWeek() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "today", daysBeforeNow: 0, km: 5),
                item(id: "yesterday", daysBeforeNow: 1, km: 6),
                item(id: "twodays", daysBeforeNow: 2, km: 7),
                item(id: "sixdays", daysBeforeNow: 6, km: 8)
            ],
            now: fixedNow
        )

        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups[0].items.map(\.id), ["today"])
        XCTAssertEqual(groups[1].items.map(\.id), ["yesterday"])
        XCTAssertEqual(groups[2].items.map(\.id), ["sixdays"])
        XCTAssertEqual(groups[3].items.map(\.id), ["twodays"])
        XCTAssertEqual(groups[0].title, L10n.Record.Group.today.localized)
        XCTAssertEqual(groups[1].title, L10n.Record.Group.yesterday.localized)
        XCTAssertEqual(groups[2].title, L10n.Record.Group.lastWeek.localized)
        XCTAssertEqual(
            groups[3].title,
            L10n.Record.Group.monthGroupFormat.localized(with: 2026, 8),
            "本週非今天／昨天的紀錄歸月份桶，不叫「上週」"
        )
    }

    /// 「上週」＝上一個日曆週，週界固定在週一，不隨 locale 週首（zh-TW 是週日）飄：
    /// 在 9/2（週三）看，8/30（週日）是上週最後一天，8/31（週一）已經是本週。
    func test_groups_lastWeekIsCalendarWeekStartingMonday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar.firstWeekday = 1
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 8))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 8))!
        // 上上週 → 月份桶。
        let older = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 8))!

        let groups = App2RecordsViewModel.groups(
            [
                item(id: "sunday", date: sunday, km: 5.01),
                item(id: "monday", date: monday, km: 8.46),
                item(id: "older", date: older, km: 3)
            ],
            now: wednesday,
            calendar: calendar
        )

        let sundayGroup = groups.first { $0.items.contains { $0.id == "sunday" } }
        let mondayGroup = groups.first { $0.items.contains { $0.id == "monday" } }
        let olderGroup = groups.first { $0.items.contains { $0.id == "older" } }
        let augustTitle = L10n.Record.Group.monthGroupFormat.localized(with: 2026, 8)
        XCTAssertEqual(sundayGroup?.title, L10n.Record.Group.lastWeek.localized)
        XCTAssertEqual(mondayGroup?.title, augustTitle, "本週一不是上週")
        XCTAssertEqual(olderGroup?.title, augustTitle)
        XCTAssertEqual(groups.map(\.title), [L10n.Record.Group.lastWeek.localized, augustTitle],
                       "月份桶排在「上週」之後，同一個月不被切成兩段")
    }

    /// 更早的紀錄按月分桶：同一個月一定落在同一組（月初當 key，已正規化）。
    func test_groups_bucketsOlderRecordsByMonth() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "jun-a", daysBeforeNow: 70, km: 5),
                item(id: "jun-b", daysBeforeNow: 80, km: 5),
                item(id: "jul", daysBeforeNow: 45, km: 5)
            ],
            now: fixedNow
        )

        XCTAssertEqual(groups.count, 2, "6 月兩筆要合成同一組")
        XCTAssertEqual(groups[0].items.map(\.id), ["jul"])          // 新的在前
        XCTAssertEqual(groups[1].items.map(\.id), ["jun-a", "jun-b"])
    }

    func test_groups_subtotalSumsDistanceAndCount() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "a", daysBeforeNow: 0, km: 5.5),
                item(id: "b", daysBeforeNow: 0, km: 4.5)
            ],
            now: fixedNow
        )

        let today = groups.first
        XCTAssertEqual(today?.count, 2)
        XCTAssertEqual(today?.totalKm ?? 0, 10, accuracy: 0.001)
    }

    /// 沒有距離的紀錄（樣本）不計入小計，也不讓小計變成 0 以外的假數字。
    func test_groups_subtotalIgnoresUnknownDistance() {
        let groups = App2RecordsViewModel.groups(
            [item(id: "a", daysBeforeNow: 0, km: nil)],
            now: fixedNow
        )
        XCTAssertEqual(groups.first?.count, 1)
        XCTAssertEqual(groups.first?.totalKm ?? -1, 0, accuracy: 0.001)
    }

    /// chip 只列出資料裡真的存在的課型 —— 沒有間歇就沒有間歇 chip。
    func test_filters_onlyIncludeTypesPresentInData() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "b", daysBeforeNow: 1, km: 5, type: .longRun)
        ])

        XCTAssertEqual(filters.first?.id, "all")
        let labels = filters.map(\.label)
        XCTAssertTrue(labels.contains(DayType.easy.localizedName))
        XCTAssertTrue(labels.contains(DayType.longRun.localizedName))
        XCTAssertFalse(labels.contains(DayType.interval.localizedName), "資料裡沒有間歇就不該出現 chip")
    }

    /// 同顯示名的多個 raw value（`easy` / `easy_run`）合成一顆 chip，不重複兩顆。
    func test_filters_mergesTypesSharingTheSameLabel() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "b", daysBeforeNow: 1, km: 5, type: .easyRun),
            item(id: "c", daysBeforeNow: 2, km: 5, type: .interval)
        ])

        XCTAssertEqual(filters.count, 3, "全部 ＋ 輕鬆跑 ＋ 間歇")
        let easyFilter = filters.first { $0.label == DayType.easy.localizedName }
        XCTAssertEqual(easyFilter?.types, [.easy, .easyRun])
    }

    /// 只有一種課型時整列 chip 沒有作用 → 不出現。
    func test_filters_singleTypeProducesNoChips() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy)
        ])
        XCTAssertTrue(filters.isEmpty)
    }

    func test_filtered_keepsOnlySelectedTypes() throws {
        let items = [
            item(id: "easy", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "easyRun", daysBeforeNow: 1, km: 5, type: .easyRun),
            item(id: "interval", daysBeforeNow: 2, km: 5, type: .interval),
            item(id: "untyped", daysBeforeNow: 3, km: 5, type: nil)
        ]
        let filters = App2RecordsViewModel.filters(for: items)
        let easyFilter = try XCTUnwrap(filters.first { $0.label == DayType.easy.localizedName })

        XCTAssertEqual(
            App2RecordsViewModel.filtered(items, by: easyFilter).map(\.id),
            ["easy", "easyRun"]
        )
        // 「全部」不過濾，沒有課型的那一筆仍在。
        XCTAssertEqual(App2RecordsViewModel.filtered(items, by: App2RecordFilter.all).count, 4)
        XCTAssertEqual(App2RecordsViewModel.filtered(items, by: nil).count, 4)
    }

    // MARK: - 相對日期（設計 r.when）

    /// 今天的紀錄顯示「今天 HH:mm」，幾天前的顯示「N 天前」—— 兩者不同、且只有
    /// 今天那一筆帶時間。走既有的 `DateFormatterHelper`，不另做一份格式。
    func test_load_usesRelativeWhenLabels() async throws {
        let source = FakeStatsSource()
        source.workouts = [
            run(id: "today", at: Date().addingTimeInterval(-3600), km: 5),
            run(id: "old", at: Date().addingTimeInterval(-3 * 86_400), km: 5)
        ]
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.items.count, 2)
        let todayLabel = try XCTUnwrap(vm.items.first { $0.id == "today" }?.whenLabel)
        let oldLabel = try XCTUnwrap(vm.items.first { $0.id == "old" }?.whenLabel)
        XCTAssertNotEqual(todayLabel, oldLabel)
        XCTAssertTrue(todayLabel.contains(":"), "今天那一筆要帶時間：\(todayLabel)")
        XCTAssertFalse(oldLabel.contains(":"), "「N 天前」不帶時間：\(oldLabel)")
    }

    // MARK: - 單位切換（T-0366 外審 B07／E03）

    /// 切換公制／英制時這一頁要重投影一次，不能等 60 秒 SWR 視窗
    /// —— 與 `workout_processed` 那條同一個理由、同一個處置。
    ///
    /// 觀察點是「有沒有再向資料來源要一次」：這一頁的量有些是 View 現算的、
    /// 有些是投影時就組好的，唯一能證明整頁都換過的就是重跑一輪投影。
    func test_unitSystemChange_revalidatesSoProjectionsAreRebuilt() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = makeViewModel(source)
        await vm.loadIfNeeded()
        XCTAssertEqual(source.statsCallCount, 1)

        let manager = UnitManager.shared
        let original = manager.currentUnitSystem
        defer { manager.currentUnitSystem = original }
        manager.currentUnitSystem = original == .metric ? .imperial : .metric

        // 事件的訂閱通知走 `Task { @MainActor }`，讓出一次執行緒讓它跑完。
        for _ in 0..<50 where source.statsCallCount == 1 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(source.statsCallCount, 2, "切換單位後要重投影一次")

        // 還原也會發一次 fire-and-forget 事件，排空後再離開，不留給下一條測試。
        manager.currentUnitSystem = original
        for _ in 0..<50 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - 載入與 SWR

    func test_load_mapsStatsAndMonthlyTotals() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()

        let records = try XCTUnwrap(vm.records)
        XCTAssertEqual(records.value.ytdDistanceKm, 530)
        XCTAssertEqual(records.value.ytdWorkouts, 61)
        XCTAssertEqual(records.value.weeklySeries.count, 1)
        XCTAssertEqual(records.value.weeklySeries.first?.shortLabel, "8/17")
        XCTAssertEqual(records.value.monthDistanceKm, 7, accuracy: 0.001)
        XCTAssertFalse(records.origin.isStub)
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - 往更舊分頁（捲到底載入）

    /// 首屏只顯示 `listPageSize` 筆；捲到底先展開本地已取回的列。
    func test_loadMore_expandsLocallyFetchedRows() async {
        let source = FakeStatsSource()
        source.workouts = (0..<25).map {
            run(id: "w\($0)", at: Date().addingTimeInterval(Double(-$0) * 86_400), km: 5)
        }
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        XCTAssertEqual(vm.items.count, 20)
        XCTAssertTrue(vm.canLoadMore)

        await vm.loadMore()
        XCTAssertEqual(vm.items.count, 25)
        XCTAssertFalse(vm.canLoadMore, "本地展開完、後端也沒更舊 → sentinel 要消失")
    }

    /// 本地展開完但後端還有更舊 → 拿游標往後端要下一頁。
    func test_loadMore_fetchesOlderPageWithCursor() async {
        let source = FakeStatsSource()
        source.workouts = (0..<20).map {
            run(id: "w\($0)", at: Date().addingTimeInterval(Double(-$0) * 86_400), km: 5)
        }
        source.nextCursorAfterFirstPage = "c1"
        source.olderPages["c1"] = (20..<25).map {
            run(id: "w\($0)", at: Date().addingTimeInterval(Double(-$0) * 86_400), km: 5)
        }
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        XCTAssertEqual(vm.items.count, 20)
        XCTAssertTrue(vm.canLoadMore, "後端 hasMore → 還能往前")

        await vm.loadMore()
        XCTAssertEqual(vm.items.count, 25)
        XCTAssertFalse(vm.canLoadMore)
    }

    /// 清單分頁失敗、stats 成功：**保留上一輪的清單**，不得發布空 live 清單
    /// （2026-08-29 外審 D04/D07：「沒有紀錄」與「沒取到」是兩回事）。
    func test_revalidate_pageFailureKeepsPreviousRows() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "w1", at: dayOfThisMonth(2), km: 5)]
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        XCTAssertEqual(vm.items.count, 1)

        source.pageError = URLError(.timedOut)
        await vm.forceRefresh()

        XCTAssertEqual(vm.items.count, 1, "分頁失敗後既有清單必須保留")
        XCTAssertEqual(vm.items.first?.id, "w1")
        let records = try XCTUnwrap(vm.records)
        XCTAssertFalse(records.origin.isStub, "已有真資料時不得退樣本")
    }

    /// 冷啟（沒有任何舊清單）就遇到分頁失敗：走整體失敗路徑退樣本＋offline 徽章，
    /// 不畫一個看起來像「這個人沒跑過步」的空 live 清單。
    func test_revalidate_pageFailureWithNoPriorRowsFallsBackToStub() async throws {
        let source = FakeStatsSource()
        source.pageError = URLError(.timedOut)
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()

        let records = try XCTUnwrap(vm.records)
        XCTAssertTrue(records.origin.isStub)
    }

    func test_loadIfNeeded_withinStaleWindow_doesNotRefetch() async {
        let source = FakeStatsSource()
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        XCTAssertEqual(source.statsCallCount, 1)
    }

    func test_loadIfNeeded_pastStaleWindow_refetches() async {
        let source = FakeStatsSource()
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        // 門檻是參數，不用真的等 60 秒。
        await vm.loadIfNeeded(staleAfter: -1)

        XCTAssertEqual(source.statsCallCount, 2)
    }

    func test_forceRefresh_ignoresStaleWindow() async {
        let source = FakeStatsSource()
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()
        await vm.forceRefresh()

        XCTAssertEqual(source.statsCallCount, 2)
        XCTAssertFalse(vm.isLoading)
    }

    /// 重驗失敗保留舊資料 —— 不清畫面、也不換成樣本。
    func test_revalidateFailure_keepsPreviousData() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = makeViewModel(source)
        await vm.loadIfNeeded()
        let before = try XCTUnwrap(vm.records?.value)

        source.statsError = URLError(.timedOut)
        await vm.forceRefresh()

        XCTAssertEqual(vm.records?.value, before)
        XCTAssertFalse(vm.records?.origin.isStub ?? true)
    }

    /// **取消不是失敗。** 下拉刷新時 SwiftUI 收掉 refresh task，in-flight 請求
    /// 全部回 `-999`；當成失敗會把畫面上的真資料換成樣本
    /// （2026-08-25 在模擬器上實際看到：下拉一次，指標列從 live 變成「樣本 offline」）。
    func test_cancellationDuringRevalidate_keepsLiveData() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = makeViewModel(source)
        await vm.loadIfNeeded()
        let before = try XCTUnwrap(vm.records?.value)

        source.statsError = URLError(.cancelled)
        await vm.forceRefresh()

        XCTAssertEqual(vm.records?.value, before)
        XCTAssertFalse(vm.records?.origin.isStub ?? true, "取消後不得退樣本")
    }

    /// 首載被取消 → 保持沒有資料，也不假裝有（不退樣本）。
    func test_cancellationOnFirstLoad_doesNotFallBackToStub() async {
        let source = FakeStatsSource()
        source.statsError = URLError(.cancelled)
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()

        XCTAssertNil(vm.records)
        XCTAssertFalse(vm.isLoading)
    }

    /// 從沒載成功過就失敗 → 退樣本並掛徽章。
    func test_firstLoadFailure_fallsBackToStub() async {
        let source = FakeStatsSource()
        source.statsError = URLError(.notConnectedToInternet)
        let vm = makeViewModel(source)

        await vm.loadIfNeeded()

        XCTAssertTrue(vm.records?.origin.isStub ?? false)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Garmin badge（2026-08-27 走查裁決（o））

    /// Garmin 來源的判定與 1.4 `WorkoutV2RowView` 同一條 —— badge 是品牌合規要求，
    /// 判錯就是該掛沒掛。Apple Health 轉進來的那批 `provider` 是 `apple_health`，
    /// 只有 `device_name` 說得出來源，所以裝置名也要認。
    func test_isGarminSourced_matchesProviderOrDeviceName() {
        XCTAssertTrue(App2RecordsView.isGarminSourced(
            Self.workout(provider: "garmin", deviceName: nil)
        ))
        XCTAssertTrue(App2RecordsView.isGarminSourced(
            Self.workout(provider: "apple_health", deviceName: "Forerunner 965")
        ))
        XCTAssertTrue(App2RecordsView.isGarminSourced(
            Self.workout(provider: "apple_health", deviceName: "Garmin Fenix 7")
        ))
        XCTAssertFalse(App2RecordsView.isGarminSourced(
            Self.workout(provider: "strava", deviceName: nil)
        ))
        XCTAssertFalse(App2RecordsView.isGarminSourced(
            Self.workout(provider: "apple_health", deviceName: "Apple Watch")
        ))
    }

    private static func workout(provider: String, deviceName: String?) -> WorkoutV2 {
        WorkoutV2(
            id: "w", provider: provider, activityType: "running",
            startTimeUtc: nil, endTimeUtc: nil, durationSeconds: 1800,
            distanceMeters: 5000, distanceDisplay: nil, distanceUnit: nil,
            deviceName: deviceName, basicMetrics: nil, advancedMetrics: nil,
            createdAt: nil, schemaVersion: nil, storagePath: nil,
            dailyPlanSummary: nil, aiSummary: nil, shareCardContent: nil
        )
    }
}
