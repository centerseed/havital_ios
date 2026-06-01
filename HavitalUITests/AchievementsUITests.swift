import XCTest

final class AchievementsUITests: XCTestCase {
    func testPersonalAchievementsHomeShowsP0SectionsAndRealBadgeNames() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing_achievements"]
        app.launch()

        XCTAssertTrue(app.staticTexts["個人最佳"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["第一個重要成果"].exists)
        XCTAssertFalse(app.staticTexts["achievements.badge.start.first_week.name"].exists)
        XCTAssertFalse(app.staticTexts["achievements.badge.start.plan_started.name"].exists)

        app.swipeUp()

        XCTAssertTrue(element(in: app, id: "Achievements_ChapterCard_start").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["徽章收藏"].exists)
        XCTAssertTrue(app.staticTexts["開始起跑"].exists)
        XCTAssertTrue(app.staticTexts["一季跑者"].exists)
        XCTAssertTrue(app.staticTexts["第一個重要成果"].exists)
        XCTAssertFalse(app.staticTexts["achievements.badge.start.first_week.name"].exists)
        XCTAssertFalse(app.staticTexts["achievements.badge.start.plan_started.name"].exists)

        XCTAssertFalse(app.staticTexts["長跑完成"].exists)

        app.staticTexts["一季跑者"].tap()
        XCTAssertTrue(app.staticTexts["成就詳情"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["故事"].exists)
    }

    private func element(in app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }
}
