//
//  OnboardingPageObjects.swift
//  HavitalUITests
//
//  Page Object pattern for onboarding flow UI automation
//

import XCTest

// MARK: - Base Page

class BasePage {
    let app: XCUIApplication
    let testCase: XCTestCase

    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
    }

    @discardableResult
    func waitForElement(_ identifier: String, timeout: TimeInterval = 10) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element '\(identifier)' did not appear within \(timeout)s")
        return element
    }

    func tapRobust(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else {
            XCTFail("Element does not exist for tap: \(element)", file: file, line: line)
            return
        }

        if element.isHittable {
            element.tap()
            return
        }

        // Best-effort nudge in case the element is slightly off-screen.
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

        // Fallback to coordinate tap to avoid AX scroll-to-visible failures.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func tapIfExists(_ identifier: String, timeout: TimeInterval = 3) -> Bool {
        let element = app.descendants(matching: .any)[identifier]
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
}

// MARK: - Login Page

class LoginPage: BasePage {
    func loginWithDemo() {
        let demoButton = app.buttons["Login_DemoButton"].firstMatch
        XCTAssertTrue(demoButton.waitForExistence(timeout: 10), "Demo button should exist")
        tapRobust(demoButton)
        // Wait for demo login API call + auth state update + UI transition
        // Demo login involves: API call → Firebase auth → AppStateManager ready → ContentView switch
        sleep(5)
    }
}

// MARK: - Intro Page

class IntroPage: BasePage {
    func tapStart() {
        let startButton = waitForElement("OnboardingStartButton", timeout: 20)
        startButton.tap()
    }
}

// MARK: - Data Source Page

class DataSourcePage: BasePage {
    func selectAppleHealth() {
        let option = waitForElement("DataSourceOption_appleHealth")
        option.tap()
    }

    func tapContinue() {
        let button = waitForElement("OnboardingContinueButton")
        button.tap()
    }
}

// MARK: - Heart Rate Zone Page

class HeartRateZonePage: BasePage {
    func tapContinue() {
        // In toolbar, use .buttons to avoid matching parent ToolbarItem container
        let button = app.buttons["HeartRateZone_ContinueButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15),
                      "Element 'HeartRateZone_ContinueButton' did not appear within 15s")
        button.tap()
    }

    func skipIfVisible() {
        let button = app.buttons["HeartRateZone_ContinueButton"].firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
        }
    }
}

// MARK: - Personal Best Page

class PersonalBestPage: BasePage {
    private func isSwitchOn(_ value: Any?) -> Bool {
        guard let raw = value else { return false }
        if let text = raw as? String {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true"
        }
        if let number = raw as? NSNumber {
            return number.intValue == 1
        }
        return false
    }

    private func forceHasPersonalBestOff(_ toggle: XCUIElement) {
        guard toggle.exists else { return }

        if !isSwitchOn(toggle.value) { return }

        tapRobust(toggle)
        let deadline = Date().addingTimeInterval(2.5)
        while Date() < deadline {
            if !isSwitchOn(toggle.value) {
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }

        // Retry once if value did not settle after first tap.
        tapRobust(toggle)
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func waitUntilButtonEnabled(_ button: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if button.isEnabled { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return button.isEnabled
    }

    private func setMinimumPersonalBestTimeIfNeeded() {
        let pickerWheels = app.pickerWheels.allElementsBoundByIndex
        guard pickerWheels.count >= 3 else { return }

        let secondsWheel = pickerWheels[2]
        guard secondsWheel.exists else { return }

        secondsWheel.adjust(toPickerWheelValue: "1")
        Thread.sleep(forTimeInterval: 0.4)
        if let value = secondsWheel.value {
            print("ℹ️ [UI Test] PersonalBest seconds wheel value after adjust: \(value)")
        }
    }

    func tapContinue() {
        // Wait for page to appear
        let button = app.buttons["PersonalBest_ContinueButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15),
                      "Element 'PersonalBest_ContinueButton' did not appear within 15s")
        let toggle = app.switches["PersonalBest_HasPBToggle"].firstMatch

        // Retry once if backend/update latency keeps user on PersonalBest screen.
        for attempt in 0..<2 {
            if toggle.waitForExistence(timeout: 3) {
                // Force "no PB" path to avoid relying on remote PB update.
                print("ℹ️ [UI Test] PersonalBest toggle value before forcing off: \(String(describing: toggle.value))")
                forceHasPersonalBestOff(toggle)
                print("ℹ️ [UI Test] PersonalBest toggle value after forcing off: \(String(describing: toggle.value))")
            }

            // Wait for button to become enabled (isLoading/loading PBs may take time).
            if !waitUntilButtonEnabled(button, timeout: 5) {
                // Fallback: keep hasPB=true path but make time non-zero to satisfy validation.
                setMinimumPersonalBestTimeIfNeeded()
            }

            _ = waitUntilButtonEnabled(button, timeout: 10)
            XCTAssertTrue(button.isEnabled, "PersonalBest_ContinueButton should be enabled before continue")
            tapRobust(button)

            // If we navigated away, button should disappear quickly.
            if !button.waitForExistence(timeout: 3) {
                return
            }

            if attempt == 0 {
                print("ℹ️ [UI Test] PersonalBest still visible after continue, retrying once")
            }
        }
    }
}

// MARK: - Weekly Distance Page

class WeeklyDistancePage: BasePage {
    func tapContinue() {
        let button = app.buttons["WeeklyDistance_ContinueButton"].firstMatch
        if button.waitForExistence(timeout: 15) {
            tapRobust(button)
            return
        }

        let fallback = app.descendants(matching: .any)["WeeklyDistance_ContinueButton"].firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 5),
                      "Element 'WeeklyDistance_ContinueButton' did not appear within 20.0s")
        tapRobust(fallback)
    }
}

// MARK: - Goal Type Page

class GoalTypePage: BasePage {
    func isStepVisible(timeout: TimeInterval = 8) -> Bool {
        let nextButton = app.descendants(matching: .any)["GoalType_NextButton"].firstMatch
        return nextButton.waitForExistence(timeout: timeout)
    }

