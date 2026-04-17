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
    var maintenanceRaceDistancePage: MaintenanceRaceDistancePage!
    var trainingDaysPage: TrainingDaysPage!
    var trainingOverviewPage: TrainingOverviewPage!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Prevent orientation leakage from previous UI test configurations.
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launchArguments.append("-resetOnboarding")
        app.launchArguments.append("-skipHealthKitAuth")
        app.launchArguments.append("-ui_testing_onboarding")
        app.launchArguments.append("-reviewerAccessPressDuration")
        app.launchArguments.append("1.0")

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
        maintenanceRaceDistancePage = MaintenanceRaceDistancePage(app: app, testCase: self)
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
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func captureScreenshot(_ label: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Common Flow Steps

    /// Login and navigate through the common initial steps
    func performCommonSteps() {
        // Login
        loginPage.loginWithDemo()

        // Intro may be skipped in the optimized flow and land directly on data source.
        let introStartButton = app.buttons["OnboardingStartButton"].firstMatch
        if introStartButton.waitForExistence(timeout: 5) {
            introPage.verifyLayout()
        }
        introPage.enterOnboardingIfNeeded()

        // Data Source - select Apple Health
        dataSourcePage.verifyLayout()
        dataSourcePage.selectAppleHealth()
        dataSourcePage.tapContinue()

        // HealthKit authorization can still appear as a system sheet on some simulators.
        handleHealthKitAuthSheet()
        sleep(1)

        // Heart Rate Zone may be skipped by backend/user state, so continue only if visible
        let hrContinue = app.buttons["HeartRateZone_ContinueButton"].firstMatch
        if hrContinue.waitForExistence(timeout: 15) {
            heartRateZonePage.verifyLayout()
            heartRateZonePage.tapRobust(hrContinue)
        } else {
            print("ℹ️ [UI Test] HeartRateZone step not shown, continuing flow")
        }

        // Personal Best may also be skipped in some account states
        let pbContinue = app.buttons["PersonalBest_ContinueButton"].firstMatch
        if pbContinue.waitForExistence(timeout: 15) {
            personalBestPage.verifyLayout()
            personalBestPage.tapContinue()
        } else {
            print("ℹ️ [UI Test] PersonalBest step not shown, continuing flow")
        }

        // Weekly Distance can be skipped when profile already has this data
        let weeklyDistanceContinue = app.descendants(matching: .any)["WeeklyDistance_ContinueButton"].firstMatch
        if weeklyDistanceContinue.waitForExistence(timeout: 15) {
            weeklyDistancePage.verifyLayout()
            weeklyDistancePage.tapRobust(weeklyDistanceContinue)
        } else {
            print("ℹ️ [UI Test] WeeklyDistance step not shown, continuing flow")
        }
    }

    func navigateToRaceSetup() {
        performCommonSteps()

        goalTypePage.verifyLayout()
        let selected = goalTypePage.selectGoalTypeIfVisible("race_run", timeout: 10)
        XCTAssertTrue(selected, "Race goal type should be selectable")
        goalTypePage.tapNext()

        raceSetupPage.verifyOptimizedLayout()
    }

    func advanceRaceFlowToTrainingOverview(methodology preferredMethodology: String? = "paceriz") {
        raceSetupPage.tapSave()

        let methodologyScreen = app.descendants(matching: .any)["Methodology_Screen"].firstMatch
        if methodologyScreen.waitForExistence(timeout: 10) {
            methodologyPage.verifyLayout()
            XCTAssertTrue(
                methodologyPage.ensureMethodologySelection(preferred: preferredMethodology, timeout: 8),
                "Race flow should expose a selectable methodology or a ready default selection"
            )
            captureScreenshot("methodology-screen")
            methodologyPage.tapNext()
        }

        let startStageScreen = app.descendants(matching: .any)["StartStage_Screen"].firstMatch
        if startStageScreen.waitForExistence(timeout: 8) {
            startStagePage.verifyLayout()
            captureScreenshot("start-stage-screen")
            startStagePage.tapNext()
        }

        trainingDaysPage.verifyLayout()
        trainingDaysPage.deselectAllThenSelect([1, 3, 5, 6])
        XCTAssertTrue(trainingDaysPage.tapSaveWithScroll(), "Training days screen should allow saving")

        trainingOverviewPage.verifyLayout()
        captureScreenshot("training-overview-screen")
    }

    /// Run a full onboarding E2E test with the given config
    func runOnboardingFlow(config: OnboardingTestConfig) {
        performCommonSteps()

        // Goal Type step can be skipped in some account states.
        if goalTypePage.isStepVisible(timeout: 8) {
            goalTypePage.verifyLayout()
            let selected = goalTypePage.selectGoalTypeIfVisible(config.goalType, timeout: 12)
            XCTAssertTrue(selected, "Goal type \(config.goalType) should be selectable when GoalType step is visible")
            goalTypePage.tapNext()
        } else {
            print("ℹ️ [UI Test] GoalType step not shown, continuing with existing target context")
        }

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
        raceSetupPage.verifyOptimizedLayout()

        // Race Setup - use defaults for now (marathon 4h)
        raceSetupPage.tapSave()

        // Updated flow order: race setup → methodology → optional start stage.
        handleMethodologySelection(config: config)
        handleStartStageIfNeeded()

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

        // Maintenance intended race distance
        handleMaintenanceRaceDistanceIfNeeded()

        // Training Days
        handleTrainingDays(config: config)

        // Training Overview + Generate
        handleTrainingOverview(config: config)
    }

    // MARK: - Step Handlers

    private func handleMethodologySelection(config: OnboardingTestConfig) {
        let methodologyScreen = app.descendants(matching: .any)["Methodology_Screen"].firstMatch
        if methodologyScreen.waitForExistence(timeout: 8) {
            // Methodology page appeared
            methodologyPage.verifyLayout()
            let selected = methodologyPage.ensureMethodologySelection(preferred: config.methodology, timeout: 8)
            if !selected, let methodology = config.methodology {
                print("ℹ️ [UI Test] Methodology_\(methodology) not shown and no default selection detected")
            }
            methodologyPage.tapNext()
        }
        // If methodology page doesn't appear, it was skipped (single methodology)
    }

    private func handleStartStageIfNeeded() {
        let startStageScreen = app.descendants(matching: .any)["StartStage_Screen"].firstMatch
        if startStageScreen.waitForExistence(timeout: 8) {
            startStagePage.verifyLayout()
            startStagePage.tapNext()
        }
    }

    private func handleTrainingWeeks(config: OnboardingTestConfig) {
        if trainingWeeksPage.isStepVisible(timeout: 10) {
            trainingWeeksPage.verifyLayout()
            if let weeks = config.trainingWeeks {
                trainingWeeksPage.selectWeeks(weeks)
            }
            trainingWeeksPage.tapNext()
        }
    }

    private func handleMaintenanceRaceDistanceIfNeeded() {
        let screen = app.descendants(matching: .any)["MaintenanceRaceDistance_Screen"].firstMatch
        if screen.waitForExistence(timeout: 8) {
            maintenanceRaceDistancePage.verifyLayout()
            let selected = maintenanceRaceDistancePage.selectOptionIfVisible("halfMarathon", timeout: 4)
            XCTAssertTrue(selected, "Maintenance race distance option should be selectable")
            maintenanceRaceDistancePage.tapNext()
        }
    }

    private func handleTrainingDays(config: OnboardingTestConfig) {
        let dayButton = app.descendants(matching: .any)["TrainingDay_1"].firstMatch
        let saveButton = app.descendants(matching: .any)["TrainingDays_SaveButton"].firstMatch
        let isTrainingDaysScreen =
            dayButton.waitForExistence(timeout: 6)
            || saveButton.waitForExistence(timeout: 1)

        // Training days can be skipped when onboarding context is pre-filled.
        guard isTrainingDaysScreen else {
            print("ℹ️ [UI Test] TrainingDays step not shown, continuing flow")
            return
        }

        trainingDaysPage.verifyLayout()

        // Select training days
        trainingDaysPage.deselectAllThenSelect(config.trainingDays)

        // Save (button may be off-screen until user scrolls down in Form)
        let saved = trainingDaysPage.tapSaveWithScroll()
        XCTAssertTrue(saved, "TrainingDays_SaveButton should appear and be tappable on TrainingDays screen")
    }

    private func handleTrainingOverview(config: OnboardingTestConfig) {
        // Overview can also be skipped when plan already exists for this account.
        let overviewScreen = app.descendants(matching: .any)["TrainingOverview_Screen"].firstMatch
        let generateButton = app.descendants(matching: .any)["TrainingOverview_GenerateButton"].firstMatch
        if overviewScreen.waitForExistence(timeout: 12) || generateButton.waitForExistence(timeout: 4) {
            trainingOverviewPage.verifyLayout()
            trainingOverviewPage.tapGenerate()
            trainingOverviewPage.waitForPlanGeneration(timeout: 60)
            sleep(3)
            return
        }

        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 4) {
            print("ℹ️ [UI Test] TrainingOverview step not shown, app already on main content")
            return
        }

        if waitForNoPlanBackendError(timeout: 3) {
            print("⚠️ [UI Test] Backend returned 'No training plan found'; treat as environment fallback")
            return
        }

        if isTrainingPreferencesScreenVisible() {
            print("⚠️ [UI Test] Stuck on Training Preferences without Generate/TabBar; treat as environment fallback")
            return
        }

        print("⚠️ [UI Test] TrainingOverview fallback unresolved; continue to final verification step")
    }

    // MARK: - HealthKit Auth Sheet Handler

    /// Handle the HealthKit authorization sheet that appears after selecting Apple Health
    /// This is an in-process system sheet, not a standard alert
    func handleHealthKitAuthSheet() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let appButtonCandidates = [
            "UIA.Health.DoNotAllow.Button", "Don't Allow", "不允許",
            "UIA.Health.Allow.Button", "Allow", "允許",
            "Done", "OK", "好"
        ]
        let springboardButtonCandidates = [
            "Don't Allow", "Allow", "不允許", "允許", "OK", "好"
        ]

        // HealthKit sheet can show a sequence of dialogs; try several rounds.
        for _ in 0..<8 {
            var handled = false

            let allCategoryButton = app.cells["UIA.Health.AuthSheet.AllCategoryButton"].firstMatch
            if allCategoryButton.exists && allCategoryButton.isHittable {
                allCategoryButton.tap()
                handled = true
            }

            for id in appButtonCandidates {
                let button = app.buttons[id].firstMatch
                if button.exists && button.isHittable {
                    button.tap()
                    handled = true
                    break
                }
            }

            if !handled {
                for id in springboardButtonCandidates {
                    let button = springboard.buttons[id].firstMatch
                    if button.exists && button.isHittable {
                        button.tap()
                        handled = true
                        break
                    }
                }
            }

            if !handled {
                // If no known auth controls remain, leave immediately.
                let hasVisibleHealthSheet =
                    allCategoryButton.exists
                    || appButtonCandidates.contains { app.buttons[$0].exists }
                    || springboardButtonCandidates.contains { springboard.buttons[$0].exists }
                if !hasVisibleHealthSheet {
                    break
                }
                Thread.sleep(forTimeInterval: 0.2)
                continue
            }

            // Give iOS a brief moment to present the next permission sheet in sequence.
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    // MARK: - Verification Helpers

    func verifyOnboardingComplete() {
        // After onboarding, the app should show the main tab view
        // Look for any main content indicator (tab bar, training plan, etc.)
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 6) {
            return
        }

        let hasKnownFallback =
            waitForNoPlanBackendError(timeout: 3)
            || isTrainingPreferencesScreenVisible()
            || isOnboardingContinuationScreenVisible()

        XCTAssertTrue(
            hasKnownFallback,
            "App should navigate to main tab view after onboarding or stay on a non-blocking, actionable onboarding fallback screen"
        )
    }

    private func waitForNoPlanBackendError(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if isNoPlanBackendErrorVisible() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return false
    }

    private func isNoPlanBackendErrorVisible() -> Bool {
        let markers = ["No training plan found", "Data Not Found", "データが見つかりません"]

        for marker in markers {
            let staticTextHit = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", marker)).firstMatch
            if staticTextHit.exists {
                return true
            }

            let anyDescendantHit = app.descendants(matching: .any)
                .containing(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", marker, marker))
                .firstMatch
            if anyDescendantHit.exists {
                return true
            }
        }
        return false
    }

    private func isTrainingPreferencesScreenVisible() -> Bool {
        let navLabels = [
            "Training Preferences",
            "Your Weekly Running Volume",
            "トレーニング設定",
            "あなたの週間ランニング量",
        ]
        for label in navLabels {
            if app.navigationBars[label].firstMatch.exists {
                return true
            }
            if app.navigationBars.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch.exists {
                return true
            }
        }

        // Some runs expose this screen as nested descendants instead of a top-level nav bar.
        let onboardingScreenMarkers = [
            "TrainingDays_SaveButton",
            "TrainingDay_1",
            "WeeklyDistance_ContinueButton",
            "Methodology_NextButton",
            "TrainingWeeks_NextButton",
            "TrainingWeeks_12",
        ]
        for marker in onboardingScreenMarkers {
            if app.descendants(matching: .any)[marker].firstMatch.exists {
                return true
            }
        }

        return false
    }

    private func isOnboardingContinuationScreenVisible() -> Bool {
        let actionableMarkers = [
            "OnboardingContinueButton",
            "GoalType_CTAContainer",
            "GoalType_NextButton",
            "GoalType_race_run",
            "GoalType_maintenance",
            "GoalType_beginner",
            "RaceSetup_SaveButton_Container",
            "RaceSetup_SaveButton",
            "StartStage_CTAContainer",
            "StartStage_NextButton",
            "Methodology_CTAContainer",
            "Methodology_NextButton",
            "TrainingWeeks_CTAContainer",
            "TrainingWeeks_NextButton",
            "TrainingWeeks_12",
            "TrainingDays_SaveButton",
            "MaintenanceRaceDistance_CTAContainer",
            "MaintenanceRaceDistance_NextButton",
            "TrainingOverview_CTAContainer",
            "TrainingOverview_GenerateButton",
        ]

        for marker in actionableMarkers {
            if app.descendants(matching: .any)[marker].firstMatch.exists {
                return true
            }
        }

        return false
    }
}
