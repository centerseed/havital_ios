import AppIntents

struct WeeklyMileageIntent: AppIntent {
    static var title: LocalizedStringResource = "我這週跑多少"
    static var description = IntentDescription("念出本週累積跑量")
    static var openAppWhenRun: Bool = false

    /// Running activity types recognised by the backend.
    /// Mirrors the trimmable-activity-types set in WorkoutV2Models + the canonical
    /// "running" value used in AggregateWorkoutMetricsUseCase for run-distance sums.
    private static let runningActivityTypes: Set<String> = [
        "running",
        "indoor_running",
        "street_running",
        "track_running",
        "trail_running",
        "treadmill_running",
    ]

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()
        let repo: WorkoutRepository = DependencyContainer.shared.resolve()
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let all = await repo.getWorkoutsInDateRangeAsync(startDate: start, endDate: now)
        let running = all.filter { Self.runningActivityTypes.contains($0.activityType.lowercased()) }
        return .result(dialog: IntentDialog(stringLiteral: WeeklyMileageDialogBuilder.build(from: running)))
    }
}
