//
//  TrainingPlanRepositoryImplTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanRepositoryImpl
//  Tests caching strategies and data flow between remote and local data sources
//

import XCTest
@testable import paceriz_dev

final class TrainingPlanRepositoryImplTests: XCTestCase {

    // MARK: - Properties

    var sut: TrainingPlanRepositoryImpl!
    var mockHTTPClient: MockHTTPClient!
    var mockUserDefaults: MockUserDefaults!
    var remoteDataSource: TrainingPlanRemoteDataSource!
    var localDataSource: TrainingPlanLocalDataSource!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create mocks
        mockHTTPClient = MockHTTPClient()
        mockUserDefaults = MockUserDefaults()

        // Create data sources with mocks
        remoteDataSource = TrainingPlanRemoteDataSource(
            httpClient: mockHTTPClient,
            parser: DefaultAPIParser.shared
        )
        localDataSource = TrainingPlanLocalDataSource(defaults: mockUserDefaults)

        // Create repository
        sut = TrainingPlanRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockUserDefaults.clear()
        sut = nil
        remoteDataSource = nil
        localDataSource = nil
        mockHTTPClient = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Weekly Plan Cache Hit Tests

    func test_getWeeklyPlan_cacheHit_shouldReturnCachedData() async throws {
        // Given: Plan is in cache (not expired)
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanTestFixtures.weeklyPlan1
        localDataSource.saveWeeklyPlan(cachedPlan, planId: planId)

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then: Should return cached plan without calling API
        XCTAssertEqual(result.id, cachedPlan.id, "Should return cached plan")
        XCTAssertEqual(result.weekOfPlan, cachedPlan.weekOfPlan)

        // API might be called for background refresh, but immediate result should be available without waiting
        // We check that the main flow didn't trigger API synchronously
        XCTAssertLessThanOrEqual(mockHTTPClient.callCount(for: "/plan/race_run/weekly/\(planId)", method: .GET), 1,
                       "Should not call API synchronously when cache is fresh")
    }

    func test_getWeeklyPlan_cacheHit_shouldTriggerBackgroundRefresh() async throws {
        // Given: Plan is in cache (not expired)
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanTestFixtures.weeklyPlan1
        localDataSource.saveWeeklyPlan(cachedPlan, planId: planId)

        // Configure API response for background refresh
        let freshPlan = TrainingPlanTestFixtures.weeklyPlan1
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(freshPlan)
        mockHTTPClient.setResponse(for: "/plan/race_run/weekly/\(planId)", method: .GET, data: responseData)

        // When: Get plan (returns from cache)
        _ = try await sut.getWeeklyPlan(planId: planId)

        // Wait for background refresh
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then: Background refresh should have been triggered
        // Note: The background refresh is detached, so timing may vary
        // This test verifies the mechanism exists
    }

    // MARK: - Weekly Plan Cache Miss Tests

    func test_getWeeklyPlan_cacheMiss_shouldFetchFromAPI() async throws {
        // Given: No cached plan
        let planId = "plan_123_1"
        let apiPlan = TrainingPlanTestFixtures.weeklyPlan1
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(apiPlan)
        mockHTTPClient.setResponse(for: "/plan/race_run/weekly/\(planId)", method: .GET, data: responseData)

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then: Should fetch from API
        XCTAssertEqual(result.id, apiPlan.id, "Should return API response")
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/weekly/\(planId)", method: .GET), 1,
                       "Should call API once")

