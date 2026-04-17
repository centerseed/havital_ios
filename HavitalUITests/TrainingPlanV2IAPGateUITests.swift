import XCTest

@MainActor
final class TrainingPlanV2IAPGateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testGenerateWeeklyPlan_WhenSubscriptionRequired_ShowsPaywall() {
        launchApp(
            generatePlanError: "subscription_required",
            generateSummaryError: "none",
            updateOverviewError: "none"
        )

        tapActionButtonAndAssertPaywall(actionButtonId: "UITest_TPV2_GeneratePlanButton")
    }

    func testGenerateWeeklySummary_WhenSubscriptionRequired_ShowsPaywall() {
        launchApp(
            generatePlanError: "none",
            generateSummaryError: "subscription_required",
            updateOverviewError: "none"
        )

        tapActionButtonAndAssertPaywall(actionButtonId: "UITest_TPV2_GenerateSummaryButton")
    }

    func testRegenerateOverview_WhenSubscriptionRequired_ShowsPaywall() {
        launchApp(
            generatePlanError: "none",
            generateSummaryError: "none",
            updateOverviewError: "subscription_required"
        )

        tapActionButtonAndAssertPaywall(actionButtonId: "UITest_TPV2_RegenerateOverviewButton")
    }

    func testGenerateWeeklyPlan_WhenServerError_DoesNotShowPaywall() {
        launchApp(
            generatePlanError: "server_error",
            generateSummaryError: "none",
            updateOverviewError: "none"
        )

        tapActionButtonAndAssertNonBlockingNoPaywall(
            actionButtonId: "UITest_TPV2_GeneratePlanButton",
            doneActionToken: "done_generate_plan",
            reason: "server error"
        )
    }

    func testGenerateWeeklyPlan_WhenDataCorruption_DoesNotShowPaywallOrBlock() {
        launchApp(
            generatePlanError: "data_corruption",
            generateSummaryError: "none",
            updateOverviewError: "none"
        )

        tapActionButtonAndAssertNonBlockingNoPaywall(
            actionButtonId: "UITest_TPV2_GeneratePlanButton",
            doneActionToken: "done_generate_plan",
            reason: "decode/data corruption"
        )
    }

    func testGenerateWeeklySummary_WhenDataCorruption_DoesNotShowPaywallOrBlock() {
        launchApp(
            generatePlanError: "none",
            generateSummaryError: "data_corruption",
            updateOverviewError: "none"
        )

        tapActionButtonAndAssertNonBlockingNoPaywall(
            actionButtonId: "UITest_TPV2_GenerateSummaryButton",
            doneActionToken: "done_generate_summary",
            reason: "decode/data corruption"
        )
    }

    func testRegenerateOverview_WhenDataCorruption_DoesNotShowPaywallOrBlock() {
        launchApp(
            generatePlanError: "none",
            generateSummaryError: "none",
            updateOverviewError: "data_corruption"
        )

        tapActionButtonAndAssertNonBlockingNoPaywall(
            actionButtonId: "UITest_TPV2_RegenerateOverviewButton",
            doneActionToken: "done_regenerate_overview",
            reason: "decode/data corruption"
        )
    }

    private func launchApp(
        generatePlanError: String,
        generateSummaryError: String,
        updateOverviewError: String
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_training_v2_gates"
        ]
        app.launchEnvironment["UITEST_TPV2_GENERATE_PLAN_ERROR"] = generatePlanError
        app.launchEnvironment["UITEST_TPV2_GENERATE_SUMMARY_ERROR"] = generateSummaryError
        app.launchEnvironment["UITEST_TPV2_UPDATE_OVERVIEW_ERROR"] = updateOverviewError
        app.launch()

        let hostTitle = app.staticTexts["UITest_TPV2_HostTitle"]
        XCTAssertTrue(hostTitle.waitForExistence(timeout: 10), "TrainingPlanV2 gate host should be visible")
    }

    private func tapActionButtonAndAssertPaywall(actionButtonId: String) {
        let button = app.buttons[actionButtonId]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Action button \(actionButtonId) should exist")
        button.tap()

        let paywallCloseButton = app.buttons["Paywall_CloseButton"]
        XCTAssertTrue(paywallCloseButton.waitForExistence(timeout: 10), "Paywall should appear after subscription-gated action")
    }

    private func tapActionButtonAndAssertNonBlockingNoPaywall(
        actionButtonId: String,
        doneActionToken: String,
        reason: String
    ) {
        let button = app.buttons[actionButtonId]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Action button \(actionButtonId) should exist")
        button.tap()

        let lastActionLabel = app.staticTexts["UITest_TPV2_LastActionLabel"]
        XCTAssertTrue(lastActionLabel.waitForExistence(timeout: 8), "Last action label should exist")
        let donePredicate = NSPredicate(format: "label CONTAINS %@", doneActionToken)
        let doneExpectation = XCTNSPredicateExpectation(predicate: donePredicate, object: lastActionLabel)
        XCTAssertEqual(
            XCTWaiter().wait(for: [doneExpectation], timeout: 10),
            .completed,
            "Action should complete for \(reason) path without blocking"
        )

        let paywallCloseButton = app.buttons["Paywall_CloseButton"]
        XCTAssertFalse(paywallCloseButton.waitForExistence(timeout: 2), "\(reason) path should not open paywall")
    }
}
