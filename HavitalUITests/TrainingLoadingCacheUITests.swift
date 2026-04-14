import XCTest

@MainActor
final class TrainingLoadingCacheUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCacheFirst_ShowsCachedDistanceImmediately_AndNoBlockingOverlay() {
        launchApp(
            scenario: "cache_then_refresh_success",
            refreshDelayMs: "20000"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_CacheStatus", "cache_status:cache_hit", timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:5.0", timeout: 2))
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testBackgroundRefreshSuccess_UpdatesVisibleDistanceWithoutBlocking() {
        launchApp(scenario: "cache_then_refresh_success")

        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:12.0", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:idle", timeout: 5))
        XCTAssertTrue(app.staticTexts["UITest_Loading_MainContent"].exists)
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testUserActionDuringRefresh_IsStillInteractive() {
        launchApp(
            scenario: "cache_then_refresh_success",
            refreshDelayMs: "2500"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:idle", timeout: 6))
        tapManualRefreshAndAssertNonBlocking()
        let actionButton = app.buttons["UITest_Loading_UserActionButton"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 2))
        actionButton.tap()

        XCTAssertTrue(waitLabelContains("UITest_Loading_ActionTapCount", "action_tap_count:1", timeout: 2))
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testManualRefresh_AfterInitialSuccess_UpdatesDistanceAgain() {
        launchApp(
            scenario: "cache_then_refresh_success",
            manualRefreshDistance: "18.5",
            refreshDelayMs: "1500"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:12.0", timeout: 5))
        tapManualRefreshAndAssertNonBlocking()
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshTick", "refresh_tick:2", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:18.5", timeout: 5))
    }

    func testBackgroundRefreshFailure_KeepsCachedValue_AndShowsNonBlockingBanner() {
        launchApp(scenario: "cache_then_refresh_failure")

        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:5.0", timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:failed_non_blocking", timeout: 5))
        XCTAssertTrue(app.staticTexts["UITest_Loading_NonBlockingBanner"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testFailureScenario_ManualRefreshCanRecoverToFreshData() {
        launchApp(
            scenario: "cache_then_refresh_failure",
            manualOutcome: "success",
            manualRefreshDistance: "19.0"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:failed_non_blocking", timeout: 5))
        tapManualRefreshAndAssertNonBlocking()
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshTick", "refresh_tick:2", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:19.0", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:idle", timeout: 5))
    }

    func testNoCacheSuccess_StillAllowsInteractionWhileLoading() {
        launchApp(
            scenario: "no_cache_success",
            refreshDelayMs: "5000"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_CacheStatus", "cache_status:cache_miss", timeout: 2))

        let actionButton = app.buttons["UITest_Loading_UserActionButton"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 2))
        actionButton.tap()
        XCTAssertTrue(waitLabelContains("UITest_Loading_ActionTapCount", "action_tap_count:1", timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:12.0", timeout: 5))
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testNoCacheFailure_ShowsFailureButMainContentStillVisible() {
        launchApp(scenario: "no_cache_failure")

        XCTAssertTrue(waitLabelContains("UITest_Loading_CacheStatus", "cache_status:cache_miss", timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:failed_non_blocking", timeout: 5))
        XCTAssertTrue(app.staticTexts["UITest_Loading_MainContent"].exists)
        XCTAssertTrue(app.staticTexts["UITest_Loading_NonBlockingBanner"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }

    func testRefreshTick_IncrementsAcrossInitialAndManualRefresh() {
        launchApp(
            scenario: "cache_then_refresh_success",
            refreshDelayMs: "2500"
        )

        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshTick", "refresh_tick:1", timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_Distance", "distance_km:12.0", timeout: 5))
        tapManualRefreshAndAssertNonBlocking()
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshTick", "refresh_tick:2", timeout: 5))
    }

    func testManualRefreshButton_DisabledOnlyDuringRefreshAndReenabledAfter() {
        launchApp(
            scenario: "cache_then_refresh_success",
            refreshDelayMs: "5000"
        )

        let manualButton = app.buttons["UITest_Loading_ManualRefreshButton"]
        XCTAssertTrue(manualButton.waitForExistence(timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:idle", timeout: 5))
        XCTAssertTrue(manualButton.isEnabled, "Manual refresh should be enabled after refresh settles")

        manualButton.tap()
        XCTAssertTrue(waitButtonEnabled("UITest_Loading_ManualRefreshButton", expected: false, timeout: 2))
        XCTAssertTrue(waitLabelContains("UITest_Loading_RefreshStatus", "refresh_status:idle", timeout: 5))
        XCTAssertTrue(waitButtonEnabled("UITest_Loading_ManualRefreshButton", expected: true, timeout: 2))
    }

    private func launchApp(
        scenario: String,
        manualOutcome: String = "success",
        manualRefreshDistance: String = "18.0",
        refreshDelayMs: String = "1200"
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_loading_cache"
        ]
        app.launchEnvironment["UITEST_LOADING_SCENARIO"] = scenario
        app.launchEnvironment["UITEST_LOADING_MANUAL_OUTCOME"] = manualOutcome
        app.launchEnvironment["UITEST_LOADING_MANUAL_REFRESH_DISTANCE"] = manualRefreshDistance
        app.launchEnvironment["UITEST_LOADING_REFRESH_DELAY_MS"] = refreshDelayMs
        app.launch()

        XCTAssertTrue(
            app.staticTexts["UITest_Loading_HostTitle"].waitForExistence(timeout: 8),
            "Loading/cache UI test host should be visible"
        )
    }

    @discardableResult
    private func waitLabelContains(_ id: String, _ expectedSubstring: String, timeout: TimeInterval) -> Bool {
        let element = app.staticTexts[id]
        guard element.waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate(format: "label CONTAINS %@", expectedSubstring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    private func waitButtonEnabled(_ id: String, expected: Bool, timeout: TimeInterval) -> Bool {
        let button = app.buttons[id]
        guard button.waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: expected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapManualRefreshAndAssertNonBlocking() {
        let manualButton = app.buttons["UITest_Loading_ManualRefreshButton"]
        XCTAssertTrue(manualButton.waitForExistence(timeout: 2))
        XCTAssertTrue(manualButton.isEnabled)
        manualButton.tap()

        XCTAssertFalse(app.otherElements["UITest_Loading_BlockingOverlay"].exists)
    }
}
