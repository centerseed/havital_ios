#if DEBUG
import Foundation

enum UITestOnboardingHarness {
    static func registerDependencies() {
        DependencyContainer.shared.replace(
            UITestOnboardingTrainingPlanV2Repository() as TrainingPlanV2Repository,
            for: TrainingPlanV2Repository.self
        )
        DependencyContainer.shared.replace(
            UITestOnboardingTargetRepository() as TargetRepository,
            for: TargetRepository.self
        )
    }
}

private final class UITestOnboardingTargetRepository: TargetRepository {
    private var targets: [Target] = []

    func getTargets() async throws -> [Target] {
        targets
    }

    func getTarget(id: String) async throws -> Target {
        guard let target = targets.first(where: { $0.id == id }) else {
            throw NSError(domain: "UITestOnboardingTargetRepository", code: 404)
        }
        return target
    }

    func getMainTarget() async -> Target? {
        targets.first(where: \.isMainRace)
    }

    func getSupportingTargets() async -> [Target] {
        targets.filter { !$0.isMainRace }
    }

    func createTarget(_ target: Target) async throws -> Target {
        targets.removeAll(where: { $0.id == target.id })
        targets.append(target)
        return target
    }

    func updateTarget(id: String, target: Target) async throws -> Target {
        let updated = Target(
            id: id,
            type: target.type,
            name: target.name,
            distanceKm: target.distanceKm,
            targetTime: target.targetTime,
            targetPace: target.targetPace,
            raceDate: target.raceDate,
            isMainRace: target.isMainRace,
            trainingWeeks: target.trainingWeeks,
            timezone: target.timezone
        )
        targets.removeAll(where: { $0.id == id })
        targets.append(updated)
        return updated
    }

    func deleteTarget(id: String) async throws {
        targets.removeAll(where: { $0.id == id })
    }

    func forceRefresh() async throws -> [Target] {
        targets
    }

    func clearCache() {
        targets.removeAll()
    }

    func hasCache() -> Bool {
        !targets.isEmpty
    }
}

private final class UITestOnboardingTrainingPlanV2Repository: TrainingPlanV2Repository {
    private let targetTypes: [TargetTypeV2] = [
        TargetTypeV2(
            id: "race_run",
            name: "Specific Race",
            description: "Set a race goal and train toward it.",
            defaultMethodology: "paceriz",
            availableMethodologies: ["paceriz", "norwegian"]
        ),
        TargetTypeV2(
            id: "maintenance",
            name: "Maintain Fitness",
            description: "Keep a sustainable running rhythm.",
            defaultMethodology: "paceriz",
            availableMethodologies: ["paceriz", "polarized"]
        ),
        TargetTypeV2(
            id: "beginner",
            name: "Build Habit",
            description: "Progress gradually and enjoy running.",
            defaultMethodology: "paceriz",
            availableMethodologies: ["paceriz"]
        )
    ]

    private let methodologies: [MethodologyV2] = [
        MethodologyV2(
            id: "paceriz",
            name: "Paceriz",
            description: "Balanced progression with clear structure.",
            targetTypes: ["race_run", "maintenance", "beginner"],
            phases: ["base", "build", "peak"],
            crossTrainingEnabled: true
        ),
        MethodologyV2(
            id: "norwegian",
            name: "Norwegian",
            description: "Threshold-focused development for race goals.",
            targetTypes: ["race_run"],
            phases: ["base", "build", "peak"],
            crossTrainingEnabled: false
        ),
        MethodologyV2(
            id: "polarized",
            name: "Polarized",
            description: "Mostly easy with targeted harder efforts.",
            targetTypes: ["maintenance"],
            phases: ["base", "build"],
            crossTrainingEnabled: true
        )
    ]

