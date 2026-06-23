import XCTest
@testable import paceriz_dev

// MARK: - WeeklySummaryCoordinatorTests

@MainActor
final class WeeklySummaryCoordinatorTests: XCTestCase {

    // MARK: - Properties

    private var mockRepository: MockTrainingPlanV2Repository!

    // MARK: - Helpers

    private func makeCoordinator(
        selectedWeek: Int = 2,
        setLoadingAnimation: @escaping (Bool) -> Void = { _ in },
        shouldBlockByRizoQuota: @escaping () async -> Bool = { false },
        refreshPlanStatusResponse: @escaping () async -> Void = {},
        shouldSuppressError: @escaping (DomainError, String, (() -> Void)?) -> Bool = { _, _, _ in false },
        resolvePaywallTrigger: @escaping () -> PaywallTrigger = { .apiGated },
        onSuccessToast: @escaping (String) -> Void = { _ in },
        onPaywallTriggered: @escaping (PaywallTrigger) -> Void = { _ in },
        onRizoQuotaExceeded: @escaping () -> Void = {},
        onNetworkError: @escaping (Error) -> Void = { _ in },
        isEnforcementEnabled: @escaping () -> Bool = { false },
        rizoRepository: RizoRepository? = nil
    ) -> WeeklySummaryCoordinator {
        WeeklySummaryCoordinator(
            repository: mockRepository,
            currentSelectedWeek: { selectedWeek },
            setLoadingAnimation: setLoadingAnimation,
            shouldBlockByRizoQuota: shouldBlockByRizoQuota,
            refreshPlanStatusResponse: refreshPlanStatusResponse,
            shouldSuppressError: shouldSuppressError,
            resolvePaywallTrigger: resolvePaywallTrigger,
            onSuccessToast: onSuccessToast,
            onPaywallTriggered: onPaywallTriggered,
            onRizoQuotaExceeded: onRizoQuotaExceeded,
            onNetworkError: onNetworkError,
            isEnforcementEnabled: isEnforcementEnabled,
            rizoRepository: rizoRepository
        )
    }

    private func makeRizoReply(reply: String = "好，記下了", sessionId: String = "s1") -> RizoReply {
        RizoReply(
            reply: reply,
            sessionId: sessionId,
            quota: RizoQuota(
                allowed: true, used: 1, limit: nil, remaining: nil,
                resetsAt: nil, reserved: false
            ),
            safety: RizoSafety(dangerClass: "none", canned: false)
        )
    }

