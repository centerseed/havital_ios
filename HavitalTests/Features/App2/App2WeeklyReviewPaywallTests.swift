import XCTest
@testable import paceriz_dev

@MainActor
final class App2WeeklyReviewPaywallTests: XCTestCase {
    private var repository: MockTrainingPlanV2Repository!
    private var viewModel: App2WeeklyReviewViewModel!
    private var previousSubscriptionStatus: SubscriptionStatusEntity?

    override func setUp() async throws {
        try await super.setUp()
        previousSubscriptionStatus = SubscriptionStateManager.shared.currentStatus
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .expired, enforcementEnabled: true)
        )
        repository = MockTrainingPlanV2Repository()
        viewModel = App2WeeklyReviewViewModel(weekOfPlan: 4, repository: repository)
    }

    override func tearDown() async throws {
        if let previousSubscriptionStatus {
            SubscriptionStateManager.shared.update(previousSubscriptionStatus)
        } else {
            SubscriptionStateManager.shared.applyLogoutReset()
        }
        SubscriptionStateManager.shared.clearDowngrade()
        repository = nil
        viewModel = nil
        try await super.tearDown()
    }

    func testLoad_WhenSubscriptionGateBlocksAccess_ReadsOnlyAndShowsUpsell() async {
        repository.weeklySummaryV2ToReturn = nil

        await viewModel.load()

        XCTAssertEqual(repository.generateWeeklySummaryCallCount, 0)
        XCTAssertEqual(repository.getWeeklySummaryCallCount, 1, "A blocked review must use the read-only fetch path")
        XCTAssertTrue(viewModel.showsUpsell)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.needsGeneration)
    }

    func testLoad_WhenSummaryReadReturnsSubscriptionRequired_ShowsUpsellInsteadOfError() async {
        repository.weeklySummaryErrorToThrow = DomainError.subscriptionRequired

        await viewModel.load()

        XCTAssertEqual(repository.generateWeeklySummaryCallCount, 0)
        XCTAssertEqual(repository.getWeeklySummaryCallCount, 1)
        XCTAssertTrue(viewModel.showsUpsell)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.needsGeneration)
        if case .error = viewModel.weeklySummaryState {
            XCTFail("A subscription gate must not become a weekly summary error state")
        }
    }
}
