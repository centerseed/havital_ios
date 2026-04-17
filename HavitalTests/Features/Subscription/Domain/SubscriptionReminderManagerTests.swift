import XCTest
@testable import paceriz_dev

@MainActor
final class SubscriptionReminderManagerTests: XCTestCase {
    private let trialReminderKey = "subscription_last_trial_reminder_date"
    private var sut: SubscriptionReminderManager { .shared }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: trialReminderKey)
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .active, enforcementEnabled: true)
        )
        sut.resetSession()
        sut.checkAndShowReminder(status: nil)
    }

    override func tearDown() {
        sut.checkAndShowReminder(status: nil)
        sut.resetSession()
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(status: .none, enforcementEnabled: false)
        )
        UserDefaults.standard.removeObject(forKey: trialReminderKey)
        super.tearDown()
    }

    func testCheckAndShowReminder_trialWithinThreeDays_showsTrialReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))

        assertTrialExpiring(sut.pendingReminder, daysRemaining: 2)
    }

    func testCheckAndShowReminder_trialOverSevenDays_doesNotShowReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 8))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_trialReminderShownOncePerDay() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))
        assertTrialExpiring(sut.pendingReminder, daysRemaining: 2)

        sut.dismissReminder()
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_trialNotEligible_clearsExistingReminder() {
        sut.checkAndShowReminder(status: makeStatus(.trial, daysFromNow: 2))
        assertTrialExpiring(sut.pendingReminder, daysRemaining: 2)

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
        assertTrialExpiring(sut.pendingReminder, daysRemaining: 2)

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

    private func assertTrialExpiring(
        _ reminder: SubscriptionReminder?,
        daysRemaining expectedDays: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .trialExpiring(daysRemaining: actualDays, trialEndsAt: trialEndsAt)? = reminder else {
            XCTFail("Expected trialExpiring reminder but got \(String(describing: reminder))", file: file, line: line)
            return
        }

        XCTAssertEqual(actualDays, expectedDays, file: file, line: line)
        XCTAssertNotNil(trialEndsAt, "trialEndsAt should be present for trial reminder", file: file, line: line)
    }
}