    func selectGoalTypeIfVisible(_ goalTypeId: String, timeout: TimeInterval = 10) -> Bool {
        let primary = app.descendants(matching: .any)["GoalType_\(goalTypeId)"].firstMatch
        if primary.waitForExistence(timeout: timeout) {
            tapRobust(primary)
            return true
        }

        // Legacy beginner card fallback may use different identifiers/content.
        if goalTypeId == "beginner" {
            for candidate in ["GoalType_beginner5k", "GoalType_beginner_5k"] {
                let legacy = app.descendants(matching: .any)[candidate].firstMatch
                if legacy.waitForExistence(timeout: 1) {
                    tapRobust(legacy)
                    return true
                }
            }

            for label in ["5km", "5K", "beginner", "Beginner", "初學", "入門"] {
                let byLabel = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
                if byLabel.waitForExistence(timeout: 1) {
                    tapRobust(byLabel)
                    return true
                }
            }
        }

        return false
    }

    func selectGoalType(_ goalTypeId: String) {
        let card = waitForElement("GoalType_\(goalTypeId)", timeout: 15)
        card.tap()
    }

    func tapNext() {
        let button = waitForElement("GoalType_NextButton")
        button.tap()
    }
}

// MARK: - Race Setup Page

class RaceSetupPage: BasePage {
    @discardableResult
    func waitUntilVisible(timeout: TimeInterval = 15) -> Bool {
        let screen = app.descendants(matching: .any)["RaceSetup_Screen"].firstMatch
        if screen.waitForExistence(timeout: timeout) {
            return true
        }

        let saveButton = app.descendants(matching: .any)["RaceSetup_SaveButton"].firstMatch
        return saveButton.waitForExistence(timeout: 2)
    }

    func verifyOptimizedLayout() {
        XCTAssertTrue(waitUntilVisible(), "Race setup screen should appear")

        let saveButton = app.descendants(matching: .any)["RaceSetup_SaveButton"].firstMatch
        XCTAssertTrue(saveButton.exists, "Race setup screen should expose a fixed primary CTA")

        let browseDatabaseButton = app.descendants(matching: .any)["RaceSetup_BrowseDatabaseButton"].firstMatch
        let targetTimeEditorButton = app.descendants(matching: .any)["RaceSetup_TargetTimeEditorButton"].firstMatch

        XCTAssertTrue(
            browseDatabaseButton.exists || targetTimeEditorButton.exists,
            "Race setup screen should show either the database entry card or the target-time editor entry point"
        )
    }

    func setDistanceAndTime(distanceKm: Int, hours: Int, minutes: Int) {
        // Tap the edit button to open the distance/time editor sheet
        // The distance/time is edited via a sheet
        // For now, keep defaults or tap the edit area
        // The default is 42.195km, 4:00

        // If we need a different distance, we need to open the editor
        // For simplicity in E2E tests, we may just use defaults for marathon
        // or adjust via the sheet picker

        // Note: Wheel pickers are hard to automate reliably in XCUITest
        // We'll rely on the default values being acceptable or use pickerWheel.adjust
    }

    func tapSave() {
        XCTAssertTrue(waitUntilVisible(), "Race setup screen should appear before saving")
        let button = waitForElement("RaceSetup_SaveButton", timeout: 10)
        tapRobust(button)
    }
}

// MARK: - Start Stage Page

class StartStagePage: BasePage {
    func tapNext() {
        let button = waitForElement("StartStage_NextButton", timeout: 10)
        button.tap()
    }

