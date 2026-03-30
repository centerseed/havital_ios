import XCTest
@testable import paceriz_dev

// MARK: - Workout Remote Data Source Tests
/// 測試 WorkoutRemoteDataSource 的 API 調用邏輯
class WorkoutRemoteDataSourceTests: XCTestCase {

    var sut: WorkoutRemoteDataSource!
    var mockHTTPClient: MockHTTPClient!
    var mockParser: MockAPIParser!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = WorkoutRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockHTTPClient = nil
        mockParser = nil
        super.tearDown()
    }

    // MARK: - fetchWorkouts Tests

    func testFetchWorkouts_WithPageSizeAndCursor_BuildsCorrectPath() async throws {
        // Given
        let mockResponse = createMockWorkoutListResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts?page_size=10&cursor=abc123", method: .GET, response: mockResponse)

        // When
        _ = try await sut.fetchWorkouts(pageSize: 10, cursor: "abc123")

        // Then
        XCTAssertEqual(mockHTTPClient.requestCount, 1, "Should make one HTTP request")
        XCTAssertNotNil(mockHTTPClient.lastRequest, "Should have made a request")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, HTTPMethod.GET, "Should use GET method")
        XCTAssertTrue(mockHTTPClient.lastRequest?.path.contains("page_size=10") ?? false, "Path should contain page_size parameter")
        XCTAssertTrue(mockHTTPClient.lastRequest?.path.contains("cursor=abc123") ?? false, "Path should contain cursor parameter")
    }

    func testFetchWorkouts_WithoutParameters_BuildsCorrectPath() async throws {
        // Given
        let mockResponse = createMockWorkoutListResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts", method: .GET, response: mockResponse)

        // When
        _ = try await sut.fetchWorkouts(pageSize: nil, cursor: nil)

        // Then
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/workouts", "Path should not contain query parameters")
    }

    func testFetchWorkouts_Success_ReturnsWorkouts() async throws {
        // Given
        let mockResponse = createMockWorkoutListResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts?page_size=10", method: .GET, response: mockResponse)

        // When
        let workouts = try await sut.fetchWorkouts(pageSize: 10, cursor: nil)

        // Then
        XCTAssertTrue(workouts.count > 0, "Should return workouts")
    }

    func testFetchWorkouts_NetworkError_ThrowsError() async {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockHTTPClient.setError(for: "/v2/workouts", method: .GET, error: networkError)

        // When/Then
        do {
            _ = try await sut.fetchWorkouts(pageSize: nil, cursor: nil)
            XCTFail("Should throw network error")
        } catch {
            XCTAssertNotNil(error, "Should throw error")
        }
    }

    // MARK: - fetchRecentWorkouts Tests

    func testFetchRecentWorkouts_UsesDefaultPageSize() async throws {
        // Given
        let mockResponse = createMockWorkoutListResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts?page_size=20", method: .GET, response: mockResponse)

        // When
        _ = try await sut.fetchRecentWorkouts(pageSize: 20)

        // Then
        XCTAssertTrue(mockHTTPClient.lastRequest?.path.contains("page_size=20") ?? false, "Should use provided page_size")
    }

    // MARK: - fetchWorkout Tests

    func testFetchWorkout_BuildsCorrectPath() async throws {
        // Given
        let mockResponse = createMockWorkoutDetailResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/workout_123", method: .GET, response: mockResponse)

        // When
        _ = try await sut.fetchWorkout(id: "workout_123")

        // Then
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/workouts/workout_123", "Path should include workout ID")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, HTTPMethod.GET, "Should use GET method")
    }

    func testFetchWorkout_Success_ReturnsWorkout() async throws {
        // Given
        let mockResponse = createMockWorkoutDetailResponse()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/workout_123", method: .GET, response: mockResponse)

        // When
        let workout = try await sut.fetchWorkout(id: "workout_123")

        // Then
        XCTAssertEqual(workout.id, "workout_123", "Workout ID should match")
    }

    // MARK: - uploadWorkout Tests

    func testUploadWorkout_UsesCorrectEndpoint() async throws {
        // Given
        let uploadRequest = createUploadRequest()
        let mockResponse = UploadWorkoutResponse(
            id: "upload_123",
            schemaVersion: "2.0",
            provider: "apple_health",
            createdAt: "2026-01-05T11:00:00Z",
            basicMetrics: nil,
            advancedMetrics: nil,
            message: "Upload successful"
        )
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/upload", method: .POST, response: mockResponse)

        // When
        _ = try await sut.uploadWorkout(uploadRequest)

        // Then
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/workouts/upload", "Should use upload endpoint")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, HTTPMethod.POST, "Should use POST method")
        XCTAssertNotNil(mockHTTPClient.lastRequest?.body, "Should include request body")
    }

    func testUploadWorkout_Success_ReturnsResponse() async throws {
        // Given
        let uploadRequest = createUploadRequest()
        let mockResponse = UploadWorkoutResponse(
            id: "upload_123",
            schemaVersion: "2.0",
            provider: "apple_health",
            createdAt: "2026-01-05T11:00:00Z",
            basicMetrics: nil,
            advancedMetrics: nil,
            message: "Upload successful"
        )
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/upload", method: .POST, response: mockResponse)

        // When
        let response = try await sut.uploadWorkout(uploadRequest)

        // Then
        XCTAssertEqual(response.id, "upload_123", "Upload ID should match")
        XCTAssertEqual(response.message, "Upload successful", "Message should match")
    }

    // MARK: - deleteWorkout Tests

    func testDeleteWorkout_BuildsCorrectPath() async throws {
        // Given
        mockHTTPClient.setResponse(for: "/v2/workouts/workout_to_delete", method: .DELETE, data: Data())

        // When
        try await sut.deleteWorkout(id: "workout_to_delete")

        // Then
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/workouts/workout_to_delete", "Path should include workout ID")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, HTTPMethod.DELETE, "Should use DELETE method")
    }

    func testDeleteWorkout_Success_CompletesWithoutError() async throws {
        // Given
        mockHTTPClient.setResponse(for: "/v2/workouts/workout_123", method: .DELETE, data: Data())

        // When/Then
        do {
            try await sut.deleteWorkout(id: "workout_123")
            XCTAssertTrue(true, "Delete completed without error")
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }

    // MARK: - fetchWorkoutStats Tests

    func testFetchWorkoutStats_BuildsCorrectPath() async throws {
        // Given
        let mockStats = createMockWorkoutStats()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/stats?days=30", method: .GET, response: mockStats)

        // When
        _ = try await sut.fetchWorkoutStats(days: 30)

        // Then
        XCTAssertTrue(mockHTTPClient.lastRequest?.path.contains("/v2/workouts/stats") ?? false, "Should use stats endpoint")
        XCTAssertTrue(mockHTTPClient.lastRequest?.path.contains("days=30") ?? false, "Should include days parameter")
    }

    func testFetchWorkoutStats_Success_ReturnsStats() async throws {
        // Given
        let mockStats = createMockWorkoutStats()
        try mockHTTPClient.setJSONResponse(for: "/v2/workouts/stats?days=30", method: .GET, response: mockStats)

        // When
        let stats = try await sut.fetchWorkoutStats(days: 30)

        // Then
        XCTAssertEqual(stats.data.totalWorkouts, 100, "Total workouts should match")
        XCTAssertEqual(stats.data.totalDistanceKm, 100.0, "Total distance should match")
    }

    // MARK: - Error Handling Tests

    func testFetchWorkout_ParserError_ThrowsError() async {
        // Given
        mockHTTPClient.setResponse(for: "/v2/workouts/workout_123", method: .GET, data: "invalid json".data(using: .utf8)!)

        // When/Then
        do {
            _ = try await sut.fetchWorkout(id: "workout_123")
            XCTFail("Should throw parser error")
        } catch {
            XCTAssertNotNil(error, "Should throw error")
        }
    }

    func testUploadWorkout_NetworkError_ThrowsError() async {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockHTTPClient.setError(for: "/v2/workouts/upload", method: .POST, error: networkError)

        // When/Then
        do {
            _ = try await sut.uploadWorkout(createUploadRequest())
            XCTFail("Should throw network error")
        } catch {
            XCTAssertNotNil(error, "Should throw error")
        }
    }

    // MARK: - Helper Methods

    private func createMockWorkoutListResponse() -> WorkoutListResponse {
        return WorkoutListResponse(
            workouts: [
                WorkoutV2(
                    id: "workout_1",
                    provider: "apple_health",
                    activityType: "running",
                    startTimeUtc: "2026-01-05T10:00:00Z",
                    endTimeUtc: "2026-01-05T11:00:00Z",
                    durationSeconds: 3600,
                    distanceMeters: 10000,
                    distanceDisplay: nil,
                    distanceUnit: nil,
                    deviceName: nil,
                    basicMetrics: nil,
                    advancedMetrics: nil,
                    createdAt: nil,
                    schemaVersion: nil,
                    storagePath: nil,
                    dailyPlanSummary: nil,
                    aiSummary: nil,
                    shareCardContent: nil
                )
            ],
            pagination: PaginationInfo(
                nextCursor: nil,
                prevCursor: nil,
                hasMore: false,
                hasNewer: false,
                oldestId: "workout_1",
                newestId: "workout_1",
                totalItems: 1,
                pageSize: 10
            )
        )
    }

    private func createMockWorkoutDetailResponse() -> WorkoutDetailResponse {
        // 使用 JSON 解碼來創建完整的 WorkoutDetailResponse
        let json = """
        {
            "id": "workout_123",
            "provider": "apple_health",
            "activity_type": "running",
            "sport_type": "running",
            "start_time": "2026-01-05T10:00:00Z",
            "end_time": "2026-01-05T11:00:00Z",
            "user_id": "user_123",
            "schema_version": "2.0",
            "source": "apple_health",
            "storage_path": "/workouts/123",
            "created_at": "2026-01-05T11:00:00Z",
            "updated_at": "2026-01-05T11:00:00Z",
            "original_id": "original_123",
            "provider_user_id": "provider_user_123"
        }
        """
        return try! JSONDecoder().decode(WorkoutDetailResponse.self, from: json.data(using: .utf8)!)
    }

    private func createUploadRequest() -> UploadWorkoutRequest {
        return UploadWorkoutRequest(
            sourceInfo: UploadSourceInfo(name: "apple_health", importMethod: "manual"),
            activityProfile: UploadActivityProfile(
                type: "running",
                startTimeUtc: "2026-01-05T10:00:00Z",
                endTimeUtc: "2026-01-05T11:00:00Z",
                durationTotalSeconds: 3600
            ),
            summaryMetrics: UploadSummaryMetrics(
                distanceMeters: 10000,
                activeCaloriesKcal: 500,
                avgHeartRateBpm: 150,
                maxHeartRateBpm: 180
            ),
            timeSeriesStreams: nil
        )
    }

    private func createMockWorkoutStats() -> WorkoutStatsResponse {
        return WorkoutStatsResponse(
            data: WorkoutStatsData(
                totalWorkouts: 100,
                totalDistanceKm: 100.0,
                avgPacePerKm: "6:00",
                providerDistribution: ["apple_health": 100],
                activityTypeDistribution: ["running": 100],
                periodDays: 30
            )
        )
    }
}
