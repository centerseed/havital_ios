import Foundation

// MARK: - App2RecordsViewModel
/// Presentation Layer — 2.0 紀錄頁（`DESIGN-app2-decision-chain-api.md` §3.6）。
///
/// 三個 bucket 一次拿完：30 天滾動視窗、近 8 週跑量序列、當地年 YTD，全部來自
/// `GET /v2/workouts/stats`（T-0304 把 `weekly_series`／`year_to_date` 做實）。
/// 清單另走 `GET /v2/workouts`；課型標籤在 row 的 `training_type`（後端已抬到頂層）。
@MainActor
final class App2RecordsViewModel: ObservableObject, TaskManageable {

    @Published private(set) var isLoading = true
    @Published private(set) var records: App2Sourced<App2Records>?

    nonisolated let taskRegistry = TaskRegistry()

    private let workoutDataSource: WorkoutRemoteDataSource

    init(workoutDataSource: WorkoutRemoteDataSource? = nil) {
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
    }

    deinit {
        cancelAllTasks()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let stats = try await workoutDataSource.fetchWorkoutStats(days: 30, weeks: 8)
            let rows = (try? await workoutDataSource.fetchRecentWorkouts(pageSize: 20)) ?? []

            records = App2Sourced(
                App2Records(
                    windowDays: stats.data.periodDays,
                    windowDistanceKm: stats.data.totalDistanceKm,
                    windowWorkouts: stats.data.totalWorkouts,
                    ytdYear: stats.data.yearToDate?.year,
                    ytdDistanceKm: stats.data.yearToDate?.distanceKm,
                    ytdWorkouts: stats.data.yearToDate?.workoutCount,
                    weeklySeries: (stats.data.weeklySeries ?? []).map(Self.map(entry:)),
                    recentWorkouts: rows.map(Self.map(workout:))
                ),
                origin: .live(endpoint: "GET /v2/workouts/stats + GET /v2/workouts")
            )
        } catch {
            Logger.debug("[App2RecordsVM] stats 取得失敗,退樣本: \(error)")
            records = App2Sourced(
                App2StubFixtures.records,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
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
        return App2WorkoutRow(
            id: workout.id,
            dateLabel: Self.shortLabel(isoDateTime: workout.startTimeUtc),
            tag: workout.advancedMetrics?.trainingType,
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
        guard let isoDateTime else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoDateTime)
            ?? ISO8601DateFormatter().date(from: isoDateTime)
        guard let date else { return "—" }
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
