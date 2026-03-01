//
//  EditScheduleViewModelTests.swift
//  HavitalTests
//
//  Unit tests for EditScheduleViewModel
//

import XCTest
@testable import paceriz_dev

@MainActor
final class EditScheduleViewModelTests: XCTestCase {

    var viewModel: EditScheduleViewModel!
    var mockRepository: MockTrainingPlanRepository!
    var mockWeeklyPlan: WeeklyPlan!

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTrainingPlanRepository()

        // TODO: Create a test weekly plan with the new model structure
        // This test needs to be updated to work with the refactored WeeklyPlan model
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        mockWeeklyPlan = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testMockRepository_Initialized() {
        XCTAssertNotNil(mockRepository)
    }
}
