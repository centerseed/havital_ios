import XCTest
@testable import paceriz_dev

// MARK: - Workout Local Data Source Tests
/// 測試 WorkoutLocalDataSource 的緩存邏輯
class WorkoutLocalDataSourceTests: XCTestCase {

    var sut: WorkoutLocalDataSource!

    /// 每個測試實例使用唯一的緩存標識，避免並行測試互相干擾
    private var testIdentifier: String!

    override func setUp() {
        super.setUp()
        // 使用 UUID 確保每個測試實例有獨立的緩存空間
        testIdentifier = "_test_\(UUID().uuidString)"
        sut = WorkoutLocalDataSource(identifierSuffix: testIdentifier)
        // 確保測試開始時緩存為空
        sut.clearAll()
    }

    override func tearDown() {
        sut.clearAll()
        sut = nil
        testIdentifier = nil
        super.tearDown()
    }

    // MARK: - Workout List Tests

    func testGetWorkouts_WhenCacheEmpty_ReturnsNil() {
        // When
        let result = sut.getWorkouts()

        // Then
        XCTAssertNil(result, "Empty cache should return nil")
    }

    func testSaveWorkouts_ThenGet_ReturnsWorkouts() {
        // Given
        let workouts = createMockWorkouts(count: 5)

        // When
        sut.saveWorkouts(workouts)
        let result = sut.getWorkouts()

        // Then
        XCTAssertNotNil(result, "Cache should contain workouts")
        XCTAssertEqual(result?.count, 5, "Should return all saved workouts")
        XCTAssertEqual(result?.first?.id, "workout_0", "First workout ID should match")
    }

    func testSaveWorkouts_OverwritesPreviousCache() {
        // Given
        let firstBatch = createMockWorkouts(count: 3)
        let secondBatch = createMockWorkouts(count: 5)

        // When
        sut.saveWorkouts(firstBatch)
        sut.saveWorkouts(secondBatch)
        let result = sut.getWorkouts()

        // Then
        XCTAssertEqual(result?.count, 5, "Should return latest batch count")
    }

    // MARK: - Single Workout Tests

    func testGetWorkout_WhenCacheEmpty_ReturnsNil() {
        // When
        let result = sut.getWorkout(id: "workout_123")

        // Then
        XCTAssertNil(result, "Empty cache should return nil")
    }

    func testSaveWorkout_ThenGet_ReturnsWorkout() {
        // Given
        let workout = createMockWorkout(id: "workout_123")

        // When
        sut.saveWorkout(workout)
        let result = sut.getWorkout(id: "workout_123")

        // Then
        XCTAssertNotNil(result, "Cache should contain workout")
        XCTAssertEqual(result?.id, "workout_123", "Workout ID should match")
    }

    // MARK: - FindWorkoutInList Tests

    func testFindWorkoutInList_WhenExists_ReturnsWorkout() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        let result = sut.findWorkoutInList(id: "workout_2")

