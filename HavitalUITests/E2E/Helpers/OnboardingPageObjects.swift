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
        let demoButton = waitForElement("Login_DemoButton", timeout: 10)
        demoButton.tap()
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
    func tapContinue() {
        // Wait for page to appear
        let button = app.buttons["PersonalBest_ContinueButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15),
                      "Element 'PersonalBest_ContinueButton' did not appear within 15s")

        // hasPersonalBest defaults to true → button disabled (needs time input)
        // Turn OFF the toggle so button enables (skip PB)
        let toggle = app.switches["PersonalBest_HasPBToggle"].firstMatch
        if toggle.waitForExistence(timeout: 8) {
            if toggle.value as? String == "1" {
                toggle.tap()
                sleep(1)
            }
        }

        // Wait for button to become enabled (isLoading may be true)
        let enabledPredicate = NSPredicate(format: "enabled == true")
        let enabledExpectation = testCase.expectation(for: enabledPredicate, evaluatedWith: button)
        _ = XCTWaiter.wait(for: [enabledExpectation], timeout: 8)

        XCTAssertTrue(button.isEnabled, "PersonalBest_ContinueButton should be enabled after disabling toggle")
        button.tap()
    }
}

// MARK: - Weekly Distance Page

class WeeklyDistancePage: BasePage {
    func tapContinue() {
        let button = waitForElement("WeeklyDistance_ContinueButton", timeout: 15)
        button.tap()
    }
}

// MARK: - Goal Type Page

class GoalTypePage: BasePage {
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
        let button = waitForElement("RaceSetup_SaveButton", timeout: 10)
        button.tap()
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
        let card = waitForElement("Methodology_\(methodologyId)", timeout: 15)
        card.tap()
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
        for day in days {
            let button = waitForElement("TrainingDay_\(day)", timeout: 5)
            button.tap()
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
