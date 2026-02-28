import XCTest

final class OnboardingScreenshotTests: XCTestCase {
    var app: XCUIApplication!
    var stepIndex = 0

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        stepIndex = 0
    }

    func screenshot(_ label: String) {
        stepIndex += 1
        let path = "/tmp/havital_step\(String(format: "%02d", stepIndex))_\(label).png"
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        print("📸 [\(stepIndex)] \(label)")
    }

    // 用文字找按鈕，不需要 accessibilityIdentifier
    func tapButton(containing text: String, timeout: TimeInterval = 5) -> Bool {
        let btn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
        guard btn.waitForExistence(timeout: timeout) else { return false }
        btn.tap()
        return true
    }

    func tapText(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let el = app.staticTexts[text]
        guard el.waitForExistence(timeout: timeout) else { return false }
        el.tap()
        return true
    }

    func testOnboarding_ViaResetGoal() {

        screenshot("launch")

        // 通知 alert
        _ = tapButton(containing: "允許") || tapButton(containing: "Allow")
        screenshot("after_alert")

        // Demo 登入
        if app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Demo'")).firstMatch.waitForExistence(timeout: 5) {
            tapButton(containing: "Demo")
            sleep(5)
        }
        screenshot("after_login")

        // 等主畫面
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
        screenshot("main_screen")

        // 關掉可能的 modal（設定心率等）
        _ = tapButton(containing: "不再提醒") || tapButton(containing: "明天再提醒") || tapButton(containing: "Never")
        sleep(1)
        screenshot("after_dismiss")

        // 右上角 ⊕ menu — 用 navigationBar 的最後一個按鈕
        let navButtons = app.navigationBars.buttons.allElementsBoundByIndex
        print("📋 NavBar buttons (\(navButtons.count)):")
        for (i, b) in navButtons.enumerated() {
            print("   [\(i)] label='\(b.label)' id='\(b.identifier)' enabled=\(b.isEnabled)")
        }
        if let menuBtn = navButtons.last, menuBtn.isHittable {
            menuBtn.tap()
            sleep(1)
            screenshot("menu_open")
        } else {
            // 嘗試用 images 找 ellipsis.circle
            let ellipsis = app.images["ellipsis.circle"]
            if ellipsis.waitForExistence(timeout: 5) {
                ellipsis.tap()
                sleep(1)
                screenshot("menu_open_via_image")
            }
        }

        // 列出所有按鈕（debug）
        let allBtns = app.buttons.allElementsBoundByIndex
        print("📋 All buttons (\(allBtns.count)):")
        for b in allBtns.prefix(20) {
            print("   label='\(b.label)' id='\(b.identifier)'")
        }

        // 點 Profile
        _ = tapButton(containing: "Profile") || tapButton(containing: "個人")
        sleep(1)
        screenshot("profile_sheet")

        // 點「重設目標」
        _ = tapButton(containing: "Reset") || tapButton(containing: "重設") || tapButton(containing: "重新")
        sleep(1)
        screenshot("reset_confirmation")

        // 確認對話框
        let alertBtns = app.alerts.buttons.allElementsBoundByIndex
        print("📋 Alert buttons: \(alertBtns.map { $0.label })")
        if let confirm = alertBtns.last {
            confirm.tap()
            sleep(2)
            screenshot("after_confirm")
        }

        // Onboarding 應該開始了
        screenshot("onboarding_start")

        // 列出現在畫面上所有可見文字（debug）
        let texts = app.staticTexts.allElementsBoundByIndex
        print("📋 Visible texts (\(texts.count)):")
        for t in texts.prefix(20) {
            print("   '\(t.label)'")
        }
    }
}
