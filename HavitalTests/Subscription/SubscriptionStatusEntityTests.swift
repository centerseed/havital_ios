import XCTest
@testable import paceriz_dev

/// SPEC-cross-store-subscription §2：iOS「在別的商店訂閱中」判準。
final class SubscriptionStatusEntityTests: XCTestCase {

    func testIsSubscribedOnOtherStore_coversEveryStatusAndStore() {
        let statuses: [SubscriptionStatus] = [
            .active, .gracePeriod, .cancelled, .trial, .expired, .none
        ]
        let stores: [String?] = [
            "APP_STORE", "PLAY_STORE", "PROMOTIONAL", "STRIPE", "MAC_APP_STORE", "", nil
        ]
        let paidRemaining: Set<SubscriptionStatus> = [.active, .gracePeriod, .cancelled]

        for status in statuses {
            for store in stores {
                let entity = SubscriptionStatusEntity(status: status, store: store)
                let expected = paidRemaining.contains(status) && store != "APP_STORE"
                XCTAssertEqual(
                    entity.isSubscribedOnOtherStore,
                    expected,
                    "status=\(status.rawValue) store=\(store ?? "nil")"
                )
            }
        }
    }

    func testLaunchGraceWithEmptyStore_isNotOtherStore() {
        let entity = SubscriptionStatusEntity(
            status: .none,
            inGracePeriod: true,
            store: nil
        )
        XCTAssertFalse(entity.isSubscribedOnOtherStore)
    }
}
