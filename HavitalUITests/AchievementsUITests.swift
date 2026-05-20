import XCTest

final class AchievementsUITests: XCTestCase {
    func testPersonalAchievementsHomeShowsP0SectionsAndRealBadgeNames() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing_achievements"]
        app.launch()

        XCTAssertTrue(element(in: app, id: "Achievements_TrackRoutes").waitForExistence(timeout: 8))
        let rhythmCard = element(in: app, id: "Achievements_TrackCard_rhythm")
        let planCard = element(in: app, id: "Achievements_TrackCard_plan")
        let resultsCard = element(in: app, id: "Achievements_TrackCard_results")
        XCTAssertTrue(rhythmCard.exists)
        XCTAssertEqual(rhythmCard.label, "訓練節奏")
        XCTAssertTrue(planCard.exists)
        XCTAssertEqual(planCard.label, "課表執行")
        XCTAssertTrue(resultsCard.exists)
        XCTAssertEqual(resultsCard.label, "成果突破")
        XCTAssertTrue(element(in: app, id: "Achievements_HeroCard").exists)
        XCTAssertTrue(element(in: app, id: "Achievements_PBCard").exists)

        XCTAssertTrue(app.staticTexts["個人最佳"].exists)

        app.swipeUp()

        XCTAssertTrue(element(in: app, id: "Achievements_BadgeLibraryEntry").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["徽章收藏"].exists)
        XCTAssertTrue(app.staticTexts["回到節奏"].exists)
        XCTAssertTrue(app.staticTexts["完成了 1 週課表"].exists)
        XCTAssertTrue(app.staticTexts["第一個重要成果"].exists)

        XCTAssertFalse(app.staticTexts["第一筆跑步"].exists)
        XCTAssertFalse(app.staticTexts["長跑完成"].exists)

        app.staticTexts["徽章收藏"].tap()
        XCTAssertTrue(app.staticTexts["訓練節奏"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["課表執行"].exists)
        XCTAssertTrue(app.staticTexts["成果突破"].exists)

        app.staticTexts["回到節奏"].tap()
        XCTAssertTrue(app.staticTexts["成就詳情"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["故事"].exists)
        XCTAssertTrue(app.staticTexts["進度"].exists)
    }

    private func element(in app: XCUIApplication, id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }
}
