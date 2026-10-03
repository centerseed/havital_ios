import XCTest
@testable import paceriz_dev

@MainActor
final class App2OnboardingViewModelTests: XCTestCase {
    private var sut: App2OnboardingViewModel!
    private var coordinator: OnboardingCoordinator!
    private var userProfileRepository: MockUserProfileRepository!
    private var trainingPlanV2Repository: MockTrainingPlanV2Repository!
    private var profilePreferencesRepository: MockUserPreferencesRepository!
    private var authService: MockAuthenticationService!

    override func setUp() async throws {
        try await super.setUp()

        coordinator = OnboardingCoordinator.shared
        coordinator.reset()
        userProfileRepository = MockUserProfileRepository()
        profilePreferencesRepository = MockUserPreferencesRepository()
        authService = MockAuthenticationService()
        trainingPlanV2Repository = MockTrainingPlanV2Repository()
        let profile = UserProfileFeatureViewModel(
            getUserProfileUseCase: GetUserProfileUseCase(repository: userProfileRepository),
            updateUserProfileUseCase: UpdateUserProfileUseCase(repository: userProfileRepository),
            getHeartRateZonesUseCase: GetHeartRateZonesUseCase(repository: userProfileRepository),
            updateHeartRateZonesUseCase: UpdateHeartRateZonesUseCase(repository: userProfileRepository),
            getUserTargetsUseCase: GetUserTargetsUseCase(repository: userProfileRepository),
            createTargetUseCase: CreateTargetUseCase(repository: userProfileRepository),
            syncUserPreferencesUseCase: SyncUserPreferencesUseCase(preferencesRepository: profilePreferencesRepository),
            calculateUserStatsUseCase: CalculateUserStatsUseCase(repository: userProfileRepository),
            preferencesRepository: profilePreferencesRepository,
            userRepository: userProfileRepository,
            authService: authService
        )
        let flow = OnboardingFeatureViewModel(
            userProfileRepository: userProfileRepository,
            targetRepository: MockTargetRepository(),
            trainingPlanRepository: MockTrainingPlanRepository(),
            trainingPlanV2Repository: trainingPlanV2Repository,
            raceRepository: App2OnboardingRaceRepositoryStub(),
            versionRouter: MockTrainingVersionRouter()
        )

        sut = App2OnboardingViewModel(
            isReonboarding: false,
            metricsDataSource: App2EmptyAthleteStateMetricsDataSource(),
            flow: flow,
            profile: profile,
            coordinator: coordinator
        )
        sut.flow.selectedTargetTypeV2 = TargetTypeV2(
            id: "beginner",
            name: "Beginner",
            description: "Start running",
            defaultMethodology: "paceriz",
            availableMethodologies: ["paceriz"]
        )
        coordinator.selectedTargetTypeId = "beginner"
        coordinator.trainingWeeks = 8
        coordinator.selectedMethodologyId = "paceriz"
    }

    func testHeartRateDefaultsUseFreshBackendProfileInsteadOfLocalPreferences() async {
        profilePreferencesRepository.updateHeartRateData(maxHR: 185, restingHR: 58)
        userProfileRepository.userToReturn = UserProfileTestFixtures.testUser

        await sut.loadHeartRateDefaults()

        XCTAssertEqual(sut.maxHeartRate, 190)
        XCTAssertEqual(sut.restingHeartRate, 60)
        XCTAssertTrue(sut.heartRateDefaultsResolved)
        XCTAssertFalse(sut.heartRateDefaultsFailed)
    }

    func testHeartRateDefaultsReadFailureBlocksContinueAndDoesNotWriteEstimate() async {
        userProfileRepository.errorToThrow = DomainError.networkFailure("profile read failed")
        await sut.loadHeartRateDefaults()

        XCTAssertFalse(sut.heartRateDefaultsResolved)
        XCTAssertTrue(sut.heartRateDefaultsFailed)
        await sut.confirmHeartRate()

        XCTAssertEqual(userProfileRepository.updateUserProfileCallCount, 0)
    }