        // Then
        XCTAssertNotNil(result, "Should find workout in list")
        XCTAssertEqual(result?.id, "workout_2", "Should return correct workout")
    }

    func testFindWorkoutInList_WhenNotExists_ReturnsNil() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        let result = sut.findWorkoutInList(id: "workout_999")

        // Then
        XCTAssertNil(result, "Should not find non-existent workout")
    }

    func testFindWorkoutInList_WhenCacheEmpty_ReturnsNil() {
        // When
        let result = sut.findWorkoutInList(id: "workout_123")

        // Then
        XCTAssertNil(result, "Should return nil when cache is empty")
    }

    // MARK: - Delete Tests

    func testDeleteWorkout_RemovesFromCache() {
        // Given
        let workout = createMockWorkout(id: "workout_123")
        sut.saveWorkout(workout)

        // When
        sut.deleteWorkout(id: "workout_123")
        let result = sut.getWorkout(id: "workout_123")

        // Then
        XCTAssertNil(result, "Workout should be deleted from cache")
    }

    func testDeleteWorkout_RemovesFromListCache() {
        // Given
        var workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        sut.deleteWorkout(id: "workout_2")
        let result = sut.getWorkouts()

        // Then
        XCTAssertEqual(result?.count, 4, "List should have one less workout")
        XCTAssertNil(result?.first(where: { $0.id == "workout_2" }), "Deleted workout should not be in list")
    }

    // MARK: - Cache Management Tests

    func testClearAll_RemovesAllCaches() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        let singleWorkout = createMockWorkout(id: "workout_single")
        sut.saveWorkouts(workouts)
        sut.saveWorkout(singleWorkout)

        // When
        sut.clearAll()

        // Then
        XCTAssertNil(sut.getWorkouts(), "Workout list cache should be cleared")
        XCTAssertNil(sut.getWorkout(id: "workout_single"), "Single workout cache should be cleared")
    }

    func testGetCacheStats_ReturnsCorrectSizes() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        let stats = sut.getCacheStats()

        // Then
        XCTAssertTrue(stats.listCacheSize > 0, "List cache size should be greater than 0")
        XCTAssertEqual(stats.totalSize, stats.listCacheSize + stats.detailCacheSize, "Total size should be sum of both caches")
    }

    func testGetCacheSize_WhenEmpty_ReturnsZero() {
        // When
        let size = sut.getCacheSize()

        // Then
        XCTAssertEqual(size, 0, "Empty cache should have size 0")
    }

    func testGetCacheSize_AfterSaving_ReturnsNonZero() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        let size = sut.getCacheSize()

        // Then
        XCTAssertTrue(size > 0, "Cache with data should have size > 0")
    }

    // MARK: - Cacheable Protocol Tests

    func testCacheIdentifier_ReturnsCorrectValue() {
        // When
        let identifier = sut.cacheIdentifier

        // Then
        XCTAssertEqual(identifier, "WorkoutLocalDataSource", "Cache identifier should match")
    }

    func testClearCache_ClearsAllData() {
        // Given
        let workouts = createMockWorkouts(count: 3)
        sut.saveWorkouts(workouts)

        // When
        sut.clearCache()

        // Then
        XCTAssertNil(sut.getWorkouts(), "Cache should be cleared")
    }

    // MARK: - Cache Expiration Tests

    func testIsExpired_WhenBothCachesExpired_ReturnsTrue() {
        // Given - 清空緩存讓兩個緩存都處於過期狀態
        sut.clearAll()

        // When
        let isExpired = sut.isExpired()

        // Then
        // 注意：由於實際的過期邏輯依賴於時間，這個測試可能需要調整
        // 當兩個緩存都為空時，應該被視為過期
        XCTAssertTrue(isExpired, "Both empty caches should be considered expired")
    }

    func testIsExpired_WhenCacheFresh_ReturnsFalse() {
        // Given
        let workouts = createMockWorkouts(count: 3)
        sut.saveWorkouts(workouts)

        // When
        let isExpired = sut.isExpired()

        // Then
        XCTAssertFalse(isExpired, "Fresh cache should not be expired")
    }

    // MARK: - Edge Cases Tests

    func testSaveWorkouts_WithEmptyArray_SavesSuccessfully() {
        // Given
        let emptyWorkouts: [WorkoutV2] = []

        // When
        sut.saveWorkouts(emptyWorkouts)
        let result = sut.getWorkouts()

        // Then
        XCTAssertNotNil(result, "Should save empty array")
        XCTAssertEqual(result?.count, 0, "Should return empty array")
    }

    func testFindWorkoutInList_WithEmptyID_ReturnsNil() {
        // Given
        let workouts = createMockWorkouts(count: 5)
        sut.saveWorkouts(workouts)

        // When
        let result = sut.findWorkoutInList(id: "")

        // Then
        XCTAssertNil(result, "Should not find workout with empty ID")
    }

    func testDeleteWorkout_WhenNotInCache_DoesNotCrash() {
        // When/Then
        XCTAssertNoThrow(sut.deleteWorkout(id: "non_existent_workout"), "Delete should not crash for non-existent workout")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentSaveAndGet_DoesNotCrash() {
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let iterations = 100

        for i in 0..<iterations {
            queue.async {
                let workouts = self.createMockWorkouts(count: 5)
                self.sut.saveWorkouts(workouts)
            }

            queue.async {
                _ = self.sut.getWorkouts()
            }

            if i == iterations - 1 {
                queue.async {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Concurrent operations should complete without crashing")
    }

    // MARK: - Helper Methods

    private func createMockWorkout(id: String) -> WorkoutV2 {
        return WorkoutV2(
            id: id,
            provider: "apple_health",
            activityType: "running",
            startTimeUtc: "2026-01-05T10:00:00Z",
            endTimeUtc: "2026-01-05T11:00:00Z",
            durationSeconds: 3600,
            distanceMeters: 10000,
            deviceName: "Apple Watch",
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: "2026-01-05T11:00:00Z",
            schemaVersion: "2.0",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }

    private func createMockWorkouts(count: Int) -> [WorkoutV2] {
        return (0..<count).map { index in
            createMockWorkout(id: "workout_\(index)")
        }
    }
}
