//
//  TargetMocks.swift
//  HavitalTests
//

import Foundation
@testable import paceriz_dev

// MARK: - MockTargetRepository
class MockTargetRepository: TargetRepository {
    var targetsToReturn: [Target] = []
    var targetToReturn: Target?
    var mainTargetToReturn: Target?
    var supportingTargetsToReturn: [Target] = []
    var errorToThrow: Error?
    
    var getTargetsCallCount = 0
    var getTargetCallCount = 0
    var createTargetCallCount = 0
    var updateTargetCallCount = 0
    var deleteTargetCallCount = 0
    var forceRefreshCallCount = 0
    var clearCacheCallCount = 0
    
    func getTargets() async throws -> [Target] {
        getTargetsCallCount += 1
        if let error = errorToThrow { throw error }
        return targetsToReturn
    }
    
    func getTarget(id: String) async throws -> Target {
        getTargetCallCount += 1
        if let error = errorToThrow { throw error }
        if let target = targetToReturn { return target }
        throw NSError(domain: "Mock", code: 404, userInfo: [NSLocalizedDescriptionKey: "Target not found"])
    }
    
    func getMainTarget() async -> Target? {
        return mainTargetToReturn
    }
    
    func getSupportingTargets() async -> [Target] {
        return supportingTargetsToReturn
    }
    
    func createTarget(_ target: Target) async throws -> Target {
        createTargetCallCount += 1
        if let error = errorToThrow { throw error }
        return target
    }
    
    func updateTarget(id: String, target: Target) async throws -> Target {
        updateTargetCallCount += 1
        if let error = errorToThrow { throw error }
        return target
    }
    
    func deleteTarget(id: String) async throws {
        deleteTargetCallCount += 1
        if let error = errorToThrow { throw error }
    }
    
    func forceRefresh() async throws -> [Target] {
        forceRefreshCallCount += 1
        if let error = errorToThrow { throw error }
        return targetsToReturn
    }
    
    func clearCache() {
        clearCacheCallCount += 1
    }
    
    func hasCache() -> Bool {
        return !targetsToReturn.isEmpty
    }
}

// MARK: - MockTargetRemoteDataSource
class MockTargetRemoteDataSource: TargetRemoteDataSourceProtocol {
    var targetsToReturn: [Target] = []
    var targetToReturn: Target?
    var errorToThrow: Error?
    
    var getTargetsCallCount = 0
    var getTargetCallCount = 0
    var createTargetCallCount = 0
    var updateTargetCallCount = 0
    var deleteTargetCallCount = 0
    
    func getTargets() async throws -> [Target] {
        getTargetsCallCount += 1
        if let error = errorToThrow { throw error }
        return targetsToReturn
    }
    
    func getTarget(id: String) async throws -> Target {
        getTargetCallCount += 1
        if let error = errorToThrow { throw error }
        if let target = targetToReturn { return target }
        throw NSError(domain: "Mock", code: 404, userInfo: [NSLocalizedDescriptionKey: "Target not found"])
    }
    
    func createTarget(_ target: Target) async throws -> Target {
        createTargetCallCount += 1
        if let error = errorToThrow { throw error }
        return target
    }
    
    func updateTarget(id: String, target: Target) async throws -> Target {
        updateTargetCallCount += 1
        if let error = errorToThrow { throw error }
        return target
    }
    
    func deleteTarget(id: String) async throws {
        deleteTargetCallCount += 1
        if let error = errorToThrow { throw error }
    }
}

// MARK: - MockTargetLocalDataSource
class MockTargetLocalDataSource: TargetLocalDataSourceProtocol {
    var targetsToReturn: [Target] = []
    var targetToReturn: Target?
    var mainTargetToReturn: Target?
    var supportingTargetsToReturn: [Target] = []
    
    var getTargetsCallCount = 0
    var getTargetCallCount = 0
    var saveTargetsCallCount = 0
    var saveTargetCallCount = 0
    var removeTargetCallCount = 0
    var clearAllCallCount = 0
    
    func getTargets() -> [Target] {
        getTargetsCallCount += 1
        return targetsToReturn
    }
    
    func getTarget(id: String) -> Target? {
        getTargetCallCount += 1
        return targetToReturn
    }
    
    func getMainTarget() -> Target? {
        return mainTargetToReturn
    }
    
    func getSupportingTargets() -> [Target] {
        return supportingTargetsToReturn
    }
    
    func saveTargets(_ targets: [Target]) {
        saveTargetsCallCount += 1
        targetsToReturn = targets
    }
    
    func saveTarget(_ target: Target) {
        saveTargetCallCount += 1
    }
    
    func removeTarget(id: String) {
        removeTargetCallCount += 1
    }
    
    func isExpired() -> Bool {
        return false
    }
    
    func hasTargets() -> Bool {
        return !targetsToReturn.isEmpty
    }
    
    func clearAll() {
        clearAllCallCount += 1
        targetsToReturn = []
    }
    
    func getCacheSize() -> Int {
        return targetsToReturn.count * 100
    }
}
