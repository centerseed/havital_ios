//
//  OnboardingBeginnerE2ETests.swift
//  HavitalUITests
//
//  E2E tests for beginner goal type onboarding flows
//

import XCTest

final class OnboardingBeginnerE2ETests: OnboardingE2ETestBase {

    // Case 5: beginner + default + 3 days
    func testCase05_Beginner_Default() {
        runOnboardingFlow(config: TestMatrix.beginnerDefault)
        verifyOnboardingComplete()
    }

    // Case 6: beginner + alternate + 12w + 3 days
    func testCase06_Beginner_Alternate_12w() {
        runOnboardingFlow(config: TestMatrix.beginnerAlternate12w)
        verifyOnboardingComplete()
    }

    // Case 12: beginner + default + 24w (max) + 7 days (all)
    func testCase12_Beginner_Default_24w_Max_7days() {
        runOnboardingFlow(config: TestMatrix.beginnerDefault24w)
        verifyOnboardingComplete()
    }
}
