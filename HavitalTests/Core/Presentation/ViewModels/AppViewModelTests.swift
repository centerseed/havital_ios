//
//  AppViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import paceriz_dev

@MainActor
final class AppViewModelTests: XCTestCase {
    private let dataSourceReminderKey = "data_source_unbound_last_shown_at"

    var sut: AppViewModel!
    var mockAppStateManager: MockAppStateManager!
    var mockWorkoutRepository: MockWorkoutRepository!
    var mockUserProfileRepository: MockUserProfileRepository!
    var interruptCoordinator: InterruptCoordinator!
    
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: dataSourceReminderKey)
        DataSourceBindingReminderManager.shared.resetSession()
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        mockAppStateManager = MockAppStateManager()
        mockWorkoutRepository = MockWorkoutRepository()
        mockUserProfileRepository = MockUserProfileRepository()
        interruptCoordinator = InterruptCoordinator()
        sut = AppViewModel(
            appStateManager: mockAppStateManager,
            workoutRepository: mockWorkoutRepository,
            userProfileRepository: mockUserProfileRepository,
            interruptCoordinator: interruptCoordinator
        )
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: dataSourceReminderKey)
        DataSourceBindingReminderManager.shared.resetSession()
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        sut = nil
        mockAppStateManager = nil
        mockWorkoutRepository = nil
        mockUserProfileRepository = nil
        interruptCoordinator = nil
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
        XCTAssertEqual(mockWorkoutRepository.refreshWorkoutsCallCount, 1)
    }
    
    func testOnAppBecameActive_NotReadyState_DoesNotRefreshWorkouts() async {
        // Given
        mockAppStateManager.currentState = .initializing
        
        // When
        await sut.onAppBecameActive()
        
        // Then
        XCTAssertEqual(mockWorkoutRepository.refreshWorkoutsCallCount, 0)
    }
    
    func testRefreshData_ReadyState_RefreshesWorkouts() async {
        // Given
        mockAppStateManager.currentState = .ready
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertEqual(mockWorkoutRepository.refreshWorkoutsCallCount, 1)
    }
    
    func testRefreshData_NotReadyState_DoesNotRefreshWorkouts() async {
        // Given
        mockAppStateManager.currentState = .initializing
        
        // When
        await sut.refreshData()
        
        // Then
        XCTAssertEqual(mockWorkoutRepository.refreshWorkoutsCallCount, 0)
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
    
    func testHandleDataSourceNotBoundNotification_UpdatesState() {
        sut.handleDataSourceNotBoundNotification()

        XCTAssertTrue(sut.showDataSourceNotBoundAlert)
    }

    func testDismissDataSourceNotBoundAlert_ClearsState() {
        sut.handleDataSourceNotBoundNotification()
        XCTAssertEqual(interruptCoordinator.currentItem?.type, .dataSourceBindingReminder)

        interruptCoordinator.dismissCurrent(reason: .secondaryAction)

        XCTAssertFalse(sut.showDataSourceNotBoundAlert)
    }

    func testHandleDataSourceNotBoundNotification_ShowsOnlyOncePerSession() {
        sut.handleDataSourceNotBoundNotification()

        XCTAssertTrue(sut.showDataSourceNotBoundAlert)

        interruptCoordinator.dismissCurrent(reason: .secondaryAction)
        sut.handleDataSourceNotBoundNotification()

        XCTAssertFalse(sut.showDataSourceNotBoundAlert)
    }

    func testCheckDataSourceBindingReminderIfNeeded_Unbound_ShowsAlert() async {
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        mockUserProfileRepository.userToReturn = makeUser(
            dataSource: "unbound",
            trainingVersion: "v2"
        )

        await sut.checkDataSourceBindingReminderIfNeeded()

        XCTAssertTrue(sut.showDataSourceNotBoundAlert)
        XCTAssertEqual(mockUserProfileRepository.getUserProfileCallCount, 1)
    }

    func testCheckDataSourceBindingReminderIfNeeded_Bound_DoesNotShowAlert() async {
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        mockUserProfileRepository.userToReturn = makeUser(
            dataSource: "apple_health",
            trainingVersion: "v2"
        )

        await sut.checkDataSourceBindingReminderIfNeeded()

        XCTAssertFalse(sut.showDataSourceNotBoundAlert)
    }

    func testCheckDataSourceBindingReminderIfNeeded_ForceRefresh_UsesRefreshUserProfile() async {
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        mockUserProfileRepository.userToReturn = makeUser(
            dataSource: "unbound",
            trainingVersion: "v2"
        )

        await sut.checkDataSourceBindingReminderIfNeeded(forceRefresh: true)

        XCTAssertTrue(sut.showDataSourceNotBoundAlert)
        XCTAssertEqual(mockUserProfileRepository.refreshUserProfileCallCount, 1)
        XCTAssertEqual(mockUserProfileRepository.getUserProfileCallCount, 0)
    }

    func testCheckDataSourceBindingReminderIfNeeded_LocalPreferenceUnbound_SkipsRepositoryAndShowsAlert() async {
        UserPreferencesManager.shared.dataSourcePreference = .unbound

        await sut.checkDataSourceBindingReminderIfNeeded(forceRefresh: true)

        XCTAssertTrue(sut.showDataSourceNotBoundAlert)
        XCTAssertEqual(mockUserProfileRepository.refreshUserProfileCallCount, 0)
        XCTAssertEqual(mockUserProfileRepository.getUserProfileCallCount, 0)
    }

    private func makeUser(dataSource: String?, trainingVersion: String?) -> User {
        let dataSourceJSON = dataSource.map { "\"\($0)\"" } ?? "null"
        let trainingVersionJSON = trainingVersion.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
            "display_name": "Test User",
            "email": "test@example.com",
            "data_source": \(dataSourceJSON),
            "training_version": \(trainingVersionJSON)
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(User.self, from: json)
    }
}
