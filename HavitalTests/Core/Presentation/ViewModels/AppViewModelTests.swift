//
//  AppViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

@MainActor
final class AppViewModelTests: XCTestCase {
    
    var sut: AppViewModel!
    var mockAppStateManager: MockAppStateManager!
    var mockUnifiedWorkoutManager: MockUnifiedWorkoutManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockAppStateManager = MockAppStateManager()
        mockUnifiedWorkoutManager = MockUnifiedWorkoutManager()
        sut = AppViewModel(
            appStateManager: mockAppStateManager,
            unifiedWorkoutManager: mockUnifiedWorkoutManager
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockAppStateManager = nil
        mockUnifiedWorkoutManager = nil
        try await super.tearDown()
    }
    
    // MARK: - App Lifecycle Tests
    
    func testInitializeApp_DelegatesToAppStateManager() async {
        // When
        await sut.initializeApp()
        
        // Then
        XCTAssertEqual(mockAppStateManager.initializeAppCallCount, 1)
    }
    
    func testOnAppBecameActive_ReadyState_RefreshesWorkouts() async {
        // Given
        mockAppStateManager.currentState = .ready
        
        // When
        await sut.onAppBecameActive()
        
        // Then
        XCTAssertEqual(mockUnifiedWorkoutManager.refreshWorkoutsCallCount, 1)
    }
    
    func testOnAppBecameActive_NotReadyState_DoesNotRefreshWorkouts() async {
        // Given
        mockAppStateManager.currentState = .initializing
        
        // When
        await sut.onAppBecameActive()
        
        // Then
        XCTAssertEqual(mockUnifiedWorkoutManager.refreshWorkoutsCallCount, 0)
    }
    
    func testRefreshData_ReadyState_RefreshesWorkouts() async {
        // Given
        mockAppStateManager.currentState = .ready
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertEqual(mockUnifiedWorkoutManager.refreshWorkoutsCallCount, 1)
    }
    
    func testRefreshData_NotReadyState_DoesNotRefreshWorkouts() async {
        // Given
        mockAppStateManager.currentState = .initializing
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertEqual(mockUnifiedWorkoutManager.refreshWorkoutsCallCount, 0)
    }
    
    // MARK: - Notification Tests
    
    func testNotification_ShowHealthKitPermissionAlert_UpdatesState() {
        // Given
        let expectedMessage = "Please enable health access"
        let notification = Notification(
            name: NSNotification.Name("ShowHealthKitPermissionAlert"),
            object: nil,
            userInfo: ["message": expectedMessage]
        )
        
        // When
        NotificationCenter.default.post(notification)
        
        // Then
        // Allow run loop to process notification
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.async {
            if self.sut.showHealthKitAlert && self.sut.healthKitAlertMessage == expectedMessage {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNotification_GarminDataSourceMismatch_UpdatesState() {
        // When
        NotificationCenter.default.post(name: .garminDataSourceMismatch, object: nil)
        
        // Then
        // Allow run loop to process notification
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.async {
            if self.sut.showGarminMismatchAlert {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNotification_DataSourceNotBound_UpdatesState() {
        // When
        NotificationCenter.default.post(name: .dataSourceNotBound, object: nil)
        
        // Then
        // Allow run loop to process notification
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.async {
            if self.sut.showDataSourceNotBoundAlert {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