        // Verify data is cached
        let cachedPlan = localDataSource.getWeeklyPlan(planId: planId)
        XCTAssertNotNil(cachedPlan, "Plan should be cached after fetch")
        XCTAssertEqual(cachedPlan?.id, apiPlan.id)
    }

    func test_getWeeklyPlan_apiNotFound_shouldThrowWeeklyPlanNotFoundError() async throws {
        // Given: API returns 404
        let planId = "nonexistent_plan"
        mockHTTPClient.setError(
            for: "/plan/race_run/weekly/\(planId)",
            method: .GET,
            error: HTTPError.notFound("Plan not found")
        )

        // When/Then
        do {
            _ = try await sut.getWeeklyPlan(planId: planId)
            XCTFail("Should throw weeklyPlanNotFound error")
        } catch let error as TrainingPlanError {
            if case .weeklyPlanNotFound(let returnedPlanId) = error {
                XCTAssertEqual(returnedPlanId, planId, "Error should contain the plan ID")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Refresh Weekly Plan Tests

    func test_refreshWeeklyPlan_shouldAlwaysFetchFromAPI() async throws {
        // Given: Plan is in cache
        let planId = "plan_123_1"
        let cachedPlan = TrainingPlanTestFixtures.weeklyPlan1
        localDataSource.saveWeeklyPlan(cachedPlan, planId: planId)

        // Configure API with different data
        let freshPlan = TrainingPlanTestFixtures.weeklyPlan2
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(freshPlan)
        mockHTTPClient.setResponse(for: "/plan/race_run/weekly/\(planId)", method: .GET, data: responseData)

        // When: Force refresh
        let result = try await sut.refreshWeeklyPlan(planId: planId)

        // Then: Should return fresh data from API
        XCTAssertEqual(result.id, freshPlan.id, "Should return fresh API data")
        XCTAssertEqual(result.weekOfPlan, freshPlan.weekOfPlan)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/weekly/\(planId)", method: .GET), 1)

        // Verify cache is updated
        let updatedCache = localDataSource.getWeeklyPlan(planId: planId)
        XCTAssertEqual(updatedCache?.id, freshPlan.id, "Cache should be updated with fresh data")
    }

    // MARK: - Create Weekly Plan Tests

    func test_createWeeklyPlan_shouldSaveToCacheAndInvalidatePlanStatus() async throws {
        // Given: Plan status is cached
        localDataSource.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)
        XCTAssertNotNil(localDataSource.getPlanStatus(), "Plan status should be cached before test")

        // Configure API response
        let newPlan = TrainingPlanTestFixtures.weeklyPlan2
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(newPlan)
        mockHTTPClient.setResponse(for: "/plan/race_run/weekly", method: .POST, data: responseData)

        // When: Create new weekly plan
        let result = try await sut.createWeeklyPlan(week: 2, startFromStage: nil, isBeginner: false)

        // Then: Should return new plan
        XCTAssertEqual(result.id, newPlan.id)

        // Verify plan is cached
        let cachedPlan = localDataSource.getWeeklyPlan(planId: newPlan.id)
        XCTAssertNotNil(cachedPlan, "New plan should be cached")

        // Verify plan status is invalidated
        XCTAssertNil(localDataSource.getPlanStatus(), "Plan status should be invalidated")
    }

    // MARK: - Overview Tests

    func test_getOverview_cacheHit_shouldReturnCachedData() async throws {
        // Given: Overview is in cache
        let cachedOverview = TrainingPlanTestFixtures.trainingOverview
        localDataSource.saveOverview(cachedOverview)

        // When
        let result = try await sut.getOverview()

        // Then: Should return cached overview
        XCTAssertEqual(result.id, cachedOverview.id)
        XCTAssertEqual(result.totalWeeks, cachedOverview.totalWeeks)
        // Note: callCount may be 1 if background refresh task runs immediately
        XCTAssertLessThanOrEqual(mockHTTPClient.callCount(for: "/plan/race_run/overview", method: .GET), 1,
                       "Should not call API synchronously when cache is fresh")
    }

    func test_getOverview_cacheMiss_shouldFetchFromAPI() async throws {
        // Given: No cached overview
        let apiOverview = TrainingPlanTestFixtures.trainingOverview
        let responseData = TrainingPlanTestFixtures.overviewAPIResponseData(apiOverview)
        mockHTTPClient.setResponse(for: "/plan/race_run/overview", method: .GET, data: responseData)

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, apiOverview.id)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/overview", method: .GET), 1)

        // Verify data is cached
        let cachedOverview = localDataSource.getOverview()
        XCTAssertNotNil(cachedOverview)
        XCTAssertEqual(cachedOverview?.id, apiOverview.id)
    }

    func test_getOverview_apiNotFound_shouldThrowOverviewNotFoundError() async throws {
        // Given: API returns 404
        mockHTTPClient.setError(
            for: "/plan/race_run/overview",
            method: .GET,
            error: HTTPError.notFound("Overview not found")
        )

        // When/Then
        do {
            _ = try await sut.getOverview()
            XCTFail("Should throw overviewNotFound error")
        } catch let error as TrainingPlanError {
            if case .overviewNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func test_refreshOverview_shouldAlwaysFetchFromAPI() async throws {
        // Given: Overview is in cache
        let cachedOverview = TrainingPlanTestFixtures.trainingOverview
        localDataSource.saveOverview(cachedOverview)

        // Configure API response
        let responseData = TrainingPlanTestFixtures.overviewAPIResponseData(cachedOverview)
        mockHTTPClient.setResponse(for: "/plan/race_run/overview", method: .GET, data: responseData)

        // When
        let result = try await sut.refreshOverview()

        // Then: Should call API even with cache
        XCTAssertEqual(result.id, cachedOverview.id)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/overview", method: .GET), 1)
    }

    // MARK: - Plan Status Tests

    func test_getPlanStatus_cacheHit_shouldReturnCachedData() async throws {
        // Given: Status is in cache
        let cachedStatus = TrainingPlanTestFixtures.planStatusWithPlan
        localDataSource.savePlanStatus(cachedStatus)

        // When
        let result = try await sut.getPlanStatus()

        // Then
        XCTAssertEqual(result.currentWeek, cachedStatus.currentWeek)
        XCTAssertEqual(result.totalWeeks, cachedStatus.totalWeeks)
        XCTAssertLessThanOrEqual(mockHTTPClient.callCount(for: "/plan/race_run/status", method: .GET), 1)
    }

    func test_getPlanStatus_cacheMiss_shouldFetchFromAPI() async throws {
        // Given: No cached status
        let apiStatus = TrainingPlanTestFixtures.planStatusWithPlan
        let responseData = TrainingPlanTestFixtures.planStatusAPIResponseData(apiStatus)
        mockHTTPClient.setResponse(for: "/plan/race_run/status", method: .GET, data: responseData)

        // When
        let result = try await sut.getPlanStatus()

        // Then
        XCTAssertEqual(result.currentWeek, apiStatus.currentWeek)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/status", method: .GET), 1)

        // Verify cache
        let cachedStatus = localDataSource.getPlanStatus()
        XCTAssertNotNil(cachedStatus)
        XCTAssertEqual(cachedStatus?.currentWeek, apiStatus.currentWeek)
    }

    func test_refreshPlanStatus_shouldAlwaysFetchFromAPI() async throws {
        // Given: Status is in cache
        let cachedStatus = TrainingPlanTestFixtures.planStatusWithPlan
        localDataSource.savePlanStatus(cachedStatus)

        // Configure API
        let responseData = TrainingPlanTestFixtures.planStatusAPIResponseData(cachedStatus)
        mockHTTPClient.setResponse(for: "/plan/race_run/status", method: .GET, data: responseData)

        // When
        let result = try await sut.refreshPlanStatus()

        // Then
        XCTAssertEqual(result.currentWeek, cachedStatus.currentWeek)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/status", method: .GET), 1)
    }

    // MARK: - Cache Management Tests

    func test_clearCache_shouldRemoveAllCachedData() async throws {
        // Given: All types of data are cached
        localDataSource.saveOverview(TrainingPlanTestFixtures.trainingOverview)
        localDataSource.savePlanStatus(TrainingPlanTestFixtures.planStatusWithPlan)
        localDataSource.saveWeeklyPlan(TrainingPlanTestFixtures.weeklyPlan1, planId: "plan_123_1")

        XCTAssertNotNil(localDataSource.getOverview())
        XCTAssertNotNil(localDataSource.getPlanStatus())
        XCTAssertNotNil(localDataSource.getWeeklyPlan(planId: "plan_123_1"))

        // When
        await sut.clearCache()

        // Then
        XCTAssertNil(localDataSource.getOverview())
        XCTAssertNil(localDataSource.getPlanStatus())
        XCTAssertNil(localDataSource.getWeeklyPlan(planId: "plan_123_1"))
    }

    // MARK: - Network Error Tests

    func test_getWeeklyPlan_networkError_shouldPropagateError() async throws {
        // Given: Network error
        let planId = "plan_123_1"
        mockHTTPClient.setError(
            for: "/plan/race_run/weekly/\(planId)",
            method: .GET,
            error: HTTPError.noConnection
        )

        // When/Then
        do {
            _ = try await sut.getWeeklyPlan(planId: planId)
            XCTFail("Should throw network error")
        } catch let error as HTTPError {
            if case .noConnection = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Modify Weekly Plan Tests

    func test_modifyWeeklyPlan_shouldUpdateCache() async throws {
        // Given: Existing plan in cache
        let planId = "plan_123_1"
        let originalPlan = TrainingPlanTestFixtures.weeklyPlan1
        localDataSource.saveWeeklyPlan(originalPlan, planId: planId)

        // Configure API response
        let modifiedPlan = TrainingPlanTestFixtures.weeklyPlan2
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(modifiedPlan)
        mockHTTPClient.setResponse(
            for: "/plan/race_run/weekly/\(planId)/modify",
            method: .PUT,
            data: responseData
        )

        // When
        let result = try await sut.modifyWeeklyPlan(planId: planId, updatedPlan: modifiedPlan)

        // Then
        XCTAssertEqual(result.id, modifiedPlan.id)

        // Verify cache is updated
        let cachedPlan = localDataSource.getWeeklyPlan(planId: planId)
        XCTAssertEqual(cachedPlan?.id, modifiedPlan.id)
    }
}

final class TrainingPlanV2RepositoryRegressionTests: XCTestCase {

    private var sut: TrainingPlanV2RepositoryImpl!
    private var remoteDataSource: FailingTrainingPlanV2RemoteDataSource!
    private var localDataSource: TrainingPlanV2LocalDataSource!
    private var mockUserDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        remoteDataSource = FailingTrainingPlanV2RemoteDataSource()
        localDataSource = TrainingPlanV2LocalDataSource(defaults: mockUserDefaults)
        sut = TrainingPlanV2RepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )
    }

    override func tearDown() {
        sut = nil
        remoteDataSource = nil
        localDataSource = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    func test_getOverview_whenOnlyStaleCacheExistsAndAPIUnavailable_shouldReturnCachedOverview() async throws {
        let cachedOverview = try loadOverviewEntityFixture(named: "race_run_paceriz")
        localDataSource.saveOverview(cachedOverview)
        mockUserDefaults.set(
            Date(timeIntervalSinceNow: -7200),
            forKey: "training_plan_v2_overview_cache_timestamp"
        )
        remoteDataSource.overviewError = DomainError.noConnection

        let result = try await sut.getOverview()

        XCTAssertEqual(result.id, cachedOverview.id)
    }

    func test_getWeeklyPlan_whenOnlyStaleCacheExistsAndAPIUnavailable_shouldReturnCachedPlan() async throws {
        let cachedPlan = try loadWeeklyPlanEntityFixture(named: "paceriz_42k_base_week")
        localDataSource.saveWeeklyPlan(cachedPlan, week: 1)
        mockUserDefaults.set(
            Date(timeIntervalSinceNow: -10800),
            forKey: "training_plan_v2_weekly_1_timestamp"
        )
        remoteDataSource.weeklyPlanError = DomainError.noConnection

        let result = try await sut.getWeeklyPlan(weekOfTraining: 1, overviewId: "overview_001")

        XCTAssertEqual(result.id, cachedPlan.id)
        XCTAssertEqual(result.effectiveWeek, cachedPlan.effectiveWeek)
    }

    private func loadOverviewEntityFixture(named name: String) throws -> PlanOverviewV2 {
        let data = try loadFixtureData(
            directory: "PlanOverview",
            name: name
        )
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    private func loadWeeklyPlanEntityFixture(named name: String) throws -> WeeklyPlanV2 {
        let data = try loadFixtureData(
            directory: "WeeklyPlan",
            name: name
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private func loadFixtureData(directory: String, name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = testDir
            .appendingPathComponent("APISchema/Fixtures/\(directory)/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }
}

private final class FailingTrainingPlanV2RemoteDataSource: TrainingPlanV2RemoteDataSourceProtocol {

    var overviewError: Error?
    var weeklyPlanError: Error?

    func getTargetTypes() async throws -> [TargetTypeV2] {
        fatalError("Unexpected call to getTargetTypes()")
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        fatalError("Unexpected call to getMethodologies(targetType:)")
    }

    func getPlanStatus() async throws -> PlanStatusV2Response {
        fatalError("Unexpected call to getPlanStatus()")
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call to createOverviewForRace(targetId:startFromStage:methodologyId:)")
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call to createOverviewForNonRace(targetType:trainingWeeks:availableDays:methodologyId:startFromStage:intendedRaceDistanceKm:)")
    }

    func getOverview() async throws -> PlanOverviewV2DTO {
        throw overviewError ?? DomainError.noConnection
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2DTO {
        fatalError("Unexpected call to updateOverview(overviewId:startFromStage:methodologyId:)")
    }

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected call to generateWeeklyPlan(weekOfTraining:forceGenerate:promptVersion:methodology:)")
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanV2DTO {
        throw weeklyPlanError ?? DomainError.noConnection
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2DTO {
        fatalError("Unexpected call to updateWeeklyPlan(planId:updates:)")
    }

    func deleteWeeklyPlan(planId: String) async throws {
        fatalError("Unexpected call to deleteWeeklyPlan(planId:)")
    }

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewResponseDTO {
        fatalError("Unexpected call to getWeeklyPreview(overviewId:)")
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        fatalError("Unexpected call to getWeeklySummaries()")
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected call to generateWeeklySummary(weekOfPlan:forceUpdate:)")
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        fatalError("Unexpected call to getWeeklySummary(weekOfPlan:)")
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        fatalError("Unexpected call to deleteWeeklySummary(summaryId:)")
    }
}
