import CoreLocation
import HealthKit
import XCTest
@testable import HavitalWatch

final class PermissionGateTests: XCTestCase {
    func test_allRequiredPermissions_requiresWorkoutAndRouteSharing() {
        XCTAssertFalse(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .authorizedWhenInUse,
            motionAvailable: true,
            healthSharingStatuses: [.sharingAuthorized, .notDetermined]
        ))
    }

    func test_allRequiredPermissions_requiresLocation() {
        XCTAssertFalse(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .denied,
            motionAvailable: true,
            healthSharingStatuses: [.sharingAuthorized, .sharingAuthorized]
        ))
    }

    func test_allRequiredPermissions_passesWhenHealthLocationAndMotionAreReady() {
        XCTAssertTrue(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .authorizedWhenInUse,
            motionAvailable: true,
            healthSharingStatuses: [.sharingAuthorized, .sharingAuthorized]
        ))
    }
}
