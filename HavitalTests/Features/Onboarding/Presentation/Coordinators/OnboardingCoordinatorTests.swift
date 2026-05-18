//
//  OnboardingCoordinatorTests.swift
//  HavitalTests
//
//  Unit tests for OnboardingCoordinator.completeOnboarding()
//  Verifies that UserProfile cache is cleared for BOTH new user and re-onboarding paths,
//  preventing stale v1 cache from causing V1Guard blocks after onboarding completion.
//
//  Regression for: prod 41x v1_endpoint_blocked_for_v2_user in 7 days
//  Root cause: new-user branch of completeOnboarding() did not call clearUserProfile()
//

import XCTest
@testable import paceriz_dev

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {

    private var mockLocalDS: MockUserProfileLocalDataSource!
    private var mockTrainingPlanRepository: MockTrainingPlanRepository!
    private var mockTrainingPlanV2Repository: MockTrainingPlanV2Repository!
    private var mockAnalyticsService: MockAnalyticsServiceForCoordinatorTests!

    override func setUp() async throws {
        try await super.setUp()

        DependencyContainer.shared.reset()

        mockLocalDS = MockUserProfileLocalDataSource()
        mockTrainingPlanRepository = MockTrainingPlanRepository()
        mockTrainingPlanV2Repository = MockTrainingPlanV2Repository()
        mockAnalyticsService = MockAnalyticsServiceForCoordinatorTests()

        // Inject analytics mock — required because coordinator calls analyticsService.track()
        // after the use case completes. Without this, DI.resolve() for AnalyticsService fatalErrors.
        DependencyContainer.shared.replace(mockAnalyticsService as AnalyticsService, for: AnalyticsService.self)

        // Inject mock repositories so CompleteOnboardingUseCase uses mocks (no real network calls)
        DependencyContainer.shared.replace(
            mockTrainingPlanRepository as TrainingPlanRepository,
            for: TrainingPlanRepository.self
        )
        DependencyContainer.shared.replace(
            mockTrainingPlanV2Repository as TrainingPlanV2Repository,
            for: TrainingPlanV2Repository.self
        )

        // Inject mock UserProfileLocalDataSource so coordinator's
        // DependencyContainer.shared.resolve() for UserProfileLocalDataSourceProtocol
        // returns our spy (tracking clearUserProfile() call count)
        DependencyContainer.shared.register(
            mockLocalDS as UserProfileLocalDataSourceProtocol,
            forProtocol: UserProfileLocalDataSourceProtocol.self
        )

        // Provide a default V1 plan so the use case succeeds in V1 path
        mockTrainingPlanRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        // Reset coordinator + auth state for clean test run
        OnboardingCoordinator.shared.reset()
        AuthenticationViewModel.shared.isReonboardingMode = false
        AuthenticationViewModel.shared.hasCompletedOnboarding = false
        UserDefaults.standard.analyticsOnboardingStartTime = 0
    }

    override func tearDown() async throws {
        OnboardingCoordinator.shared.reset()
        AuthenticationViewModel.shared.isReonboardingMode = false
        AuthenticationViewModel.shared.hasCompletedOnboarding = false
        UserDefaults.standard.analyticsOnboardingStartTime = 0
        mockLocalDS = nil
        mockTrainingPlanRepository = nil
        mockTrainingPlanV2Repository = nil
        mockAnalyticsService = nil
        DependencyContainer.shared.reset()
        AppDependencyBootstrap.registerAllModules()
        try await super.tearDown()
    }

    // MARK: - Tests

    /// TDD: 驗證新用戶完成 onboarding 時，clearUserProfile() 被呼叫一次。
    /// 修復前此測試 FAIL（新用戶分支漏了 clearUserProfile()）。
    /// 修復後此測試 PASS。
    func test_completeOnboarding_newUser_clearsUserProfileCache() async {
        // Given: 新用戶流程（isReonboardingMode = false，selectedTargetTypeId = nil → V1 path）
        AuthenticationViewModel.shared.isReonboardingMode = false
        // selectedTargetTypeId 未設定 → isV2Flow = false → V1 branch in use case

        let callCountBefore = mockLocalDS.clearUserProfileCallCount

        // When
        await OnboardingCoordinator.shared.completeOnboarding()

        // Then: clearUserProfile() 必須被呼叫至少一次
        XCTAssertGreaterThan(
            mockLocalDS.clearUserProfileCallCount,
            callCountBefore,
            "新用戶完成 onboarding 後，必須清除 UserProfile cache 以避免 stale v1 profile"
        )
    }

    /// TDD: 驗證 re-onboarding 完成時，clearUserProfile() 也被呼叫（regression prevention）。
    /// re-onboarding 分支原本就有 clearUserProfile()，此測試確保重構後仍保留。
    func test_completeOnboarding_reonboarding_clearsUserProfileCache() async {
        // Given: re-onboarding 流程
        AuthenticationViewModel.shared.isReonboardingMode = true

        let callCountBefore = mockLocalDS.clearUserProfileCallCount

        // When
        await OnboardingCoordinator.shared.completeOnboarding()

        // Then: clearUserProfile() 必須被呼叫至少一次
        XCTAssertGreaterThan(
            mockLocalDS.clearUserProfileCallCount,
            callCountBefore,
            "re-onboarding 完成後，必須清除 UserProfile cache（regression prevention）"
        )
    }
}

// MARK: - Private Mock (local to this test file)

private final class MockAnalyticsServiceForCoordinatorTests: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
    func setUserProperty(_ value: String, forName name: String) {}
}
