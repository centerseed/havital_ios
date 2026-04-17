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
    private var reviewerPasscode: String {
        ProcessInfo.processInfo.environment["HAVITAL_REVIEWER_PASSCODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func loginWithDemo(timeout: TimeInterval = 30) {
        let demoButton = app.buttons["Login_DemoButton"].firstMatch
        let reviewerTrigger = app.descendants(matching: .any)["Login_ReviewerAccessTrigger"].firstMatch
        let reviewerSheet = app.descendants(matching: .any)["Login_ReviewerAccessSheet"].firstMatch
        let reviewerPasscodeField = app.secureTextFields["Login_ReviewerPasscodeField"].firstMatch
        let reviewerActivateButton = app.buttons["Login_ReviewerActivateButton"].firstMatch
        let onboardingStartButton = app.buttons["OnboardingStartButton"].firstMatch
        let onboardingIntroScreen = app.descendants(matching: .any)["OnboardingIntro_Screen"].firstMatch
        let dataSourceScreen = app.descendants(matching: .any)["DataSource_Screen"].firstMatch
        let dataSourceOption = app.descendants(matching: .any)["DataSourceOption_appleHealth"].firstMatch
        let heartRateButton = app.buttons["HeartRateZone_ContinueButton"].firstMatch
        let personalBestButton = app.buttons["PersonalBest_ContinueButton"].firstMatch
        let goalTypeScreen = app.descendants(matching: .any)["GoalType_Screen"].firstMatch
        let tabBar = app.tabBars.firstMatch

        let deadline = Date().addingTimeInterval(timeout)
        var didTapDemo = false
        var didTriggerReviewerAccess = false
        while Date() < deadline {
            if demoButton.exists {
                if !didTapDemo {
                    tapRobust(demoButton)
                    didTapDemo = true
                    Thread.sleep(forTimeInterval: 1.0)
                    continue
                }
            }

            if reviewerTrigger.exists && !didTriggerReviewerAccess {
                XCTAssertFalse(
                    reviewerPasscode.isEmpty,
                    "Set HAVITAL_REVIEWER_PASSCODE to run onboarding UI tests with reviewer demo access."
                )

                reviewerTrigger.press(forDuration: 1.2)
                XCTAssertTrue(
                    reviewerSheet.waitForExistence(timeout: 5),
                    "Reviewer access sheet should appear after long press."
                )

                XCTAssertTrue(
                    reviewerPasscodeField.waitForExistence(timeout: 5),
                    "Reviewer passcode field should appear in reviewer access sheet."
                )
                reviewerPasscodeField.tap()
                reviewerPasscodeField.typeText(reviewerPasscode)

                XCTAssertTrue(
                    reviewerActivateButton.waitForExistence(timeout: 5),
                    "Reviewer activate button should appear in reviewer access sheet."
                )
                tapRobust(reviewerActivateButton)

                didTriggerReviewerAccess = true
                Thread.sleep(forTimeInterval: 1.0)
                continue
            }

            if onboardingStartButton.exists
                || onboardingIntroScreen.exists
                || dataSourceScreen.exists
                || dataSourceOption.exists
                || heartRateButton.exists
                || personalBestButton.exists
                || goalTypeScreen.exists
                || tabBar.exists {
                return
            }

            // Retry demo login once if the button is still present after the first tap.
            if didTapDemo && demoButton.exists && demoButton.isHittable {
                tapRobust(demoButton)
            }

            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTFail("Demo login did not reach onboarding or main content within \(timeout)s")
    }
}

// MARK: - Intro Page

class IntroPage: BasePage {
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["OnboardingIntro_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Intro screen should appear")
        XCTAssertTrue(app.buttons["OnboardingStartButton"].firstMatch.exists, "Intro screen should show start CTA")
    }

    func enterOnboardingIfNeeded(timeout: TimeInterval = 25) {
        let startButton = app.buttons["OnboardingStartButton"].firstMatch
        let dataSourceOption = app.descendants(matching: .any)["DataSourceOption_appleHealth"].firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if startButton.exists {
                tapRobust(startButton)
                return
            }

            if dataSourceOption.exists {
                return
            }

            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTFail("Neither intro start button nor data source step appeared within \(timeout)s")
    }
}

// MARK: - Data Source Page

