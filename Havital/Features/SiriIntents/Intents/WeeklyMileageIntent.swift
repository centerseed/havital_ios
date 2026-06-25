import AppIntents

struct WeeklyMileageIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("voice.intent.weekly_mileage.title", defaultValue: "我這週跑多少")
    static var description = IntentDescription(LocalizedStringResource("voice.intent.weekly_mileage.desc", defaultValue: "念出本週累積跑量"))
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()

        // 1. Resolve version router — registered as TrainingVersionRouting protocol
        //    via registerTrainingVersionRouter() (see TrainingVersionRouter.swift).
        //    Type annotation drives the generic resolve<T>() call.
        let router: TrainingVersionRouting = DependencyContainer.shared.resolve()
        let isV2 = await router.isV2User()

        // 2. Fetch ALL cached workouts — mirrors WeeklyPlanLoader.loadWorkoutsForCurrentWeek(),
        //    which calls getAllWorkoutsAsync() and lets WeekMetricsCalculator filter by week
        //    boundary.  Pre-filtering to [monday, now] was a subset that excluded future-dated
        //    entries within the same week; using the full set ensures the number matches the
        //    on-screen V2 card BY CONSTRUCTION.
        let repo: WorkoutRepository = DependencyContainer.shared.resolve()
        let now = Date()
        let monday = WeekDateService.currentCalendarMonday() ?? now
        let allWorkouts = await repo.getAllWorkoutsAsync()

        // 3. Route by training version so Siri's number matches the on-screen number
        //    by construction — same computation path as the corresponding UI card.
        let dialog: String
        if isV2 {
            // V2 on-screen card (WeeklyPlanLoader.currentWeekDistance) is computed by
            // WeekMetricsCalculator.metrics(for:weekInfo:), which sums distanceMeters for
            // ALL activity types in the week range with no type filter.
            // Build a WeekDateInfo covering Monday → Sunday (same week boundary the app uses)
            // so the calculator can apply its date-range filter exactly as the UI does.
            let calendar = Calendar.current
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: monday)?.addingTimeInterval(86399) ?? now
            var daysMap: [Int: Date] = [:]
            for i in 0..<7 {
                if let d = calendar.date(byAdding: .day, value: i, to: monday) {
                    daysMap[i + 1] = d
                }
            }
            let weekInfo = WeekDateInfo(startDate: monday, endDate: weekEnd, daysMap: daysMap)

            // Reuse WeekMetricsCalculator — same function the WeekOverviewCardV2 hero calls.
            // Pass the full workout set; the calculator applies its own week-boundary filter
            // (startDate…endDate), exactly as WeeklyPlanLoader does.
            let weekMetrics = WeekMetricsCalculator.metrics(for: allWorkouts, weekInfo: weekInfo)

            // Count uses the same [startDate, endDate] window the calculator uses, so count
            // and distance are always computed over the identical set of workouts.
            let weekCount = allWorkouts.filter {
                $0.startDate >= weekInfo.startDate && $0.startDate <= weekInfo.endDate
            }.count

            // Use the precomputed totalKm overload — avoids double-summation and ensures
            // Siri's number is exactly WeekMetricsCalculator's output, not a re-sum.
            dialog = WeeklyMileageDialogBuilder.build(totalKm: weekMetrics.totalDistanceKm, count: weekCount)
        } else {
            // V1 on-screen card uses AggregateWorkoutMetricsUseCase.calculateTotalDistance(),
            // which filters strictly to activityType == "running".
            // V1 still uses a pre-filtered date range (Monday → now) for correctness with V1's
            // cumulative-to-date semantics; only V2 switches to getAllWorkoutsAsync + calculator.
            let allWeekWorkouts = await repo.getWorkoutsInDateRangeAsync(startDate: monday, endDate: now)
            let runningWorkouts = allWeekWorkouts.filter { $0.activityType == "running" }
            dialog = WeeklyMileageDialogBuilder.build(from: runningWorkouts)
        }

        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
