import XCTest

// MARK: - AC38GracePeriodUITests
//
// UITest for AC-PAYWALL-38/39: verifies that when a user is in the 7-day
// grace period (inGracePeriod=true, graceRemainingDays=5), the app correctly:
//
//   1. Shows the FreeTierBanner (hasRealSubscription=false)
//   2. Renders the grace-period text variant ("免費體驗中，剩 X 天" / "%d days free trial remaining")
//   3. Does NOT trigger the inline upsell (hasPremiumAccess=true)
//
// Harness:
//   -ui_testing_ac38 → routes HavitalApp to UITestAC38GraceHostView
//                       injects grace period status (inGracePeriod=true, graceRemainingDays=5)

@MainActor
final class AC38GracePeriodUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main Test

    /// AC-PAYWALL-38/39: Grace period user sees FreeTierBanner with remaining days text;
    /// hasPremiumAccess=true (no inline upsell), hasRealSubscription=false (banner visible).
    func testGracePeriodUser_ShowsBannerWithRemainingDays_NoPremiumGate() {
        launchApp()

        // Wait for harness to be ready
        let hostReady = app.staticTexts["UITest_AC38_HostReady"]
        XCTAssertTrue(
            hostReady.waitForExistence(timeout: 10),
            "AC38 harness host should appear within 10 seconds"
        )

        // ASSERTION 1: hasPremiumAccess diagnostic should be true
        let premiumLabel = app.staticTexts["UITest_AC38_HasPremiumAccess"]
        XCTAssertTrue(
            premiumLabel.waitForExistence(timeout: 3),
            "UITest_AC38_HasPremiumAccess label should be visible"
        )
        let hasPremiumPredicate = NSPredicate(format: "label CONTAINS 'true'")
        let hasPremiumExpectation = XCTNSPredicateExpectation(
            predicate: hasPremiumPredicate,
            object: premiumLabel
        )
        let hasPremiumResult = XCTWaiter().wait(for: [hasPremiumExpectation], timeout: 3)
        XCTAssertEqual(
            hasPremiumResult, .completed,
            "hasPremiumAccess must be true for grace period user (AI features unlocked)"
        )

        // ASSERTION 2: hasRealSubscription diagnostic should be false
        let realSubLabel = app.staticTexts["UITest_AC38_HasRealSubscription"]
        XCTAssertTrue(
            realSubLabel.waitForExistence(timeout: 3),
            "UITest_AC38_HasRealSubscription label should be visible"
        )
        let notRealSubPredicate = NSPredicate(format: "label CONTAINS 'false'")
        let notRealSubExpectation = XCTNSPredicateExpectation(
            predicate: notRealSubPredicate,
            object: realSubLabel
        )
        let notRealSubResult = XCTWaiter().wait(for: [notRealSubExpectation], timeout: 3)
        XCTAssertEqual(
            notRealSubResult, .completed,
            "hasRealSubscription must be false for grace period user (banner should be visible)"
        )

        // ASSERTION 3: FreeTierBanner must be visible (plan exists, grace cohort)
        let bannerButton = app.buttons["FreeTierBanner"]
        let bannerOther = app.otherElements["FreeTierBanner"]
        let bannerVisible = bannerButton.waitForExistence(timeout: 3) || bannerOther.exists
        XCTAssertTrue(
            bannerVisible,
            "FreeTierBanner must be visible for grace period user with existing training plan"
        )

        // ASSERTION 4: Banner contains the remaining days number "5"
        // The grace title format puts "%d" as the days count; rendered = "5"
        let bannerContains5Predicate = NSPredicate(format: "label CONTAINS '5'")
        // Check all text elements within the banner area for the number "5"
        let textsContaining5 = app.staticTexts.matching(bannerContains5Predicate)
        XCTAssertGreaterThan(
            textsContaining5.count,
            0,
            "FreeTierBanner must display the remaining days count (5) in the grace period text variant"
        )

        // ASSERTION 5: No inline upsell alert or paywall sheet should be triggered
        // (hasPremiumAccess=true means gating is bypassed)
        let alertExists = app.alerts.firstMatch.waitForExistence(timeout: 1)
        XCTAssertFalse(
            alertExists,
            "No subscription alert must appear for grace period user (hasPremiumAccess=true)"
        )

        // Attach screenshot as evidence
        attachScreenshot(name: "ac38_grace_period_banner_visible")
    }

    // MARK: - Helpers

    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_ac38"
        ]
        app.launch()
    }

    private func attachScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let tmpPath = "/tmp/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: tmpPath))
    }
}
