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

// MARK: - MockUnifiedWorkoutManager

@MainActor
class MockUnifiedWorkoutManager: UnifiedWorkoutManagerProtocol {
    @Published var isLoading: Bool = false
    @Published var workouts: [WorkoutV2] = []
    @Published var lastSyncTime: Date? = nil
    @Published var syncError: String? = nil
    
    // Call counts
    var initializeCallCount = 0
    var loadWorkoutsCallCount = 0
    var refreshWorkoutsCallCount = 0
    var forceRefreshFromAPICallCount = 0
    var switchDataSourceCallCount = 0
    var getWorkoutStatsCallCount = 0
    
    // Stubbed properties
    var workoutStatsToReturn: WorkoutStatsResponse?
    var errorToThrow: Error?
    
    func initialize() async {
        initializeCallCount += 1
    }
    
    func loadWorkouts() async {
        loadWorkoutsCallCount += 1
    }
    
    func refreshWorkouts() async {
        refreshWorkoutsCallCount += 1
    }
    
    func forceRefreshFromAPI() async {
        forceRefreshFromAPICallCount += 1
    }
    
    func switchDataSource(to newDataSource: DataSourceType) async {
        switchDataSourceCallCount += 1
    }
    
    func getWorkoutStats(days: Int) async throws -> WorkoutStatsResponse {
        getWorkoutStatsCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return workoutStatsToReturn ?? WorkoutStatsResponse(
            data: WorkoutStatsData(
                totalWorkouts: 0,
                totalDistanceKm: 0,
                avgPacePerKm: nil,
                providerDistribution: [:],
                activityTypeDistribution: [:],
                periodDays: days
            )
        )
    }
}