    private var cachedOverview: PlanOverviewV2?
    private var cachedWeeklyPlan: WeeklyPlanV2?

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        let currentWeekPlanId = cachedWeeklyPlan?.effectivePlanId
        return PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: cachedOverview?.totalWeeks ?? 12,
            nextAction: currentWeekPlanId == nil ? "create_plan" : "view_plan",
            canGenerateNextWeek: currentWeekPlanId == nil,
            currentWeekPlanId: currentWeekPlanId,
            previousWeekSummaryId: nil,
            targetType: cachedOverview?.targetType ?? "maintenance",
            methodologyId: cachedOverview?.methodologyId ?? "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    func getTargetTypes() async throws -> [TargetTypeV2] {
        targetTypes
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        guard let targetType else { return methodologies }
        return methodologies.filter { $0.targetTypes.contains(targetType) }
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        let overview = makeOverview(
            targetId: targetId,
            targetType: "race_run",
            targetDescription: "Race goal",
            methodologyId: methodologyId ?? "paceriz",
            totalWeeks: 16,
            startFromStage: startFromStage ?? "base",
            distanceKm: 42.195,
            targetTime: 14_400
        )
        cachedOverview = overview
        cachedWeeklyPlan = nil
        return overview
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        let resolvedDistance = Double(intendedRaceDistanceKm ?? (targetType == "maintenance" ? 21 : 5))
        let overview = makeOverview(
            targetId: nil,
            targetType: targetType,
            targetDescription: targetType == "maintenance" ? "Maintain fitness" : "Build running habit",
            methodologyId: methodologyId ?? "paceriz",
            totalWeeks: trainingWeeks,
            startFromStage: startFromStage ?? "base",
            distanceKm: resolvedDistance,
            targetTime: nil
        )
        cachedOverview = overview
        cachedWeeklyPlan = nil
        return overview
    }

    func getOverview() async throws -> PlanOverviewV2 {
        cachedOverview ?? makeOverview(
            targetId: nil,
            targetType: "maintenance",
            targetDescription: "Maintain fitness",
            methodologyId: "paceriz",
            totalWeeks: 12,
            startFromStage: "base",
            distanceKm: 21,
            targetTime: nil
        )
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        try await getOverview()
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        let base = try await getOverview()
        let updated = makeOverview(
            targetId: base.targetId,
            targetType: base.targetType,
            targetDescription: base.targetDescription,
            methodologyId: methodologyId ?? base.methodologyId ?? "paceriz",
            totalWeeks: base.totalWeeks,
            startFromStage: startFromStage ?? base.startFromStage ?? "base",
            distanceKm: base.distanceKm,
            targetTime: base.targetTime
        )
        cachedOverview = updated
        cachedWeeklyPlan = nil
        return updated
    }

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        let planId = "ui_test_overview_\(weekOfTraining)"
        let weeklyPlan = WeeklyPlanV2(
            planId: planId,
            weekOfTraining: weekOfTraining,
            id: planId,
            purpose: "UITest onboarding weekly plan",
            weekOfPlan: weekOfTraining,
            totalWeeks: cachedOverview?.totalWeeks ?? 12,
            totalDistance: 28,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: ["Deterministic onboarding UI test plan"],
            days: makeWeeklyDays(),
            intensityTotalMinutes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
        cachedWeeklyPlan = weeklyPlan
        return weeklyPlan
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        cachedWeeklyPlan ?? makeGeneratedWeeklyPlan(weekOfTraining: weekOfTraining)
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        cachedWeeklyPlan ?? makeGeneratedWeeklyPlan(weekOfTraining: 1)
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        cachedWeeklyPlan ?? makeGeneratedWeeklyPlan(weekOfTraining: 1)
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        cachedWeeklyPlan ?? makeGeneratedWeeklyPlan(weekOfTraining: weekOfTraining)
    }

    func deleteWeeklyPlan(planId: String) async throws {
        cachedWeeklyPlan = nil
    }

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        WeeklyPreviewV2(
            id: overviewId,
            methodologyId: cachedOverview?.methodologyId ?? "paceriz",
            weeks: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        fatalError("Weekly summary is not expected in onboarding UI tests")
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        []
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        fatalError("Weekly summary is not expected in onboarding UI tests")
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        fatalError("Weekly summary is not expected in onboarding UI tests")
    }

    func deleteWeeklySummary(summaryId: String) async throws {}

    func getCachedPlanStatus() -> PlanStatusV2Response? {
        return PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: cachedOverview?.totalWeeks ?? 12,
            nextAction: cachedWeeklyPlan == nil ? "create_plan" : "view_plan",
            canGenerateNextWeek: cachedWeeklyPlan == nil,
            currentWeekPlanId: cachedWeeklyPlan?.effectivePlanId,
            previousWeekSummaryId: nil,
            targetType: cachedOverview?.targetType ?? "maintenance",
            methodologyId: cachedOverview?.methodologyId ?? "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    func getCachedOverview() -> PlanOverviewV2? {
        cachedOverview
    }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        cachedWeeklyPlan
    }

    func clearCache() async {
        cachedOverview = nil
        cachedWeeklyPlan = nil
    }

    func clearOverviewCache() async {
        cachedOverview = nil
    }

    func clearWeeklyPlanCache(weekOfTraining: Int?) async {
        cachedWeeklyPlan = nil
    }

    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}

    func preloadData() async {}

    private func makeGeneratedWeeklyPlan(weekOfTraining: Int) -> WeeklyPlanV2 {
        let days = makeWeeklyDays()
        let totalDistance = days.reduce(0.0) { partialResult, day in
            guard case let .run(activity)? = day.session?.primary else {
                return partialResult
            }
            return partialResult + (activity.distanceKm ?? 0)
        }
        let planId = "ui_test_overview_\(weekOfTraining)"
        let plan = WeeklyPlanV2(
            planId: planId,
            weekOfTraining: weekOfTraining,
            id: planId,
            purpose: "UITest onboarding weekly plan",
            weekOfPlan: weekOfTraining,
            totalWeeks: cachedOverview?.totalWeeks ?? 12,
            totalDistance: totalDistance,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: ["Deterministic onboarding UI test plan"],
            days: days,
            intensityTotalMinutes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
        cachedWeeklyPlan = plan
        return plan
    }

    private func makeWeeklyDays() -> [DayDetail] {
        if cachedOverview?.targetType == "beginner" {
            return [
                makeRunDay(dayIndex: 1, runType: "easy", target: "Easy run", reason: "Build confidence with relaxed aerobic work.", distanceKm: 4, pace: "6:40", targetIntensity: "low"),
                makeRestDay(dayIndex: 2, reason: "Recovery day to keep the routine sustainable."),
                makeRunDay(dayIndex: 3, runType: "easy", target: "Easy run", reason: "Keep the habit going without adding stress.", distanceKm: 4, pace: "6:35", targetIntensity: "low"),
                makeRestDay(dayIndex: 4, reason: "Extra recovery supports adaptation for new runners."),
                makeRunDay(dayIndex: 5, runType: "easy", target: "Easy run", reason: "Steady low-intensity volume.", distanceKm: 5, pace: "6:30", targetIntensity: "low"),
                makeRunDay(dayIndex: 6, runType: "long_run", target: "Long easy run", reason: "Extend endurance gently.", distanceKm: 6, pace: "6:45", targetIntensity: "low"),
                makeRestDay(dayIndex: 7, reason: "Full rest before the next week begins.")
            ]
        }

        return [
            makeRunDay(dayIndex: 1, runType: "easy", target: "Easy aerobic run", reason: "Build your weekly rhythm.", distanceKm: 6, pace: "6:10"),
            makeRunDay(dayIndex: 2, runType: "interval", target: "Speed intervals", reason: "Touch quality early in the week.", distanceKm: 8, pace: "5:05"),
            makeRestDay(dayIndex: 3, reason: "Absorb the previous quality session."),
            makeRunDay(dayIndex: 4, runType: "tempo", target: "Tempo effort", reason: "Practice sustained threshold work.", distanceKm: 7, pace: "5:30"),
            makeRunDay(dayIndex: 5, runType: "easy", target: "Easy shakeout", reason: "Stay loose before the weekend.", distanceKm: 4, pace: "6:20"),
            makeRunDay(dayIndex: 6, runType: "long_run", target: "Long easy run", reason: "Extend endurance safely.", distanceKm: 12, pace: "6:25"),
            makeRestDay(dayIndex: 7, reason: "Full rest to reset for next week.")
        ]
    }

    private func makeRunDay(
        dayIndex: Int,
        runType: String,
        target: String,
        reason: String,
        distanceKm: Double,
        pace: String,
        targetIntensity: String = "moderate"
    ) -> DayDetail {
        DayDetail(
            dayIndex: dayIndex,
            dayTarget: target,
            reason: reason,
            tips: "Stay relaxed and keep the effort controlled.",
            category: .run,
            session: TrainingSession(
                warmup: nil,
                primary: .run(
                    RunActivity(
                        runType: runType,
                        distanceKm: distanceKm,
                        distanceDisplay: nil,
                        distanceUnit: nil,
                        paceUnit: nil,
                        durationMinutes: Int((distanceKm * 60.0) / 6.0),
                        durationSeconds: nil,
                        pace: pace,
                        heartRateRange: nil,
                        interval: nil,
                        segments: nil,
                        description: target,
                        targetIntensity: targetIntensity
                    )
                ),
                cooldown: nil,
                supplementary: nil
            )
        )
    }

    private func makeRestDay(dayIndex: Int, reason: String) -> DayDetail {
        DayDetail(
            dayIndex: dayIndex,
            dayTarget: "Rest",
            reason: reason,
            tips: nil,
            category: .rest,
            session: nil
        )
    }

    private func makeOverview(
        targetId: String?,
        targetType: String,
        targetDescription: String?,
        methodologyId: String,
        totalWeeks: Int,
        startFromStage: String,
        distanceKm: Double?,
        targetTime: Int?
    ) -> PlanOverviewV2 {
        let methodologyName = methodologies.first(where: { $0.id == methodologyId })?.name ?? "Paceriz"
        return PlanOverviewV2(
            id: "ui_test_overview",
            targetId: targetId,
            targetType: targetType,
            targetDescription: targetDescription,
            methodologyId: methodologyId,
            totalWeeks: totalWeeks,
            startFromStage: startFromStage,
            raceDate: targetType == "race_run" ? Int(Date().addingTimeInterval(60 * 60 * 24 * 112).timeIntervalSince1970) : nil,
            distanceKm: distanceKm,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: targetType == "race_run" ? "5:41" : "6:00",
            targetTime: targetTime,
            isMainRace: targetType == "race_run",
            targetName: targetType == "race_run" ? "UITest Goal Race" : nil,
            methodologyOverview: MethodologyOverviewV2(
                name: methodologyName,
                philosophy: "Structured and sustainable progression.",
                intensityStyle: "balanced",
                intensityDescription: "80% easy / 15% moderate / 5% hard"
            ),
            targetEvaluate: "UITest target evaluation",
            approachSummary: "UITest onboarding overview summary",
            trainingStages: [
                TrainingStageV2(
                    stageId: "base",
                    stageName: "Base",
                    stageDescription: "Base phase",
                    weekStart: 1,
                    weekEnd: max(totalWeeks, 1),
                    trainingFocus: "Aerobic consistency",
                    targetWeeklyKmRange: TargetWeeklyKmRangeV2(low: 20, high: 32),
                    targetWeeklyKmRangeDisplay: nil,
                    intensityRatio: IntensityDistributionV2(low: 0.8, medium: 0.15, high: 0.05),
                    keyWorkouts: ["easy_run", "long_run"]
                )
            ],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: "ui-test",
            milestoneBasis: nil
        )
    }
}
#endif
