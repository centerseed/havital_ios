//
//  OnboardingFlowTests.swift
//  HavitalUITests
//
//  End-to-end onboarding flow tests covering V2 race and non-race paths.
//

import XCTest

final class OnboardingFlowTests: OnboardingE2ETestBase {

    // MARK: - Test 1: Full V2 Race Target Flow

    /// Login → Intro → DataSource → HeartRateZone → PersonalBest → WeeklyDistance
    /// → GoalType(race_run) → RaceSetup → StartStage → Methodology → TrainingWeeks → TrainingDays → TrainingOverview
    func testFullOnboarding_V2_RaceTarget() {
        // Common steps: Login → Intro → DataSource → HeartRateZone → PersonalBest → WeeklyDistance
        performCommonSteps()

        // GoalType: select race_run
        goalTypePage.selectGoalType("race_run")
        goalTypePage.tapNext()

        // RaceSetup: use defaults (marathon 4h) and save
        raceSetupPage.tapSave()

        // StartStage: may or may not appear — tap next if visible
        let startStageNext = app.descendants(matching: .any)["StartStage_NextButton"]
        if startStageNext.waitForExistence(timeout: 10) {
            startStagePage.tapNext()
        }

        // Methodology: select paceriz if page appears
        let methodologyNext = app.descendants(matching: .any)["Methodology_NextButton"]
        if methodologyNext.waitForExistence(timeout: 10) {
            methodologyPage.selectMethodology("paceriz")
            methodologyPage.tapNext()
        }

        // TrainingWeeks: may appear for race target — select if visible
        let trainingWeeksNext = app.descendants(matching: .any)["TrainingWeeks_NextButton"]
        if trainingWeeksNext.waitForExistence(timeout: 5) {
            trainingWeeksPage.selectWeeks(12)
            trainingWeeksPage.tapNext()
        }

        // TrainingDays: select Mon/Wed/Fri/Sat (need >= 3 days)
        let trainingSave = app.descendants(matching: .any)["TrainingDays_SaveButton"]
        XCTAssertTrue(trainingSave.waitForExistence(timeout: 10),
                      "TrainingDays page should appear")
        trainingDaysPage.deselectAllThenSelect([1, 3, 5, 6])
        trainingDaysPage.tapSave()

        // TrainingOverview: verify generate button exists
        trainingOverviewPage.verifyWeeksLabel()
        let generateButton = app.descendants(matching: .any)["TrainingOverview_GenerateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 15),
                      "TrainingOverview should show Generate button")
    }

    // MARK: - Test 2: Full V2 Non-Race Target Flow

    /// Login → Intro → DataSource → HeartRateZone → PersonalBest → WeeklyDistance
    /// → GoalType(maintenance) → Methodology → TrainingWeeks → TrainingDays → TrainingOverview
    func testFullOnboarding_V2_NonRaceTarget() {
        performCommonSteps()

        // GoalType: select maintenance (non-race)
        goalTypePage.selectGoalType("maintenance")
        goalTypePage.tapNext()

        // No RaceSetup or StartStage for non-race targets

        // Methodology: select if page appears
        let methodologyNext = app.descendants(matching: .any)["Methodology_NextButton"]
        if methodologyNext.waitForExistence(timeout: 10) {
            methodologyPage.selectMethodology("paceriz")
            methodologyPage.tapNext()
        }

        // TrainingWeeks: select 12 weeks
        let trainingWeeksNext = app.descendants(matching: .any)["TrainingWeeks_NextButton"]
        if trainingWeeksNext.waitForExistence(timeout: 10) {
            trainingWeeksPage.selectWeeks(12)
            trainingWeeksPage.tapNext()
        }

        // TrainingDays: select Tue/Thu/Sat
        let trainingSave = app.descendants(matching: .any)["TrainingDays_SaveButton"]
        XCTAssertTrue(trainingSave.waitForExistence(timeout: 10),
                      "TrainingDays page should appear")
        trainingDaysPage.deselectAllThenSelect([2, 4, 6])
        trainingDaysPage.tapSave()

        // TrainingOverview: verify generate button
        trainingOverviewPage.verifyWeeksLabel()
        let generateButton = app.descendants(matching: .any)["TrainingOverview_GenerateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 15),
                      "TrainingOverview should show Generate button")
    }

    // MARK: - Test 3: Step Navigation Smoke Test

    /// Lightweight test: verify each onboarding step's key element is visible
    func testOnboarding_StepNavigation_EachStepVisible() {
        // Login
        let demoButton = app.buttons["Login_DemoButton"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 10), "Login page should show Demo button")
        loginPage.loginWithDemo()

        // Intro (demo login API + auth state + UI transition takes time)
        let startButton = app.buttons["OnboardingStartButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 20), "Intro page should appear")
        introPage.tapStart()

        // DataSource
        let appleHealth = app.descendants(matching: .any)["DataSourceOption_appleHealth"]
        XCTAssertTrue(appleHealth.waitForExistence(timeout: 5), "DataSource page should show Apple Health option")
        dataSourcePage.selectAppleHealth()
        dataSourcePage.tapContinue()

        // HealthKit auth is skipped via -skipHealthKitAuth launch argument
        sleep(1)

        // HeartRateZone
        let hrContinue = app.descendants(matching: .any)["HeartRateZone_ContinueButton"]
        XCTAssertTrue(hrContinue.waitForExistence(timeout: 10), "HeartRateZone page should appear")
        heartRateZonePage.tapContinue()

        // PersonalBest
        let pbContinue = app.descendants(matching: .any)["PersonalBest_ContinueButton"]
        XCTAssertTrue(pbContinue.waitForExistence(timeout: 10), "PersonalBest page should appear")
        personalBestPage.tapContinue()

        // WeeklyDistance
        let wdContinue = app.descendants(matching: .any)["WeeklyDistance_ContinueButton"]
        XCTAssertTrue(wdContinue.waitForExistence(timeout: 15), "WeeklyDistance page should appear")
        weeklyDistancePage.tapContinue()

        // GoalType
        let goalNext = app.descendants(matching: .any)["GoalType_NextButton"]
        XCTAssertTrue(goalNext.waitForExistence(timeout: 15), "GoalType page should appear")
        // Don't proceed further — smoke test verified all common steps are visible
    }
}
