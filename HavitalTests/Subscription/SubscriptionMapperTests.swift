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

    // MARK: - New contract fields (Phase 2)

    func testMapsInIntroTrialFlagToEntity() {
        let dto = SubscriptionStatusDTO(
            status: "trial_active",
            expiresAt: "2099-12-31T00:00:00Z",
            planType: "monthly",
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: true,
            trialRemainingDays: 5,
            isEarlyBird: true,
            hasOverride: false,
            inIntroTrial: true
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.inIntroTrial, true)
        XCTAssertEqual(entity.isEarlyBird, true)
        XCTAssertEqual(entity.hasOverride, false)
    }

    func testTrialRemainingDaysFromDTOIsPreserved() {
        let dto = SubscriptionStatusDTO(
            status: "trial_active",
            expiresAt: "2099-12-31T00:00:00Z",
            trialRemainingDays: 9
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        XCTAssertEqual(entity.trialRemainingDays, 9)
    }

    func testMapsRizoUsageRemainingAndResetsAtToEntity() throws {
        let dto = SubscriptionStatusDTO(
            status: "subscribed",
            rizoUsage: RizoUsageDTO(used: 3, limit: 10, remaining: 7, resetsAt: "2026-04-22T00:00:00Z")
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        let rizo = try XCTUnwrap(entity.rizoUsage)
        XCTAssertEqual(rizo.used, 3)
        XCTAssertEqual(rizo.limit, 10)
        XCTAssertEqual(rizo.remaining, 7)
        XCTAssertEqual(rizo.resetsAt, "2026-04-22T00:00:00Z")
    }

    func testRizoUsageFallsBackToLimitMinusUsedWhenRemainingNil() throws {
        let dto = SubscriptionStatusDTO(
            status: "subscribed",
            rizoUsage: RizoUsageDTO(used: 4, limit: 10)
        )

        let entity = SubscriptionMapper.toEntity(from: dto)

        let rizo = try XCTUnwrap(entity.rizoUsage)
        XCTAssertEqual(rizo.remaining, 6, "remaining should fall back to max(0, limit - used)")
        XCTAssertNil(rizo.resetsAt)
    }
}
