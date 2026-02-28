//
//  OnboardingE2ETestBase.swift
//  HavitalUITests
//
//  Base class for E2E onboarding tests
//

import XCTest

class OnboardingE2ETestBase: XCTestCase {
    var app: XCUIApplication!

    // Page objects
    var loginPage: LoginPage!
    var introPage: IntroPage!
    var dataSourcePage: DataSourcePage!
    var heartRateZonePage: HeartRateZonePage!
    var personalBestPage: PersonalBestPage!
    var weeklyDistancePage: WeeklyDistancePage!
    var goalTypePage: GoalTypePage!
    var raceSetupPage: RaceSetupPage!
    var startStagePage: StartStagePage!
    var methodologyPage: MethodologyPage!
    var trainingWeeksPage: TrainingWeeksPage!
    var trainingDaysPage: TrainingDaysPage!
    var trainingOverviewPage: TrainingOverviewPage!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("-resetOnboarding")
        app.launchArguments.append("-skipHealthKitAuth")

        // Initialize page objects
        loginPage = LoginPage(app: app, testCase: self)
        introPage = IntroPage(app: app, testCase: self)
        dataSourcePage = DataSourcePage(app: app, testCase: self)
        heartRateZonePage = HeartRateZonePage(app: app, testCase: self)
        personalBestPage = PersonalBestPage(app: app, testCase: self)
        weeklyDistancePage = WeeklyDistancePage(app: app, testCase: self)
        goalTypePage = GoalTypePage(app: app, testCase: self)
        raceSetupPage = RaceSetupPage(app: app, testCase: self)
        startStagePage = StartStagePage(app: app, testCase: self)
        methodologyPage = MethodologyPage(app: app, testCase: self)
        trainingWeeksPage = TrainingWeeksPage(app: app, testCase: self)
        trainingDaysPage = TrainingDaysPage(app: app, testCase: self)
        trainingOverviewPage = TrainingOverviewPage(app: app, testCase: self)

