import XCTest
@testable import paceriz_dev

final class WeekMetricsCalculatorTests: XCTestCase {

    // MARK: - Fixtures

    /// Build a WeekDateInfo anchored at a known Monday (2026-04-13).
    private func makeWeekInfo(
        mondayOffset: Int = 0
    ) -> WeekDateInfo {
        // 2026-04-13 is a Monday (UTC)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let base = date("2026-04-13T00:00:00Z")
        let weekStart = calendar.date(byAdding: .day, value: mondayOffset * 7, to: base)!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            .addingTimeInterval(86399)

        var daysMap: [Int: Date] = [:]
        for i in 0..<7 {
            daysMap[i + 1] = calendar.date(byAdding: .day, value: i, to: weekStart)!
        }
        return WeekDateInfo(startDate: weekStart, endDate: weekEnd, daysMap: daysMap)
    }

    /// Create a WorkoutV2 with the given activity type, start time (ISO8601), distance, and intensity.
    private func makeWorkout(
        id: String = "w1",
        activityType: String = "running",
        startTimeUtc: String = "2026-04-14T08:00:00Z",
        distanceMeters: Double? = nil,
        lowMin: Double? = nil,
        mediumMin: Double? = nil,
        highMin: Double? = nil
    ) -> WorkoutV2 {
        let intensity: AdvancedMetrics?
        if lowMin != nil || mediumMin != nil || highMin != nil {
            let apiIntensity = APIIntensityMinutes(low: lowMin, medium: mediumMin, high: highMin)
            intensity = AdvancedMetrics(intensityMinutes: apiIntensity)
        } else {
            intensity = nil
        }

        return WorkoutV2(
            id: id,
            provider: "apple_health",
            activityType: activityType,
            startTimeUtc: startTimeUtc,
            endTimeUtc: startTimeUtc,
            durationSeconds: 3600,
            distanceMeters: distanceMeters,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: nil,
            basicMetrics: nil,
            advancedMetrics: intensity,
            createdAt: nil,
            schemaVersion: "2.0",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }

    private func date(_ iso: String) -> Date {
        let fmt = ISO8601DateFormatter()
        return fmt.date(from: iso)!
    }

    // MARK: - groupWorkoutsByDay

    func test_groupWorkoutsByDay_emptyWorkouts_returnsEmpty() {
        let weekInfo = makeWeekInfo()
        let result = WeekMetricsCalculator.groupWorkoutsByDay([], weekInfo: weekInfo)
        XCTAssertTrue(result.isEmpty)
    }

    func test_groupWorkoutsByDay_filtersNonRunningTypes() {
        // swimming and cycling should not appear
        let weekInfo = makeWeekInfo()
        let workouts = [
            makeWorkout(id: "s1", activityType: "swimming", startTimeUtc: "2026-04-14T08:00:00Z"),
            makeWorkout(id: "c1", activityType: "cycling", startTimeUtc: "2026-04-14T08:00:00Z"),
            makeWorkout(id: "r1", activityType: "running", startTimeUtc: "2026-04-14T08:00:00Z")
        ]
        let result = WeekMetricsCalculator.groupWorkoutsByDay(workouts, weekInfo: weekInfo)
        let allIDs = result.values.flatMap { $0 }.map { $0.id }
        XCTAssertFalse(allIDs.contains("s1"), "swimming should be filtered")
        XCTAssertFalse(allIDs.contains("c1"), "cycling should be filtered")
        XCTAssertTrue(allIDs.contains("r1"), "running should be retained")
    }

    func test_groupWorkoutsByDay_filtersOutsideWeekRange() {
        // workout from the previous week should be excluded
        let weekInfo = makeWeekInfo()  // week of 2026-04-13
        let workouts = [
            makeWorkout(id: "prev", activityType: "running", startTimeUtc: "2026-04-06T08:00:00Z"),
            makeWorkout(id: "curr", activityType: "running", startTimeUtc: "2026-04-14T08:00:00Z")
        ]
        let result = WeekMetricsCalculator.groupWorkoutsByDay(workouts, weekInfo: weekInfo)
        let allIDs = result.values.flatMap { $0 }.map { $0.id }
        XCTAssertFalse(allIDs.contains("prev"), "previous-week workout should be filtered")
        XCTAssertTrue(allIDs.contains("curr"), "current-week workout should be retained")
    }

    func test_groupWorkoutsByDay_sortsByEndDateDesc() {
        // Two runs on the same day — the later one should be first in the array.
        let weekInfo = makeWeekInfo()
        let workouts = [
            makeWorkout(id: "early", activityType: "running", startTimeUtc: "2026-04-14T06:00:00Z"),
            makeWorkout(id: "late", activityType: "running", startTimeUtc: "2026-04-14T10:00:00Z")
        ]
        let result = WeekMetricsCalculator.groupWorkoutsByDay(workouts, weekInfo: weekInfo)
        // Day 2 = Tuesday (2026-04-14)
        guard let tuesdayWorkouts = result[2] else {
            XCTFail("Expected workouts on day 2 (Tuesday)")
            return
        }
        XCTAssertEqual(tuesdayWorkouts.count, 2)
        XCTAssertEqual(tuesdayWorkouts[0].id, "late", "Later workout should sort first")
        XCTAssertEqual(tuesdayWorkouts[1].id, "early")
    }

    // MARK: - metrics

    func test_metrics_emptyWorkouts_returnsZero() {
        let weekInfo = makeWeekInfo()
        let result = WeekMetricsCalculator.metrics(for: [], weekInfo: weekInfo)
        XCTAssertEqual(result.totalDistanceKm, 0.0)
        XCTAssertEqual(result.intensity.low, 0.0)
        XCTAssertEqual(result.intensity.medium, 0.0)
        XCTAssertEqual(result.intensity.high, 0.0)
    }

    func test_metrics_aggregatesDistanceAndIntensity() {
        let weekInfo = makeWeekInfo()
        let workouts = [
            makeWorkout(
                id: "w1",
                activityType: "running",
                startTimeUtc: "2026-04-14T08:00:00Z",
                distanceMeters: 5000,
                lowMin: 10, mediumMin: 20, highMin: 5
            ),
            makeWorkout(
                id: "w2",
                activityType: "walking",
                startTimeUtc: "2026-04-15T08:00:00Z",
                distanceMeters: 3000,
                lowMin: 30, mediumMin: 5, highMin: 2
            )
        ]
        let result = WeekMetricsCalculator.metrics(for: workouts, weekInfo: weekInfo)
        XCTAssertEqual(result.totalDistanceKm, 8.0, accuracy: 0.001)
        XCTAssertEqual(result.intensity.low, 40.0, accuracy: 0.001)
        XCTAssertEqual(result.intensity.medium, 25.0, accuracy: 0.001)
        XCTAssertEqual(result.intensity.high, 7.0, accuracy: 0.001)
    }
}
