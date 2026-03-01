//
//  DeleteWorkoutUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for DeleteWorkoutUseCase
//

import XCTest
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
}
