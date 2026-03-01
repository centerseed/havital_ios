//
//  TargetFeatureViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

@MainActor
final class TargetFeatureViewModelTests: XCTestCase {
    
    var sut: TargetFeatureViewModel!
    var mockRepository: MockTargetRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTargetRepository()
        sut = TargetFeatureViewModel(repository: mockRepository)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - loadTargets Tests
    
    func testLoadTargets_Success_UpdatesPublishedProperties() async throws {
        // Given
        let targets = TargetTestFixtures.targetsList
        mockRepository.targetsToReturn = targets
        
        // When
        await sut.loadTargets()
        
        // Then
        XCTAssertEqual(sut.targets.count, 2)
        XCTAssertEqual(sut.mainTarget?.id, TargetTestFixtures.mainTarget.id)
        XCTAssertEqual(sut.supportingTargets.count, 1)
        XCTAssertEqual(sut.supportingTargets.first?.id, TargetTestFixtures.supportingTarget.id)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }
    
    func testLoadTargets_Failure_UpdatesErrorState() async throws {
        // Given
        let expectedError = NSError(domain: "test", code: -1, userInfo: nil)
        mockRepository.errorToThrow = expectedError
        
        // When
        await sut.loadTargets()
        
        // Then
        XCTAssertTrue(sut.targets.isEmpty)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - CRUD Operations Tests
    
    func testCreateTarget_Success_ReloadsTargets() async throws {
        // Given
        let newTarget = TargetTestFixtures.supportingTarget
        mockRepository.targetsToReturn = [TargetTestFixtures.mainTarget, newTarget]
        
        // When
        _ = try await sut.createTarget(newTarget)
        
        // Then
        XCTAssertEqual(mockRepository.createTargetCallCount, 1)
        XCTAssertEqual(mockRepository.getTargetsCallCount, 1, "Should reload targets after creation")
        XCTAssertEqual(sut.targets.count, 2)
    }
    
    func testDeleteTarget_Success_ReloadsTargets() async throws {
        // Given
        let targetId = "target_123"
        mockRepository.targetsToReturn = [] // Simulate empty after deletion
        
        // When
        try await sut.deleteTarget(id: targetId)
        
        // Then
        XCTAssertEqual(mockRepository.deleteTargetCallCount, 1)
        XCTAssertEqual(mockRepository.getTargetsCallCount, 1, "Should reload targets after deletion")
        XCTAssertTrue(sut.targets.isEmpty)
    }
    
    // MARK: - Force Refresh Tests
    
    func testForceRefresh_Success_UpdatesState() async throws {
        // Given
        let targets = TargetTestFixtures.targetsList
        mockRepository.targetsToReturn = targets
        
        // When
        await sut.forceRefresh()
        
        // Then
        XCTAssertEqual(mockRepository.forceRefreshCallCount, 1)
        XCTAssertEqual(sut.targets.count, 2)
    }
}