    override func tearDown() async throws {
        sut = nil
        coordinator.reset()
        coordinator = nil
        userProfileRepository = nil
        trainingPlanV2Repository = nil
        try await super.tearDown()
    }

    func testGeneratePlan_SubscriptionRequired_DoesNotPushCompletionOrKeepOverview() async {
        trainingPlanV2Repository.errorToThrow = DomainError.subscriptionRequired

        await sut.generatePlan()

        XCTAssertFalse(sut.path.contains(.completion))
        XCTAssertNil(sut.flow.trainingOverviewV2)
        XCTAssertNil(coordinator.trainingPlanOverviewV2)
        XCTAssertTrue(sut.isShowingOnboardingPaywall)
    }

    func testGeneratePlan_OtherFailureAndRecoveryFailure_DoesNotPushCompletion() async {
        trainingPlanV2Repository.errorToThrow = DomainError.networkFailure("create failed")
        trainingPlanV2Repository.refreshOverviewErrorToThrow = DomainError.notFound("no active overview")

        await sut.generatePlan()

        XCTAssertFalse(sut.path.contains(.completion))
        XCTAssertNil(sut.flow.trainingOverviewV2)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isShowingOnboardingPaywall)
    }

    func testPaywallDismissalWithPremiumAccessRetriesAndPushesCompletionOnSuccess() async {
        trainingPlanV2Repository.errorToThrow = DomainError.subscriptionRequired
        await sut.generatePlan()
        XCTAssertTrue(sut.isShowingOnboardingPaywall)
        XCTAssertEqual(trainingPlanV2Repository.createOverviewForNonRaceCallCount, 1)

        trainingPlanV2Repository.errorToThrow = nil
        trainingPlanV2Repository.overviewToReturn = makeOverview(id: "backend-overview")
        sut.isShowingOnboardingPaywall = false
        await sut.onboardingPaywallDidDismiss(hasPremiumAccess: true)

        XCTAssertEqual(trainingPlanV2Repository.createOverviewForNonRaceCallCount, 2)
        XCTAssertTrue(sut.path.contains(.completion))
        XCTAssertEqual(coordinator.trainingPlanOverviewV2?.id, "backend-overview")
        XCTAssertFalse(sut.isShowingOnboardingPaywall)
    }

    func testPaywallDismissalWithoutPremiumAccessDoesNotRetry() async {
        trainingPlanV2Repository.errorToThrow = DomainError.subscriptionRequired
        await sut.generatePlan()
        let createCount = trainingPlanV2Repository.createOverviewForNonRaceCallCount

        sut.isShowingOnboardingPaywall = false
        await sut.onboardingPaywallDidDismiss(hasPremiumAccess: false)

        XCTAssertEqual(trainingPlanV2Repository.createOverviewForNonRaceCallCount, createCount)
        XCTAssertFalse(sut.path.contains(.completion))
    }

    func testPaywallRetryStillGatedShowsConfirmationPendingWithoutReopeningPaywall() async {
        trainingPlanV2Repository.errorToThrow = DomainError.subscriptionRequired
        await sut.generatePlan()
        sut.isShowingOnboardingPaywall = false

        await sut.onboardingPaywallDidDismiss(hasPremiumAccess: true)

        XCTAssertEqual(trainingPlanV2Repository.createOverviewForNonRaceCallCount, 2)
        XCTAssertFalse(sut.isShowingOnboardingPaywall)
        XCTAssertFalse(sut.path.contains(.completion))
        XCTAssertEqual(
            sut.errorMessage,
            NSLocalizedString("onboarding.payment_confirmation_pending", comment: "")
        )
    }

    private func makeOverview(id: String) -> PlanOverviewV2 {
        PlanOverviewV2(
            id: id,
            targetId: nil,
            targetType: "beginner",
            targetDescription: "Start running",
            methodologyId: "paceriz",
            totalWeeks: 8,
            startFromStage: nil,
            raceDate: nil,
            distanceKm: nil,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: nil,
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }
}

private struct App2OnboardingRaceRepositoryStub: RaceRepository {
    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> [RaceEvent] {
        []
    }
}