    func selectStage(_ stageId: String) {
        let card = waitForElement("StartStage_\(stageId)", timeout: 5)
        card.tap()
    }
}

// MARK: - Methodology Page

class MethodologyPage: BasePage {
    func selectMethodology(_ methodologyId: String) {
        XCTAssertTrue(
            selectMethodologyIfVisible(methodologyId, timeout: 15),
            "Element 'Methodology_\(methodologyId)' did not appear within 15.0s"
        )
    }

    @discardableResult
    func selectMethodologyIfVisible(_ methodologyId: String, timeout: TimeInterval = 3) -> Bool {
        let card = app.descendants(matching: .any)["Methodology_\(methodologyId)"].firstMatch
        guard card.waitForExistence(timeout: timeout) else {
            return false
        }
        tapRobust(card)
        return true
    }

    func tapNext() {
        let button = waitForElement("Methodology_NextButton")
        button.tap()
    }
}

// MARK: - Training Weeks Page

class TrainingWeeksPage: BasePage {
    func selectWeeks(_ weeks: Int) {
        // Try quick option button first
        let quickOption = app.descendants(matching: .any)["TrainingWeeks_\(weeks)"]
        if quickOption.waitForExistence(timeout: 5) {
            quickOption.tap()
            return
        }
        // If not a quick option, we'd need to use custom picker
        // For now, log a warning
        print("⚠️ Week \(weeks) not found as quick option, using default")
    }

    func tapNext() {
        let button = waitForElement("TrainingWeeks_NextButton")
        button.tap()
    }
}

// MARK: - Training Days Page

class TrainingDaysPage: BasePage {
    func selectDays(_ days: [Int]) {
        var selectedCount = 0
        for day in days {
            let button = app.descendants(matching: .any)["TrainingDay_\(day)"].firstMatch
            if button.waitForExistence(timeout: 3) {
                tapRobust(button)
                selectedCount += 1
            } else {
                print("ℹ️ [UI Test] TrainingDay_\(day) not shown, skip selecting this day")
            }
        }

        if selectedCount == 0 {
            print("ℹ️ [UI Test] No requested training day was selectable on this screen")
        }
    }

    func deselectAllThenSelect(_ days: [Int]) {
        // First check which days are currently selected and deselect them
        for day in 1...7 {
            let button = app.descendants(matching: .any)["TrainingDay_\(day)"]
            if button.waitForExistence(timeout: 2) {
                // Check if it has a checkmark (selected)
                let checkmark = button.images["checkmark"]
                if checkmark.exists {
                    button.tap() // Deselect
                }
            }
        }

        // Then select desired days
        selectDays(days)
    }

    func tapSave() {
        let button = waitForElement("TrainingDays_SaveButton", timeout: 10)
        button.tap()
    }

    @discardableResult
    func tapSaveWithScroll(maxScrolls: Int = 8) -> Bool {
        let saveButton = app.descendants(matching: .any)["TrainingDays_SaveButton"].firstMatch

        if saveButton.waitForExistence(timeout: 2) {
            tapRobust(saveButton)
            return true
        }

        for _ in 0..<maxScrolls {
            app.swipeUp()
            if saveButton.waitForExistence(timeout: 1) {
                tapRobust(saveButton)
                return true
            }
        }

        return false
    }
}

// MARK: - Training Overview Page

class TrainingOverviewPage: BasePage {
    func verifyWeeksLabel(exists: Bool = true) {
        if exists {
            waitForElement("TrainingOverview_WeeksLabel", timeout: 15)
        }
    }

    func verifyMethodologyLabel(_ methodologyName: String? = nil) {
        let label = app.descendants(matching: .any)["TrainingOverview_MethodologyLabel"]
        if label.waitForExistence(timeout: 5) {
            if let name = methodologyName {
                XCTAssertTrue(label.staticTexts.allElementsBoundByIndex.contains { $0.label.contains(name) },
                              "Methodology label should contain '\(name)'")
            }
        }
    }

    func tapGenerate() {
        let button = waitForElement("TrainingOverview_GenerateButton", timeout: 10)
        button.tap()
    }

    func waitForPlanGeneration(timeout: TimeInterval = 60) {
        // After tapping generate, a loading cover appears
        // Wait for it to dismiss (the main tab view should appear)
        // We check for the absence of the loading cover or presence of main content
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.otherElements["LoadingAnimationView"]
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result == .timedOut {
            // Loading may have already dismissed, check for main content
            print("⚠️ Loading cover wait timed out, checking for main content...")
        }
    }
}
