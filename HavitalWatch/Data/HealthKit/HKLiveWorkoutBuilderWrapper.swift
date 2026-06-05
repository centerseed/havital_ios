import CoreLocation
import HealthKit

final class HKLiveWorkoutBuilderWrapper: NSObject, WorkoutBuilding {
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var indoor = false
    private var routeLocationCount = 0
    private var startDate: Date?
    private var lastSpeedMeters: Double?
    private var lastSpeedDate: Date?

    let workoutUUID = WorkoutUUIDValidator.generate()

    var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start(indoor: Bool) throws {
        self.indoor = indoor
        routeLocationCount = 0
        lastSpeedMeters = nil
        lastSpeedDate = nil

        let configuration = HealthKitWorkoutWritePayload.configuration(indoor: indoor)

        let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let workoutBuilder = workoutSession.associatedWorkoutBuilder()
        workoutBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        workoutBuilder.delegate = self

        session = workoutSession
        builder = workoutBuilder
        routeBuilder = indoor ? nil : HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

        let startDate = Date()
        self.startDate = startDate
        workoutSession.startActivity(with: startDate)
        workoutBuilder.beginCollection(withStart: startDate) { _, _ in }

        if !indoor {
            locationManager.startUpdatingLocation()
        }
    }

    func pause() {
        session?.pause()
        if !indoor {
            locationManager.stopUpdatingLocation()
        }
    }

    func resume() {
        session?.resume()
        if !indoor {
            locationManager.startUpdatingLocation()
        }
    }

    func markSegment(start: Date, end: Date, distanceMeters: Double?) {
        let event = HealthKitWorkoutWritePayload.segmentEvent(
            start: start,
            end: end,
            distanceMeters: distanceMeters
        )
        builder?.addWorkoutEvents([event]) { _, _ in }
    }

    func appendLocations(_ locations: [CLLocation]) {
        guard !indoor, !locations.isEmpty else { return }
        routeLocationCount += locations.count
        routeBuilder?.insertRouteData(locations) { _, _ in }
    }

    func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
        guard
            let builder,
            let metadata = HealthKitWorkoutWritePayload.metadata(
                workoutUUID: workoutUUID,
                indoor: indoor,
                rpe: rpe
            )
        else {
            NSLog("[Watch] invalid workout_uuid: %@ - abort finish", workoutUUID)
            completion(false)
            return
        }

        builder.addMetadata(metadata) { [weak self] metadataAdded, _ in
            guard let self, metadataAdded else {
                completion(false)
                return
            }

            self.session?.end()
            self.locationManager.stopUpdatingLocation()
            builder.endCollection(withEnd: Date()) { [weak self] didEnd, _ in
                guard let self, didEnd else {
                    completion(false)
                    return
                }

                builder.finishWorkout { workout, _ in
                    guard let workout else {
                        completion(false)
                        return
                    }

                    if self.indoor {
                        completion(true)
                        return
                    }

                    guard
                        HealthKitWorkoutWritePayload.shouldFinishRoute(
                            indoor: self.indoor,
                            routeLocationCount: self.routeLocationCount
                        ),
                        let routeBuilder = self.routeBuilder
                    else {
                        completion(false)
                        return
                    }

                    routeBuilder.finishRoute(with: workout, metadata: nil) { _, _ in
                        completion(true)
                    }
                }
            }
        }
    }
}

extension HKLiveWorkoutBuilderWrapper: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        guard let startDate else { return }

        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)

        let meters = distanceType
            .flatMap { workoutBuilder.statistics(for: $0) }
            .flatMap { $0.sumQuantity() }?
            .doubleValue(for: .meter()) ?? 0

        let heartRate = heartRateType
            .flatMap { workoutBuilder.statistics(for: $0) }
            .flatMap { $0.mostRecentQuantity() }?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0

        let now = Date()
        let seconds = max(0, Int(now.timeIntervalSince(startDate)))
        let recentSpeedMps: Double
        if
            let lastSpeedMeters,
            let lastSpeedDate,
            now.timeIntervalSince(lastSpeedDate) > 0
        {
            recentSpeedMps = max(0, meters - lastSpeedMeters) / now.timeIntervalSince(lastSpeedDate)
        } else {
            recentSpeedMps = 0
        }

        self.lastSpeedMeters = meters
        self.lastSpeedDate = now
        onMetrics?(meters, seconds, heartRate, recentSpeedMps)
    }
}

extension HKLiveWorkoutBuilderWrapper: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let validLocations = locations.filter { $0.horizontalAccuracy >= 0 }
        appendLocations(validLocations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("[Watch] route location update failed: %@", String(describing: error))
    }
}
