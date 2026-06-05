import XCTest
import HealthKit
@testable import paceriz_dev

final class PacerizRPEMetadataTests: XCTestCase {
    func test_validIntegerRPE_isExtracted() {
        let workout = makeWorkout(metadata: ["com.paceriz.rpe": 7])

        XCTAssertEqual(AppleHealthWorkoutUploadService.extractPacerizRPE(from: workout), 7)
    }

    func test_validNSNumberRPE_isExtracted() {
        let workout = makeWorkout(metadata: ["com.paceriz.rpe": NSNumber(value: 8)])

        XCTAssertEqual(AppleHealthWorkoutUploadService.extractPacerizRPE(from: workout), 8)
    }

    func test_outOfRangeRPE_isIgnored() {
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: makeWorkout(metadata: ["com.paceriz.rpe": 0])))
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: makeWorkout(metadata: ["com.paceriz.rpe": 11])))
    }

    func test_missingRPE_returnsNil() {
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: makeWorkout(metadata: nil)))
    }

    private func makeWorkout(metadata: [String: Any]?) -> HKWorkout {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return HKWorkout(
            activityType: .running,
            start: start,
            end: start.addingTimeInterval(600),
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 2_000),
            metadata: metadata
        )
    }
}
