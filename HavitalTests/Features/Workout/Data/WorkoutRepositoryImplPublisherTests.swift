//
//  WorkoutRepositoryImplPublisherTests.swift
//  HavitalTests
//
//  Test 1: WorkoutRepositoryImpl.workoutsDidRefresh publisher fires after background refresh.
//

import Combine
import XCTest
@testable import paceriz_dev

// MARK: - Stub Remote Data Source

/// Subclass that returns synthetic workout data immediately, without a real HTTP call.
final class StubWorkoutRemoteDataSource: WorkoutRemoteDataSource {

    var stubbedWorkouts: [WorkoutV2] = []
    var fetchCallCount = 0

    override func fetchWorkouts(pageSize: Int?, cursor: String?) async throws -> [WorkoutV2] {
        fetchCallCount += 1
        return stubbedWorkouts
    }
}

// MARK: - WorkoutRepositoryImpl Publisher Tests

final class WorkoutRepositoryImplPublisherTests: XCTestCase {

    var remoteDataSource: StubWorkoutRemoteDataSource!
    var localDataSource: WorkoutLocalDataSource!
    var repository: WorkoutRepositoryImpl!

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        remoteDataSource = StubWorkoutRemoteDataSource()

        // Use a unique suffix so each test run gets a fresh cache namespace.
        let suffix = "_test_publisher_\(UUID().uuidString)"
        localDataSource = WorkoutLocalDataSource(identifierSuffix: suffix)

        repository = WorkoutRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )
    }

    override func tearDown() {
        cancellables.removeAll()
        repository = nil
        localDataSource = nil
        remoteDataSource = nil
        super.tearDown()
    }

    // MARK: - Test 1: publisher fires after Track B background refresh succeeds

    /// Regression: WorkoutRepositoryImpl.workoutsDidRefresh must send after a successful
    /// background refresh (Track B). WorkoutListViewModel depends on this to republish EventBus.
    /// Found by QA architecture-health-A review.
    func test_workoutsDidRefresh_sendsAfterBackgroundRefresh() async {
        // Given: pre-populate local cache so getWorkouts() takes Track A and spawns Track B
        let cachedWorkout = makeWorkout(id: "cached_1")
        localDataSource.saveWorkouts([cachedWorkout])
        remoteDataSource.stubbedWorkouts = [makeWorkout(id: "fresh_1"), makeWorkout(id: "fresh_2")]

        let expectation = XCTestExpectation(description: "workoutsDidRefresh fires after background refresh")
        expectation.expectedFulfillmentCount = 1

        repository.workoutsDidRefresh
            .sink { expectation.fulfill() }
            .store(in: &cancellables)

        // Bypass the 12-hour cooldown so Track B actually runs
        repository.invalidateRefreshCooldown()

        // When: call getWorkouts — Track A returns cache, Track B fires in background
        _ = try? await repository.getWorkouts(limit: nil, offset: nil)

        // Then: wait for the background Task to complete and signal
        await fulfillment(of: [expectation], timeout: 3.0)

        // Confirm the background fetch did happen
        XCTAssertGreaterThanOrEqual(remoteDataSource.fetchCallCount, 1,
            "Remote data source should have been called by Track B")
    }

    // MARK: - Helper

    private func makeWorkout(id: String) -> WorkoutV2 {
        WorkoutV2(
            id: id,
            provider: "apple_health",
            activityType: "running",
            startTimeUtc: "2026-01-05T10:00:00Z",
            endTimeUtc: "2026-01-05T11:00:00Z",
            durationSeconds: 3600,
            distanceMeters: 1000,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: nil,
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: nil,
            schemaVersion: "2.0",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}
