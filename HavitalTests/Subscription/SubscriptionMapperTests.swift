import XCTest
@testable import paceriz_dev

final class SubscriptionMapperTests: XCTestCase {

    func testToEntity_mapsSubscribedToActive() {
        let dto = SubscriptionStatusDTO(
            status: "subscribed",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.active)
    }

    func testToEntity_mapsTrialActiveToTrial() {
        let dto = SubscriptionStatusDTO(
            status: "trial_active",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: nil,
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.trial)
    }

    func testToEntity_mapsCancelledToCancelled() {
        let dto = SubscriptionStatusDTO(
            status: "cancelled",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.cancelled)
    }

    func testToEntity_mapsActiveWithBillingIssueToGracePeriod() {
        let dto = SubscriptionStatusDTO(
            status: "active",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: true,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.gracePeriod)
        XCTAssertTrue(entity.billingIssue)
    }

    func testToEntity_mapsGracePeriodStringToGracePeriod() {
        let dto = SubscriptionStatusDTO(
            status: "grace_period",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.gracePeriod)
    }

    func testToEntity_mapsRevokedToExpired() {
        let dto = SubscriptionStatusDTO(
            status: "revoked",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.expired)
    }

    func testToEntity_mapsRevokeToExpired() {
        let dto = SubscriptionStatusDTO(
            status: "revoke",
            expiresAt: "2026-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.expired)
    }

    func testToEntity_mapsCancelledWithPastExpiryToExpired() {
        let dto = SubscriptionStatusDTO(
            status: "cancelled",
            expiresAt: "2020-01-01T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.expired)
    }

    func testToEntity_keepsCancelledWhenExpiryInFuture() {
        let dto = SubscriptionStatusDTO(
            status: "cancelled",
            expiresAt: "2099-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: false
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.status, SubscriptionStatus.cancelled)
    }
}
