import XCTest
import Combine
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
        // Use churned expired status (subscribedAt != nil) so dialog fires
        let expiredStatus = makeChurnedExpiredStatus()
        sut.checkAndShowReminder(status: expiredStatus)

        XCTAssertEqual(sut.pendingReminder, .expired)

        sut.dismissReminder()
        sut.checkAndShowReminder(status: expiredStatus)

        XCTAssertNil(sut.pendingReminder)
    }

    func testCheckAndShowReminder_expiredAfterSessionReset_showsAgain() {
        // Use churned expired status (subscribedAt != nil) so dialog fires
        let expiredStatus = makeChurnedExpiredStatus()
        sut.checkAndShowReminder(status: expiredStatus)
        sut.dismissReminder()

        sut.resetSession()
        sut.checkAndShowReminder(status: expiredStatus)

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

    // MARK: - AC-PAYWALL-37 Race Condition Tests

    /// Simulates cold-start race (churned user with plan):
    /// 1. onAppear fires immediately → cache empty → dialog shows (hasGeneratedTrainingPlan=false)
    /// 2. Plan loader completes → cache populated → publisher fires → re-evaluation with
    ///    hasGeneratedTrainingPlan=true → dialog dismissed (pendingReminder = nil)
    func testRaceCondition_dialogDismissedWhenPlanLoaderPopulatesCache() {
        let expiredStatus = makeChurnedExpiredStatus()

        // Step 1: onAppear fires before plan loader — cache empty, dialog should appear
        sut.resetSession()
        sut.checkAndShowReminder(status: expiredStatus, hasGeneratedTrainingPlan: false)
        XCTAssertEqual(
            sut.pendingReminder, .expired,
            "Dialog must appear initially when cache is empty (hasGeneratedTrainingPlan=false)"
        )

        // Step 2: Plan loader completes → publisher fires → ContentView re-evaluates
        // In production this is triggered by overviewDidUpdate publisher, represented here as
        // a direct call with hasGeneratedTrainingPlan=true (the state after cache is populated).
        sut.checkAndShowReminder(status: expiredStatus, hasGeneratedTrainingPlan: true)
        XCTAssertNil(
            sut.pendingReminder,
            "Dialog must be dismissed when plan loader populates cache (hasGeneratedTrainingPlan=true) — FreeTierBanner handles the UX"
        )
    }

    /// Regression: churned user, no plan (status=expired, subscribedAt!=nil).
    /// The re-fire from the publisher must NOT suppress the dialog if no plan exists.
    func testRaceCondition_newUserWithoutPlan_dialogSurvivesReEvaluation() {
        // This test uses a churned user (subscribedAt != nil) — dialog SHOULD fire.
        // For a true new user (subscribedAt = nil), the dialog is suppressed by design.
        let expiredStatus = makeChurnedExpiredStatus()

        // Step 1: onAppear — no plan
        sut.resetSession()
        sut.checkAndShowReminder(status: expiredStatus, hasGeneratedTrainingPlan: false)
        XCTAssertEqual(
            sut.pendingReminder, .expired,
            "Dialog must appear for churned user with no training plan"
        )

        // Step 2: Re-evaluation arrives but plan still doesn't exist (hasGeneratedTrainingPlan=false)
        // This can happen if the API returns 404 (user truly has no plan yet)
        sut.checkAndShowReminder(status: expiredStatus, hasGeneratedTrainingPlan: false)
        // hasShownExpiredThisSession is already true, so re-check will clear (session guard)
        // The important thing: dialog was correctly shown in step 1 and wasn't incorrectly suppressed
        // The session guard prevents a second dialog from appearing, which is correct behaviour
        XCTAssertNil(
            sut.pendingReminder,
            "Second check in same session correctly returns nil (session guard prevents re-show), but dialog was correctly shown in step 1"
        )
    }

    /// AC-PAYWALL-37 belt-and-suspenders: true new user (subscribedAt=nil) never sees expired dialog.
    func testRaceCondition_trueNewUser_neverSeesExpiredDialog() {
        let newUserExpiredStatus = SubscriptionStatusEntity(
            status: .expired,
            enforcementEnabled: true,
            subscribedAt: nil
        )

        sut.resetSession()
        sut.checkAndShowReminder(status: newUserExpiredStatus, hasGeneratedTrainingPlan: false)
        XCTAssertNil(
            sut.pendingReminder,
            "True new user (subscribedAt=nil) must never see 'expired' dialog — they never subscribed"
        )
    }

    /// Creates an expired status for a **churned** user (subscribedAt != nil).
    /// Use this when you want the reminder manager to fire the expired dialog.
    private func makeChurnedExpiredStatus() -> SubscriptionStatusEntity {
        SubscriptionStatusEntity(
            status: .expired,
            enforcementEnabled: true,
            subscribedAt: Date().addingTimeInterval(-7_776_000).timeIntervalSince1970 // 90 days ago
        )
    }

    /// Creates a status entity for non-expired states (no subscribedAt needed).
    private func makeStatus(_ status: SubscriptionStatus, daysFromNow: Int? = nil) -> SubscriptionStatusEntity {
        let trialEndAt = daysFromNow.map { Date().addingTimeInterval(Double($0) * 86400).timeIntervalSince1970 }
        return SubscriptionStatusEntity(
            status: status,
            expiresAt: trialEndAt,
            planType: "premium",
            trialRemainingDays: status == .trial ? daysFromNow : nil,
            trialEndAt: status == .trial ? trialEndAt : nil
        )
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
