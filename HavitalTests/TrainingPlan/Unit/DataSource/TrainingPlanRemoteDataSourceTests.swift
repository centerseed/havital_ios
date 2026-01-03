//
//  TrainingPlanRemoteDataSourceTests.swift
//  HavitalTests
//
//  Unit tests for TrainingPlanRemoteDataSource
//  Tests API communication with mock HTTP client
//

import XCTest
@testable import paceriz_dev

final class TrainingPlanRemoteDataSourceTests: XCTestCase {

    // MARK: - Properties

    var sut: TrainingPlanRemoteDataSource!
    var mockHTTPClient: MockHTTPClient!
    var mockParser: MockAPIParser!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = TrainingPlanRemoteDataSource(
            httpClient: mockHTTPClient,
            parser: DefaultAPIParser.shared  // Use real parser for proper JSON handling
        )
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockHTTPClient = nil
        mockParser = nil
        super.tearDown()
    }

    // MARK: - Weekly Plan Tests

    func test_getWeeklyPlan_success_shouldReturnPlan() async throws {
        // Given
        let planId = "plan_123_1"
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan1
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(expectedPlan)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/weekly/\(planId)",
            method: .GET,
            data: responseData
        )

        // When
        let result = try await sut.getWeeklyPlan(planId: planId)

        // Then
        XCTAssertEqual(result.id, expectedPlan.id, "Plan ID should match")
        XCTAssertEqual(result.weekOfPlan, expectedPlan.weekOfPlan, "Week of plan should match")
        XCTAssertEqual(result.totalDistance, expectedPlan.totalDistance, "Total distance should match")
        XCTAssertEqual(mockHTTPClient.requestCount, 1, "Should make exactly one request")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/weekly/\(planId)", method: .GET))
    }

    func test_getWeeklyPlan_notFound_shouldThrowError() async throws {
        // Given
        let planId = "nonexistent_plan"
        mockHTTPClient.setError(
            for: "/plan/race_run/weekly/\(planId)",
            method: .GET,
            error: HTTPError.notFound("Plan not found")
        )

        // When/Then
        do {
            _ = try await sut.getWeeklyPlan(planId: planId)
            XCTFail("Should throw notFound error")
        } catch let error as HTTPError {
            if case .notFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_getWeeklyPlan_networkError_shouldThrowError() async throws {
        // Given
        let planId = "plan_123_1"
        mockHTTPClient.setError(
            for: "/plan/race_run/weekly/\(planId)",
            method: .GET,
            error: HTTPError.noConnection
        )

        // When/Then
        do {
            _ = try await sut.getWeeklyPlan(planId: planId)
            XCTFail("Should throw noConnection error")
        } catch let error as HTTPError {
            if case .noConnection = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_createWeeklyPlan_success_shouldReturnNewPlan() async throws {
        // Given
        let week = 2
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan2
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(expectedPlan)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/weekly/v2",
            method: .POST,
            data: responseData
        )

        // When
        let result = try await sut.createWeeklyPlan(
            week: week,
            startFromStage: nil,
            isBeginner: false
        )

        // Then
        XCTAssertEqual(result.id, expectedPlan.id, "Plan ID should match")
        XCTAssertEqual(result.weekOfPlan, expectedPlan.weekOfPlan, "Week should match")
        XCTAssertEqual(mockHTTPClient.requestCount, 1, "Should make exactly one request")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/weekly/v2", method: .POST))

        // Verify request body
        if let lastRequest = mockHTTPClient.lastRequest, let body = lastRequest.body {
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["week_of_training"] as? Int, week)
        }
    }

    func test_createWeeklyPlan_withStartFromStage_shouldIncludeInRequest() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan1
        let responseData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData(expectedPlan)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/weekly/v2",
            method: .POST,
            data: responseData
        )

        // When
        _ = try await sut.createWeeklyPlan(
            week: 1,
            startFromStage: "stage_1",
            isBeginner: true
        )

        // Then
        if let lastRequest = mockHTTPClient.lastRequest, let body = lastRequest.body {
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["start_from_stage"] as? String, "stage_1")
            XCTAssertEqual(json?["is_beginner"] as? Bool, true)
        }
    }

    // MARK: - Overview Tests

    func test_getOverview_success_shouldReturnOverview() async throws {
        // Given
        let expectedOverview = TrainingPlanTestFixtures.trainingOverview
        let responseData = TrainingPlanTestFixtures.overviewAPIResponseData(expectedOverview)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/overview",
            method: .GET,
            data: responseData
        )

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, expectedOverview.id, "Overview ID should match")
        XCTAssertEqual(result.totalWeeks, expectedOverview.totalWeeks, "Total weeks should match")
        XCTAssertEqual(result.trainingPlanName, expectedOverview.trainingPlanName, "Plan name should match")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/overview", method: .GET))
    }

    func test_getOverview_notFound_shouldThrowError() async throws {
        // Given
        mockHTTPClient.setError(
            for: "/plan/race_run/overview",
            method: .GET,
            error: HTTPError.notFound("Overview not found")
        )

        // When/Then
        do {
            _ = try await sut.getOverview()
            XCTFail("Should throw notFound error")
        } catch let error as HTTPError {
            if case .notFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func test_createOverview_success_shouldReturnNewOverview() async throws {
        // Given
        let expectedOverview = TrainingPlanTestFixtures.trainingOverview
        let responseData = TrainingPlanTestFixtures.overviewAPIResponseData(expectedOverview)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/overview",
            method: .POST,
            data: responseData
        )

        // When
        let result = try await sut.createOverview(
            startFromStage: "stage_1",
            isBeginner: false
        )

        // Then
        XCTAssertEqual(result.id, expectedOverview.id, "Overview ID should match")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/overview", method: .POST))
    }

    func test_updateOverview_success_shouldReturnUpdatedOverview() async throws {
        // Given
        let overviewId = "plan_123"
        let expectedOverview = TrainingPlanTestFixtures.trainingOverview
        let responseData = TrainingPlanTestFixtures.overviewAPIResponseData(expectedOverview)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/overview/\(overviewId)",
            method: .PUT,
            data: responseData
        )

        // When
        let result = try await sut.updateOverview(overviewId: overviewId)

        // Then
        XCTAssertEqual(result.id, expectedOverview.id, "Overview ID should match")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/overview/\(overviewId)", method: .PUT))
    }

    // MARK: - Plan Status Tests

    func test_getPlanStatus_success_shouldReturnStatus() async throws {
        // Given
        let expectedStatus = TrainingPlanTestFixtures.planStatusWithPlan
        let responseData = TrainingPlanTestFixtures.planStatusAPIResponseData(expectedStatus)

        mockHTTPClient.setResponse(
            for: "/plan/race_run/status",
            method: .GET,
            data: responseData
        )

        // When
        let result = try await sut.getPlanStatus()

        // Then
        XCTAssertEqual(result.currentWeek, expectedStatus.currentWeek, "Current week should match")
        XCTAssertEqual(result.totalWeeks, expectedStatus.totalWeeks, "Total weeks should match")
        XCTAssertEqual(result.nextAction, expectedStatus.nextAction, "Next action should match")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/plan/race_run/status", method: .GET))
    }

    func test_getPlanStatus_serverError_shouldThrowError() async throws {
        // Given
        mockHTTPClient.setError(
            for: "/plan/race_run/status",
            method: .GET,
            error: HTTPError.serverError(500, "Internal server error")
        )

        // When/Then
        do {
            _ = try await sut.getPlanStatus()
            XCTFail("Should throw server error")
        } catch let error as HTTPError {
            if case .serverError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Request Tracking Tests

    func test_multipleRequests_shouldTrackHistory() async throws {
        // Given
        let planData = TrainingPlanTestFixtures.weeklyPlanAPIResponseData()
        let statusData = TrainingPlanTestFixtures.planStatusAPIResponseData()

        mockHTTPClient.setResponse(for: "/plan/race_run/weekly/plan_123_1", method: .GET, data: planData)
        mockHTTPClient.setResponse(for: "/plan/race_run/status", method: .GET, data: statusData)

        // When
        _ = try await sut.getWeeklyPlan(planId: "plan_123_1")
        _ = try await sut.getPlanStatus()

        // Then
        XCTAssertEqual(mockHTTPClient.requestCount, 2, "Should track two requests")
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/weekly/plan_123_1", method: .GET), 1)
        XCTAssertEqual(mockHTTPClient.callCount(for: "/plan/race_run/status", method: .GET), 1)
    }
}
