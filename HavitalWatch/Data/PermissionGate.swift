import CoreLocation
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

    #if DEBUG
    /// Set by the `-injectTodayPlan` sync-test hook so the simulator can render the
    /// synced start view — HealthKit authorization cannot be granted headlessly via
    /// simctl, so the gate would otherwise always block on the sim.
    static var debugAssumeGranted = false
    #endif

    func allGranted() -> Bool {
        #if DEBUG
        if Self.debugAssumeGranted { return true }
        #endif
        return Self.hasAllRequiredPermissions(
            locationStatus: locationManager.authorizationStatus,
            healthSharingStatuses: Self.requiredHealthShareTypes.map {
                healthStore.authorizationStatus(for: $0)
            }
        )
    }

    static func hasAllRequiredPermissions(
        locationStatus: CLAuthorizationStatus,
        healthSharingStatuses: [HKAuthorizationStatus]
    ) -> Bool {
        let locationGranted = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
        let healthGranted = !healthSharingStatuses.isEmpty &&
            healthSharingStatuses.allSatisfy { $0 == .sharingAuthorized }
        return locationGranted && healthGranted
    }
}
