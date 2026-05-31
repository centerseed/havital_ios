import XCTest

// MARK: - AC37BannerVsAlertRaceUITests
//
// UITest for AC-PAYWALL-37: verifies that when a user with subscription_status=expired
// AND an existing Week 1 plan opens the app, only FreeTierBanner is shown and the
// "Subscription Expired" dialog is NOT shown.
//
// Race condition being tested:
//   onAppear fires with hasGeneratedTrainingPlan=false (cache cold)
//   → expired dialog is queued
//   → plan loader completes (~0.6s later) → overviewDidUpdate fires
//   → dialog should be suppressed, FreeTierBanner appears
//
// Harness:
//   -ui_testing_ac37         → routes HavitalApp to UITestAC37HostView
//                              injects UITestAC37MockSubscriptionRepository (expired)
//                              injects UITestAC37MockTrainingPlanV2Repository
//                              (getCachedOverview=nil initially, fires overviewDidUpdate after delay)
//
// How to read results:
//   FAIL before fix: XCTAssertFalse(alerts...) — dialog visible, race confirmed
//   PASS after fix:  FreeTierBanner visible, no dialog

@MainActor
final class AC37BannerVsAlertRaceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        // Screenshot already attached inside test; clean up app reference
        app = nil
    }

    // MARK: - Main Regression Test

    /// AC-PAYWALL-37: Only FreeTierBanner should be visible; expired dialog must NOT appear.
    func testExpiredUserWithPlan_ShowsBannerOnly_NoExpiredDialog() {
        launchApp()

        // Wait for harness host to be ready (replaces waiting for TabBar / home screen)
        let hostReady = app.staticTexts["UITest_AC37_HostReady"]
        XCTAssertTrue(
            hostReady.waitForExistence(timeout: 10),
            "AC37 harness host should appear within 10 seconds"
        )

        // Wait for the plan loader simulation to complete (mock delays ~0.6s).
        // The diagnostic label "UITest_AC37_HasOverview" should flip to "hasOverview:true"
        // once PlanOverviewObserver receives the overviewDidUpdate event.
        let hasOverviewLabel = app.staticTexts["UITest_AC37_HasOverview"]
        XCTAssertTrue(
            hasOverviewLabel.waitForExistence(timeout: 5),
            "Diagnostic label UITest_AC37_HasOverview should be visible"
        )

        // Wait up to 5s for the label to show "hasOverview:true"
        let hasOverviewPredicate = NSPredicate(format: "label CONTAINS 'true'")
        let hasOverviewExpectation = XCTNSPredicateExpectation(
            predicate: hasOverviewPredicate,
            object: hasOverviewLabel
        )
        let hasOverviewResult = XCTWaiter().wait(for: [hasOverviewExpectation], timeout: 5)
        XCTAssertEqual(
            hasOverviewResult, .completed,
            "PlanOverviewObserver.hasOverview should flip to true within 5s (plan loader simulation delay ~0.6s)"
        )

        // ASSERTION 1: FreeTierBanner must be visible (plan exists, user expired)
        // FreeTierBanner is a Button with .buttonStyle(.plain) — check both buttons and otherElements
        let bannerButton = app.buttons["FreeTierBanner"]
        let bannerOther = app.otherElements["FreeTierBanner"]
        let bannerVisible = bannerButton.waitForExistence(timeout: 3) || bannerOther.exists
        XCTAssertTrue(
            bannerVisible,
            "FreeTierBanner must be visible for expired user with existing training plan (checked both button and otherElement)"
        )

        // ASSERTION 2: Expired dialog must NOT be present
        // A dialog appearing here means the race condition is NOT fixed.
        let alertExists = app.alerts.firstMatch.waitForExistence(timeout: 1)
        XCTAssertFalse(
            alertExists,
            "Expired subscription dialog must NOT appear when FreeTierBanner is already shown (AC-PAYWALL-37 regression)"
        )

        // Attach screenshot as evidence
        attachScreenshot(name: "ac37_after_fix_banner_only")
    }

    // MARK: - New user cohort: subscribedAt=nil, no plan → no banner, no dialog

    /// AC-PAYWALL-37 belt-and-suspenders: true new user (never subscribed, no plan).
    /// subscribedAt=nil means they never paid — "expired" dialog is wrong messaging.
    /// Expected: neither banner nor dialog appears.
    func testExpiredNewUser_NoPlan_NoDialog() {
        launchApp(scenario: "new_user_no_plan")

        let hostReady = app.staticTexts["UITest_AC37_HostReady"]
        XCTAssertTrue(
            hostReady.waitForExistence(timeout: 10),
            "AC37 harness host should appear within 10 seconds"
        )

        // Wait for plan loader to complete: planCheckConfirmed should flip to true
        let confirmedLabel = app.staticTexts["UITest_AC37_PlanCheckConfirmed"]
        XCTAssertTrue(
            confirmedLabel.waitForExistence(timeout: 5),
            "Diagnostic label UITest_AC37_PlanCheckConfirmed should be visible"
        )

        let confirmedPredicate = NSPredicate(format: "label CONTAINS 'true'")
        let confirmedExpectation = XCTNSPredicateExpectation(
            predicate: confirmedPredicate,
            object: confirmedLabel
        )
        let confirmedResult = XCTWaiter().wait(for: [confirmedExpectation], timeout: 5)
        XCTAssertEqual(
            confirmedResult, .completed,
            "PlanOverviewObserver.planCheckConfirmed should flip to true within 5s for no-plan user"
        )

        // ASSERTION 1: FreeTierBanner must NOT be visible (no plan generated)
        let bannerButton = app.buttons["FreeTierBanner"]
        let bannerOther = app.otherElements["FreeTierBanner"]
        let bannerVisible = bannerButton.exists || bannerOther.exists
        XCTAssertFalse(
            bannerVisible,
            "FreeTierBanner must NOT be visible for new user with no training plan"
        )

        // ASSERTION 2: Expired dialog must NOT appear (subscribedAt=nil → never subscribed)
        let alertExists = app.alerts.firstMatch.waitForExistence(timeout: 2)
        XCTAssertFalse(
            alertExists,
            "Expired subscription dialog must NOT appear for true new user (subscribedAt=nil) — wrong message for someone who never paid"
        )

        attachScreenshot(name: "ac37_new_user_no_plan_nothing_shown")
    }

    // MARK: - Churned user cohort: subscribedAt!=nil, no plan → no banner, dialog fires

    /// AC-PAYWALL-37 belt-and-suspenders: churned user (was subscribed, let it lapse, no plan).
    /// subscribedAt!=nil means they previously paid — "expired" dialog is correct.
    /// Expected: no banner (no plan), but dialog fires (re-engagement nudge).
    func testExpiredChurnedUser_NoPlan_DialogFires() {
        launchApp(scenario: "churned_user_no_plan")

        let hostReady = app.staticTexts["UITest_AC37_HostReady"]
        XCTAssertTrue(
            hostReady.waitForExistence(timeout: 10),
            "AC37 harness host should appear within 10 seconds"
        )

        // Wait for plan loader to confirm no plan
        let confirmedLabel = app.staticTexts["UITest_AC37_PlanCheckConfirmed"]
        XCTAssertTrue(
            confirmedLabel.waitForExistence(timeout: 5),
            "Diagnostic label UITest_AC37_PlanCheckConfirmed should be visible"
        )

        let confirmedPredicate = NSPredicate(format: "label CONTAINS 'true'")
        let confirmedExpectation = XCTNSPredicateExpectation(
            predicate: confirmedPredicate,
            object: confirmedLabel
        )
        let confirmedResult = XCTWaiter().wait(for: [confirmedExpectation], timeout: 5)
        XCTAssertEqual(
            confirmedResult, .completed,
            "PlanOverviewObserver.planCheckConfirmed should flip to true within 5s for churned user"
        )

        // ASSERTION 1: FreeTierBanner must NOT be visible (no plan generated)
        let bannerButton = app.buttons["FreeTierBanner"]
        let bannerOther = app.otherElements["FreeTierBanner"]
        let bannerVisible = bannerButton.exists || bannerOther.exists
        XCTAssertFalse(
            bannerVisible,
            "FreeTierBanner must NOT be visible for churned user with no training plan"
        )

        // ASSERTION 2: Expired dialog MUST appear (churned user, subscribedAt!=nil)
        let alertExists = app.alerts.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(
            alertExists,
            "Expired subscription dialog MUST appear for churned user (subscribedAt!=nil, no plan) — re-engagement nudge"
        )

        attachScreenshot(name: "ac37_churned_user_no_plan_dialog_shown")
    }

    // MARK: - Helpers

    private func launchApp(scenario: String = "expired_with_plan") {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_ac37"
        ]
        app.launchEnvironment["UITEST_AC37_SCENARIO"] = scenario
        app.launch()
    }

    /// Waits the specified duration for async operations to settle.
    /// Uses XCTNSPredicateExpectation on a condition that is always true
    /// so we get a non-blocking wait compatible with XCTest.
    private func waitForPlanLoaderToComplete(seconds: TimeInterval) {
        let start = Date()
        let predicate = NSPredicate { _, _ in
            Date().timeIntervalSince(start) >= seconds
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        _ = XCTWaiter().wait(for: [expectation], timeout: seconds + 2)
    }

    /// Attaches a screenshot to the test result for manual verification.
    private func attachScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to /tmp for easy access
        let tmpPath = "/tmp/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: tmpPath))
    }
}