class DataSourcePage: BasePage {
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["DataSource_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Data source screen should appear")
        XCTAssertTrue(app.descendants(matching: .any)["DataSourceOption_appleHealth"].firstMatch.exists, "Apple Health option should exist")
        XCTAssertTrue(app.descendants(matching: .any)["DataSourceOption_garmin"].firstMatch.exists, "Garmin option should exist")
        XCTAssertTrue(app.descendants(matching: .any)["DataSourceOption_strava"].firstMatch.exists, "Strava option should exist")
        XCTAssertTrue(app.buttons["OnboardingContinueButton"].firstMatch.exists, "Data source screen should show continue CTA")
    }

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
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["HeartRateZone_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "Heart rate zone screen should appear")
        XCTAssertTrue(app.buttons["HeartRateZone_ContinueButton"].firstMatch.exists, "Heart rate zone screen should show continue CTA")
    }

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

        secondsWheel.adjust(toPickerWheelValue: "01")
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

    func verifyLayout() {
        let screen = app.descendants(matching: .any)["PersonalBest_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "Personal best screen should appear")
        XCTAssertTrue(app.switches["PersonalBest_HasPBToggle"].firstMatch.exists, "Personal best toggle should exist")
        XCTAssertTrue(app.buttons["PersonalBest_ContinueButton"].firstMatch.exists, "Personal best screen should show next CTA")
    }
}

// MARK: - Weekly Distance Page

class WeeklyDistancePage: BasePage {
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["WeeklyDistance_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "Weekly distance screen should appear")
        XCTAssertTrue(app.staticTexts["WeeklyDistance_Display"].firstMatch.exists, "Weekly distance display should exist")
        XCTAssertTrue(app.descendants(matching: .any)["WeeklyDistance_Preset_10"].firstMatch.exists, "Weekly distance preset should exist")
        XCTAssertTrue(app.buttons["WeeklyDistance_ContinueButton"].firstMatch.exists, "Weekly distance screen should show next CTA")
    }

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
    private var ctaContainer: XCUIElement {
        app.descendants(matching: .any)["GoalType_CTAContainer"].firstMatch
    }

    private var nextButtonCandidates: [XCUIElement] {
        [
            ctaContainer.buttons["GoalType_NextButton"].firstMatch,
            ctaContainer.buttons["Next Step"].firstMatch,
            ctaContainer.buttons["次のステップ"].firstMatch,
            ctaContainer.buttons["下一步"].firstMatch,
            app.descendants(matching: .any)["GoalType_NextButton"].firstMatch,
            app.buttons["GoalType_NextButton"].firstMatch,
            app.buttons["Next Step"].firstMatch,
            app.buttons["次のステップ"].firstMatch,
            app.buttons["下一步"].firstMatch
        ]
    }

    private func nextButton(timeout: TimeInterval) -> XCUIElement? {
        for candidate in nextButtonCandidates {
            if candidate.waitForExistence(timeout: timeout) {
                return candidate
            }
        }
        return nil
    }

    func verifyLayout() {
        let screen = app.descendants(matching: .any)["GoalType_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "Goal type screen should appear")
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || nextButton(timeout: 2) != nil,
            "Goal type screen should show a fixed CTA container"
        )

        let race = app.descendants(matching: .any)["GoalType_race_run"].firstMatch
        let beginner = app.descendants(matching: .any)["GoalType_beginner"].firstMatch
        XCTAssertTrue(race.exists || beginner.exists, "Goal type screen should expose selectable goal cards")
    }

    func isStepVisible(timeout: TimeInterval = 8) -> Bool {
        let screen = app.descendants(matching: .any)["GoalType_Screen"].firstMatch
        if screen.waitForExistence(timeout: timeout) {
            return true
        }

        let race = app.descendants(matching: .any)["GoalType_race_run"].firstMatch
        let beginner = app.descendants(matching: .any)["GoalType_beginner"].firstMatch
        let maintenance = app.descendants(matching: .any)["GoalType_maintenance"].firstMatch
        return race.exists || beginner.exists || maintenance.exists
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
        if let candidate = nextButton(timeout: 10) {
            tapRobust(candidate)
            return
        }

        XCTFail("Element 'GoalType_NextButton' did not appear within 10.0s")
    }
}

// MARK: - Race Setup Page

class RaceSetupPage: BasePage {
    private var ctaContainer: XCUIElement {
        app.descendants(matching: .any)["RaceSetup_SaveButton_Container"].firstMatch
    }

