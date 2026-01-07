//
//  LoadWeeklyWorkoutsUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for LoadWeeklyWorkoutsUseCase
//

import XCTest
@testable import paceriz_dev

final class LoadWeeklyWorkoutsUseCaseTests: XCTestCase {

    var useCase: LoadWeeklyWorkoutsUseCase!
    var mockRepository: MockWorkoutRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockWorkoutRepository()
        useCase = LoadWeeklyWorkoutsUseCase(workoutRepository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testUseCase_Initialized() {
        XCTAssertNotNil(useCase)
    }

    func testUseCase_RepositoryRegistered() {
        XCTAssertNotNil(mockRepository)
    }
}
