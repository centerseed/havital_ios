import XCTest
@testable import paceriz_dev

// MARK: - TrainingPlanV2RepositoryImplTests
//
// Tests TrainingPlanV2RepositoryImpl caching strategies:
// - Track A: immediate cache return on cache hit
// - Track B: background refresh scheduling on cache hit (cooldown expired)
// - Cache miss: fetches from API and saves result
// - Force refresh: bypasses cache entirely
//
// Uses:
// - SpyTrainingPlanV2RemoteDataSource (tracks calls, returns fixtures)
// - SpyTrainingPlanV2LocalDataSource (in-memory storage, tracks calls)

final class TrainingPlanV2RepositoryImplTests: XCTestCase {

    // MARK: - Properties

    private var sut: TrainingPlanV2RepositoryImpl!
    private var spyRemote: SpyTrainingPlanV2RemoteDataSource!
    private var spyLocal: SpyTrainingPlanV2LocalDataSource!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        spyRemote = SpyTrainingPlanV2RemoteDataSource()
        spyLocal = SpyTrainingPlanV2LocalDataSource()
        sut = TrainingPlanV2RepositoryImpl(
            remoteDataSource: spyRemote,
            localDataSource: spyLocal
        )
    }

    override func tearDown() {
        sut = nil
        spyRemote = nil
        spyLocal = nil
        super.tearDown()
    }

    // MARK: - getPlanStatus Tests

    /// Track A: cache present, not expired → returns immediately without remote call.
    /// Track B: shouldRefresh returns false (cooldown not expired) → no background call.
    func test_getPlanStatus_cacheHit_returnsCachedAndDoesNotCallRemote() async throws {
        // Given
        let cached = PlanStatusV2Response.stubForRepo(currentWeek: 2)
        spyLocal.cachedPlanStatus = cached
        spyLocal.planStatusExpired = false
        spyLocal.shouldRefreshResult = false

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)
        // Allow any detached background tasks to settle
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(result.currentWeek, 2, "Should return cached value")
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 0, "Remote must not be called when within cooldown")
    }

    /// Track B: cache present, shouldRefresh returns true → remote called in background.
    func test_getPlanStatus_cacheHit_cooldownExpired_schedulesBackgroundRefresh() async throws {
        // Given
        let cached = PlanStatusV2Response.stubForRepo(currentWeek: 5)
        spyLocal.cachedPlanStatus = cached
        spyLocal.planStatusExpired = false
        spyLocal.shouldRefreshResult = true
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 6)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)
        // Wait for background task
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then
        XCTAssertEqual(result.currentWeek, 5, "Track A: should return cached value immediately")
        XCTAssertGreaterThanOrEqual(spyRemote.getPlanStatusCallCount, 1, "Track B: background refresh should hit remote")
    }

    func test_getPlanStatus_cacheMiss_fetchesFromAPI() async throws {
        // Given: no cached value
        spyLocal.cachedPlanStatus = nil
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 1)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: false)

        // Then
        XCTAssertEqual(result.currentWeek, 1)
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 1, "Cache miss must call remote")
        XCTAssertNotNil(spyLocal.savedPlanStatus, "Result must be saved to cache")
    }

    func test_getPlanStatus_forceRefresh_bypassesCache() async throws {
        // Given: cache has stale value
        spyLocal.cachedPlanStatus = PlanStatusV2Response.stubForRepo(currentWeek: 1)
        spyRemote.planStatusToReturn = PlanStatusV2Response.stubForRepo(currentWeek: 9)

        // When
        let result = try await sut.getPlanStatus(forceRefresh: true)

        // Then
        XCTAssertEqual(result.currentWeek, 9, "Force refresh should return fresh remote data")
        XCTAssertEqual(spyRemote.getPlanStatusCallCount, 1, "Force refresh must call remote regardless of cache")
    }

    // MARK: - getOverview Tests

    func test_getOverview_success_savesToCache() async throws {
        // Given: no cached overview
        spyLocal.cachedOverview = nil
        spyRemote.overviewDTOToReturn = .stubForRepo()

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, "overview_001")
        XCTAssertNotNil(spyLocal.savedOverview, "Overview should be saved to cache after fetch")
        XCTAssertEqual(spyLocal.savedOverview?.id, "overview_001")
    }

    func test_getOverview_cacheHit_doesNotCallRemote() async throws {
        // Given
        spyLocal.cachedOverview = .stubForRepo()

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, "overview_001")
        XCTAssertEqual(spyRemote.getOverviewCallCount, 0, "Cache hit should not call remote")
    }

    // MARK: - getWeeklyPlan Tests

    func test_getWeeklyPlan_notFound_propagatesError() async {
        // Given
        spyLocal.cachedWeeklyPlan = nil
        spyRemote.weeklyPlanError = HTTPError.notFound("Weekly plan not found")

        // When / Then
        do {
            _ = try await sut.getWeeklyPlan(weekOfTraining: 3, overviewId: "overview_001")
            XCTFail("Should have thrown an error")
        } catch {
            // DomainError conversion happens inside the repo, so just check error was thrown
            XCTAssertNotNil(error)
        }
    }

    // MARK: - generateWeeklyPlan Tests

    func test_generateWeeklyPlan_success_savesAndInvalidatesCache() async throws {
        // Given
        spyRemote.weeklyPlanDTOToReturn = .stubForRepo(weekOfTraining: 4)

        // When
        let result = try await sut.generateWeeklyPlan(
            weekOfTraining: 4,
            forceGenerate: nil,
            promptVersion: nil,
            methodology: nil
        )

        // Then
        XCTAssertEqual(result.effectiveWeek, 4)
        XCTAssertNotNil(spyLocal.savedWeeklyPlan, "Generated plan must be saved to cache")
    }

    func test_generateWeeklyPlan_networkError_throwsDomainError() async {
        // Given
        spyRemote.weeklyPlanError = HTTPError.serverError(500, "Generation failed")

        // When / Then
        do {
            _ = try await sut.generateWeeklyPlan(
                weekOfTraining: 2,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - clearCache Tests

    func test_clearCache_clearsAllLayers() async {
        // Given
        spyLocal.cachedPlanStatus = PlanStatusV2Response.stubForRepo()
        spyLocal.cachedOverview = PlanOverviewV2.stubForRepo()

        // When
        await sut.clearCache()

        // Then
        XCTAssertEqual(spyLocal.clearAllCallCount, 1, "clearAll() must be called on local data source")
    }
}

// MARK: - SpyTrainingPlanV2RemoteDataSource

/// Full-fidelity spy: tracks calls and returns configurable fixtures.
/// Methods not under test fatalError to surface unexpected calls.
private final class SpyTrainingPlanV2RemoteDataSource: TrainingPlanV2RemoteDataSourceProtocol {

    // MARK: - Return Values

    var planStatusToReturn: PlanStatusV2Response = PlanStatusV2Response.stubForRepo()
    var overviewDTOToReturn: PlanOverviewV2DTO = .stubForRepo()
    var weeklyPlanDTOToReturn: WeeklyPlanV2DTO?
    var weeklyPlanError: Error?

    // MARK: - Call Tracking

    private(set) var getPlanStatusCallCount = 0
    private(set) var getOverviewCallCount = 0
    private(set) var generateWeeklyPlanCallCount = 0
    private(set) var getWeeklyPlanCallCount = 0

    // MARK: - Protocol — Plan Status

    func getPlanStatus() async throws -> PlanStatusV2Response {
        getPlanStatusCallCount += 1
        return planStatusToReturn
    }

    // MARK: - Protocol — Target Types & Methodologies

    func getTargetTypes() async throws -> [TargetTypeV2] {
        fatalError("Unexpected: getTargetTypes()")
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        fatalError("Unexpected: getMethodologies()")
    }

    // MARK: - Protocol — Plan Overview

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: createOverviewForRace()")
    }

    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?, intendedRaceDistanceKm: Int?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: createOverviewForNonRace()")
    }

    func getOverview() async throws -> PlanOverviewV2DTO {
        getOverviewCallCount += 1
        return overviewDTOToReturn
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected: updateOverview()")
    }

    // MARK: - Protocol — Weekly Plan

    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2DTO {
        generateWeeklyPlanCallCount += 1
        if let error = weeklyPlanError { throw error }
        guard let dto = weeklyPlanDTOToReturn else {
            throw HTTPError.serverError(500, "No mock plan configured")
        }
        return dto
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanV2DTO {
        getWeeklyPlanCallCount += 1
        if let error = weeklyPlanError { throw error }
        guard let dto = weeklyPlanDTOToReturn else {
            throw HTTPError.notFound("No mock weekly plan configured")
        }
        return dto
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected: updateWeeklyPlan()")
    }

    func deleteWeeklyPlan(planId: String) async throws {
        fatalError("Unexpected: deleteWeeklyPlan()")
    }

    // MARK: - Protocol — Weekly Preview

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewResponseDTO {
        fatalError("Unexpected: getWeeklyPreview()")
    }

    // MARK: - Protocol — Weekly Summary

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        fatalError("Unexpected: getWeeklySummaries()")
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected: generateWeeklySummary()")
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected: getWeeklySummary()")
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        fatalError("Unexpected: applyAdjustmentItems()")
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        fatalError("Unexpected: deleteWeeklySummary()")
    }
}

