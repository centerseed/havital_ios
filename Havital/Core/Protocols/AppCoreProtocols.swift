//
//  AppCoreProtocols.swift
//  Havital
//
//  Created for testing purposes to mock singletons.
//

import Foundation

// MARK: - AppStateManager Protocol

@MainActor
protocol AppStateManagerProtocol: ObservableObject {
    var currentState: AppStateManager.AppState { get }
    var isUserAuthenticated: Bool { get }
    var userDataSource: DataSourceType { get }
    var subscriptionStatus: AppStateManager.SubscriptionStatus { get } // Assuming SubscriptionStatus is public or internal
    var initializationProgress: Double { get }
    
    func initializeApp() async
    func reinitialize() async
    func handleDataSourceChange(to newDataSource: DataSourceType) async
    func hasPermission(for feature: String) -> Bool
}

// Ensure AppStateManager conforms to the protocol
extension AppStateManager: AppStateManagerProtocol {}


