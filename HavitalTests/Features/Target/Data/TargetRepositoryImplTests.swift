//
//  TargetRepositoryImplTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

final class TargetRepositoryImplTests: XCTestCase {
    
    var sut: TargetRepositoryImpl!
    var mockRemoteDS: MockTargetRemoteDataSource!
    var mockLocalDS: MockTargetLocalDataSource!
    
    override func setUp() {
        super.setUp()
        mockRemoteDS = MockTargetRemoteDataSource()
        mockLocalDS = MockTargetLocalDataSource()
        sut = TargetRepositoryImpl(remoteDataSource: mockRemoteDS, localDataSource: mockLocalDS)
    }
    
    override func tearDown() {
        sut = nil
        mockRemoteDS = nil
        mockLocalDS = nil
        super.tearDown()
    }

    private func waitForBackgroundRefresh(
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async {
        let interval: UInt64 = 20_000_000
        var elapsed: UInt64 = 0

        while elapsed < timeoutNanoseconds {
            if mockRemoteDS.getTargetCallCount > 0 || mockRemoteDS.getTargetsCallCount > 0 {
                return
            }
            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }
    }
    
    // MARK: - getTargets Tests
    
    func testGetTargets_CacheHit_ReturnsCachedDataAndTriggersBackgroundRefresh() async throws {
        // Given
        let cachedTargets = TargetTestFixtures.targetsList
        mockLocalDS.targetsToReturn = cachedTargets
        
        // When
        let result = try await sut.getTargets()
        
        // Then
        XCTAssertEqual(result.count, cachedTargets.count)
        XCTAssertEqual(result.first?.id, cachedTargets.first?.id)
        XCTAssertEqual(mockLocalDS.getTargetsCallCount, 1)
        
        // Background refresh should be triggered
        await waitForBackgroundRefresh()
        XCTAssertEqual(mockRemoteDS.getTargetsCallCount, 1, "Background refresh should have been called")
        XCTAssertEqual(mockLocalDS.saveTargetsCallCount, 1, "Cache should have been updated after background refresh")
    }
    
    func testGetTargets_CacheMiss_FetchesFromAPIAndSavesToCache() async throws {
        // Given
        mockLocalDS.targetsToReturn = []
        let apiTargets = TargetTestFixtures.targetsList
        mockRemoteDS.targetsToReturn = apiTargets
        
        // When
        let result = try await sut.getTargets()
        
        // Then
        XCTAssertEqual(result.count, apiTargets.count)
        XCTAssertEqual(mockLocalDS.getTargetsCallCount, 1)
        XCTAssertEqual(mockRemoteDS.getTargetsCallCount, 1)
        XCTAssertEqual(mockLocalDS.saveTargetsCallCount, 1)
    }
    
    // MARK: - getTarget Tests
    
    func testGetTarget_CacheHit_ReturnsCachedTargetAndTriggersBackgroundRefresh() async throws {
        // Given
        let cachedTarget = TargetTestFixtures.mainTarget
        mockLocalDS.targetToReturn = cachedTarget
        mockRemoteDS.targetToReturn = cachedTarget
        
        // When
        let result = try await sut.getTarget(id: cachedTarget.id)
        
        // Then
        XCTAssertEqual(result.id, cachedTarget.id)
        XCTAssertEqual(mockLocalDS.getTargetCallCount, 1)
        
        // Background refresh
        await waitForBackgroundRefresh()
        XCTAssertEqual(mockRemoteDS.getTargetCallCount, 1)
        XCTAssertEqual(mockLocalDS.saveTargetCallCount, 1)
    }
    
    func testGetTarget_CacheMiss_FetchesFromAPIAndSavesToCache() async throws {
        // Given
        mockLocalDS.targetToReturn = nil
        let apiTarget = TargetTestFixtures.mainTarget
        mockRemoteDS.targetToReturn = apiTarget
        
        // When
        let result = try await sut.getTarget(id: apiTarget.id)
        
        // Then
        XCTAssertEqual(result.id, apiTarget.id)
        XCTAssertEqual(mockLocalDS.getTargetCallCount, 1)
        XCTAssertEqual(mockRemoteDS.getTargetCallCount, 1)
        XCTAssertEqual(mockLocalDS.saveTargetCallCount, 1)
    }
    
    // MARK: - Write Operation Tests
    
    func testCreateTarget_CallsRemoteAndUpdatesLocalCache() async throws {
        // Given
        let newTarget = TargetTestFixtures.supportingTarget
        mockRemoteDS.targetToReturn = newTarget
        
        // When
        let result = try await sut.createTarget(newTarget)
        
        // Then
        XCTAssertEqual(result.id, newTarget.id)
        XCTAssertEqual(mockRemoteDS.createTargetCallCount, 1)
        XCTAssertEqual(mockLocalDS.saveTargetCallCount, 1)
    }
    
    func testUpdateTarget_CallsRemoteAndUpdatesLocalCache() async throws {
        // Given
        let existingTarget = TargetTestFixtures.mainTarget
        mockRemoteDS.targetToReturn = existingTarget
        
        // When
        let result = try await sut.updateTarget(id: existingTarget.id, target: existingTarget)
        
        // Then
        XCTAssertEqual(result.id, existingTarget.id)
        XCTAssertEqual(mockRemoteDS.updateTargetCallCount, 1)
        XCTAssertEqual(mockLocalDS.saveTargetCallCount, 1)
    }
    
    func testDeleteTarget_CallsRemoteAndRemovesFromLocalCache() async throws {
        // Given
        let targetId = "target_123"
        
        // When
        try await sut.deleteTarget(id: targetId)
        
        // Then
        XCTAssertEqual(mockRemoteDS.deleteTargetCallCount, 1)
        XCTAssertEqual(mockLocalDS.removeTargetCallCount, 1)
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache_ClearsLocalDataSource() {
        // When
        sut.clearCache()
        
        // Then
        XCTAssertEqual(mockLocalDS.clearAllCallCount, 1)
    }
}
