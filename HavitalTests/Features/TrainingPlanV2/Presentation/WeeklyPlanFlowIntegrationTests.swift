import XCTest
@testable import paceriz_dev

// MARK: - WeeklyPlanFlowIntegrationTests
//
// Integration-level tests for the Sunday vs Mon–Sat branching that drives
// "produce which week's summary / which week's plan."
//
// Wires three real coordinators (WeeklyPlanLoader + WeeklySummaryCoordinator +
// WeeklyPlanGenerator) against a mock repository — same composition as
// TrainingPlanV2ViewModel, minus the singleton dependencies (SubscriptionStateManager,
// DependencyContainer) that block pure-mock testing.
//
// Regression target: the sheet's "weekToShow" and generator's
// "resolveWeekToGenerateAfterSummary" must never drift away from the backend's
// nextWeekInfo / nextAction contract.

@MainActor
final class WeeklyPlanFlowIntegrationTests: XCTestCase {

    // MARK: - System Under Test

    private var mockRepository: MockTrainingPlanV2Repository!
    private var mockWorkoutRepository: MockWorkoutRepository!
    private var loader: WeeklyPlanLoader!
    private var summary: WeeklySummaryCoordinator!
    private var generator: WeeklyPlanGenerator!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanV2Repository()
        mockWorkoutRepository = MockWorkoutRepository()
        wireCoordinators()
    }

    override func tearDown() {
        generator = nil
        summary = nil
        loader = nil
        mockWorkoutRepository = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Wiring (mirrors TrainingPlanV2ViewModel minus singletons)

    private func wireCoordinators() {
        loader = WeeklyPlanLoader(
            repository: mockRepository,
            workoutRepository: mockWorkoutRepository,
            shouldSuppressError: { _, _, _ in false },
            onNetworkError: { _ in }
        )

        summary = WeeklySummaryCoordinator(
            repository: mockRepository,
            currentSelectedWeek: { [weak loader] in loader?.selectedWeek ?? 1 },
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: { false },
            refreshPlanStatusResponse: { [weak loader] in await loader?.refreshPlanStatusResponse() },
            shouldSuppressError: { _, _, _ in false },
            resolvePaywallTrigger: { .apiGated },
            onSuccessToast: { _ in },
            onPaywallTriggered: { _ in },
            onRizoQuotaExceeded: { },
            onNetworkError: { _ in },
            isEnforcementEnabled: { false }
        )

        generator = WeeklyPlanGenerator(
            repository: mockRepository,
            loader: loader,
            summary: summary,
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: { false },
            triggerPaywallIfEnforced: { },
            shouldSuppressError: { _, _, _ in false },
            onSuccessToast: { _ in },
            onRizoQuotaExceeded: { },
            onNetworkError: { _ in }
        )
    }

    // MARK: - Factories

    private func makePlanStatus(
        currentWeek: Int,
        nextAction: String = "view_plan",
        nextWeekInfo: NextWeekInfoV2? = nil,
        previousWeekSummaryId: String? = nil
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 12,
            nextAction: nextAction,
            canGenerateNextWeek: nextWeekInfo?.canGenerate ?? false,
            currentWeekPlanId: "plan-\(currentWeek)",
            previousWeekSummaryId: previousWeekSummaryId,
            targetType: "maintenance",
            methodologyId: "paceriz",
            nextWeekInfo: nextWeekInfo,
            metadata: nil
        )
    }

    private func makeOverview() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview-1",
            targetId: nil,
            targetType: "maintenance",
            targetDescription: "Test",
            methodologyId: "paceriz",
            totalWeeks: 12,
            startFromStage: "base",
            raceDate: nil,
            distanceKm: nil,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: "Test Plan",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func makeWeeklyPlan(week: Int) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "plan-\(week)",
            weekOfTraining: week,
            id: "plan-\(week)",
            purpose: "Test",
            weekOfPlan: week,
            totalWeeks: 12,
            totalDistance: 30,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            days: [],
            intensityTotalMinutes: nil,
            createdAt: Date(),
            updatedAt: Date(),
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
    }

    private func makeWeeklySummary(week: Int) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "summary-\(week)",
            uid: "user-1",
            weeklyPlanId: "plan-\(week)",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 80.0, plannedKm: 40.0, completedKm: 32.0,
                plannedSessions: 4, completedSessions: 3, evaluation: "Good"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil, pace: nil, distance: nil, intensityDistribution: nil
            ),
            readinessSummary: nil, capabilityProgression: nil, milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(highlights: [], achievements: [], areasForImprovement: []),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [], summary: "", methodologyConstraintsConsidered: true, basedOnFlags: []
            ),
            restWeekRecommendation: nil, finalTrainingReview: nil, promptAuditId: nil
        )
    }

    /// Replicates the View's `weekToShow` fallback chain exactly (TrainingPlanV2View.swift).
    /// Integration tests lock in the contract so regressions are impossible to miss.
    private func weekToShow() -> Int {
        if case .loaded(let loadedSummary) = summary.weeklySummary {
            return loadedSummary.weekOfTraining
        }
        if let requested = summary.lastRequestedSummaryWeek {
            return requested
        }
        return max(1, loader.currentWeek - 1)
    }

    // MARK: - Scenario 1: Sunday — generate CURRENT week summary + NEXT week plan

    /// Backend contract on Sunday (Week 2, last day):
    ///   currentWeek=2, nextAction=view_plan, nextWeekInfo={week=3, canGenerate=true,
    ///   hasPlan=false, requiresCurrentWeekSummary=true}
    ///
    /// When user taps "產生下週課表", generator must:
    ///  1. Detect requiresCurrentWeekSummary → route to summary for CURRENT week (=2)
    ///  2. lastRequestedSummaryWeek must be 2 (NOT currentWeek-1=1)
    ///  3. Sheet's weekToShow must resolve to 2
    ///  4. After summary, resolveWeekToGenerateAfterSummary must return 3 (from backend)
    func test_sundayFlow_generatesCurrentWeekSummaryThenNextWeekPlan() async {
        // Arrange: Sunday state
        let status = makePlanStatus(
            currentWeek: 2,
            nextAction: "view_plan",
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 3, hasPlan: false, canGenerate: true,
                requiresCurrentWeekSummary: true, nextAction: nil
            )
        )
        mockRepository.planStatusToReturn = status
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 2)

        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        // Act 1: user taps "generate next week plan"
        await generator.generateNextWeekPlan()

        // Assert 1: summary was generated for CURRENT week (2), not previous
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
        XCTAssertEqual(summary.lastRequestedSummaryWeek, 2,
                       "Sunday: summary must target CURRENT week (currentWeek), not currentWeek-1")
        XCTAssertEqual(weekToShow(), 2,
                       "Sunday: sheet must display CURRENT week, proving currentWeek-1 fallback was not used")
        // Weekly plan should NOT have been generated yet — requires summary first
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 0)

        // Act 2: summary done → resolve which week to generate a plan for
        let weekToGenerate = await generator.resolveWeekToGenerateAfterSummary(summaryWeek: 2)

        // Assert 2: resolved from backend nextWeekInfo.weekNumber (=3), not summaryWeek+1 fallback
        XCTAssertEqual(weekToGenerate, 3,
                       "Sunday: next plan must be week 3 (from backend), not fallback summaryWeek+1")
    }

    // MARK: - Scenario 2: Mon–Sat — generate PREVIOUS week summary

    /// Backend contract Mon–Sat when prior-week summary missing:
    ///   currentWeek=2, nextAction=create_summary
    ///
    /// View layer calls createWeeklySummaryAndShow(week: currentWeek-1=1).
    /// The week that the sheet displays MUST be 1, not 2.
    func test_monToSatFlow_generatesPreviousWeekSummary() async {
        // Arrange: Mon-Sat, needing last week's summary
        let status = makePlanStatus(currentWeek: 2, nextAction: "create_summary")
        mockRepository.planStatusToReturn = status
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 1)

        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        // Act: View path — user taps "產生第 1 週回顧" (currentWeek - 1)
        await summary.createWeeklySummaryAndShow(week: loader.currentWeek - 1)

        // Assert
        XCTAssertEqual(summary.lastRequestedSummaryWeek, 1)
        XCTAssertEqual(weekToShow(), 1,
                       "Mon-Sat: sheet must display previous week (currentWeek-1)")
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
    }

    // MARK: - Scenario 3: weekToShow fallback resilience when summary is not .loaded

    /// Simulates sheet being opened while summary is in .error state
    /// (e.g., user retrying after transient failure). Before the fix,
    /// fallback would drop to currentWeek-1, showing WRONG week on Sunday.
    func test_weekToShow_sundayFallback_usesLastRequestedNotCurrentMinusOne() async {
        // Arrange: Sunday state
        let status = makePlanStatus(currentWeek: 2, nextAction: "view_plan",
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 3, hasPlan: false, canGenerate: true,
                requiresCurrentWeekSummary: true, nextAction: nil
            )
        )
        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        // Coordinator is asked to generate for CURRENT week, but the repo call fails
        mockRepository.errorToThrow = DomainError.networkFailure("simulated")
        await summary.createWeeklySummaryAndShow(week: loader.currentWeek)

        // weeklySummary is NOT .loaded (failure path); must still resolve to 2.
        switch summary.weeklySummary {
        case .loaded:
            XCTFail("Precondition: summary should NOT be .loaded after error")
        default:
            break
        }
        XCTAssertEqual(summary.lastRequestedSummaryWeek, 2)
        XCTAssertEqual(weekToShow(), 2,
                       "Sunday with summary in error state: must still display CURRENT week, never currentWeek-1")
    }

    /// Mon–Sat counterpart: error state must NOT accidentally flip to currentWeek
    /// either — lastRequestedSummaryWeek=1 must be respected.
    func test_weekToShow_monToSatFallback_respectsLastRequested() async {
        let status = makePlanStatus(currentWeek: 2, nextAction: "create_summary")
        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        mockRepository.errorToThrow = DomainError.networkFailure("simulated")
        await summary.createWeeklySummaryAndShow(week: loader.currentWeek - 1)

        XCTAssertEqual(summary.lastRequestedSummaryWeek, 1)
        XCTAssertEqual(weekToShow(), 1)
    }

    // MARK: - Scenario 4: resolveWeekToGenerateAfterSummary fallback safety

    /// If backend omits nextWeekInfo (shouldn't happen, but defensive),
    /// generator must fallback to summaryWeek + 1 — regardless of Sunday or Mon–Sat.
    func test_resolveWeekAfterSummary_missingBackendInfo_fallsBackCorrectly() async {
        // Arrange: backend returns NO nextWeekInfo
        let status = makePlanStatus(currentWeek: 2, nextAction: "view_plan", nextWeekInfo: nil)
        mockRepository.planStatusToReturn = status
        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.planOverview = makeOverview()

        // Sunday-ish: summary was for week 2 → fallback must yield 3
        let sundayResolved = await generator.resolveWeekToGenerateAfterSummary(summaryWeek: 2)
        XCTAssertEqual(sundayResolved, 3)

        // Mon-Sat-ish: summary was for week 1 → fallback must yield 2 (this week's plan)
        let monSatResolved = await generator.resolveWeekToGenerateAfterSummary(summaryWeek: 1)
        XCTAssertEqual(monSatResolved, 2)
    }

    // MARK: - Scenario 5: full Sunday flow end-to-end (summary → next-week plan)

    /// Complete Sunday user journey: tap generate-next-week → summary produced →
    /// next-week plan produced with the week number backend dictated.
    func test_fullSundayFlow_summaryThenPlan_endToEnd() async {
        // Arrange: Sunday
        let initialStatus = makePlanStatus(
            currentWeek: 2, nextAction: "view_plan",
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 3, hasPlan: false, canGenerate: true,
                requiresCurrentWeekSummary: true, nextAction: nil
            )
        )
        mockRepository.planStatusToReturn = initialStatus
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 2)
        mockRepository.weeklyPlanV2ToReturn = makeWeeklyPlan(week: 3)
        mockRepository.overviewToReturn = makeOverview()

        loader.planStatusResponse = initialStatus
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        // Act: complete flow (mimics View's summary-sheet "generate next week" button)
        await generator.generateNextWeekPlan()                   // → summary for week 2
        let weekToGenerate = await generator.resolveWeekToGenerateAfterSummary(summaryWeek: 2)
        await generator.generateWeeklyPlanDirectly(weekNumber: weekToGenerate)

        // Assert: both side effects occurred in the right order with the right weeks
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1,
                       "Summary for current week must be produced first")
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 1,
                       "Next-week plan must be produced after summary")
        XCTAssertEqual(weekToGenerate, 3, "Backend's nextWeekInfo.weekNumber must drive target week")
        XCTAssertEqual(loader.selectedWeek, 3, "selectedWeek should track newly generated week")
        if case .ready(let plan) = loader.planStatus {
            XCTAssertEqual(plan.weekOfTraining, 3,
                           "Loaded plan must be the week backend told us to produce")
        } else {
            XCTFail("Expected loader.planStatus=.ready(week 3), got \(loader.planStatus)")
        }
        // Note: loader.currentWeek is backend-sourced and may be re-fetched as part of
        // refreshPlanStatusResponse inside generateWeeklyPlanDirectly. Its value is not
        // the contract under test here — weekToGenerate + loaded plan are.
    }
}
