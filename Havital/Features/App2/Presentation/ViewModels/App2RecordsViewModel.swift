import Foundation

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
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    private let workoutDataSource: WorkoutStatsDataSourceProtocol

    init(workoutDataSource: WorkoutStatsDataSourceProtocol? = nil) {
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
    }

    deinit {
        cancelAllTasks()
    }

    func revalidate() async {
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        do {
            let stats = try await workoutDataSource.fetchWorkoutStats(days: 30, weeks: 8)
            // 月比要看到「上個月」，所以取回的筆數比清單顯示的多。
            // `/v2/workouts/stats` 只給滾動視窗（days）與 YTD，沒有日曆月的分桶，
            // 月量與月比在 client 端從同一批紀錄算，不新增端點。
            let rows = (try? await workoutDataSource.fetchRecentWorkouts(pageSize: Self.aggregationPageSize)) ?? []
            let month = Self.monthlyTotals(rows)

            records = App2Sourced(
                App2Records(
                    monthDistanceKm: month.distanceKm,
                    monthWorkouts: month.workouts,
                    monthDeltaKm: month.deltaKm,
                    ytdYear: stats.data.yearToDate?.year,
                    ytdDistanceKm: stats.data.yearToDate?.distanceKm,
                    ytdWorkouts: stats.data.yearToDate?.workoutCount,
                    weeklySeries: (stats.data.weeklySeries ?? []).map(Self.map(entry:)),
                    recentWorkouts: rows.prefix(Self.listPageSize).map(Self.map(workout:))
                ),
                origin: .live(endpoint: "GET /v2/workouts/stats + GET /v2/workouts")
            )
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）—— 下拉刷新的 task 被收掉時
            // in-flight 請求會回 -999。
            guard !error.isCancellationError else { return }
            Logger.debug("[App2RecordsVM] stats 取得失敗,退樣本: \(error)")
            guard records == nil else { return }    // SWR：重驗失敗時保留舊資料
            records = App2Sourced(
                App2StubFixtures.records,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
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
        guard let isoDateTime else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: isoDateTime) ?? ISO8601DateFormatter().date(from: isoDateTime)
    }

    // MARK: - Mapping

    private static func map(entry: WorkoutStatsWeeklyEntry) -> App2WeeklyBar {
        App2WeeklyBar(
            weekStart: entry.weekStart,
            distanceKm: entry.distanceKm,
            isCurrentWeek: entry.isCurrentWeek,
            shortLabel: Self.shortLabel(isoDate: entry.weekStart)
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
            duration: Self.durationLabel(seconds: workout.durationSeconds),
            vdot: workout.advancedMetrics?.dynamicVdot.map { String(format: "%.1f", $0) }
        )
    }

    // MARK: - Formatting

    /// `2026-08-24` → `8/24`。weekly_series 的 `week_start` 已是用戶當地日期字串，
    /// 不再過時區換算（數字 timestamp 才是 UTC）。
    private static func shortLabel(isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return isoDate }
        return "\(month)/\(day)"
    }

    /// workout 的 `start_time_utc` 是 UTC instant → 換成裝置當地日期再顯示。
    private static func shortLabel(isoDateTime: String?) -> String {
        guard let date = parseDate(isoDateTime) else { return "—" }
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return "—" }
        return "\(month)/\(day)"
    }

    private static func paceLabel(secondsPerKm: Double) -> String {
        let total = Int(secondsPerKm.rounded())
        return String(format: "%d:%02d/km", total / 60, total % 60)
    }

    private static func durationLabel(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
