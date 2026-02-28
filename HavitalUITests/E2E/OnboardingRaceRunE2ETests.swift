//
//  OnboardingRaceRunE2ETests.swift
//  HavitalUITests
//
//  E2E tests for race_run goal type onboarding flows
//

import XCTest

final class OnboardingRaceRunE2ETests: OnboardingE2ETestBase {

    // Case 1: race_run + paceriz + 42k marathon 4h + 4 days
    func testCase01_RaceRun_Paceriz_Marathon_4h() {
        runOnboardingFlow(config: TestMatrix.raceRunPacerizMarathon)
        verifyOnboardingComplete()
    }

    // Case 2: race_run + hansons + 21k half 1h50m + 5 days
    func testCase02_RaceRun_Hansons_Half_1h50m() {
        runOnboardingFlow(config: TestMatrix.raceRunHansonsHalf)
        verifyOnboardingComplete()
    }

    // Case 3: race_run + polarized + 10k 50min + 3 days
    func testCase03_RaceRun_Polarized_10k_50m() {
        runOnboardingFlow(config: TestMatrix.raceRunPolarized10k)
        verifyOnboardingComplete()
    }

    // Case 4: race_run + norwegian + 5k 25min + 5 days
    func testCase04_RaceRun_Norwegian_5k_25m() {
        runOnboardingFlow(config: TestMatrix.raceRunNorwegian5k)
        verifyOnboardingComplete()
    }

    // Case 9: race_run + paceriz + 42k 3h30m + 7 days (all days)
    func testCase09_RaceRun_Paceriz_Marathon_3h30_7days() {
        runOnboardingFlow(config: TestMatrix.raceRunPacerizMarathon7days)
        verifyOnboardingComplete()
    }

    // Case 11: race_run + paceriz + 21k 2h15m + 2 days (minimum)
    func testCase11_RaceRun_Paceriz_Half_2h15_2days() {
        runOnboardingFlow(config: TestMatrix.raceRunPacerizHalf2days)
        verifyOnboardingComplete()
    }
}
