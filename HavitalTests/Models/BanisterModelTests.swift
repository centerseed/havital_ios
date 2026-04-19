import XCTest
@testable import paceriz_dev

final class BanisterModelTests: XCTestCase {

    func testCalculateTrimpIncreasesWithHigherHeartRate() {
        let sut = BanisterModel()

        let lowIntensity = sut.calculateTrimp(
            duration: 3_600,
            avgHR: 130,
            restingHR: 60,
            maxHR: 190
        )
        let highIntensity = sut.calculateTrimp(
            duration: 3_600,
            avgHR: 160,
            restingHR: 60,
            maxHR: 190
        )

        XCTAssertGreaterThan(highIntensity, lowIntensity)
    }

    func testUpdateFirstWorkoutLowersPerformanceFromBaseline() {
        let sut = BanisterModel()

        sut.update(date: makeDate("2026-04-01"), trimp: 50)

        XCTAssertEqual(sut.performance(), 50, accuracy: 0.001)
    }

    func testUpdateSameDayAccumulatesTrainingLoad() {
        let sut = BanisterModel()

        sut.update(date: makeDate("2026-04-01"), trimp: 40)
        sut.update(date: makeDate("2026-04-01"), trimp: 20)

        XCTAssertEqual(sut.performance(), 40, accuracy: 0.001)
    }

    func testUpdateRestDayDecaysTowardBaseline() {
        let sut = BanisterModel()

        sut.update(date: makeDate("2026-04-01"), trimp: 80)
        let trainedPerformance = sut.performance()

        sut.update(date: makeDate("2026-04-02"))

        XCTAssertGreaterThan(sut.performance(), trainedPerformance)
        XCTAssertLessThan(sut.performance(), 100)
    }

    func testGetPerformanceForFutureDateAppliesDecay() {
        let sut = BanisterModel()

        sut.update(date: makeDate("2026-04-01"), trimp: 80)
        let current = sut.performance()
        let future = sut.getPerformanceForDate(makeDate("2026-04-08"))

        XCTAssertGreaterThan(future, current)
        XCTAssertLessThan(future, 100)
    }

    func testResetRestoresBaselinePerformance() {
        let sut = BanisterModel()

        sut.update(date: makeDate("2026-04-01"), trimp: 80)
        sut.reset()

        XCTAssertEqual(sut.performance(), 100, accuracy: 0.001)
        XCTAssertEqual(sut.getPerformanceForDate(makeDate("2026-04-08")), 100, accuracy: 0.001)
    }

    private func makeDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: value)!
    }
}
