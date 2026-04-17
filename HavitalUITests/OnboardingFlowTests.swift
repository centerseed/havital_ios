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

    /// Verify the optimized race onboarding exposes the expected UI contract on each critical screen.
    func testOnboarding_StepNavigation_EachStepVisible() {
        loginPage.loginWithDemo()

        let introStartButton = app.buttons["OnboardingStartButton"].firstMatch
        if introStartButton.waitForExistence(timeout: 5) {
            introPage.verifyLayout()
        }
        introPage.enterOnboardingIfNeeded()

        dataSourcePage.verifyLayout()
        dataSourcePage.selectAppleHealth()
        dataSourcePage.tapContinue()

        handleHealthKitAuthSheet()
        sleep(1)

        let hrContinue = app.buttons["HeartRateZone_ContinueButton"].firstMatch
        if hrContinue.waitForExistence(timeout: 15) {
            heartRateZonePage.verifyLayout()
            heartRateZonePage.tapContinue()
        }

        let pbContinue = app.buttons["PersonalBest_ContinueButton"].firstMatch
        if pbContinue.waitForExistence(timeout: 15) {
            personalBestPage.verifyLayout()
            personalBestPage.tapContinue()
        }

        let wdContinue = app.descendants(matching: .any)["WeeklyDistance_ContinueButton"].firstMatch
        if wdContinue.waitForExistence(timeout: 15) {
            weeklyDistancePage.verifyLayout()
            weeklyDistancePage.tapContinue()
        }

        goalTypePage.verifyLayout()
        let selected = goalTypePage.selectGoalTypeIfVisible("race_run", timeout: 10)
        XCTAssertTrue(selected, "Race goal type should be selectable")
        goalTypePage.tapNext()

        raceSetupPage.verifyOptimizedLayout()
        raceSetupPage.tapSave()

        let methodologyScreen = app.descendants(matching: .any)["Methodology_Screen"].firstMatch
        if methodologyScreen.waitForExistence(timeout: 10) {
            methodologyPage.verifyLayout()
            _ = methodologyPage.selectMethodologyIfVisible("paceriz", timeout: 4)
            methodologyPage.tapNext()
        }

        let startStageScreen = app.descendants(matching: .any)["StartStage_Screen"].firstMatch
        if startStageScreen.waitForExistence(timeout: 8) {
            startStagePage.verifyLayout()
            startStagePage.tapNext()
        }

        trainingDaysPage.verifyLayout()
        trainingDaysPage.deselectAllThenSelect([1, 3, 5, 6])
        XCTAssertTrue(trainingDaysPage.tapSaveWithScroll(), "Training days screen should allow saving")
        trainingOverviewPage.verifyLayout()
    }

    /// Optimized race setup should keep a fixed CTA and expose at least one actionable entry point.
    func testRaceSetup_OptimizedLayout_ShowsPrimaryActions() {
        navigateToRaceSetup()
        captureScreenshot("race-setup-screen")
        raceSetupPage.verifyOptimizedLayout()
    }

    /// Race onboarding after race setup should still reach methodology / overview screens under Japanese longer labels.
    func testRaceRun_AfterRaceSetup_ReachesTrainingOverview() {
        navigateToRaceSetup()
        captureScreenshot("race-setup-screen")
        advanceRaceFlowToTrainingOverview()
    }

    /// Maintenance onboarding should expose training weeks and intended race distance before training preferences.
    func testOnboarding_MaintenanceFlow_UIContracts_AllCriticalScreens() {
        performCommonSteps()

        goalTypePage.verifyLayout()
        let selected = goalTypePage.selectGoalTypeIfVisible("maintenance", timeout: 10)
        XCTAssertTrue(selected, "Maintenance goal type should be selectable")
        goalTypePage.tapNext()

        let methodologyScreen = app.descendants(matching: .any)["Methodology_Screen"].firstMatch
        XCTAssertTrue(methodologyScreen.waitForExistence(timeout: 10), "Maintenance flow should show methodology selection")
        methodologyPage.verifyLayout()
        XCTAssertTrue(
            methodologyPage.ensureMethodologySelection(preferred: "paceriz", timeout: 8),
            "Maintenance flow should expose a selectable methodology or a ready default selection"
        )
        methodologyPage.tapNext()

        XCTAssertTrue(trainingWeeksPage.isStepVisible(timeout: 12), "Maintenance flow should show training weeks selection")
        trainingWeeksPage.verifyLayout()
        trainingWeeksPage.selectWeeks(12)
        trainingWeeksPage.tapNext()

        let maintenanceRaceDistanceScreen = app.descendants(matching: .any)["MaintenanceRaceDistance_Screen"].firstMatch
        XCTAssertTrue(maintenanceRaceDistanceScreen.waitForExistence(timeout: 10), "Maintenance flow should show intended race distance selection")
        maintenanceRaceDistancePage.verifyLayout()
        XCTAssertTrue(
            maintenanceRaceDistancePage.selectOptionIfVisible("halfMarathon", timeout: 4),
            "Maintenance intended race distance option should be selectable"
        )
        maintenanceRaceDistancePage.tapNext()

        trainingDaysPage.verifyLayout()
        trainingDaysPage.deselectAllThenSelect([1, 2, 4, 5, 6])
        XCTAssertTrue(trainingDaysPage.tapSaveWithScroll(), "Training days screen should allow saving")
        trainingOverviewPage.verifyLayout()
    }
}
