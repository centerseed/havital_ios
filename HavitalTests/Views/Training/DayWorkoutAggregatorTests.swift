import XCTest
@testable import paceriz_dev

final class DayWorkoutAggregatorTests: XCTestCase {

    private func wk(_ activity: String, _ runType: String?, km: Double, day: Int) -> DayWorkoutAggregator.Input {
        let date = DateComponents(calendar: .current, year: 2026, month: 6, day: day, hour: 8).date!
        return DayWorkoutAggregator.Input(
            startDate: date,
            activityType: activity,
            displayTrainingType: runType,
            distanceMeters: km * 1000,
            duration: 1800
        )
    }

    private func dayKey(_ day: Int) -> TimeInterval {
        let date = DateComponents(calendar: .current, year: 2026, month: 6, day: day, hour: 8).date!
        return Calendar.current.startOfDay(for: date).timeIntervalSince1970
    }

    func test_sameDay_twoDifferentRunTypes_splitIntoTwoBreakdowns() {
        let input = [wk("running", "easy", km: 5, day: 10), wk("running", "interval", km: 8, day: 10)]
        let result = DayWorkoutAggregator.aggregate(workouts: input, calendar: .current)
        let day = result[dayKey(10)]!
        XCTAssertEqual(day.breakdown.count, 2)
        XCTAssertEqual(Set(day.breakdown.map { $0.bucket }), [.green, .orange])
    }

    func test_runWithoutRunType_fallsBackToGreen_perD5() {
        let input = [wk("running", nil, km: 6, day: 11)]
        let result = DayWorkoutAggregator.aggregate(workouts: input, calendar: .current)
        XCTAssertEqual(result[dayKey(11)]!.breakdown.first!.bucket, .green)
    }

    func test_runPlusStrength_splitByDisplayType() {
        let input = [wk("running", "easy", km: 5, day: 12), wk("strength", nil, km: 0, day: 12)]
        let result = DayWorkoutAggregator.aggregate(workouts: input, calendar: .current)
        let buckets = Set(result[dayKey(12)]!.breakdown.map { $0.bucket })
        XCTAssertEqual(buckets, [.green, .indigo])
    }

    func test_restExcluded() {
        let input = [wk("rest", nil, km: 0, day: 13)]
        let result = DayWorkoutAggregator.aggregate(workouts: input, calendar: .current)
        XCTAssertTrue(result.isEmpty)
    }
}
