import XCTest

class MethodologyRenderUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += [
            "-ui_testing_methodology_fixture",
            "-AppleLanguages", "(zh-Hant)",
            "-AppleLocale", "zh_TW",
        ]
    }

    func launchApp(
        overviewFixture: String? = nil,
        weeklyFixture: String? = nil,
        summaryFixture: String? = nil,
        screen: String? = nil,
        overviewTab: Int? = nil
    ) {
        if let overviewFixture {
            app.launchEnvironment["UITEST_METHODOLOGY_OVERVIEW_FIXTURE_PATH"] = fixtureURL(
                category: "PlanOverview",
                name: overviewFixture
            ).path
        }

        if let weeklyFixture {
            app.launchEnvironment["UITEST_METHODOLOGY_WEEKLY_FIXTURE_PATH"] = fixtureURL(
                category: "WeeklyPlan",
                name: weeklyFixture
            ).path
        }

        if let summaryFixture {
            app.launchEnvironment["UITEST_METHODOLOGY_SUMMARY_FIXTURE_PATH"] = fixtureURL(
                category: "WeeklySummary",
                name: summaryFixture
            ).path
        }

        if let screen {
            app.launchEnvironment["UITEST_METHODOLOGY_SCREEN"] = screen
        }

        if let overviewTab {
            app.launchEnvironment["UITEST_METHODOLOGY_OVERVIEW_TAB"] = String(overviewTab)
        }

        app.launch()
    }

    func assertExpectedElements(_ elements: [UIAssertionGuide.ExpectedElement], timeout: TimeInterval = 8) {
        for expected in elements {
            let element: XCUIElement
            if let identifier = expected.identifier {
                element = uiElement(identifier: identifier)
            } else if let visibleText = expected.visibleText {
                element = app.staticTexts[visibleText].firstMatch
            } else {
                XCTFail("ExpectedElement must declare an identifier or visibleText")
                continue
            }

            XCTAssertTrue(
                element.waitForExistence(timeout: timeout),
                "Expected element not found: identifier=\(expected.identifier ?? "nil") visibleText=\(expected.visibleText ?? "nil")"
            )

            if let expectedText = expected.mustContainText {
                let rendered = [element.label, element.value as? String]
                    .compactMap { $0 }
                    .joined(separator: " ")
                XCTAssertTrue(
                    rendered.contains(expectedText),
                    "Expected \(expected.identifier ?? expected.visibleText ?? "element") to contain '\(expectedText)', got '\(rendered)'"
                )
            }
        }
    }

    func assertOverviewFixture(_ fixtureName: String, tab: UIAssertionGuide.OverviewTab = .trainingPlan) throws {
        let fixtureURL = fixtureURL(category: "PlanOverview", name: fixtureName)
        launchApp(
            overviewFixture: fixtureName,
            screen: "overview",
            overviewTab: tab.rawValue
        )
        assertExpectedElements(try UIAssertionGuide.expectedOverviewElements(from: fixtureURL, tab: tab))
    }

    func assertWeeklyFixture(
        _ fixtureName: String,
        methodologyId: String,
        phaseId: String
    ) throws {
        let fixtureURL = fixtureURL(category: "WeeklyPlan", name: fixtureName)
        launchApp(
            weeklyFixture: fixtureName,
            screen: "weekly"
        )
        assertExpectedElements(
            try UIAssertionGuide.expectedVisibleElements(
                methodologyId: methodologyId,
                phaseId: phaseId,
                fromWeeklyFixture: fixtureURL
            )
        )
    }

    func assertSummaryFixture(_ fixtureName: String) throws {
        let fixtureURL = fixtureURL(category: "WeeklySummary", name: fixtureName)
        launchApp(
            summaryFixture: fixtureName,
            screen: "summary"
        )
        assertExpectedElements(try UIAssertionGuide.expectedSummaryElements(from: fixtureURL))
    }

    func uiElement(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    override func record(_ issue: XCTIssue) {
        if let app {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "MethodologyRenderFailure"
            attachment.lifetime = .keepAlways
            add(attachment)

            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "MethodologyRenderTree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        super.record(issue)
    }

    func fixtureURL(category: String, name: String) -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        return testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HavitalTests/TrainingPlan/Unit/APISchema/Fixtures/\(category)/\(name).json")
    }
}
