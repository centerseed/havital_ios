//
//  CoreMocks.swift
//  HavitalTests
//

import Foundation
import Combine
@testable import paceriz_dev

// MARK: - MockAppStateManager

@MainActor
class MockAppStateManager: AppStateManagerProtocol {
    @Published var currentState: AppStateManager.AppState = .initializing
    @Published var isUserAuthenticated: Bool = false
    @Published var userDataSource: DataSourceType = .unbound
    @Published var subscriptionStatus: AppStateManager.SubscriptionStatus = .free
    @Published var initializationProgress: Double = 0.0
    
    // Call counts
    var initializeAppCallCount = 0
    var reinitializeCallCount = 0
    var handleDataSourceChangeCallCount = 0
    var hasPermissionCallCount = 0
    
    // Stubbed properties
    var hasPermissionResult = true
    
    func initializeApp() async {
        initializeAppCallCount += 1
    }
    
    func reinitialize() async {
        reinitializeCallCount += 1
    }
    
    func handleDataSourceChange(to newDataSource: DataSourceType) async {
        handleDataSourceChangeCallCount += 1
        userDataSource = newDataSource
    }
    
    func hasPermission(for feature: String) -> Bool {
        hasPermissionCallCount += 1
        return hasPermissionResult
    }
}


