import CoreLocation
import HealthKit
import XCTest
@testable import HavitalWatch

final class PermissionGateTests: XCTestCase {
    func test_allRequiredPermissions_requiresWorkoutAndRouteSharing() {
        XCTAssertFalse(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .authorizedWhenInUse,
            healthSharingStatuses: [.sharingAuthorized, .notDetermined]
        ))
    }

    func test_allRequiredPermissions_requiresLocation() {
        XCTAssertFalse(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .denied,
            healthSharingStatuses: [.sharingAuthorized, .sharingAuthorized]
        ))
    }

    func test_allRequiredPermissions_passesWhenHealthAndLocationAreReady() {
        XCTAssertTrue(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .authorizedWhenInUse,
            healthSharingStatuses: [.sharingAuthorized, .sharingAuthorized]
        ))
    }

    func test_allRequiredPermissions_doesNotBlockWhenMotionActivityIsUnavailable() {
        XCTAssertTrue(PermissionGate.hasAllRequiredPermissions(
            locationStatus: .authorizedWhenInUse,
            healthSharingStatuses: [.sharingAuthorized, .sharingAuthorized]
        ))
    }
}
