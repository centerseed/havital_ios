import XCTest
@testable import paceriz_dev

@MainActor
final class OnboardingCoordinatorAnalyticsTests: XCTestCase {

    private let sourceKey = "analytics_attribution_source"
    private let campaignIdKey = "analytics_attribution_campaign_id"
    private var analyticsService: MockAnalyticsService!
    private var mockTrainingPlanRepository: MockTrainingPlanRepository!
    private var mockTrainingPlanV2Repository: MockTrainingPlanV2Repository!

    override func setUp() async throws {
        try await super.setUp()

        DependencyContainer.shared.reset()

        analyticsService = MockAnalyticsService()
        mockTrainingPlanRepository = MockTrainingPlanRepository()
        mockTrainingPlanV2Repository = MockTrainingPlanV2Repository()
        DependencyContainer.shared.replace(analyticsService as AnalyticsService, for: AnalyticsService.self)
        DependencyContainer.shared.replace(mockTrainingPlanRepository as TrainingPlanRepository, for: TrainingPlanRepository.self)
        DependencyContainer.shared.replace(mockTrainingPlanV2Repository as TrainingPlanV2Repository, for: TrainingPlanV2Repository.self)

        UserDefaults.standard.removeObject(forKey: sourceKey)
        UserDefaults.standard.removeObject(forKey: campaignIdKey)
        UserDefaults.standard.analyticsOnboardingStartTime = 0
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        AuthenticationViewModel.shared.isReonboardingMode = false
        AuthenticationViewModel.shared.hasCompletedOnboarding = false

        OnboardingCoordinator.shared.reset()
    }

    override func tearDown() async throws {
        OnboardingCoordinator.shared.reset()
        analyticsService = nil
        UserDefaults.standard.removeObject(forKey: sourceKey)
        UserDefaults.standard.removeObject(forKey: campaignIdKey)
        UserDefaults.standard.analyticsOnboardingStartTime = 0
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        AuthenticationViewModel.shared.isReonboardingMode = false
        AuthenticationViewModel.shared.hasCompletedOnboarding = false
        DependencyContainer.shared.reset()
        AppDependencyBootstrap.registerAllModules()
        try await super.tearDown()
    }

    func testTrackOnboardingStart_EmitsSourceAndCampaignId() {
        UserDefaults.standard.set("apple_search_ads", forKey: sourceKey)
        UserDefaults.standard.set("12345", forKey: campaignIdKey)

        OnboardingCoordinator.shared.trackOnboardingStart()

        XCTAssertEqual(analyticsService.trackedEvents.count, 1)
        if case .onboardingStart(let source, let campaignId) = analyticsService.trackedEvents[0] {
            XCTAssertEqual(source, "apple_search_ads")
            XCTAssertEqual(campaignId, "12345")
        } else {
            XCTFail("Expected onboardingStart event")
        }
    }

    func testCompleteOnboarding_ForNewUser_EmitsDurationBasedAnalytics() async {
        mockTrainingPlanRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1
        UserDefaults.standard.analyticsOnboardingStartTime = Date().addingTimeInterval(-42).timeIntervalSince1970

        await OnboardingCoordinator.shared.completeOnboarding()

        XCTAssertEqual(analyticsService.trackedEvents.count, 1)
        if case .onboardingComplete(let durationSeconds) = analyticsService.trackedEvents[0] {
            XCTAssertGreaterThanOrEqual(durationSeconds, 40)
            XCTAssertLessThan(durationSeconds, 120)
        } else {
            XCTFail("Expected onboardingComplete event")
        }
    }
}

private final class MockAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_: String, forName _: String) {}
}
