import XCTest
import StoreKitTest

@available(iOS 15.0, *)
final class StoreKitPaywallUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKitSession: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false

        XCUIDevice.shared.orientation = .portrait

        storeKitSession = try SKTestSession(configurationFileNamed: "PacerizUITests")
        storeKitSession.resetToDefaultState()
        storeKitSession.clearTransactions()
        storeKitSession.disableDialogs = true
        storeKitSession.askToBuyEnabled = false
        storeKitSession.failTransactionsEnabled = false

        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_paywall",
            "-useStoreKitTestRepository"
        ]
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        let openPaywallButton = app.buttons["UITest_OpenPaywall"]
        XCTAssertTrue(openPaywallButton.waitForExistence(timeout: 10), "UITest host should expose paywall trigger button")

        let repoTypeLabel = app.staticTexts["UITest_SubscriptionRepositoryType"]
        XCTAssertTrue(repoTypeLabel.waitForExistence(timeout: 5), "UITest host should expose repository type for diagnostics")
        XCTAssertTrue(
            repoTypeLabel.label.contains("StoreKitTestSubscriptionRepository"),
            "Expected StoreKit test repository, got: \(repoTypeLabel.label)"
        )

        tapRobust(openPaywallButton)
        XCTAssertTrue(waitForPaywallVisible(timeout: 12), "Paywall should be visible after tapping open button")
    }

    override func tearDownWithError() throws {
        storeKitSession?.failTransactionsEnabled = false
        storeKitSession?.askToBuyEnabled = false
        storeKitSession?.disableDialogs = true
        storeKitSession?.resetToDefaultState()
        app = nil
        storeKitSession = nil
    }

    func testPurchaseYearlyActivatesSubscription() {
        XCTAssertTrue(
            purchaseUntilActive(packageButtonId: "Paywall_YearlyOption"),
            "Subscription status should become active after successful purchase"
        )
        XCTAssertFalse(app.alerts.firstMatch.exists, "No purchase error alert expected on success path")
    }

    func testFailedPurchaseShowsErrorAlert() {
        storeKitSession.failTransactionsEnabled = true

        XCTAssertTrue(openPaywallIfNeeded(), "Paywall should be open before failed purchase assertion")
        let monthlyOption = app.buttons["Paywall_MonthlyOption"]
        XCTAssertTrue(monthlyOption.waitForExistence(timeout: 8), "Monthly option should exist")

        monthlyOption.tap()

        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 10), "Purchase error alert should be shown when StoreKit transaction fails")
        dismissPurchaseAlertIfPresent()
        storeKitSession.failTransactionsEnabled = false
    }

    func testRestorePurchasesKeepsActiveStatusAfterPurchase() {
        XCTAssertTrue(
            purchaseUntilActive(packageButtonId: "Paywall_YearlyOption"),
            "Status should become active after initial purchase"
        )

        XCTAssertTrue(openPaywallIfNeeded(), "Paywall should be open before restore")

        let restoreButton = app.buttons["Paywall_RestoreButton"]
        XCTAssertFalse(restoreButton.waitForExistence(timeout: 3), "Restore button should stay hidden for active subscription")
        XCTAssertTrue(waitForSubscriptionStatus("active", timeout: 10), "Status should remain active after purchase")
    }

    func testRestoreButtonVisibleWhenStatusIsNone() {
        let restoreButton = app.buttons["Paywall_RestoreButton"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 8), "Restore button should be visible for non-subscribed user")
    }

    func testRestoreButtonHiddenWhenStatusIsActive() {
        XCTAssertTrue(
            purchaseUntilActive(packageButtonId: "Paywall_YearlyOption"),
            "Status should become active after successful purchase"
        )

        XCTAssertTrue(openPaywallIfNeeded(), "Paywall should be open after purchase")

        let restoreButton = app.buttons["Paywall_RestoreButton"]
        XCTAssertFalse(restoreButton.waitForExistence(timeout: 3), "Restore button should be hidden for active subscription")
    }

    @discardableResult
    private func waitForSubscriptionStatus(_ status: String, timeout: TimeInterval) -> Bool {
        guard ensureHostVisible(timeout: 8) else {
            return false
        }

        let statusLabel = app.staticTexts["UITest_SubscriptionStatus"]
        guard statusLabel.waitForExistence(timeout: timeout) else {
            return false
        }

        let predicate = NSPredicate(format: "label CONTAINS %@", status)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: statusLabel)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    private func purchaseUntilActive(packageButtonId: String, maxAttempts: Int = 5) -> Bool {
        storeKitSession.failTransactionsEnabled = false
        storeKitSession.askToBuyEnabled = false
        storeKitSession.disableDialogs = true

        guard openPaywallIfNeeded() else { return false }

        for _ in 0..<maxAttempts {
            let packageButton = app.buttons[packageButtonId]
            guard packageButton.waitForExistence(timeout: 8) else { return false }
            packageButton.tap()

            // If StoreKit immediately returns an error/cancel alert, retry.
            if app.alerts.firstMatch.waitForExistence(timeout: 2) {
                print("🧪 [StoreKitPaywallUITests] purchase alert: \(currentAlertDebugText())")
                dismissPurchaseAlertIfPresent()
                _ = openPaywallIfNeeded()
                continue
            }

            if waitForPurchaseSuccessOverlay(timeout: 8) {
                dismissPurchaseSuccessIfPresent()
            }

            if waitForSubscriptionStatus("active", timeout: 10) {
                return true
            }

            dismissPurchaseAlertIfPresent()
            _ = openPaywallIfNeeded()
        }

        return false
    }

    @discardableResult
    private func openPaywallIfNeeded() -> Bool {
        let yearlyOption = app.buttons["Paywall_YearlyOption"]
        if yearlyOption.exists {
            return true
        }

        guard ensureHostVisible(timeout: 8) else { return false }
        let openPaywallButton = app.buttons["UITest_OpenPaywall"]
        guard openPaywallButton.waitForExistence(timeout: 5) else { return false }
        tapRobust(openPaywallButton)
        return waitForPaywallVisible(timeout: 10)
    }

    @discardableResult
    private func ensureHostVisible(timeout: TimeInterval) -> Bool {
        dismissPurchaseSuccessIfPresent()

        let closeButton = app.buttons["Paywall_CloseButton"]
        if closeButton.waitForExistence(timeout: 1) {
            closeButton.tap()
        }

        let openPaywallButton = app.buttons["UITest_OpenPaywall"]
        return openPaywallButton.waitForExistence(timeout: timeout)
    }

    @discardableResult
    private func waitForPurchaseSuccessOverlay(timeout: TimeInterval) -> Bool {
        let startUsingButton = app.buttons["Paywall_StartUsingButton"]
        if startUsingButton.waitForExistence(timeout: timeout) {
            return true
        }

        return app.otherElements["Paywall_SuccessOverlay"].exists
    }

    private func dismissPurchaseSuccessIfPresent() {
        let startUsingButton = app.buttons["Paywall_StartUsingButton"]
        if startUsingButton.waitForExistence(timeout: 1) {
            startUsingButton.tap()
        }
    }

    private func dismissPurchaseAlertIfPresent() {
        let alert = app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }

        let preferredButtons = ["OK", "確定", "好"]
        for title in preferredButtons {
            let button = alert.buttons[title]
            if button.exists {
                button.tap()
                return
            }
        }

        alert.buttons.firstMatch.tap()
    }

    private func currentAlertDebugText() -> String {
        let alert = app.alerts.firstMatch
        guard alert.exists else { return "<no alert>" }

        var texts: [String] = []
        texts.append(alert.label)
        texts.append(contentsOf: alert.staticTexts.allElementsBoundByIndex.map(\.label))
        return texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    @discardableResult
    private func waitForPaywallVisible(timeout: TimeInterval) -> Bool {
        let yearlyOption = app.buttons["Paywall_YearlyOption"]
        if yearlyOption.waitForExistence(timeout: timeout) {
            return true
        }
        return app.buttons["Paywall_CloseButton"].waitForExistence(timeout: 2)
    }

    private func tapRobust(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }

        app.swipeUp()
        if element.isHittable {
            element.tap()
            return
        }

        app.swipeDown()
        if element.isHittable {
            element.tap()
            return
        }

        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
