import HealthKit

enum HealthKitWorkoutWritePayload {
    static let rpeMetadataKey = "com.paceriz.rpe"
    /// Marks the workout as recorded by the Paceriz watchOS app specifically (vs the
    /// iPhone app or a backend-synced Garmin/Strava import). HealthKit's source revision
    /// already carries the watch bundle id, but an explicit marker survives the backend
    /// round-trip and is unambiguous to query.
    static let recordedByMetadataKey = "com.paceriz.recorded_by"
    static let recordedByValue = "watchos_app"
    static let brandName = "Paceriz"

    static func configuration(indoor: Bool) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = indoor ? .indoor : .outdoor
        return configuration
    }

    static func metadata(workoutUUID: String, indoor: Bool, rpe: Int?) -> [String: Any]? {
        guard WorkoutUUIDValidator.isValid(workoutUUID) else { return nil }

        var metadata: [String: Any] = [
            WorkoutUUIDValidator.metadataKey: workoutUUID,
            HKMetadataKeyIndoorWorkout: indoor,
            HKMetadataKeyWorkoutBrandName: brandName,
            recordedByMetadataKey: recordedByValue
        ]

        if let rpe, (1...10).contains(rpe) {
            metadata[rpeMetadataKey] = rpe
        }

        return metadata
    }

    static func segmentEvent(start: Date, end: Date, distanceMeters: Double?) -> HKWorkoutEvent {
        let metadata: [String: Any]?
        if let distanceMeters, distanceMeters > 0 {
            metadata = [
                HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: distanceMeters)
            ]
        } else {
            metadata = nil
        }

        return HKWorkoutEvent(
            type: .segment,
            dateInterval: DateInterval(start: start, end: end),
            metadata: metadata
        )
    }

    static func shouldFinishRoute(indoor: Bool, routeLocationCount: Int) -> Bool {
        !indoor && routeLocationCount > 0
    }
}
