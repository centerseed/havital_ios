import XCTest
@testable import paceriz_dev

// MARK: - WeeklyPlanGeneratorTests

@MainActor
final class WeeklyPlanGeneratorTests: XCTestCase {

    // MARK: - Properties

    private var mockRepository: MockTrainingPlanV2Repository!
    private var mockWorkoutRepository: MockWorkoutRepository!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanV2Repository()
        mockWorkoutRepository = MockWorkoutRepository()
    }

    override func tearDown() {
        mockRepository = nil
        mockWorkoutRepository = nil
        super.tearDown()
    }

    // MARK: - Factory Helpers

    private func makeLoader() -> WeeklyPlanLoader {
        WeeklyPlanLoader(
            repository: mockRepository,
            workoutRepository: mockWorkoutRepository,
            shouldSuppressError: { _, _, _ in false },
            onNetworkError: { _ in }
        )
    }

    private func makeSummaryCoordinator(
        loader: WeeklyPlanLoader,
        shouldBlockByRizoQuota: @escaping () async -> Bool = { false }
    ) -> WeeklySummaryCoordinator {
        WeeklySummaryCoordinator(
            repository: mockRepository,
            currentSelectedWeek: { loader.selectedWeek },
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: shouldBlockByRizoQuota,
            refreshPlanStatusResponse: { await loader.refreshPlanStatusResponse() },
            shouldSuppressError: { _, _, _ in false },
            resolvePaywallTrigger: { .apiGated },
            onSuccessToast: { _ in },
            onPaywallTriggered: { _ in },
            onRizoQuotaExceeded: { },
            onNetworkError: { _ in },
            isEnforcementEnabled: { false }
        )
    }

    private func makeGenerator(
        loader: WeeklyPlanLoader,
        summary: WeeklySummaryCoordinator,
        setLoadingAnimation: @escaping (Bool) -> Void = { _ in },
        shouldBlockByRizoQuota: @escaping () async -> Bool = { false },
        triggerPaywallIfEnforced: @escaping () -> Void = {},
        onSuccessToast: @escaping (String) -> Void = { _ in },
        onRizoQuotaExceeded: @escaping () -> Void = {},
        onNetworkError: @escaping (Error) -> Void = { _ in }
    ) -> WeeklyPlanGenerator {
        WeeklyPlanGenerator(
            repository: mockRepository,
            loader: loader,
            summary: summary,
            setLoadingAnimation: setLoadingAnimation,
            shouldBlockByRizoQuota: shouldBlockByRizoQuota,
            triggerPaywallIfEnforced: triggerPaywallIfEnforced,
            shouldSuppressError: { _, _, _ in false },
            onSuccessToast: onSuccessToast,
            onRizoQuotaExceeded: onRizoQuotaExceeded,
            onNetworkError: onNetworkError
        )
    }

    private func makeWeeklyPlan(week: Int = 1) -> WeeklyPlanV2 {
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

    private func makePlanStatusWithNextWeekInfo(
        currentWeek: Int = 1,
        nextWeekNumber: Int = 2,
        requiresSummary: Bool = false
    ) -> PlanStatusV2Response {
        let nextWeekInfo = NextWeekInfoV2(
            weekNumber: nextWeekNumber,
            hasPlan: false,
            canGenerate: true,
            requiresCurrentWeekSummary: requiresSummary,
            nextAction: nil
        )
        return PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: "plan-\(currentWeek)",
            previousWeekSummaryId: nil,
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

    // MARK: - Test 1: generateCurrentWeekPlan success

    func test_generateCurrentWeekPlan_success_setsPlanAndToast() async {
        // Arrange
        let plan = makeWeeklyPlan(week: 1)
        mockRepository.weeklyPlanV2ToReturn = plan
        mockRepository.overviewToReturn = makeOverview()

        let loader = makeLoader()
        loader.selectedWeek = 1
        loader.planOverview = makeOverview()

        let summary = makeSummaryCoordinator(loader: loader)

        var capturedToast: String?
        let generator = makeGenerator(
            loader: loader,
            summary: summary,
            onSuccessToast: { capturedToast = $0 }
        )

        // Act
        await generator.generateCurrentWeekPlan()

        // Assert
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 1)
        if case .ready(let loadedPlan) = loader.planStatus {
            XCTAssertEqual(loadedPlan.id, plan.id)
        } else {
            XCTFail("Expected planStatus .ready, got \(loader.planStatus)")
        }
        XCTAssertEqual(loader.weeklyPlan?.id, plan.id)
        XCTAssertNotNil(capturedToast)
        XCTAssertTrue(capturedToast?.contains("1") == true)
    }

    // MARK: - Test 2: generateCurrentWeekPlan blocked by Rizo quota

    func test_generateCurrentWeekPlan_rizoQuotaBlocks_callsOnRizoQuotaExceeded() async {
        // Arrange
        let loader = makeLoader()
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()
        let summary = makeSummaryCoordinator(loader: loader, shouldBlockByRizoQuota: { true })

        var rizoExceededCalled = false
        var loadingAnimationValues: [Bool] = []

        let generator = makeGenerator(
            loader: loader,
            summary: summary,
            setLoadingAnimation: { loadingAnimationValues.append($0) },
            shouldBlockByRizoQuota: { true },
            onRizoQuotaExceeded: { rizoExceededCalled = true }
        )

        // Act
        await generator.generateCurrentWeekPlan()

        // Assert: quota exceeded callback was invoked, no repo call
        XCTAssertTrue(rizoExceededCalled)
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 0)
        // Loading animation should be turned off after block
        XCTAssertTrue(loadingAnimationValues.contains(false))
    }

    // MARK: - Test 3: generateCurrentWeekPlan throws subscriptionRequired → paywall

    func test_generateCurrentWeekPlan_subscriptionRequired_triggersPaywall() async {
        // Arrange
        mockRepository.errorToThrow = DomainError.subscriptionRequired
        let loader = makeLoader()
        loader.selectedWeek = 1
        loader.planOverview = makeOverview()
        let summary = makeSummaryCoordinator(loader: loader)

        var paywallTriggered = false
        let generator = makeGenerator(
            loader: loader,
            summary: summary,
            triggerPaywallIfEnforced: { paywallTriggered = true }
        )

        // Act
        await generator.generateCurrentWeekPlan()

        // Assert: paywall triggered, plan status not changed to error
        XCTAssertTrue(paywallTriggered)
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 1)
    }

    // MARK: - Test 4: generateNextWeekPlan requiresSummary → creates summary

    func test_generateNextWeekPlan_requiresSummary_callsSummaryCoordinator() async {
        // Arrange: next week requires summary
        let status = makePlanStatusWithNextWeekInfo(
            currentWeek: 2,
            nextWeekNumber: 3,
            requiresSummary: true
        )
        let weeklySummary = WeeklySummaryV2(
            id: "s1",
            uid: "user-1",
            weeklyPlanId: "plan-2",
            trainingOverviewId: "overview-1",
            weekOfTraining: 2,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 80.0,
                plannedKm: 40.0,
                completedKm: 32.0,
                plannedSessions: 4,
                completedSessions: 3,
                evaluation: "Good"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: nil,
                intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: [],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [],
                summary: "Keep it up",
                methodologyConstraintsConsidered: true,
                basedOnFlags: []
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil
        )

        mockRepository.planStatusToReturn = status
        mockRepository.weeklySummaryV2ToReturn = weeklySummary

        let loader = makeLoader()
        loader.planStatusResponse = status
        loader.currentWeek = 2
        loader.selectedWeek = 2
        loader.planOverview = makeOverview()

        let summary = makeSummaryCoordinator(loader: loader)
        let generator = makeGenerator(loader: loader, summary: summary)

        // Act
        await generator.generateNextWeekPlan()

        // Assert: generateWeeklySummary was called (via createWeeklySummaryAndShow)
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
        // No weekly plan generation should have occurred
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 0)
    }

    // MARK: - Test 5: generateWeeklyPlanDirectly success → refreshes status and workouts

    func test_generateWeeklyPlanDirectly_success_refreshesPlanStatusAndWorkouts() async {
        // Arrange
        let plan = makeWeeklyPlan(week: 3)
        let status = makePlanStatusWithNextWeekInfo(currentWeek: 3, nextWeekNumber: 4)
        mockRepository.weeklyPlanV2ToReturn = plan
        mockRepository.planStatusToReturn = status
        mockRepository.overviewToReturn = makeOverview()

        let loader = makeLoader()
        loader.planOverview = makeOverview()

        let summary = makeSummaryCoordinator(loader: loader)
        let generator = makeGenerator(loader: loader, summary: summary)

        // Act
        await generator.generateWeeklyPlanDirectly(weekNumber: 3)

        // Assert
        XCTAssertEqual(mockRepository.generateWeeklyPlanCallCount, 1)
        // planStatusResponse refresh should be called
        XCTAssertGreaterThanOrEqual(mockRepository.getPlanStatusCallCount, 1)
        // Loader state updated
        XCTAssertEqual(loader.currentWeek, 3)
        XCTAssertEqual(loader.selectedWeek, 3)
        if case .ready(let p) = loader.planStatus {
            XCTAssertEqual(p.id, plan.id)
        } else {
            XCTFail("Expected .ready, got \(loader.planStatus)")
        }
    }

    // MARK: - Test 6: updateOverview success → clears cache and reloads status

    func test_updateOverview_success_clearsCacheAndReloadsStatus() async {
        // Arrange
        let updatedOverview = makeOverview()
        mockRepository.overviewToReturn = updatedOverview
        mockRepository.planStatusToReturn = makePlanStatusWithNextWeekInfo()

        let loader = makeLoader()
        loader.planOverview = makeOverview()

        let summary = makeSummaryCoordinator(loader: loader)

        var capturedToast: String?
        let generator = makeGenerator(
            loader: loader,
            summary: summary,
            onSuccessToast: { capturedToast = $0 }
        )

        // Act
        await generator.updateOverview(startFromStage: "base")

        // Assert
        XCTAssertEqual(mockRepository.updateOverviewCallCount, 1)
        XCTAssertEqual(mockRepository.lastUpdatedOverviewStartFromStage, "base")
        XCTAssertEqual(mockRepository.clearCacheCallCount, 1)
        // loadPlanStatus was called
        XCTAssertGreaterThanOrEqual(mockRepository.getPlanStatusCallCount, 1)
        XCTAssertNotNil(capturedToast)
        // loader.planOverview should be updated
        XCTAssertEqual(loader.planOverview?.id, updatedOverview.id)
    }
}
