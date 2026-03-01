//
//  AddSupportingTargetViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

@MainActor
final class AddSupportingTargetViewModelTests: XCTestCase {
    
    var sut: AddSupportingTargetViewModel!
    var mockRepository: MockTargetRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTargetRepository()
        sut = AddSupportingTargetViewModel(targetRepository: mockRepository)
        
        // Clear TargetStorage to avoid side effects
        TargetStorage.shared.clearAllTargets()
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        TargetStorage.shared.clearAllTargets()
        try await super.tearDown()
    }
    
    func testCreateTarget_Success_ReturnsTrue() async {
        // Given
        let target = TargetTestFixtures.supportingTarget
        mockRepository.targetToReturn = target
        
        sut.raceName = "Test Race"
        sut.selectedDistance = "10"
        sut.targetHours = 1
        sut.targetMinutes = 0
        
        // When
        let result = await sut.createTarget()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockRepository.createTargetCallCount, 1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        
        // Verify TargetStorage side effect (even if redundant)
        XCTAssertTrue(TargetStorage.shared.hasTargets())
    }
    
    func testCreateTarget_Failure_ReturnsFalseAndSetsError() async {
        // Given
        mockRepository.errorToThrow = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Error"])
        
        // When
        let result = await sut.createTarget()
        
        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
}
