import XCTest
import RevenueCat
@testable import paceriz_dev

/// T-0236: intro offer 只有在用戶確定合格時才可列入 paywall 顯示候選。
/// 資格未知/不合格/不存在一律隱藏,避免「看到優惠價、實扣原價」。
final class SubscriptionIntroEligibilityTests: XCTestCase {

    func testEligibleStatusDisplaysIntro() {
        XCTAssertTrue(SubscriptionRepositoryImpl.shouldDisplayIntroDiscount(status: .eligible))
    }

    func testIneligibleStatusHidesIntro() {
        XCTAssertFalse(SubscriptionRepositoryImpl.shouldDisplayIntroDiscount(status: .ineligible))
    }

    func testUnknownStatusHidesIntro() {
        XCTAssertFalse(SubscriptionRepositoryImpl.shouldDisplayIntroDiscount(status: .unknown))
    }

    func testNoIntroOfferExistsHidesIntro() {
        XCTAssertFalse(SubscriptionRepositoryImpl.shouldDisplayIntroDiscount(status: .noIntroOfferExists))
    }
}
