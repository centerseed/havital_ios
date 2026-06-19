import AppIntents

struct WeeklyMileageIntent: AppIntent {
    static var title: LocalizedStringResource = "我這週跑多少"
    static var description = IntentDescription("念出本週累積跑量")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()
        let repo: WorkoutRepository = DependencyContainer.shared.resolve()
        let now = Date()

        // Use the app's Monday-start week boundary (WeekDateService.currentCalendarMonday()).
        // Calendar.current with .weekOfYear gives Sunday-first on default locale — do NOT use it.
        let start = WeekDateService.currentCalendarMonday() ?? now

        let all = await repo.getWorkoutsInDateRangeAsync(startDate: start, endDate: now)

        // Filter to "running" only — strict equality matching
        // AggregateWorkoutMetricsUseCase.calculateTotalDistance() in
        // Havital/Features/TrainingPlan/Domain/UseCases/AggregateWorkoutMetricsUseCase.swift:61.
        // The spoken sentence uses 跑 ("ran"), so running-only is the correct semantic.
        // NOTE: The WeekOverviewCardV2 hero card uses WeekMetricsCalculator which sums ALL
        // activity types (no running filter) as total-distance-toward-target — that number
        // differs from this one by design: the card tracks training load, Siri answers the
        // question "how far did I RUN this week." A product decision is needed if the user
        // wants Siri to match the card's total instead; see DONE_WITH_CONCERNS in task notes.
        let running = all.filter { $0.activityType == "running" }

        return .result(dialog: IntentDialog(stringLiteral: WeeklyMileageDialogBuilder.build(from: running)))
    }
}
