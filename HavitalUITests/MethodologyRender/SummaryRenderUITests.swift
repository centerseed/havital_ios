import XCTest

final class SummaryRenderUITests: MethodologyRenderUITestBase {
    @MainActor
    func testFullSummaryFixtureRendersExpectedElements() throws {
        try assertSummaryFixture("full_summary")
    }

    @MainActor
    func testMinimalSummaryFixtureRendersExpectedElements() throws {
        try assertSummaryFixture("minimal_summary")
    }

    @MainActor
    func testFullSummaryFixtureExpandsNextWeekAdjustmentCard() throws {
        let fixtureURL = fixtureURL(category: "WeeklySummary", name: "full_summary")
        launchApp(
            summaryFixture: "full_summary",
            screen: "summary"
        )
        assertExpectedElements(try UIAssertionGuide.expectedSummaryElements(from: fixtureURL))

        let toggle = uiElement(identifier: "v2.summary.next_week_toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        toggle.tap()

        let firstAdjustment = uiElement(identifier: "v2.summary.adjustment_item_0")
        XCTAssertTrue(firstAdjustment.waitForExistence(timeout: 8))
    }
}