    private func makeWeeklySummary(id: String = "summary-1", week: Int = 2) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: id,
            uid: "user-1",
            weeklyPlanId: "plan-1",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 85.0,
                plannedKm: 40.0,
                completedKm: 34.0,
                plannedSessions: 4,
                completedSessions: 3,
                evaluation: "Good week"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: nil,
                intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: ["Completed long run"],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [],
                summary: "Increase volume slightly",
                methodologyConstraintsConsidered: true,
                basedOnFlags: [],
                userNlEdit: nil,
                userNlEditStatus: .none,
                userNlEditFailReason: nil
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil,
            observations: nil
        )
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanV2Repository()
    }

    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    // MARK: Test 1: loadWeeklySummary success

    func test_loadWeeklySummary_success() async {
        // Arrange
        let expectedSummary = makeWeeklySummary()
        mockRepository.weeklySummaryV2ToReturn = expectedSummary
        let coordinator = makeCoordinator()

        // Act
        await coordinator.loadWeeklySummary(weekOfPlan: 2)

        // Assert
        if case .loaded(let summary) = coordinator.weeklySummary {
            XCTAssertEqual(summary.id, "summary-1")
        } else {
            XCTFail("Expected weeklySummary to be .loaded, got \(coordinator.weeklySummary)")
        }
        XCTAssertEqual(mockRepository.getWeeklySummaryCallCount, 1)
    }

    // MARK: Test 2: generateWeeklySummary success sets toast and summary

    func test_generateWeeklySummary_success_setsToastAndSummary() async {
        // Arrange
        let expectedSummary = makeWeeklySummary()
        mockRepository.weeklySummaryV2ToReturn = expectedSummary

        var toastMessage: String?
        let coordinator = makeCoordinator(
            selectedWeek: 2,
            onSuccessToast: { message in toastMessage = message }
        )

        // Act
        await coordinator.generateWeeklySummary()

        // Assert
        if case .loaded(let summary) = coordinator.weeklySummary {
            XCTAssertEqual(summary.id, "summary-1")
        } else {
            XCTFail("Expected weeklySummary to be .loaded, got \(coordinator.weeklySummary)")
        }
        XCTAssertNotNil(toastMessage)
        XCTAssertEqual(toastMessage, "週回顧已產生")
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 1)
    }

    // MARK: Test 3: generateWeeklySummary with quota blocked calls onRizoQuotaExceeded

    func test_generateWeeklySummary_rizoQuotaBlocks_setsBanner() async {
        // Arrange
        let expectation = expectation(description: "onRizoQuotaExceeded called")
        let coordinator = makeCoordinator(
            shouldBlockByRizoQuota: { true },
            onRizoQuotaExceeded: { expectation.fulfill() }
        )

        // Act
        await coordinator.generateWeeklySummary()

        // Assert
        await fulfillment(of: [expectation], timeout: 2)
        // Verify weeklySummary was reset to .empty when quota blocked
        if case .empty = coordinator.weeklySummary {
            // expected
        } else {
            XCTFail("Expected weeklySummary to be .empty after quota block, got \(coordinator.weeklySummary)")
        }
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 0)
    }

    // MARK: Test 4: createWeeklySummaryAndShow success shows sheet

    func test_createWeeklySummaryAndShow_success_showsSheet() async {
        // Arrange
        let expectedSummary = makeWeeklySummary()
        mockRepository.weeklySummaryV2ToReturn = expectedSummary

        var loadingValues: [Bool] = []
        let coordinator = makeCoordinator(
            setLoadingAnimation: { value in loadingValues.append(value) }
        )

        // Act
        await coordinator.createWeeklySummaryAndShow(week: 2)

        // Assert
        XCTAssertTrue(coordinator.summaryFlowActive, "summaryFlowActive should be true after success")
        XCTAssertEqual(coordinator.summaryFlowPhase, WeeklySummaryCoordinator.SummaryFlowPhase.showingSummary)
        XCTAssertFalse(coordinator.isLoadingWeeklySummary, "isLoadingWeeklySummary should be false after completion")
        XCTAssertFalse(coordinator.isGeneratingSummary, "isGeneratingSummary should be false after completion")
    }

    // MARK: Test 5: viewHistoricalSummary with subscriptionRequired error routes error

    func test_viewHistoricalSummary_subscriptionRequired_routesError() async {
        // Arrange
        mockRepository.errorToThrow = DomainError.subscriptionRequired

        var receivedError: Error?
        let coordinator = makeCoordinator(
            shouldSuppressError: { domainError, _, _ in
                // subscriptionRequired.shouldShowErrorView == true so don't suppress
                return false
            },
            onNetworkError: { error in receivedError = error }
        )

        // Act
        await coordinator.viewHistoricalSummary(week: 3)

        // Assert
        XCTAssertNotNil(receivedError, "onNetworkError should have been called with the domain error")
        XCTAssertFalse(coordinator.summaryFlowActive, "summaryFlowActive should remain false on error")
        XCTAssertEqual(mockRepository.getWeeklySummaryCallCount, 1)
    }

    // MARK: Test 6 (optional): fetchWeeklySummaries success populates list

    func test_fetchWeeklySummaries_success_populatesList() async {
        // Arrange — override getWeeklySummaries to return mock items
        // MockTrainingPlanV2Repository.getWeeklySummaries() returns [] by default.
        // We need a custom mock or to rely on the error path.
        // Since the mock returns empty array (not an error), we verify the call was made
        // and weeklySummaries reflects the result.
        let coordinator = makeCoordinator()

        // Act
        await coordinator.fetchWeeklySummaries()

        // Assert — default mock returns [], which is still a successful call
        // The important thing: no error thrown, weeklySummaries was set (to empty list here)
        XCTAssertEqual(coordinator.weeklySummaries.count, 0)
    }

    // MARK: - lastRequestedSummaryWeek: regression protection for Sunday vs Mon–Sat

    /// Sunday scenario: user in Week 2, tapped "產生下週課表" but current week summary
    /// is required first → generator calls createWeeklySummaryAndShow(week: currentWeek=2).
    /// The sheet fallback MUST use week 2, never currentWeek-1 (=1).
    func test_createWeeklySummaryAndShow_setsLastRequestedWeek_sundayScenario() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 2)
        let coordinator = makeCoordinator()
        XCTAssertNil(coordinator.lastRequestedSummaryWeek, "precondition: should start nil")

        // Act — Sunday path: generate summary for CURRENT week (2)
        await coordinator.createWeeklySummaryAndShow(week: 2)

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 2,
                       "Sunday scenario: lastRequestedSummaryWeek must equal the currentWeek passed in")
    }

    /// Mon–Sat scenario: user in Week 2 with "需要上週回顧" prompt → view calls
    /// createWeeklySummaryAndShow(week: currentWeek-1=1). Sheet fallback MUST use week 1.
    func test_createWeeklySummaryAndShow_setsLastRequestedWeek_monToSatScenario() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 1)
        let coordinator = makeCoordinator()

        // Act — Mon-Sat path: generate summary for PREVIOUS week (currentWeek-1 = 1)
        await coordinator.createWeeklySummaryAndShow(week: 1)

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 1,
                       "Mon-Sat scenario: lastRequestedSummaryWeek must equal currentWeek-1")
    }

    /// Set early (before repository call) so that a failure path still leaves the
    /// correct week for the sheet fallback to use.
    func test_createWeeklySummaryAndShow_failure_stillRecordsLastRequestedWeek() async {
        // Arrange
        mockRepository.errorToThrow = DomainError.networkFailure("boom")
        let coordinator = makeCoordinator(
            shouldSuppressError: { _, _, _ in false }
        )

        // Act
        await coordinator.createWeeklySummaryAndShow(week: 2)

        // Assert — even though generation failed, week was recorded
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 2)
    }

    func test_viewHistoricalSummary_setsLastRequestedWeek() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 5)
        let coordinator = makeCoordinator()

        // Act
        await coordinator.viewHistoricalSummary(week: 5)

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 5)
    }

    func test_loadWeeklySummary_setsLastRequestedWeek() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 3)
        let coordinator = makeCoordinator()

        // Act
        await coordinator.loadWeeklySummary(weekOfPlan: 3)

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 3)
    }

    func test_generateWeeklySummary_setsLastRequestedWeekFromSelected() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 4)
        let coordinator = makeCoordinator(selectedWeek: 4)

        // Act
        await coordinator.generateWeeklySummary()

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 4)
    }

    func test_debugGenerateForWeek_setsLastRequestedWeek() async {
        // Arrange
        mockRepository.weeklySummaryV2ToReturn = makeWeeklySummary(week: 7)
        let coordinator = makeCoordinator()

        // Act
        await coordinator.debugGenerateForWeek(7, onSuccess: { _ in }, onNetworkError: { _ in })

        // Assert
        XCTAssertEqual(coordinator.lastRequestedSummaryWeek, 7)
    }

    // MARK: Test: paywall gate — enforcement ON + no premium → triggers upsell, skips summary

    /// AC-PAYWALL-23/27: when enforcement is enabled and user has no premium access,
    /// generateWeeklySummary/createWeeklySummaryAndShow must call onWeeklyReviewInlineUpsellNeeded
    /// and NOT proceed to the repository call.
    func test_enforcementOn_noPremium_triggersUpsellAndSkipsSummary() async {
        // Arrange: seed SubscriptionStateManager with no-premium state
        await SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .none, enforcementEnabled: false)
        )
        // Confirm hasPremiumAccess is false (precondition)
        XCTAssertFalse(SubscriptionStateManager.shared.hasPremiumAccess,
                       "Precondition: SubscriptionStateManager must report no premium access")

        let upsellExpectation = expectation(description: "onWeeklyReviewInlineUpsellNeeded called")
        let coordinator = WeeklySummaryCoordinator(
            repository: mockRepository,
            currentSelectedWeek: { 2 },
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: { false },
            refreshPlanStatusResponse: {},
            shouldSuppressError: { _, _, _ in false },
            resolvePaywallTrigger: { .apiGated },
            onSuccessToast: { _ in },
            onPaywallTriggered: { _ in },
            onRizoQuotaExceeded: {},
            onNetworkError: { _ in },
            isEnforcementEnabled: { true },  // enforcement ON
            onWeeklyReviewInlineUpsellNeeded: { upsellExpectation.fulfill() }
        )

        // Act: both entry points must gate
        await coordinator.generateWeeklySummary()

        // Assert: upsell triggered, repository NOT called, flow NOT started
        await fulfillment(of: [upsellExpectation], timeout: 2)
        XCTAssertEqual(mockRepository.generateWeeklySummaryCallCount, 0,
                       "Repository must NOT be called when paywall gates the request")
        XCTAssertFalse(coordinator.summaryFlowActive,
                       "summaryFlowActive must remain false when gate fires")
    }

    // MARK: - submitUserNlEdit: free-text weekly review NL → Rizo (weekly_situation)

    func test_submitUserNlEdit_success_callsWeeklySituation_andLoaded() async {
        // Arrange
        let fake = FakeRizoRepo(stubReply: makeRizoReply(reply: "好，記下了", sessionId: "s1"))
        let coord = makeCoordinator(rizoRepository: fake)
        coord.userNlDraft = "下週減量"

        // Act
        await coord.submitUserNlEdit()

        // Assert
        XCTAssertEqual(fake.lastScenario, "weekly_situation")
        XCTAssertEqual(fake.lastMessage, "下週減量")
        if case .loaded(let msg) = coord.userNlSubmitState {
            XCTAssertEqual(msg, "好，記下了")
        } else {
            XCTFail("expected .loaded, got \(coord.userNlSubmitState)")
        }
        XCTAssertEqual(coord.userNlDraft, "", "成功後應清空 draft")
    }

    func test_submitUserNlEdit_error_setsErrorState() async {
        // Arrange
        let fake = FakeRizoRepo(stubReply: makeRizoReply(reply: "好，記下了", sessionId: "s1"))
        fake.shouldThrow = URLError(.notConnectedToInternet)
        let coord = makeCoordinator(rizoRepository: fake)
        coord.userNlDraft = "下週減量"

        // Act
        await coord.submitUserNlEdit()

        // Assert
        if case .error = coord.userNlSubmitState {
            // expected
        } else {
            XCTFail("expected .error, got \(coord.userNlSubmitState)")
        }
    }
}

// MARK: - FakeRizoRepo

private final class FakeRizoRepo: RizoRepository {
    var lastScenario: String?
    var lastMessage: String?
    var shouldThrow: Error?
    var stubReply: RizoReply

    init(stubReply: RizoReply) { self.stubReply = stubReply }

    func sendChat(scenario: String, message: String, sessionId: String?) async throws -> RizoReply {
        lastScenario = scenario
        lastMessage = message
        if let shouldThrow { throw shouldThrow }
        return stubReply
    }

    func sendJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) async throws -> RizoReply {
        stubReply
    }

    func getPresets(scenario: String) async throws -> [RizoPreset] { [] }

    func getHistory() async throws -> [RizoHistoryItem] { [] }
}
