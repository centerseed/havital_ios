//
//  WeeklySummaryV2ViewModelTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanV2ViewModel's weekly summary methods
//

import XCTest
@testable import paceriz_dev

@MainActor
final class WeeklySummaryV2ViewModelTests: XCTestCase {

    var sut: TrainingPlanV2ViewModel!
    var mockRepository: MockTrainingPlanV2Repository!
    var mockWorkoutRepository: MockWorkoutRepository!

    // MARK: - Test Fixtures

    static func makeTestSummary(
        id: String = "summary_test_1",
        weekOfTraining: Int = 1,
        percentage: Double = 0.85,
        plannedKm: Double = 30.0,
        completedKm: Double = 25.5,
        plannedSessions: Int = 5,
        completedSessions: Int = 4
    ) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: id,
            uid: "user_1",
            weeklyPlanId: "plan_1",
            trainingOverviewId: "overview_1",
            weekOfTraining: weekOfTraining,
            createdAt: Date(),
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: percentage,
                plannedKm: plannedKm,
                completedKm: completedKm,
                plannedSessions: plannedSessions,
                completedSessions: completedSessions,
                evaluation: "Good progress"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: DistanceAnalysisV2(
                    total: completedKm,
                    comparisonToPlan: "On track",
                    longRunCompleted: true,
                    evaluation: "Good"
                ),
                intensityDistribution: IntensityDistributionAnalysisV2(
                    easyPercentage: 70,
                    moderatePercentage: 20,
                    hardPercentage: 10,
                    targetDistribution: "80/10/10",
                    evaluation: "Slightly too much moderate"
                )
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: ["Completed long run"],
                achievements: ["New distance PR"],
                areasForImprovement: ["Pacing consistency"]
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [
                    AdjustmentItemV2(
                        content: "Increase easy run volume",
                        category: "volume",
                        apply: true,
                        slotType: nil,
                        trainingType: nil,
                        reason: "Build aerobic base",
                        impact: "Better endurance",
                        sourceFlag: nil,
                        priority: "high"
                    )
                ],
                summary: "Focus on volume increase",
                methodologyConstraintsConsidered: true,
                basedOnFlags: []
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil
        )
    }

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTrainingPlanV2Repository()
        mockWorkoutRepository = MockWorkoutRepository()

        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingVersionRouter.self) {
            container.registerTrainingVersionRouter()
        }
        let versionRouter: TrainingVersionRouter = container.resolve()

        sut = TrainingPlanV2ViewModel(
            repository: mockRepository,
            workoutRepository: mockWorkoutRepository,
            versionRouter: versionRouter
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        mockWorkoutRepository = nil
        try await super.tearDown()
    }

    // MARK: - loadWeeklySummary Tests

    func testLoadWeeklySummary_Success_SetsLoadedState() async {
        // Given
        let summary = Self.makeTestSummary()
        mockRepository.weeklySummaryV2ToReturn = summary

        // When
        await sut.loadWeeklySummary(weekOfPlan: 1)

        // Then
        XCTAssertEqual(mockRepository.getWeeklySummaryCallCount, 1)
        if case .loaded(let loadedSummary) = sut.weeklySummary {
            XCTAssertEqual(loadedSummary.id, "summary_test_1")
            XCTAssertEqual(loadedSummary.trainingCompletion.percentage, 0.85)
            XCTAssertEqual(loadedSummary.trainingCompletion.completedSessions, 4)
            XCTAssertEqual(loadedSummary.weeklyHighlights.highlights.count, 1)
            XCTAssertEqual(loadedSummary.nextWeekAdjustments.items.count, 1)
        } else {
            XCTFail("Expected .loaded state, got \(sut.weeklySummary)")
        }
    }

    func testLoadWeeklySummary_DomainError_SetsErrorState() async {
        // Given
        mockRepository.errorToThrow = DomainError.networkFailure("Network unavailable")

        // When
        await sut.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .error(let error) = sut.weeklySummary {
            if case .networkFailure(let message) = error {
                XCTAssertEqual(message, "Network unavailable")
            } else {
                XCTFail("Expected .networkFailure, got \(error)")
            }
        } else {
            XCTFail("Expected .error state, got \(sut.weeklySummary)")
        }
    }

    func testLoadWeeklySummary_NonDomainError_WrapsAsNetworkFailure() async {
        // Given
        mockRepository.errorToThrow = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])

        // When
        await sut.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .error(let error) = sut.weeklySummary {
            if case .networkFailure = error {
                // OK - non-domain errors are wrapped as networkFailure
            } else {
                XCTFail("Expected .networkFailure wrapper, got \(error)")
            }
        } else {
            XCTFail("Expected .error state")
        }
    }

    // MARK: - generateWeeklySummary Tests

    func testGenerateWeeklySummary_Success_SetsLoadedStateAndToast() async {
        // Given
        let summary = Self.makeTestSummary(id: "generated_1")
        mockRepository.weeklySummaryV2ToReturn = summary

        // When
        await sut.generateWeeklySummary()

        // Then
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
        if case .loaded(let loadedSummary) = sut.weeklySummary {
            XCTAssertEqual(loadedSummary.id, "generated_1")
        } else {
            XCTFail("Expected .loaded state")
        }
        XCTAssertNotNil(sut.successToast)
    }

    func testGenerateWeeklySummary_Failure_SetsErrorState() async {
        // Given
        mockRepository.errorToThrow = DomainError.serverError(500, "Server error")

        // When
        await sut.generateWeeklySummary()

        // Then
        if case .error(let error) = sut.weeklySummary {
            if case .serverError = error {
                // Expected
            } else {
                XCTFail("Expected .serverError, got \(error)")
            }
        } else {
            XCTFail("Expected .error state")
        }
        XCTAssertNil(sut.successToast)
    }

    // MARK: - State Transition Tests

    func testLoadWeeklySummary_TransitionsFromLoadingToLoaded() async {
        // Given
        let summary = Self.makeTestSummary()
        mockRepository.weeklySummaryV2ToReturn = summary

        // Initial state should be loading
        if case .loading = sut.weeklySummary {
            // OK
        } else {
            XCTFail("Initial state should be .loading")
        }

        // When
        await sut.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .loaded = sut.weeklySummary {
            // OK
        } else {
            XCTFail("Expected .loaded after successful load")
        }
    }

    // MARK: - Data Integrity Tests

    func testLoadWeeklySummary_PreservesAllSummaryFields() async {
        // Given
        let summary = Self.makeTestSummary(
            percentage: 0.92,
            plannedKm: 40.0,
            completedKm: 36.8,
            plannedSessions: 6,
            completedSessions: 6
        )
        mockRepository.weeklySummaryV2ToReturn = summary

        // When
        await sut.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .loaded(let loaded) = sut.weeklySummary {
            // Completion
            XCTAssertEqual(loaded.trainingCompletion.percentage, 0.92)
            XCTAssertEqual(loaded.trainingCompletion.plannedKm, 40.0)
            XCTAssertEqual(loaded.trainingCompletion.completedKm, 36.8)
            XCTAssertEqual(loaded.trainingCompletion.plannedSessions, 6)
            XCTAssertEqual(loaded.trainingCompletion.completedSessions, 6)

            // Analysis
            XCTAssertNotNil(loaded.trainingAnalysis.distance)
            XCTAssertNotNil(loaded.trainingAnalysis.intensityDistribution)
            XCTAssertEqual(loaded.trainingAnalysis.intensityDistribution?.easyPercentage, 70)

            // Highlights
            XCTAssertEqual(loaded.weeklyHighlights.highlights, ["Completed long run"])
            XCTAssertEqual(loaded.weeklyHighlights.achievements, ["New distance PR"])
            XCTAssertEqual(loaded.weeklyHighlights.areasForImprovement, ["Pacing consistency"])

            // Adjustments
            XCTAssertEqual(loaded.nextWeekAdjustments.items.first?.priority, "high")
            XCTAssertEqual(loaded.nextWeekAdjustments.items.first?.category, "volume")
        } else {
            XCTFail("Expected .loaded state")
        }
    }

    // MARK: - Week Resolution Tests

    func testResolveWeekToGenerateAfterSummary_UsesBackendNextWeekInfo_OnSundayLikeState() async {
        // Given: currentWeek 尚未切到下一週（例如週日），但後端 nextWeekInfo 已指出應產生第 2 週
        sut.currentWeek = 1
        sut.planStatusResponse = PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: "plan_week_1",
            previousWeekSummaryId: "summary_week_1",
            targetType: "race",
            methodologyId: nil,
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 2,
                hasPlan: false,
                canGenerate: true,
                requiresCurrentWeekSummary: false,
                nextAction: "create_plan"
            ),
            metadata: nil
        )

        // When
        let weekToGenerate = await sut.resolveWeekToGenerateAfterSummary(summaryWeek: 1)

        // Then
        XCTAssertEqual(weekToGenerate, 2)
    }

    func testResolveWeekToGenerateAfterSummary_FallbacksToSummaryPlusOne_WhenBackendMissing() async {
        // Given
        sut.currentWeek = 1
        sut.planStatusResponse = nil

        // When
        let weekToGenerate = await sut.resolveWeekToGenerateAfterSummary(summaryWeek: 1)

        // Then
        XCTAssertEqual(weekToGenerate, 2)
    }

    func testResolveWeekToGenerateAfterSummary_MonToSatFlow_UsesBackendWeek() async {
        // Given: 週一到週六情境，currentWeek=3，回顧上週(summaryWeek=2)後應產生第 3 週
        sut.currentWeek = 3
        sut.planStatusResponse = PlanStatusV2Response(
            currentWeek: 3,
            totalWeeks: 12,
            nextAction: "create_summary",
            canGenerateNextWeek: false,
            currentWeekPlanId: nil,
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: nil,
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 3,
                hasPlan: false,
                canGenerate: true,
                requiresCurrentWeekSummary: false,
                nextAction: "create_plan"
            ),
            metadata: nil
        )

        // When
        let weekToGenerate = await sut.resolveWeekToGenerateAfterSummary(summaryWeek: 2)

        // Then
        XCTAssertEqual(weekToGenerate, 3)
    }

    func testResolveWeekToGenerateAfterSummary_PrefersBackendWeek_WhenAvailable() async {
        // Given: 後端可用時，直接使用後端值
        sut.currentWeek = 5
        sut.planStatusResponse = PlanStatusV2Response(
            currentWeek: 5,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: "plan_week_5",
            previousWeekSummaryId: "summary_week_4",
            targetType: "race",
            methodologyId: nil,
            nextWeekInfo: NextWeekInfoV2(
                weekNumber: 7,
                hasPlan: false,
                canGenerate: true,
                requiresCurrentWeekSummary: false,
                nextAction: "create_plan"
            ),
            metadata: nil
        )

        // When
        let weekToGenerate = await sut.resolveWeekToGenerateAfterSummary(summaryWeek: 4)

        // Then
        XCTAssertEqual(weekToGenerate, 7)
    }
}