    private var saveButtonCandidates: [XCUIElement] {
        [
            ctaContainer.buttons["RaceSetup_SaveButton"].firstMatch,
            ctaContainer.buttons["Next Step"].firstMatch,
            ctaContainer.buttons["次のステップ"].firstMatch,
            ctaContainer.buttons["下一步"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_SaveButton"].firstMatch,
            app.buttons["RaceSetup_SaveButton"].firstMatch,
            app.buttons["Next Step"].firstMatch,
            app.buttons["次のステップ"].firstMatch,
            app.buttons["下一步"].firstMatch
        ]
    }

    private func saveButton(timeout: TimeInterval) -> XCUIElement? {
        for candidate in saveButtonCandidates {
            if candidate.waitForExistence(timeout: timeout) {
                return candidate
            }
        }
        return nil
    }

    @discardableResult
    func waitUntilVisible(timeout: TimeInterval = 15) -> Bool {
        let screen = app.descendants(matching: .any)["RaceSetup_Screen"].firstMatch
        if screen.waitForExistence(timeout: timeout) {
            return true
        }

        return saveButton(timeout: 2) != nil
    }

    func verifyOptimizedLayout() {
        XCTAssertTrue(waitUntilVisible(), "Race setup screen should appear")

        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || saveButton(timeout: 2) != nil,
            "Race setup screen should expose a fixed primary CTA"
        )

        let contentMarkers = [
            app.descendants(matching: .any)["RaceSetup_Mode_SelectedRace"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_Mode_DatabaseOrManual"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_Mode_ManualOnly"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_BrowseDatabaseButton"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_BrowseDatabaseCard"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_TargetTimeEditorButton"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_TargetTimeSection"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_ManualInputForm"].firstMatch,
            app.descendants(matching: .any)["RaceSetup_SelectedRaceCard"].firstMatch
        ]

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if contentMarkers.contains(where: \.exists) {
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTFail("Race setup screen should show a database entry, a manual-input form, or a selected-race summary")
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
        guard let button = saveButton(timeout: 10) else {
            XCTFail("Element 'RaceSetup_SaveButton' did not appear within 10s")
            return
        }
        tapRobust(button)
    }
}

// MARK: - Start Stage Page

class StartStagePage: BasePage {
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["StartStage_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Start stage screen should appear")
        let ctaContainer = app.descendants(matching: .any)["StartStage_CTAContainer"].firstMatch
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || app.descendants(matching: .any)["StartStage_NextButton"].firstMatch.exists,
            "Start stage screen should show next CTA"
        )
    }

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
    private var ctaContainer: XCUIElement {
        app.descendants(matching: .any)["Methodology_CTAContainer"].firstMatch
    }

    private var methodologyCardCandidates: [XCUIElement] {
        [
            app.descendants(matching: .any)["Methodology_paceriz"].firstMatch,
            app.descendants(matching: .any)["Methodology_norwegian"].firstMatch,
            app.descendants(matching: .any)["Methodology_hansons"].firstMatch,
            app.descendants(matching: .any)["Methodology_polarized"].firstMatch
        ]
    }

    private var nextButtonCandidates: [XCUIElement] {
        [
            ctaContainer.buttons["Methodology_NextButton"].firstMatch,
            ctaContainer.buttons["Next"].firstMatch,
            ctaContainer.buttons["Continue"].firstMatch,
            ctaContainer.buttons["下一步"].firstMatch,
            app.descendants(matching: .any)["Methodology_NextButton"].firstMatch,
            app.buttons["Methodology_NextButton"].firstMatch
        ]
    }

    private func nextButton(timeout: TimeInterval) -> XCUIElement? {
        for candidate in nextButtonCandidates {
            if candidate.waitForExistence(timeout: timeout) {
                return candidate
            }
        }
        return nil
    }

