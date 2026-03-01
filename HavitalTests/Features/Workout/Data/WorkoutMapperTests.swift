import XCTest
@testable import paceriz_dev

// MARK: - Workout Mapper Tests
/// 測試 WorkoutMapper 的數據轉換邏輯
class WorkoutMapperTests: XCTestCase {

    let decoder = JSONDecoder()

    // MARK: - WorkoutV2Detail → WorkoutV2 Conversion Tests

    func testToWorkoutV2_WithFullData_ConvertsCorrectly() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(fullWorkoutJSON)

        // When
        let result = WorkoutMapper.toWorkoutV2(from: detail)

        // Then
        XCTAssertEqual(result.id, "workout_123", "ID should match")
        XCTAssertEqual(result.provider, "apple_health", "Provider should match")
        XCTAssertEqual(result.activityType, "running", "Activity type should match")
        XCTAssertNotNil(result.basicMetrics, "Basic metrics should not be nil")
        XCTAssertNotNil(result.advancedMetrics, "Advanced metrics should not be nil")
    }

    func testToWorkoutV2_WithMinimalData_HandlesNilGracefully() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(minimalWorkoutJSON)

        // When
        let result = WorkoutMapper.toWorkoutV2(from: detail)

        // Then
        XCTAssertEqual(result.id, "workout_minimal", "ID should match")
        XCTAssertNil(result.basicMetrics, "Basic metrics should be nil")
        XCTAssertNil(result.advancedMetrics, "Advanced metrics should be nil")
    }

    // MARK: - BasicMetrics Conversion Tests

    func testToBasicMetrics_WithFullMetrics_ConvertsCorrectly() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(fullWorkoutJSON)
        let v2Metrics = detail.basicMetrics

        // When
        let result = WorkoutMapper.toBasicMetrics(from: v2Metrics)

        // Then
        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertNotNil(result?.avgHeartRateBpm, "Avg HR should exist")
        XCTAssertNotNil(result?.maxHeartRateBpm, "Max HR should exist")
        XCTAssertNotNil(result?.totalDistanceM, "Distance should exist")
    }

    func testToBasicMetrics_WithNilInput_ReturnsNil() {
        // When
        let result = WorkoutMapper.toBasicMetrics(from: nil)

        // Then
        XCTAssertNil(result, "Result should be nil when input is nil")
    }

    // MARK: - AdvancedMetrics Conversion Tests

    func testToAdvancedMetrics_WithFullMetrics_ConvertsCorrectly() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(fullWorkoutJSON)
        let v2Metrics = detail.advancedMetrics

        // When
        let result = WorkoutMapper.toAdvancedMetrics(from: v2Metrics)

        // Then
        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertNotNil(result?.dynamicVdot, "VDOT should exist")
        XCTAssertNotNil(result?.tss, "TSS should exist")
    }

    func testToAdvancedMetrics_WithNilInput_ReturnsNil() {
        // When
        let result = WorkoutMapper.toAdvancedMetrics(from: nil)

        // Then
        XCTAssertNil(result, "Result should be nil when input is nil")
    }

    // MARK: - IntensityMinutes Conversion Tests

    func testToIntensityMinutes_WithValidData_ConvertsCorrectly() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(fullWorkoutJSON)
        let v2Intensity = detail.advancedMetrics?.intensityMinutes

        // When
        let result = WorkoutMapper.toIntensityMinutes(from: v2Intensity)

        // Then
        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertNotNil(result?.low, "Low intensity should exist")
        XCTAssertNotNil(result?.medium, "Medium intensity should exist")
        XCTAssertNotNil(result?.high, "High intensity should exist")
    }

    // MARK: - ZoneDistribution Conversion Tests

    func testToZoneDistribution_WithValidData_ConvertsCorrectly() throws {
        // Given
        let detail = try createWorkoutV2DetailFromJSON(fullWorkoutJSON)
        let v2Zone = detail.advancedMetrics?.hrZoneDistribution

        // When
        let result = WorkoutMapper.toZoneDistribution(from: v2Zone)

        // Then
        XCTAssertNotNil(result, "Result should not be nil")
    }

    // MARK: - WorkoutV2 → UploadRequest Conversion Tests

    func testToUploadRequest_WithValidWorkout_CreatesCorrectRequest() throws {
        // Given
        let workout = try createWorkoutV2FromJSON(simpleWorkoutV2JSON)

        // When
        let request = WorkoutMapper.toUploadRequest(from: workout)

        // Then
        XCTAssertEqual(request.sourceInfo.name, "apple_health", "Source name should match")
        XCTAssertEqual(request.activityProfile.type, "running", "Activity type should match")
        XCTAssertEqual(request.activityProfile.durationTotalSeconds, 3600, "Duration should match")
        XCTAssertEqual(request.summaryMetrics?.distanceMeters, 10000, "Distance should match")
    }

    // MARK: - Data Validation Tests

    func testIsValid_WithValidWorkout_ReturnsTrue() throws {
        // Given
        let workout = try createWorkoutV2FromJSON(simpleWorkoutV2JSON)

        // When
        let isValid = WorkoutMapper.isValid(workout)

        // Then
        XCTAssertTrue(isValid, "Valid workout should pass validation")
    }

    func testIsValid_WithEmptyID_ReturnsFalse() throws {
        // Given
        var workout = try createWorkoutV2FromJSON(simpleWorkoutV2JSON)
        // 使用 JSON 創建新實例來修改 ID
        let invalidJSON = """
        {
            "id": "",
            "provider": "test",
            "activity_type": "running",
            "duration_seconds": 3600
        }
        """
        workout = try decoder.decode(WorkoutV2.self, from: invalidJSON.data(using: .utf8)!)

        // When
        let isValid = WorkoutMapper.isValid(workout)

        // Then
        XCTAssertFalse(isValid, "Workout with empty ID should fail validation")
    }

    func testIsValid_WithZeroDuration_ReturnsFalse() throws {
        // Given
        let invalidJSON = """
        {
            "id": "test_123",
            "provider": "test",
            "activity_type": "running",
            "duration_seconds": 0
        }
        """
        let workout = try decoder.decode(WorkoutV2.self, from: invalidJSON.data(using: .utf8)!)

        // When
        let isValid = WorkoutMapper.isValid(workout)

        // Then
        XCTAssertFalse(isValid, "Workout with zero duration should fail validation")
    }

    func testSanitize_ReturnsWorkout() throws {
        // Given
        let workout = try createWorkoutV2FromJSON(simpleWorkoutV2JSON)

        // When
        let sanitized = WorkoutMapper.sanitize(workout)

        // Then
        XCTAssertEqual(sanitized.id, workout.id, "Sanitized workout should match original")
    }

    // MARK: - Helper Methods

    private func createWorkoutV2DetailFromJSON(_ json: String) throws -> WorkoutV2Detail {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create data from JSON"])
        }
        return try decoder.decode(WorkoutV2Detail.self, from: data)
    }

    private func createWorkoutV2FromJSON(_ json: String) throws -> WorkoutV2 {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create data from JSON"])
        }
        return try decoder.decode(WorkoutV2.self, from: data)
    }

    // MARK: - Test JSON Data

    private let fullWorkoutJSON = """
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
        "provider_user_id": "provider_user_123",
        "basic_metrics": {
            "avg_heart_rate_bpm": 150,
            "max_heart_rate_bpm": 180,
            "total_distance_m": 10000,
            "total_duration_s": 3600
        },
        "advanced_metrics": {
            "dynamic_vdot": 50.0,
            "tss": 100,
            "intensity_minutes": {
                "low": 10,
                "medium": 20,
                "high": 30
            },
            "hr_zone_distribution": {
                "marathon": 10,
                "threshold": 20,
                "recovery": 15,
                "interval": 25,
                "anaerobic": 20,
                "easy": 10
            }
        }
    }
    """

    private let minimalWorkoutJSON = """
    {
        "id": "workout_minimal",
        "provider": "manual",
        "activity_type": "walking",
        "sport_type": "walking",
        "start_time": "2026-01-05T08:00:00Z",
        "end_time": "2026-01-05T08:30:00Z",
        "user_id": "user_123",
        "schema_version": "2.0",
        "source": "manual",
        "storage_path": "/workouts/minimal",
        "created_at": "2026-01-05T08:30:00Z",
        "updated_at": "2026-01-05T08:30:00Z",
        "original_id": "original_minimal",
        "provider_user_id": "provider_user_123"
    }
    """

    private let simpleWorkoutV2JSON = """
    {
        "id": "workout_simple",
        "provider": "apple_health",
        "activity_type": "running",
        "duration_seconds": 3600,
        "distance_meters": 10000,
        "start_time_utc": "2026-01-05T10:00:00Z",
        "end_time_utc": "2026-01-05T11:00:00Z"
    }
    """
}
