import CoreLocation
import CoreMotion
import HealthKit

final class PermissionGate: NSObject {
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()

    private static var requiredHealthShareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
    }

    private static var requiredHealthReadTypes: Set<HKObjectType> {
        var readTypes = Set<HKObjectType>(requiredHealthShareTypes.map { $0 as HKObjectType })
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distance)
        }
        return readTypes
    }

    func requestAll(completion: @escaping (Bool) -> Void) {
        healthStore.requestAuthorization(
            toShare: Self.requiredHealthShareTypes,
            read: Self.requiredHealthReadTypes
        ) { [weak self] ok, _ in
            guard ok, let self else {
                completion(false)
                return
            }

            self.locationManager.requestWhenInUseAuthorization()
            completion(self.allGranted())
        }
    }

    func allGranted() -> Bool {
        Self.hasAllRequiredPermissions(
            locationStatus: locationManager.authorizationStatus,
            motionAvailable: CMMotionActivityManager.isActivityAvailable(),
            healthSharingStatuses: Self.requiredHealthShareTypes.map {
                healthStore.authorizationStatus(for: $0)
            }
        )
    }

    static func hasAllRequiredPermissions(
        locationStatus: CLAuthorizationStatus,
        motionAvailable: Bool,
        healthSharingStatuses: [HKAuthorizationStatus]
    ) -> Bool {
        let locationGranted = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
        let healthGranted = !healthSharingStatuses.isEmpty &&
            healthSharingStatuses.allSatisfy { $0 == .sharingAuthorized }
        return locationGranted && motionAvailable && healthGranted
    }
}
