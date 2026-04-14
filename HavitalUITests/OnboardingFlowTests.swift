//
//  OnboardingFlowTests.swift
//  HavitalUITests
//
//  End-to-end onboarding flow tests covering V2 race and non-race paths.
//

import XCTest

final class OnboardingFlowTests: OnboardingE2ETestBase {

    // MARK: - Test 1: Full V2 Race Target Flow

    /// Full race-run onboarding flow should complete and land on main content/fallback screen.
    func testFullOnboarding_V2_RaceTarget() {
        runOnboardingFlow(config: TestMatrix.raceRunPacerizMarathon)
        verifyOnboardingComplete()
    }

    // MARK: - Test 2: Full V2 Non-Race Target Flow

    /// Full non-race onboarding flow should complete and land on main content/fallback screen.
    func testFullOnboarding_V2_NonRaceTarget() {
        runOnboardingFlow(config: TestMatrix.maintenancePaceriz12w)
        verifyOnboardingComplete()
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
        let wdContinue = app.buttons["WeeklyDistance_ContinueButton"].firstMatch
        XCTAssertTrue(wdContinue.waitForExistence(timeout: 15), "WeeklyDistance page should appear")
        weeklyDistancePage.tapRobust(wdContinue)

        // GoalType
        let goalNext = app.descendants(matching: .any)["GoalType_NextButton"]
        XCTAssertTrue(goalNext.waitForExistence(timeout: 15), "GoalType page should appear")
        // Don't proceed further — smoke test verified all common steps are visible
    }
}
