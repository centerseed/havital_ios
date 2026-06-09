import HealthKit
import XCTest
@testable import HavitalWatch

final class HealthKitWorkoutWritePayloadTests: XCTestCase {
    func test_configuration_isRunningWithExpectedLocationType() {
        let outdoor = HealthKitWorkoutWritePayload.configuration(indoor: false)
        XCTAssertEqual(outdoor.activityType, .running)
        XCTAssertEqual(outdoor.locationType, .outdoor)

        let indoor = HealthKitWorkoutWritePayload.configuration(indoor: true)
        XCTAssertEqual(indoor.activityType, .running)
        XCTAssertEqual(indoor.locationType, .indoor)
    }

    func test_metadata_containsPacerizUUIDIndoorFlagAndValidRPE() {
        let uuid = "9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b"

        let metadata = HealthKitWorkoutWritePayload.metadata(
            workoutUUID: uuid,
            indoor: true,
            rpe: 7
        )

        XCTAssertEqual(metadata?[WorkoutUUIDValidator.metadataKey] as? String, uuid)
        XCTAssertEqual(metadata?[HKMetadataKeyIndoorWorkout] as? Bool, true)
        XCTAssertEqual(metadata?[HealthKitWorkoutWritePayload.rpeMetadataKey] as? Int, 7)
    }

    func test_metadata_marksWorkoutAsRecordedByPacerizWatchApp() {
        let metadata = HealthKitWorkoutWritePayload.metadata(
            workoutUUID: "9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b",
            indoor: false,
            rpe: nil
        )

        // Attribution must be present on every Paceriz-watch-written workout so the
        // backend / Health app can tell it apart from imports and the iPhone app.
        XCTAssertEqual(metadata?[HKMetadataKeyWorkoutBrandName] as? String, "Paceriz")
        XCTAssertEqual(
            metadata?[HealthKitWorkoutWritePayload.recordedByMetadataKey] as? String,
            "watchos_app"
        )
    }

    func test_metadataRejectsInvalidUUIDAndOmitsInvalidRPE() {
        XCTAssertNil(
            HealthKitWorkoutWritePayload.metadata(
                workoutUUID: "9B2E4F1A-3C4D-4E5F-8A9B-0C1D2E3F4A5B",
                indoor: false,
                rpe: 7
            )
        )

        let metadata = HealthKitWorkoutWritePayload.metadata(
            workoutUUID: "9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b",
            indoor: false,
            rpe: 11
        )

        XCTAssertEqual(metadata?[WorkoutUUIDValidator.metadataKey] as? String, "9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b")
        XCTAssertNil(metadata?[HealthKitWorkoutWritePayload.rpeMetadataKey])
    }

    func test_segmentEventUsesSegmentTypeAndExactDateInterval() {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 250)

        let event = HealthKitWorkoutWritePayload.segmentEvent(
            start: start,
            end: end,
            distanceMeters: 800
        )

        XCTAssertEqual(event.type, .segment)
        XCTAssertEqual(event.dateInterval.start, start)
        XCTAssertEqual(event.dateInterval.end, end)
        let lapLength = event.metadata?[HKMetadataKeyLapLength] as? HKQuantity
        XCTAssertEqual(lapLength?.doubleValue(for: .meter()), 800)
    }

    func test_routePolicyRequiresOutdoorLocationDataOnly() {
        XCTAssertFalse(HealthKitWorkoutWritePayload.shouldFinishRoute(indoor: true, routeLocationCount: 3))
        XCTAssertFalse(HealthKitWorkoutWritePayload.shouldFinishRoute(indoor: false, routeLocationCount: 0))
        XCTAssertTrue(HealthKitWorkoutWritePayload.shouldFinishRoute(indoor: false, routeLocationCount: 1))
    }
}
