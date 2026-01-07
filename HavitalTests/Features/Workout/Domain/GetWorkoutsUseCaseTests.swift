//
//  GetWorkoutsUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for GetWorkoutsUseCase
//

import XCTest
@testable import paceriz_dev

final class GetWorkoutsUseCaseTests: XCTestCase {

    var useCase: GetWorkoutsUseCase!
    var mockRepository: MockWorkoutRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockWorkoutRepository()
        useCase = GetWorkoutsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    func testUseCase_Initialized() {
        XCTAssertNotNil(useCase)
    }

    func testRepository_Initialized() {
        XCTAssertNotNil(mockRepository)
    }
}