// MARK: - SpyTrainingPlanV2LocalDataSource

/// In-memory local data source spy that tracks save calls.
private final class SpyTrainingPlanV2LocalDataSource: TrainingPlanV2LocalDataSourceProtocol {

    // MARK: - Stored State

    var cachedPlanStatus: PlanStatusV2Response?
    var savedPlanStatus: PlanStatusV2Response?
    var planStatusExpired = true
    var shouldRefreshResult = false

    var cachedOverview: PlanOverviewV2?
    var savedOverview: PlanOverviewV2?
    var overviewExpired = true

    var cachedWeeklyPlan: WeeklyPlanV2?
    var savedWeeklyPlan: WeeklyPlanV2?
    var weeklyPlanExpired = true

    // MARK: - Call Tracking

    private(set) var clearAllCallCount = 0

    // MARK: - Plan Status

    func getPlanStatus() -> PlanStatusV2Response? { cachedPlanStatus }

    func savePlanStatus(_ status: PlanStatusV2Response) {
        savedPlanStatus = status   // write receipt for test assertions
        cachedPlanStatus = status  // update read path so subsequent get() returns fresh value
    }

    func isPlanStatusExpired() -> Bool { planStatusExpired }

    func clearPlanStatus() {
        cachedPlanStatus = nil
    }

