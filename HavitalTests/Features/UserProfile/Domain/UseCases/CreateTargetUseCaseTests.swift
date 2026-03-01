//
//  CreateTargetUseCaseTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

final class CreateTargetUseCaseTests: XCTestCase {
    
    var sut: CreateTargetUseCase!
    var mockRepository: MockUserProfileRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserProfileRepository()
        sut = CreateTargetUseCase(repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testExecute_CreatesTargetSuccess() async throws {
        // Given
        let target = Target(
            id: "1",
            type: "race_run",
            name: "Test Race",
            distanceKm: 42,
            targetTime: 14400,
            targetPace: "5:41",
            raceDate: 1735689600,
            isMainRace: true,
            trainingWeeks: 12
        )
        // Success is default mock behavior
        
        // When
        try await sut.execute(input: .init(target: target))
        
        // Then
        XCTAssertEqual(mockRepository.createTargetCallCount, 1)
    }
    
    func testExecute_OnFailure_ThrowsError() async {
        // Given
        let target = Target(
            id: "1",
            type: "race_run",
            name: "Test Race",
            distanceKm: 42,
            targetTime: 14400,
            targetPace: "5:41",
            raceDate: 1735689600,
            isMainRace: true,
            trainingWeeks: 12
        )
        let expectedError = NSError(domain: "test", code: -1, userInfo: nil)
        mockRepository.errorToThrow = expectedError
        
        // When/Then
        do {
            try await sut.execute(input: .init(target: target))
            XCTFail("Should throw error")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
            XCTAssertEqual(mockRepository.createTargetCallCount, 1)
        }
    }
}
