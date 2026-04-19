//
//  DeleteWorkoutUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for DeleteWorkoutUseCase
//

import XCTest
import Combine
@testable import paceriz_dev

final class DeleteWorkoutUseCaseTests: XCTestCase {

    var useCase: DeleteWorkoutUseCase!
    var mockRepository: MockWorkoutRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockWorkoutRepository()
        useCase = DeleteWorkoutUseCase(repository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testExecute_callsRepositoryDeleteWorkout() async throws {
        // Given
        let workoutId = "workout_123"

        // When
        try await useCase.execute(workoutId: workoutId)

        // Then
        XCTAssertEqual(mockRepository.deleteWorkoutCallCount, 1)
        XCTAssertEqual(mockRepository.deleteWorkoutLastId, workoutId)
    }

    func testExecute_callsClearCache() async throws {
        // Given
        let workoutId = "workout_456"

        // When
        try await useCase.execute(workoutId: workoutId)

        // Then
        XCTAssertEqual(mockRepository.clearCacheCallCount, 1)
    }

    func testExecute_whenRepositoryFails_throwsError() async throws {
        // Given
        let expectedError = WorkoutError.networkError("Delete failed")
        mockRepository.errorToThrow = expectedError

        // When/Then
        do {
            try await useCase.execute(workoutId: "workout_789")
            XCTFail("Should throw error")
        } catch let error as WorkoutError {
            XCTAssertEqual(error, expectedError)
        }
    }

    // MARK: - Test 4: DeleteWorkoutUseCase does NOT publish CacheEventBus (negative test)

    /// Regression: DeleteWorkoutUseCase must NOT touch CacheEventBus directly.
    /// EventBus publish is WorkoutListViewModel's responsibility, not the use case.
    /// Found by QA architecture-health-A review.
    func testExecute_doesNotPublishCacheEventBus() async throws {
        // Given
        let notExpected = XCTestExpectation(description: "CacheEventBus must NOT receive event from UseCase")
        notExpected.isInverted = true

        let identifier = "QATest_deleteUseCase_negative_\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: identifier) { event in
            if case .dataChanged(let dataType) = event, "\(dataType)" == "workouts" {
                notExpected.fulfill()
            }
        }

        // When
        try await useCase.execute(workoutId: "workout_negative_test")

        // Then: wait 0.5s — if EventBus fires, the inverted expectation fails
        wait(for: [notExpected], timeout: 0.5)

        // Cleanup
        CacheEventBus.shared.unsubscribe(forIdentifier: identifier)
    }
}
