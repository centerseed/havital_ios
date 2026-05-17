import XCTest

final class AchievementsUITests: XCTestCase {
    func testPersonalAchievementsHomeShowsP0SectionsAndRealBadgeNames() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing_achievements"]
        app.launch()

        XCTAssertTrue(element(in: app, id: "Achievements_OverviewCard").waitForExistence(timeout: 8))
        XCTAssertTrue(element(in: app, id: "Achievements_PBCard").exists)
        XCTAssertTrue(element(in: app, id: "Achievements_LifetimeStatsCard").exists)

        XCTAssertTrue(app.staticTexts["個人最佳"].exists)
        XCTAssertTrue(app.staticTexts["累積紀錄"].exists)

        app.swipeUp()

        XCTAssertTrue(element(in: app, id: "Achievements_BadgeLibraryEntry").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["徽章收藏"].exists)
        XCTAssertTrue(app.staticTexts["第一筆跑步"].exists)
        XCTAssertTrue(app.staticTexts["長跑完成"].exists)

        XCTAssertFalse(app.staticTexts["訓練記憶"].exists)
        XCTAssertFalse(app.staticTexts["最近成果"].exists)

        app.staticTexts["徽章收藏"].tap()
        XCTAssertTrue(app.staticTexts["開始起跑"].waitForExistence(timeout: 4))

        app.staticTexts["第一筆跑步"].tap()
        XCTAssertTrue(app.staticTexts["成就詳情"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["故事"].exists)
        XCTAssertTrue(app.staticTexts["解鎖於 2026-04-12"].exists)

        app.buttons["分享"].tap()
        XCTAssertTrue(app.staticTexts["分享預覽"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["會公開的欄位"].exists)
        XCTAssertTrue(app.staticTexts["路線、GPS、心率、睡眠、傷痛、workout ID、email、uid 與完整課表細節都不會包含。"].exists)
    }

    private func element(in app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }
}
