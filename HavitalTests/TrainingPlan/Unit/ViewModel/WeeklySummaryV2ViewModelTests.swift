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

    private func loadOverviewFixture(named name: String) throws -> PlanOverviewV2 {
        let data = try Self.loadFixtureData(directory: "PlanOverview", name: name)
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    private func loadWeeklyPlanFixture(named name: String) throws -> WeeklyPlanV2 {
        let data = try Self.loadFixtureData(directory: "WeeklyPlan", name: name)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private static func loadFixtureData(directory: String, name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = testDir
            .appendingPathComponent("APISchema/Fixtures/\(directory)/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    // MARK: - loadWeeklySummary Tests

    func testLoadWeeklySummary_Success_SetsLoadedState() async {
        // Given
        let summary = Self.makeTestSummary()
        mockRepository.weeklySummaryV2ToReturn = summary

        // When
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        XCTAssertEqual(mockRepository.getWeeklySummaryCallCount, 1)
        if case .loaded(let loadedSummary) = sut.summary.weeklySummary {
            XCTAssertEqual(loadedSummary.id, "summary_test_1")
            XCTAssertEqual(loadedSummary.trainingCompletion.percentage, 0.85)
            XCTAssertEqual(loadedSummary.trainingCompletion.completedSessions, 4)
            XCTAssertEqual(loadedSummary.weeklyHighlights.highlights.count, 1)
            XCTAssertEqual(loadedSummary.nextWeekAdjustments.items.count, 1)
        } else {
            XCTFail("Expected .loaded state, got \(sut.summary.weeklySummary)")
        }
    }

    func testLoadWeeklySummary_DomainError_SetsErrorState() async {
        // Given
        mockRepository.errorToThrow = DomainError.networkFailure("Network unavailable")

        // When
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .error(let error) = sut.summary.weeklySummary {
            if case .networkFailure(let message) = error {
                XCTAssertEqual(message, "Network unavailable")
            } else {
                XCTFail("Expected .networkFailure, got \(error)")
            }
        } else {
            XCTFail("Expected .error state, got \(sut.summary.weeklySummary)")
        }
    }

    func testLoadWeeklySummary_NonDomainError_MapsToUnknown() async {
        // Given
        mockRepository.errorToThrow = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])

        // When
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .error(let error) = sut.summary.weeklySummary {
            if case .unknown(let message) = error {
                XCTAssertEqual(message, "Unknown error")
            } else {
                XCTFail("Expected .unknown wrapper, got \(error)")
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
        await sut.summary.generateWeeklySummary()

        // Then
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
        if case .loaded(let loadedSummary) = sut.summary.weeklySummary {
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
        await sut.summary.generateWeeklySummary()

        // Then
        if case .error(let error) = sut.summary.weeklySummary {
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

    func testLoadWeeklySummary_DataCorruption_SetsEmptyAndDoesNotBlock() async {
        // Given
        mockRepository.errorToThrow = DomainError.dataCorruption("decode mismatch")

        // When
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .empty = sut.summary.weeklySummary {
            // expected
        } else {
            XCTFail("Expected .empty state for non-blocking data corruption, got \(sut.summary.weeklySummary)")
        }
        XCTAssertEqual(sut.successToast, NSLocalizedString("error.data_corruption", comment: "Data corruption"))
    }

    func testGenerateWeeklySummary_DataCorruption_SetsEmptyAndDoesNotBlock() async {
        // Given
        mockRepository.errorToThrow = DomainError.dataCorruption("decode mismatch")

        // When
        await sut.summary.generateWeeklySummary()

        // Then
        if case .empty = sut.summary.weeklySummary {
            // expected
        } else {
            XCTFail("Expected .empty state for non-blocking data corruption, got \(sut.summary.weeklySummary)")
        }
        XCTAssertEqual(sut.successToast, NSLocalizedString("error.data_corruption", comment: "Data corruption"))
    }

    // MARK: - State Transition Tests

    func testLoadWeeklySummary_TransitionsFromLoadingToLoaded() async {
        // Given
        let summary = Self.makeTestSummary()
        mockRepository.weeklySummaryV2ToReturn = summary

        // Initial state should be loading
        if case .loading = sut.summary.weeklySummary {
            // OK
        } else {
            XCTFail("Initial state should be .loading")
        }

        // When
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .loaded = sut.summary.weeklySummary {
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
        await sut.summary.loadWeeklySummary(weekOfPlan: 1)

        // Then
        if case .loaded(let loaded) = sut.summary.weeklySummary {
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
        sut.loader.currentWeek = 1
        sut.loader.planStatusResponse = PlanStatusV2Response(
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
        let weekToGenerate = await sut.generator.resolveWeekToGenerateAfterSummary(summaryWeek: 1)

        // Then
        XCTAssertEqual(weekToGenerate, 2)
    }

    func testResolveWeekToGenerateAfterSummary_FallbacksToSummaryPlusOne_WhenBackendMissing() async {
        // Given
        sut.loader.currentWeek = 1
        sut.loader.planStatusResponse = nil

        // When
        let weekToGenerate = await sut.generator.resolveWeekToGenerateAfterSummary(summaryWeek: 1)

        // Then
        XCTAssertEqual(weekToGenerate, 2)
    }

    func testResolveWeekToGenerateAfterSummary_MonToSatFlow_UsesBackendWeek() async {
        // Given: 週一到週六情境，currentWeek=3，回顧上週(summaryWeek=2)後應產生第 3 週
        sut.loader.currentWeek = 3
        sut.loader.planStatusResponse = PlanStatusV2Response(
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
        let weekToGenerate = await sut.generator.resolveWeekToGenerateAfterSummary(summaryWeek: 2)

        // Then
        XCTAssertEqual(weekToGenerate, 3)
    }

    func testResolveWeekToGenerateAfterSummary_PrefersBackendWeek_WhenAvailable() async {
        // Given: 後端可用時，直接使用後端值
        sut.loader.currentWeek = 5
        sut.loader.planStatusResponse = PlanStatusV2Response(
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
        let weekToGenerate = await sut.generator.resolveWeekToGenerateAfterSummary(summaryWeek: 4)

        // Then
        XCTAssertEqual(weekToGenerate, 7)
    }

    func testNextWeekButtonVisibility_showsWhenNextWeekCanGenerate_evenIfCurrentWeekPlanIsNotReady() {
        let nextWeekInfo = NextWeekInfoV2(
            weekNumber: 2,
            hasPlan: false,
            canGenerate: true,
            requiresCurrentWeekSummary: true,
            nextAction: "create_summary"
        )

        XCTAssertTrue(
            TrainingPlanV2View.shouldShowNextWeekButton(
                nextWeekInfo: nextWeekInfo,
                selectedWeek: 1,
                currentWeek: 1
            )
        )
    }

    func testRefreshWeeklyPlan_whenViewingNextWeek_refreshesSelectedWeekInsteadOfCurrentWeek() async throws {
        mockRepository.planStatusToReturn = PlanStatusV2Response(
            currentWeek: 1,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: true,
            currentWeekPlanId: "overview_001_1",
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
        mockRepository.overviewToReturn = try loadOverviewFixture(named: "race_run_paceriz")
        mockRepository.weeklyPlanV2ToReturn = try loadWeeklyPlanFixture(named: "paceriz_42k_base_week")

        sut.loader.planOverview = mockRepository.overviewToReturn
        sut.loader.currentWeek = 1
        sut.loader.selectedWeek = 2

        await sut.refreshWeeklyPlan()

        XCTAssertEqual(mockRepository.refreshWeeklyPlanCallCount, 1)
        XCTAssertEqual(mockRepository.lastRefreshedWeeklyPlanWeekOfTraining, 2)
        XCTAssertEqual(mockRepository.getWeeklyPlanCallCount, 0)
        XCTAssertEqual(sut.loader.selectedWeek, 2)
        if case .ready = sut.loader.planStatus {
            // expected
        } else {
            XCTFail("Expected refreshed selected week to remain visible, got \(sut.loader.planStatus)")
        }
    }
}

@MainActor
final class TrainingPlanV2InitializationRegressionTests: XCTestCase {

    private var sut: TrainingPlanV2ViewModel!
    private var workoutRepository: MockWorkoutRepository!

    override func setUp() async throws {
        try await super.setUp()
        workoutRepository = MockWorkoutRepository()

        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingVersionRouter.self) {
            container.registerTrainingVersionRouter()
        }
        let versionRouter: TrainingVersionRouter = container.resolve()

        sut = TrainingPlanV2ViewModel(
            repository: StartupStatusFailureButCachedPlanRepository(),
            workoutRepository: workoutRepository,
            versionRouter: versionRouter
        )
    }

    override func tearDown() async throws {
        sut = nil
        workoutRepository = nil
        try await super.tearDown()
    }

    func test_initialize_whenStartupNetworkFailsButCachedPlanExists_shouldStillShowCachedPlan() async {
        await sut.initialize()

        if case .ready(let plan) = sut.loader.planStatus {
            XCTAssertEqual(plan.id, "overview_001_3")
            XCTAssertEqual(plan.effectiveWeek, 3)
        } else {
            XCTFail("Expected cached weekly plan to remain visible, got \(sut.loader.planStatus)")
        }
    }
}

private final class StartupStatusFailureButCachedPlanRepository: TrainingPlanV2Repository {

    private let cachedOverview: PlanOverviewV2
    private let cachedPlan: WeeklyPlanV2

    init() {
        do {
            cachedOverview = try StartupStatusFailureButCachedPlanRepository.loadOverviewFixture(named: "race_run_paceriz")
            cachedPlan = try StartupStatusFailureButCachedPlanRepository.loadWeeklyPlanFixture(named: "paceriz_42k_base_week")
        } catch {
            fatalError("Failed to load V2 fixtures for regression test: \(error)")
        }
    }

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        throw DomainError.noConnection
    }

    func getTargetTypes() async throws -> [TargetTypeV2] { [] }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] { [] }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        cachedOverview
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        cachedOverview
    }

    func getOverview() async throws -> PlanOverviewV2 {
        cachedOverview
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        cachedOverview
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        cachedOverview
    }

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        cachedPlan
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        cachedPlan
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        cachedPlan
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        cachedPlan
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        cachedPlan
    }

    func deleteWeeklyPlan(planId: String) async throws {}

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        WeeklyPreviewV2(
            id: "overview_001",
            methodologyId: "paceriz",
            weeks: [],
            createdAt: nil,
            updatedAt: nil
        )
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        []
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {}

    func deleteWeeklySummary(summaryId: String) async throws {}

    func getCachedPlanStatus() -> PlanStatusV2Response? {
        PlanStatusV2Response(
            currentWeek: 3,
            totalWeeks: 16,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: cachedPlan.id,
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }

    func getCachedOverview() -> PlanOverviewV2? {
        cachedOverview
    }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        week == 3 ? cachedPlan : nil
    }

    func clearCache() async {}

    func clearOverviewCache() async {}

    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}

    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}

    func preloadData() async {}

    private static func loadOverviewFixture(named name: String) throws -> PlanOverviewV2 {
        let data = try loadFixtureData(directory: "PlanOverview", name: name)
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    private static func loadWeeklyPlanFixture(named name: String) throws -> WeeklyPlanV2 {
        let data = try loadFixtureData(directory: "WeeklyPlan", name: name)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private static func loadFixtureData(directory: String, name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = testDir
            .appendingPathComponent("APISchema/Fixtures/\(directory)/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }
}
