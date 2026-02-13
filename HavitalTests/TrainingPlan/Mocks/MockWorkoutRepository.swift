//
//  MockWorkoutRepository.swift
//  HavitalTests
//
//  Mock implementation of WorkoutRepository for testing
//

import Foundation
@testable import paceriz_dev

class MockWorkoutRepository: WorkoutRepository {

    // MARK: - Test Data

    var workoutsToReturn: [WorkoutV2] = []
    var errorToThrow: Error?

    // MARK: - Call Tracking

    var getWorkoutsInDateRangeCallCount = 0
    var getWorkoutsInDateRangeLastParams: (startDate: Date, endDate: Date)?

    var getAllWorkoutsCallCount = 0
    var getWorkoutsCallCount = 0
    var getWorkoutsLastParams: (limit: Int?, offset: Int?)?
    var refreshWorkoutsCallCount = 0
    var getWorkoutCallCount = 0
    var syncWorkoutCallCount = 0
    var deleteWorkoutCallCount = 0
    var deleteWorkoutLastId: String?
    var clearCacheCallCount = 0
    var preloadDataCallCount = 0

    // MARK: - WorkoutRepository Implementation

    var workoutsDidUpdateNotification: Notification.Name {
        return .workoutsDidUpdate
    }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        getWorkoutsInDateRangeCallCount += 1
        getWorkoutsInDateRangeLastParams = (startDate, endDate)
        return workoutsToReturn
    }

    func getAllWorkouts() -> [WorkoutV2] {
        getAllWorkoutsCallCount += 1
        return workoutsToReturn
    }

    // MARK: - New Async Methods

    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] {
        getWorkoutsInDateRangeCallCount += 1
        getWorkoutsInDateRangeLastParams = (startDate, endDate)
        return workoutsToReturn
    }

    func getAllWorkoutsAsync() async -> [WorkoutV2] {
        getAllWorkoutsCallCount += 1
        return workoutsToReturn
    }

    // MARK: - Pagination Methods

    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: nil,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: afterCursor,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: beforeCursor,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] {
        getWorkoutsCallCount += 1
        getWorkoutsLastParams = (limit, offset)
        if let error = errorToThrow {
            throw error
        }
        return workoutsToReturn
    }

    func refreshWorkouts() async throws -> [WorkoutV2] {
        refreshWorkoutsCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return workoutsToReturn
    }

    func getWorkout(id: String) async throws -> WorkoutV2 {
        getWorkoutCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        guard let workout = workoutsToReturn.first(where: { $0.id == id }) else {
            throw DomainError.notFound("Workout not found")
        }
        return workout
    }

    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 {
        syncWorkoutCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return workout
    }

    func deleteWorkout(id: String) async throws {
        deleteWorkoutCallCount += 1
        deleteWorkoutLastId = id
        if let error = errorToThrow {
            throw error
        }
    }

    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        if let error = errorToThrow {
            throw error
        }
        // Return a mock detail - in real tests, you'd configure this
        throw DomainError.notFound("Mock not implemented")
    }

    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        if let error = errorToThrow {
            throw error
        }
        throw DomainError.notFound("Mock not implemented")
    }

    func clearWorkoutDetailCache(id: String) async {
        // Mock implementation
    }

    func updateTrainingNotes(id: String, notes: String) async throws {
        if let error = errorToThrow {
            throw error
        }
    }

    func invalidateRefreshCooldown() {}

    func clearCache() async {
        clearCacheCallCount += 1
    }

    func preloadData() async {
        preloadDataCallCount += 1
    }

    // MARK: - Reset

    func reset() {
        workoutsToReturn = []
        errorToThrow = nil
        getWorkoutsInDateRangeCallCount = 0
        getWorkoutsInDateRangeLastParams = nil
        getAllWorkoutsCallCount = 0
        getWorkoutsCallCount = 0
        refreshWorkoutsCallCount = 0
        getWorkoutCallCount = 0
        syncWorkoutCallCount = 0
        deleteWorkoutCallCount = 0
        clearCacheCallCount = 0
        preloadDataCallCount = 0
    }
}
