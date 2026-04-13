import XCTest
@testable import paceriz_dev

@MainActor
final class SubscriptionReminderManagerTests: XCTestCase {
    private let trialReminderKey = "subscription_last_trial_reminder_date"
    private var sut: SubscriptionReminderManager { .shared }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: trialReminderKey)
        sut.resetSession()
        sut.checkAndShowReminder(status: nil)
    }

    override func tearDown() {
        sut.checkAndShowReminder(status: nil)
        sut.resetSession()
        UserDefaults.standard.removeObject(forKey: trialReminderKey)
        super.tearDown()
    }

    func testCheckAndShowReminder_trialWithinThreeDays_showsTrialReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))

        XCTAssertEqual(sut.pendingReminder, .trialExpiring(daysRemaining: 2))
    }

    func testCheckAndShowReminder_trialOverThreeDays_doesNotShowReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 5))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_trialReminderShownOncePerDay() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))
        XCTAssertEqual(sut.pendingReminder, .trialExpiring(daysRemaining: 2))

        sut.dismissReminder()
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_trialNotEligible_clearsExistingReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))
        XCTAssertEqual(sut.pendingReminder, .trialExpiring(daysRemaining: 2))

        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 6))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_expiredOnlyOncePerSession() {
        sut.checkAndShowReminder(status: makeStatus(.expired))

        XCTAssertEqual(sut.pendingReminder, .expired)

        sut.dismissReminder()
        sut.checkAndShowReminder(status: makeStatus(.expired))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_expiredAfterSessionReset_showsAgain() {
        sut.checkAndShowReminder(status: makeStatus(.expired))
        sut.dismissReminder()

        sut.resetSession()
        sut.checkAndShowReminder(status: makeStatus(.expired))

        XCTAssertEqual(sut.pendingReminder, .expired)
    }

    func testCheckAndShowReminder_nonReminderStatuses_clearReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))
        XCTAssertEqual(sut.pendingReminder, .trialExpiring(daysRemaining: 2))

        sut.checkAndShowReminder(status: makeStatus(.active))
        XCTAssertNil(sut.pendingReminder)

        sut.checkAndShowReminder(status: makeStatus(.cancelled, daysFromNow: 5))
        XCTAssertNil(sut.pendingReminder)

        sut.checkAndShowReminder(status: makeStatus(.gracePeriod, daysFromNow: 5))
        XCTAssertNil(sut.pendingReminder)

        sut.checkAndShowReminder(status: makeStatus(.none))
        XCTAssertNil(sut.pendingReminder)
    }

    private func makeStatus(_ status: SubscriptionStatus, daysFromNow: Int? = nil) -> SubscriptionStatusEntity {
        let expiresAt = daysFromNow.map { Date().addingTimeInterval(Double($0) * 86400).timeIntervalSince1970 }
        return SubscriptionStatusEntity(status: status, expiresAt: expiresAt, planType: "premium")
    }
}