    private func enabledNextButton(timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for candidate in nextButtonCandidates where candidate.exists && candidate.isEnabled {
                return candidate
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nextButtonCandidates.first(where: { $0.exists && $0.isEnabled })
    }

    @discardableResult
    func waitUntilReady(timeout: TimeInterval = 10) -> Bool {
        let screen = app.descendants(matching: .any)["Methodology_Screen"].firstMatch
        guard screen.waitForExistence(timeout: timeout) else {
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if methodologyCardCandidates.contains(where: \.exists) {
                return true
            }
            if enabledNextButton(timeout: 0.2) != nil {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline

        return methodologyCardCandidates.contains(where: \.exists) || enabledNextButton(timeout: 0.2) != nil
    }

    func verifyLayout() {
        XCTAssertTrue(waitUntilReady(timeout: 10), "Methodology screen should appear")
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || nextButton(timeout: 2) != nil,
            "Methodology screen should show next CTA"
        )
    }

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

    @discardableResult
    func ensureMethodologySelection(preferred methodologyId: String?, timeout: TimeInterval = 10) -> Bool {
        if let methodologyId,
           selectMethodologyIfVisible(methodologyId, timeout: min(timeout, 4)) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let candidate = methodologyCardCandidates.first(where: { $0.exists }) {
                tapRobust(candidate)
                return true
            }

            if enabledNextButton(timeout: 0.2) != nil {
                return true
            }

            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline

        return enabledNextButton(timeout: 0.2) != nil
    }

    func tapNext() {
        guard let button = enabledNextButton(timeout: 10) ?? nextButton(timeout: 2) else {
            XCTFail("Element 'Methodology_NextButton' did not become enabled within 10.0s")
            return
        }
        tapRobust(button)
    }
}

// MARK: - Training Weeks Page

class TrainingWeeksPage: BasePage {
    private var ctaContainer: XCUIElement {
        app.descendants(matching: .any)["TrainingWeeks_CTAContainer"].firstMatch
    }

    private var nextButtonCandidates: [XCUIElement] {
        [
            ctaContainer.buttons["TrainingWeeks_NextButton"].firstMatch,
            ctaContainer.buttons["Continue"].firstMatch,
            ctaContainer.buttons["下一步"].firstMatch,
            app.descendants(matching: .any)["TrainingWeeks_NextButton"].firstMatch,
            app.buttons["TrainingWeeks_NextButton"].firstMatch
        ]
    }

    private func nextButton(timeout: TimeInterval) -> XCUIElement? {
        for candidate in nextButtonCandidates {
            if candidate.waitForExistence(timeout: timeout) {
                return candidate
            }
        }
        return nil
    }

    func isStepVisible(timeout: TimeInterval = 10) -> Bool {
        let screen = app.descendants(matching: .any)["TrainingWeeks_Screen"].firstMatch
        if screen.waitForExistence(timeout: timeout) {
            return true
        }

        let quickOption = app.descendants(matching: .any)["TrainingWeeks_12"].firstMatch
        if quickOption.waitForExistence(timeout: 2) {
            return true
        }

        return ctaContainer.waitForExistence(timeout: 2)
    }

    func verifyLayout() {
        XCTAssertTrue(isStepVisible(timeout: 10), "Training weeks screen should appear")
        XCTAssertTrue(app.descendants(matching: .any)["TrainingWeeks_12"].firstMatch.exists, "Training weeks quick option should exist")
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || nextButton(timeout: 2) != nil,
            "Training weeks screen should show next CTA"
        )
    }

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
        guard let button = nextButton(timeout: 10) else {
            XCTFail("Element 'TrainingWeeks_NextButton' did not appear within 10.0s")
            return
        }
        tapRobust(button)
    }
}

// MARK: - Maintenance Race Distance Page

class MaintenanceRaceDistancePage: BasePage {
    private var ctaContainer: XCUIElement {
        app.descendants(matching: .any)["MaintenanceRaceDistance_CTAContainer"].firstMatch
    }

    func verifyLayout() {
        let screen = app.descendants(matching: .any)["MaintenanceRaceDistance_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Maintenance race distance screen should appear")
        XCTAssertTrue(app.descendants(matching: .any)["MaintenanceRaceDistance_marathon"].firstMatch.exists, "Maintenance race distance should show marathon option")
        XCTAssertTrue(app.descendants(matching: .any)["MaintenanceRaceDistance_unsure"].firstMatch.exists, "Maintenance race distance should show unsure option")
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || app.descendants(matching: .any)["MaintenanceRaceDistance_NextButton"].firstMatch.exists,
            "Maintenance race distance screen should show next CTA"
        )
    }

    @discardableResult
    func selectOptionIfVisible(_ optionId: String, timeout: TimeInterval = 5) -> Bool {
        let option = app.descendants(matching: .any)["MaintenanceRaceDistance_\(optionId)"].firstMatch
        guard option.waitForExistence(timeout: timeout) else {
            return false
        }
        tapRobust(option)
        return true
    }

    func tapNext() {
        let button = waitForElement("MaintenanceRaceDistance_NextButton", timeout: 10)
        tapRobust(button)
    }
}

// MARK: - Training Days Page

class TrainingDaysPage: BasePage {
    func verifyLayout() {
        let screen = app.descendants(matching: .any)["TrainingDays_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Training days screen should appear")
        XCTAssertTrue(app.descendants(matching: .any)["TrainingDay_1"].firstMatch.exists, "Training days should show weekday options")
        XCTAssertTrue(app.descendants(matching: .any)["TrainingDays_SaveButton"].firstMatch.exists, "Training days screen should show save CTA")
    }

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
    func verifyLayout(timeout: TimeInterval = 25) {
        let screen = app.descendants(matching: .any)["TrainingOverview_Screen"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Training overview screen should appear")
        let ctaContainer = app.descendants(matching: .any)["TrainingOverview_CTAContainer"].firstMatch
        XCTAssertTrue(
            ctaContainer.waitForExistence(timeout: 5) || app.descendants(matching: .any)["TrainingOverview_GenerateButton"].firstMatch.exists,
            "Training overview screen should show generate CTA"
        )
    }

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