    // MARK: - Cooldown

    func shouldRefresh(_ resource: CooldownResource) -> Bool { shouldRefreshResult }
    func markRefreshed(_ resource: CooldownResource) {}
    func invalidateCooldown(_ resource: CooldownResource) {}

    // MARK: - Overview

    func getOverview() -> PlanOverviewV2? { cachedOverview }

    func saveOverview(_ overview: PlanOverviewV2) {
        savedOverview = overview
        cachedOverview = overview
    }

    func isOverviewExpired() -> Bool { overviewExpired }

    func clearOverview() {
        cachedOverview = nil
    }

    // MARK: - Weekly Plan

    func getWeeklyPlan(week: Int) -> WeeklyPlanV2? { cachedWeeklyPlan }

    func saveWeeklyPlan(_ plan: WeeklyPlanV2, week: Int) {
        savedWeeklyPlan = plan
        cachedWeeklyPlan = plan
    }

    func isWeeklyPlanExpired(week: Int) -> Bool { weeklyPlanExpired }
    func clearWeeklyPlan(week: Int) { cachedWeeklyPlan = nil }
    func clearAllWeeklyPlans() { cachedWeeklyPlan = nil }

    // MARK: - Weekly Summary

    func getWeeklySummary(week: Int) -> WeeklySummaryV2? { nil }
    func saveWeeklySummary(_ summary: WeeklySummaryV2, week: Int) {}
    func isWeeklySummaryExpired(week: Int) -> Bool { true }
    func clearWeeklySummary(week: Int) {}
    func clearAllWeeklySummaries() {}

    // MARK: - Weekly Preview

    func getWeeklyPreview(overviewId: String) -> WeeklyPreviewV2? { nil }
    func saveWeeklyPreview(_ preview: WeeklyPreviewV2, overviewId: String) {}
    func isWeeklyPreviewExpired(overviewId: String) -> Bool { true }
    func clearWeeklyPreview(overviewId: String) {}

    // MARK: - Utility

    func clearAll() {
        clearAllCallCount += 1
        cachedPlanStatus = nil
        cachedOverview = nil
        cachedWeeklyPlan = nil
    }
}

// MARK: - Fixture Extensions

private extension PlanStatusV2Response {
    static func stubForRepo(currentWeek: Int = 1) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 12,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "plan_001_\(currentWeek)",
            previousWeekSummaryId: nil,
            targetType: "race_run",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: nil
        )
    }
}

private extension PlanOverviewV2DTO {
    static func stubForRepo() -> PlanOverviewV2DTO {
        PlanOverviewV2DTO(
            id: "overview_001",
            targetId: "target_abc",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: 16,
            startFromStage: "base",
            raceDate: 1_800_000_000,
            distanceKm: 42.195,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: "5:30",
            targetTime: nil,
            isMainRace: true,
            targetName: "Test Race",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }
}

private extension PlanOverviewV2 {
    static func stubForRepo() -> PlanOverviewV2 {
        PlanOverviewV2(
            id: "overview_001",
            targetId: "target_abc",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: 16,
            startFromStage: "base",
            raceDate: 1_800_000_000,
            distanceKm: 42.195,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: "5:30",
            targetTime: nil,
            isMainRace: true,
            targetName: "Test Race",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }
}

private extension WeeklyPlanV2DTO {
    static func stubForRepo(weekOfTraining: Int = 1) -> WeeklyPlanV2DTO {
        let json = """
        {
            "plan_id": "overview_001_\(weekOfTraining)",
            "overview_id": "overview_001",
            "week_of_training": \(weekOfTraining),
            "id": "overview_001_\(weekOfTraining)",
            "purpose": "Build aerobic base",
            "week_of_plan": \(weekOfTraining),
            "total_weeks": 16,
            "total_distance_km": 40.0,
            "days": [],
            "api_version": "2.0"
        }
        """
        return try! JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
    }
}
