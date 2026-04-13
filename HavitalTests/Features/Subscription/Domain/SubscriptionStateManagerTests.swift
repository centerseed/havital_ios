import XCTest
@testable import paceriz_dev

@MainActor
final class SubscriptionStateManagerTests: XCTestCase {

    private var sut: SubscriptionStateManager!

    override func setUp() {
        super.setUp()
        sut = SubscriptionStateManager.shared
        resetState()
    }

    override func tearDown() {
        resetState()
        sut = nil
        super.tearDown()
    }

    func testUpdate_WhenDowngradeFromActiveToExpired_SetsRecentDowngrade() {
        sut.update(SubscriptionStatusEntity(status: .active))
        sut.clearDowngrade()

        sut.update(SubscriptionStatusEntity(status: .expired))

        XCTAssertEqual(sut.recentDowngrade, StatusDowngrade(from: .active, to: .expired))
    }

    func testUpdate_WhenDowngradeFromCancelledToExpired_SetsRecentDowngrade() {
        sut.update(SubscriptionStatusEntity(status: .cancelled))
        sut.clearDowngrade()

        sut.update(SubscriptionStatusEntity(status: .expired))

        XCTAssertEqual(sut.recentDowngrade, StatusDowngrade(from: .cancelled, to: .expired))
    }

    func testUpdate_WhenUpgradeFromTrialToActive_DoesNotSetRecentDowngrade() {
        sut.update(SubscriptionStatusEntity(status: .trial))
        sut.clearDowngrade()

        sut.update(SubscriptionStatusEntity(status: .active))

        XCTAssertNil(sut.recentDowngrade)
    }

    func testClearDowngrade_RemovesRecentDowngrade() {
        sut.update(SubscriptionStatusEntity(status: .active))
        sut.update(SubscriptionStatusEntity(status: .none))
        XCTAssertNotNil(sut.recentDowngrade)

        sut.clearDowngrade()

        XCTAssertNil(sut.recentDowngrade)
    }

    private func resetState() {
        sut.update(SubscriptionStatusEntity(status: .none))
        sut.clearDowngrade()
    }
}
