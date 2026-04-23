import XCTest
@testable import paceriz_dev

@MainActor
final class AppStateManagerAnalyticsTests: XCTestCase {

    private var authSessionRepository: MockAuthSessionRepository!
    private var workoutRepository: MockWorkoutRepository!
    private var analyticsService: MockAnalyticsService!
    private var sut: AppStateManager!

    override func setUp() async throws {
        try await super.setUp()

        DependencyContainer.shared.reset()

        authSessionRepository = MockAuthSessionRepository()
        authSessionRepository.isAuthenticatedValue = false
        workoutRepository = MockWorkoutRepository()
        analyticsService = MockAnalyticsService()

        DependencyContainer.shared.register(authSessionRepository as AuthSessionRepository, forProtocol: AuthSessionRepository.self)
        DependencyContainer.shared.register(workoutRepository as WorkoutRepository, forProtocol: WorkoutRepository.self)
        DependencyContainer.shared.replace(analyticsService as AnalyticsService, for: AnalyticsService.self)

        UserDefaults.standard.removeObject(forKey: "analytics_first_install_date")
        UserDefaults.standard.removeObject(forKey: "analytics_session_count_today")
        UserDefaults.standard.removeObject(forKey: "analytics_session_count_date")
        UserDefaults.standard.removeObject(forKey: "analytics_onboarding_start_time")
        UserDefaults.standard.removeObject(forKey: "selectedTargetTypeId")

        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))

        sut = AppStateManager.shared
    }

    override func tearDown() async throws {
        sut = nil
        analyticsService = nil
        workoutRepository = nil
        authSessionRepository = nil

        UserDefaults.standard.removeObject(forKey: "analytics_first_install_date")
        UserDefaults.standard.removeObject(forKey: "analytics_session_count_today")
        UserDefaults.standard.removeObject(forKey: "analytics_session_count_date")
        UserDefaults.standard.removeObject(forKey: "analytics_onboarding_start_time")
        UserDefaults.standard.removeObject(forKey: "selectedTargetTypeId")

        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))

        DependencyContainer.shared.reset()
        AppDependencyBootstrap.registerAllModules()

        try await super.tearDown()
    }

    func testInitializeApp_WhenUnauthenticated_TracksAppOpenAndSetsUserProperties() async {
        await sut.initializeApp()

        XCTAssertEqual(analyticsService.trackedEvents.count, 1)
        if case .appOpen(let daysSinceInstall, let subscriptionStatus) = analyticsService.trackedEvents[0] {
            XCTAssertEqual(daysSinceInstall, 0)
            XCTAssertEqual(subscriptionStatus, "free")
        } else {
            XCTFail("Expected appOpen event")
        }

        XCTAssertTrue(
            analyticsService.userProperties.contains(where: { $0.name == "subscription_status" && $0.value == "free" })
        )
        XCTAssertTrue(
            analyticsService.userProperties.contains(where: { $0.name == "data_source" && $0.value == "unbound" })
        )
    }

    func testInitializeApp_WhenSelectedTargetTypeExists_SetsTargetTypeUserProperty() async {
        UserDefaults.standard.set("race_run", forKey: "selectedTargetTypeId")

        await sut.initializeApp()

        XCTAssertTrue(
            analyticsService.userProperties.contains(where: { $0.name == "target_type" && $0.value == "race_run" })
        )
    }
}

private final class MockAnalyticsService: AnalyticsService {
    struct UserPropertyCall: Equatable {
        let value: String
        let name: String
    }

    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var userProperties: [UserPropertyCall] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_ value: String, forName name: String) {
        userProperties.append(UserPropertyCall(value: value, name: name))
    }
}