        // Handle system alerts (general permissions)
        addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }
            return false
        }

        // Handle HealthKit authorization sheet
        // HealthKit presents a full-screen HKAuthorizationSheet, not a standard alert
        addUIInterruptionMonitor(withDescription: "HealthKit Permission") { alert in
            // HealthKit sheet has "Turn On All" and "Allow" buttons
            if alert.buttons["Turn On All"].exists {
                alert.buttons["Turn On All"].tap()
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            // iOS 17+ uses "Done" button on HealthKit sheet
            if alert.buttons["Done"].exists {
                alert.buttons["Done"].tap()
                return true
            }
            return false
        }

        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Common Flow Steps

    /// Login and navigate through the common initial steps
    func performCommonSteps() {
        // Login
        loginPage.loginWithDemo()

        // Intro
        introPage.tapStart()

        // Data Source - select Apple Health
        dataSourcePage.selectAppleHealth()
        dataSourcePage.tapContinue()

        // HealthKit auth is skipped via -skipHealthKitAuth launch argument
        // Wait for navigation transition
        sleep(1)

        // Heart Rate Zone - just continue with defaults
        heartRateZonePage.tapContinue()

        // Personal Best - skip (just continue)
        personalBestPage.tapContinue()

        // Weekly Distance - continue with default
        weeklyDistancePage.tapContinue()
    }

    /// Run a full onboarding E2E test with the given config
    func runOnboardingFlow(config: OnboardingTestConfig) {
        performCommonSteps()

        // Goal Type selection
        goalTypePage.selectGoalType(config.goalType)
        goalTypePage.tapNext()

        // Branch based on goal type
        switch config.goalType {
        case "race_run":
            handleRaceRunFlow(config: config)
        case "beginner":
            handleBeginnerFlow(config: config)
        case "maintenance":
            handleMaintenanceFlow(config: config)
        default:
            XCTFail("Unknown goal type: \(config.goalType)")
        }
    }

    // MARK: - Goal-Specific Flows

    private func handleRaceRunFlow(config: OnboardingTestConfig) {
        // Race Setup - use defaults for now (marathon 4h)
        raceSetupPage.tapSave()

        // Start Stage may or may not appear depending on weeks remaining
        // Check if StartStage_NextButton appears
        let startStageButton = app.descendants(matching: .any)["StartStage_NextButton"]
        if startStageButton.waitForExistence(timeout: 5) {
            startStagePage.tapNext()
        }

        // Methodology selection (appears if multiple methodologies)
        handleMethodologySelection(config: config)

        // Training Days
        handleTrainingDays(config: config)

        // Training Overview + Generate
        handleTrainingOverview(config: config)
    }

    private func handleBeginnerFlow(config: OnboardingTestConfig) {
        // Methodology selection (may or may not appear for beginner)
        handleMethodologySelection(config: config)

        // Training Weeks (if applicable)
        handleTrainingWeeks(config: config)

        // Training Days
        handleTrainingDays(config: config)

        // Training Overview + Generate
        handleTrainingOverview(config: config)
    }

    private func handleMaintenanceFlow(config: OnboardingTestConfig) {
        // Methodology selection
        handleMethodologySelection(config: config)

        // Training Weeks
        handleTrainingWeeks(config: config)

        // Training Days
        handleTrainingDays(config: config)

        // Training Overview + Generate
        handleTrainingOverview(config: config)
    }

    // MARK: - Step Handlers

    private func handleMethodologySelection(config: OnboardingTestConfig) {
        let methodologyButton = app.descendants(matching: .any)["Methodology_NextButton"]
        if methodologyButton.waitForExistence(timeout: 10) {
            // Methodology page appeared
            if let methodology = config.methodology {
                methodologyPage.selectMethodology(methodology)
            }
            methodologyPage.tapNext()
        }
        // If methodology page doesn't appear, it was skipped (single methodology)
    }

    private func handleTrainingWeeks(config: OnboardingTestConfig) {
        let weeksButton = app.descendants(matching: .any)["TrainingWeeks_NextButton"]
        if weeksButton.waitForExistence(timeout: 10) {
            if let weeks = config.trainingWeeks {
                trainingWeeksPage.selectWeeks(weeks)
            }
            trainingWeeksPage.tapNext()
        }
    }

    private func handleTrainingDays(config: OnboardingTestConfig) {
        // Wait for training days page
        _ = app.descendants(matching: .any)["TrainingDays_SaveButton"].waitForExistence(timeout: 10)

        // Select training days
        trainingDaysPage.deselectAllThenSelect(config.trainingDays)

        // Save
        trainingDaysPage.tapSave()
    }

    private func handleTrainingOverview(config: OnboardingTestConfig) {
        // Verify overview appears
        trainingOverviewPage.verifyWeeksLabel()

        // Tap generate
        trainingOverviewPage.tapGenerate()

        // Wait for plan generation (loading animation, up to 60s)
        trainingOverviewPage.waitForPlanGeneration(timeout: 60)

        // Wait for main content to appear (training plan view)
        sleep(3)
    }

    // MARK: - HealthKit Auth Sheet Handler

    /// Handle the HealthKit authorization sheet that appears after selecting Apple Health
    /// This is an in-process system sheet, not a standard alert
    func handleHealthKitAuthSheet() {
        // Try multiple approaches to dismiss HealthKit auth sheet

        // Approach 1: Look for "Turn On All" then "Allow" in the app hierarchy
        let turnOnAll = app.switches.matching(NSPredicate(format: "label CONTAINS 'Turn On All'")).firstMatch
        if turnOnAll.waitForExistence(timeout: 5) {
            turnOnAll.tap()
        }

        // Look for "Allow" button (iOS HealthKit sheet)
        let allowButton = app.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
            sleep(1)
            return
        }

        // Look for "Done" button (newer iOS)
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(1)
            return
        }

        // Approach 2: Try springboard for system alerts
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let springboardAllow = springboard.buttons["Allow"]
        if springboardAllow.waitForExistence(timeout: 3) {
            springboardAllow.tap()
            sleep(1)
            return
        }

        // If nothing found, the permission may have been pre-granted
        // Just tap the app to trigger any interruption monitors
        app.tap()
        sleep(1)
    }

    // MARK: - Verification Helpers

    func verifyOnboardingComplete() {
        // After onboarding, the app should show the main tab view
        // Look for any main content indicator (tab bar, training plan, etc.)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 30),
                      "App should navigate to main tab view after onboarding")
    }
}
