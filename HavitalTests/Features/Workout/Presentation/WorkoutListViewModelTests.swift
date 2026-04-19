//
//  WorkoutListViewModelTests.swift
//  HavitalTests
//
//  Unit tests for WorkoutListViewModel
//  Re-written to fix compilation errors caused by mismatched model definitions.
//

import Combine
import XCTest
@testable import paceriz_dev

@MainActor
final class WorkoutListViewModelTests: XCTestCase {

    var viewModel: WorkoutListViewModel!
    var mockRepository: WorkoutListTestMockRepository!

    // Mocks
    var mockGetWorkoutsUseCase: MockGetWorkoutsUseCase!
    var mockDeleteWorkoutUseCase: MockDeleteWorkoutUseCase!

    // Combine cleanup
    var cancellables = Set<AnyCancellable>()

    override func setUp() async throws {
        try await super.setUp()

        mockRepository = WorkoutListTestMockRepository()

        // Setup Mocks
        mockGetWorkoutsUseCase = MockGetWorkoutsUseCase(repository: mockRepository)
        mockDeleteWorkoutUseCase = MockDeleteWorkoutUseCase(repository: mockRepository)

        // Manual Injection
        viewModel = WorkoutListViewModel(
            getWorkoutsUseCase: mockGetWorkoutsUseCase,
            deleteWorkoutUseCase: mockDeleteWorkoutUseCase,
            repository: mockRepository
        )
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        viewModel = nil
        mockGetWorkoutsUseCase = nil
        mockDeleteWorkoutUseCase = nil
        mockRepository = nil
        try await super.tearDown()
    }

    // MARK: - Existing tests

    func testViewModel_Initialized() {
        XCTAssertNotNil(viewModel)
    }

    func testLoadWorkouts_Success() async {
        // Given
        let mockWorkouts = [createMockWorkout(id: "1"), createMockWorkout(id: "2")]
        mockGetWorkoutsUseCase.executeReturnValue = mockWorkouts

        // When
        await viewModel.loadWorkouts()

        // Then
        if case .loaded(let workouts) = viewModel.state {
            XCTAssertEqual(workouts.count, 2)
            XCTAssertEqual(workouts.first?.id, "1")
        } else {
            XCTFail("Expected state to be .loaded")
        }
    }

    func testLoadWorkouts_Failure() async {
        // Given
        mockGetWorkoutsUseCase.shouldThrowError = true

        // When
        await viewModel.loadWorkouts()

        // Then
        if case .error(let error) = viewModel.state {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected state to be .error")
        }
    }

    func testDeleteWorkout_Success() async {
        // Given
        let workout = createMockWorkout(id: "1")
        mockGetWorkoutsUseCase.executeReturnValue = [workout]
        await viewModel.loadWorkouts() // Load initial state

        // When
        _ = await viewModel.deleteWorkout(id: workout.id)

        // Then
        XCTAssertTrue(mockDeleteWorkoutUseCase.executeCalled)
        if case .loaded(_) = viewModel.state {
            // Success
        }
    }

    // MARK: - Test 2: VM republish EventBus when repository signals refresh

    /// Regression: WorkoutListViewModel must republish CacheEventBus when repository workoutsDidRefresh fires.
    /// Found by QA architecture-health-A review.
    func test_repositoryRefreshSignal_republishesToEventBus() {
        // Given
        let expectation = XCTestExpectation(description: "EventBus receives dataChanged.workouts after repository refresh")
        expectation.expectedFulfillmentCount = 1

        let identifier = "QATest_repositoryRefreshSignal_\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: identifier) { event in
            if case .dataChanged(let dataType) = event, "\(dataType)" == "workouts" {
                expectation.fulfill()
            }
        }

        // When: simulate repository background refresh completing
        mockRepository.refreshSubject.send()

        // Then
        wait(for: [expectation], timeout: 2.0)

        // Cleanup
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)
    }

    // MARK: - Test 3: deleteWorkout success path publishes EventBus

    /// Regression: WorkoutListViewModel.deleteWorkout must publish CacheEventBus.dataChanged(.workouts) on success.
    /// Found by QA architecture-health-A review.
    func test_deleteWorkout_publishesEventBus() async {
        // Given
        let expectation = XCTestExpectation(description: "EventBus receives dataChanged.workouts after delete")
        // Use >= 1: VM subscribes to its own event which may trigger another publish.
        expectation.assertForOverFulfill = false

        let identifier = "QATest_deleteWorkout_\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: identifier) { event in
            if case .dataChanged(let dataType) = event, "\(dataType)" == "workouts" {
                expectation.fulfill()
            }
        }

        // When
        _ = await viewModel.deleteWorkout(id: "1")

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)

        // Cleanup
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)
    }

    // MARK: - Helper

    private func createMockWorkout(id: String) -> WorkoutV2 {
        return WorkoutV2(
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

// MARK: - Mocks

// 1. Mock Repository
class WorkoutListTestMockRepository: WorkoutRepository {
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { return [] }
    func getAllWorkouts() -> [WorkoutV2] { return [] }

    // Async methods
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { return [] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { return [] }

    // Pagination methods
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        let pagination = PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)
        return WorkoutListResponse(workouts: [], pagination: pagination)
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        let pagination = PaginationInfo(nextCursor: nil, prevCursor: afterCursor, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)
        return WorkoutListResponse(workouts: [], pagination: pagination)
    }

    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        let pagination = PaginationInfo(nextCursor: nil, prevCursor: beforeCursor, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize)
        return WorkoutListResponse(workouts: [], pagination: pagination)
    }

    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { return [] }
    func refreshWorkouts() async throws -> [WorkoutV2] { return [] }
    func getWorkout(id: String) async throws -> WorkoutV2 { fatalError("Not implemented") }
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail { fatalError("Not implemented") }
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail { fatalError("Not implemented") }
    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { return workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}
    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}

    var workoutsDidUpdateNotification: Notification.Name { return Notification.Name("MockWorkoutUpdate") }

    let refreshSubject = PassthroughSubject<Void, Never>()
    var workoutsDidRefresh: AnyPublisher<Void, Never> { refreshSubject.eraseToAnyPublisher() }
}

// 2. Mock UseCases
class MockGetWorkoutsUseCase: GetWorkoutsUseCase {
    var executeReturnValue: [WorkoutV2] = []
    var shouldThrowError = false

    // Override execute since it's a class method
    override func execute(limit: Int?, offset: Int?) async throws -> [WorkoutV2] {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: -1)
        }
        return executeReturnValue
    }
}

class MockDeleteWorkoutUseCase: DeleteWorkoutUseCase {
    var executeCalled = false

    // Override execute
    override func execute(workoutId: String) async throws {
        executeCalled = true
    }
}
