import XCTest

@MainActor
final class WorkoutDetailRPEUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testNoRPE_CanAddRPE_AndRepositoryReceivesPayload() {
        launchApp(initialRPE: nil)

        let rpeButton = app.buttons["workout_detail_rpe_button"]
        XCTAssertTrue(rpeButton.waitForExistence(timeout: 8))
        rpeButton.tap()

        let saveButton = app.buttons["rpe_editor_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(waitLabelContains("UITest_RPE_CurrentValue", "current_rpe:5", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_RPE_LastUpdate", "last_update_rpe:5", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_RPE_UpdateCallCount", "update_call_count:1", timeout: 5))
    }

    func testExistingRPE_CanOpenEditorAndClear_AndRepositoryReceivesNilPayload() {
        launchApp(initialRPE: 6)

        XCTAssertTrue(waitLabelContains("UITest_RPE_CurrentValue", "current_rpe:6", timeout: 8))
        let rpeButton = app.buttons["workout_detail_rpe_button"]
        XCTAssertTrue(rpeButton.waitForExistence(timeout: 8))
        rpeButton.tap()

        let clearButton = app.buttons["rpe_editor_clear_button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.tap()

        XCTAssertTrue(waitLabelContains("UITest_RPE_CurrentValue", "current_rpe:nil", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_RPE_LastUpdate", "last_update_rpe:nil", timeout: 5))
        XCTAssertTrue(waitLabelContains("UITest_RPE_UpdateCallCount", "update_call_count:1", timeout: 5))
    }

    private func launchApp(initialRPE: Int?) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui_testing",
            "-ui_testing_workout_detail_rpe"
        ]
        app.launchEnvironment["UITEST_RPE_INITIAL"] = initialRPE.map(String.init) ?? "none"
        app.launch()

        XCTAssertTrue(
            app.staticTexts["UITest_RPE_HostTitle"].waitForExistence(timeout: 8),
            "Workout detail RPE UI test host should be visible"
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
}
