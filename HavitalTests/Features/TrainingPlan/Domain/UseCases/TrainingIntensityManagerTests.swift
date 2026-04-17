import XCTest
import HealthKit
@testable import paceriz_dev

final class TrainingIntensityManagerTests: XCTestCase {
    private var originalMaxHR: Int?
    private var originalRestingHR: Int?

    override func setUp() {
        super.setUp()
        let preferences = UserPreferencesManager.shared
        originalMaxHR = preferences.maxHeartRate
        originalRestingHR = preferences.restingHeartRate
        preferences.maxHeartRate = 190
        preferences.restingHeartRate = 60
    }

    override func tearDown() {
        let preferences = UserPreferencesManager.shared
        preferences.maxHeartRate = originalMaxHR
        preferences.restingHeartRate = originalRestingHR
        super.tearDown()
    }

    func testCalculateIntensity_EmptyWorkouts_ReturnsZero() async {
        let manager = TrainingIntensityManager.shared
        let healthKit = MockHealthKitManager()

        let result = await manager.calculateIntensity(for: [], healthKitManager: healthKit)

        XCTAssertEqual(result.low, 0, accuracy: 0.001)
        XCTAssertEqual(result.medium, 0, accuracy: 0.001)
        XCTAssertEqual(result.high, 0, accuracy: 0.001)
    }

    func testCalculateIntensity_NonSupportedWorkout_Ignored() async {
        let manager = TrainingIntensityManager.shared
        let healthKit = MockHealthKitManager()
        let workout = makeWorkout(type: .yoga, durationMinutes: 45)

        let result = await manager.calculateIntensity(for: [workout], healthKitManager: healthKit)

        XCTAssertEqual(result.low, 0, accuracy: 0.001)
        XCTAssertEqual(result.medium, 0, accuracy: 0.001)
        XCTAssertEqual(result.high, 0, accuracy: 0.001)
        XCTAssertEqual(healthKit.fetchHeartRateCallCount, 0)
    }

    func testCalculateIntensity_RunningWithoutHeartRate_UsesDurationAsLowIntensity() async {
        let manager = TrainingIntensityManager.shared
        let healthKit = MockHealthKitManager()
        let workout = makeWorkout(type: .running, durationMinutes: 30)
        healthKit.heartRateDataByWorkoutID[workout.uuid] = []

        let result = await manager.calculateIntensity(for: [workout], healthKitManager: healthKit)

        XCTAssertEqual(result.low, 30, accuracy: 0.01)
        XCTAssertEqual(result.medium, 0, accuracy: 0.01)
        XCTAssertEqual(result.high, 0, accuracy: 0.01)
    }

    func testCalculateIntensity_HeartRateFetchFails_FallsBackToDuration() async {
        let manager = TrainingIntensityManager.shared
        let healthKit = MockHealthKitManager()
        let workout = makeWorkout(type: .running, durationMinutes: 25)
        healthKit.failingWorkoutIDs.insert(workout.uuid)

        let result = await manager.calculateIntensity(for: [workout], healthKitManager: healthKit)

        XCTAssertEqual(result.low, 25, accuracy: 0.01)
        XCTAssertEqual(result.medium, 0, accuracy: 0.01)
        XCTAssertEqual(result.high, 0, accuracy: 0.01)
    }

    func testCalculateWeeklyIntensity_WhenFetchWorkoutsFails_ReturnsZero() async {
        let manager = TrainingIntensityManager.shared
        let healthKit = MockHealthKitManager()
        healthKit.shouldFailFetchingWorkouts = true

        let result = await manager.calculateWeeklyIntensity(
            weekStartDate: Date(),
            healthKitManager: healthKit
        )

        XCTAssertEqual(result.low, 0, accuracy: 0.001)
        XCTAssertEqual(result.medium, 0, accuracy: 0.001)
        XCTAssertEqual(result.high, 0, accuracy: 0.001)
    }

    private func makeWorkout(type: HKWorkoutActivityType, durationMinutes: Double) -> HKWorkout {
        let start = Date()
        let end = start.addingTimeInterval(durationMinutes * 60)
        return HKWorkout(
            activityType: type,
            start: start,
            end: end,
            duration: durationMinutes * 60,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )
    }
}

private final class MockHealthKitManager: HealthKitManager {
    var fetchHeartRateCallCount = 0
    var heartRateDataByWorkoutID: [UUID: [(Date, Double)]] = [:]
    var failingWorkoutIDs = Set<UUID>()
    var shouldFailFetchingWorkouts = false

    override func fetchHeartRateData(
        for workout: HKWorkout,
        forceRefresh: Bool = false,
        retryAttempt: Int = 0
    ) async throws -> [(Date, Double)] {
        fetchHeartRateCallCount += 1
        if failingWorkoutIDs.contains(workout.uuid) {
            throw NSError(domain: "MockHealthKitManager", code: -1)
        }
        return heartRateDataByWorkoutID[workout.uuid] ?? []
    }

    override func fetchWorkoutsForDateRange(start: Date, end: Date) async throws -> [HKWorkout] {
        if shouldFailFetchingWorkouts {
            throw NSError(domain: "MockHealthKitManager", code: -2)
        }
        return []
    }
}
