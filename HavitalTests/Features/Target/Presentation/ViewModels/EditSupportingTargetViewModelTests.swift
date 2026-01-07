//
//  EditSupportingTargetViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

@MainActor
final class EditSupportingTargetViewModelTests: XCTestCase {
    
    var sut: EditSupportingTargetViewModel!
    var mockRepository: MockTargetRepository!
    var testTarget: Target!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTargetRepository()
        testTarget = TargetTestFixtures.supportingTarget
        sut = EditSupportingTargetViewModel(target: testTarget, targetRepository: mockRepository)
        
        // Clear TargetStorage to avoid side effects
        TargetStorage.shared.clearAllTargets()
        TargetStorage.shared.saveTarget(testTarget)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        testTarget = nil
        TargetStorage.shared.clearAllTargets()
        try await super.tearDown()
    }
    
    func testInitialization_SetsUpInitialProperties() {
        XCTAssertEqual(sut.raceName, testTarget.name)
        XCTAssertEqual(sut.targetHours, testTarget.targetTime / 3600)
        XCTAssertEqual(sut.targetMinutes, (testTarget.targetTime % 3600) / 60)
    }
    
    func testUpdateTarget_Success_ReturnsTrue() async {
        // Given
        mockRepository.targetToReturn = testTarget
        sut.raceName = "Updated Name"
        
        // When
        let result = await sut.updateTarget()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockRepository.updateTargetCallCount, 1)
        XCTAssertEqual(TargetStorage.shared.getTarget(id: testTarget.id)?.name, "Updated Name")
    }
    
    func testDeleteTarget_Success_ReturnsTrue() async {
        // When
        let result = await sut.deleteTarget()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockRepository.deleteTargetCallCount, 1)
    }
    
    func testDeleteTarget_CloudNotFound_RemovesFromLocalAndReturnsTrue() async {
        // Given
        mockRepository.errorToThrow = NSError(domain: "APIClient", code: 404, userInfo: nil)
        
        // When
        let result = await sut.deleteTarget()
        
        // Then
        XCTAssertTrue(result, "Should return true even if cloud not found, as it handles the cleanup")
        XCTAssertEqual(mockRepository.deleteTargetCallCount, 1)
        XCTAssertNil(TargetStorage.shared.getTarget(id: testTarget.id), "Should have removed from local storage")
    }
}
