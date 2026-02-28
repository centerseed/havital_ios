//
//  OnboardingMaintenanceE2ETests.swift
//  HavitalUITests
//
//  E2E tests for maintenance goal type onboarding flows
//

import XCTest

final class OnboardingMaintenanceE2ETests: OnboardingE2ETestBase {

    // Case 7: maintenance + paceriz + 12w + 5 days
    func testCase07_Maintenance_Paceriz_12w() {
        runOnboardingFlow(config: TestMatrix.maintenancePaceriz12w)
        verifyOnboardingComplete()
    }

    // Case 8: maintenance + alternate + 16w + 3 days
    func testCase08_Maintenance_Alternate_16w() {
        runOnboardingFlow(config: TestMatrix.maintenanceAlternate16w)
        verifyOnboardingComplete()
    }

    // Case 10: maintenance + default + 4w (min) + 2 days
    func testCase10_Maintenance_Default_4w_Min() {
        runOnboardingFlow(config: TestMatrix.maintenanceDefault4w)
        verifyOnboardingComplete()
    }
}
