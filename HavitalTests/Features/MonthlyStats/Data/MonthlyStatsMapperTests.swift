import XCTest
@testable import paceriz_dev

final class MonthlyStatsMapperTests: XCTestCase {

    func testToDailyStatMapsDTOFields() {
        let dto = DailyStatsDTO(
            date: "2026-04-18",
            totalDistanceKm: 12.3,
            avgPacePerKm: 315,
            workoutCount: 2
        )

        let entity = MonthlyStatsMapper.toDailyStat(from: dto)

        XCTAssertEqual(entity.date, "2026-04-18")
        XCTAssertEqual(entity.totalDistanceKm, 12.3)
        XCTAssertEqual(entity.avgPacePerKm, 315)
        XCTAssertEqual(entity.workoutCount, 2)
    }

    func testToDailyStatsExtractsNestedDataFromResponse() {
        let response = MonthlyStatsDTO(
            success: true,
            message: nil,
            data: MonthlyStatsDataDTO(
                year: 2026,
                month: 4,
                timezone: "Asia/Tokyo",
                dailyStats: [
                    DailyStatsDTO(date: "2026-04-01", totalDistanceKm: 5.0, avgPacePerKm: 360, workoutCount: 1),
                    DailyStatsDTO(date: "2026-04-02", totalDistanceKm: 0, avgPacePerKm: nil, workoutCount: 0)
                ],
                monthlySummary: MonthlySummaryDTO(
                    totalDistanceKm: 5.0,
                    totalWorkouts: 1,
                    daysWithWorkouts: 1
                )
            )
        )

        let stats = MonthlyStatsMapper.toDailyStats(from: response)

        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats[0].date, "2026-04-01")
        XCTAssertEqual(stats[1].workoutCount, 0)
    }

    func testToDailyStatsDTORoundTripsEntity() {
        let entity = DailyStat(
            date: "2026-04-19",
            totalDistanceKm: 18.5,
            avgPacePerKm: 290,
            workoutCount: 1
        )

        let dto = MonthlyStatsMapper.toDailyStatsDTO(from: entity)

        XCTAssertEqual(dto.date, entity.date)
        XCTAssertEqual(dto.totalDistanceKm, entity.totalDistanceKm)
        XCTAssertEqual(dto.avgPacePerKm, entity.avgPacePerKm)
        XCTAssertEqual(dto.workoutCount, entity.workoutCount)
    }
}
