import XCTest
@testable import paceriz_dev

final class MonthlyStatsRemoteDataSourceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: MonthlyStatsRemoteDataSource!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = MonthlyStatsRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testFetchMonthlyStatsBuildsPathAndParsesResponse() async throws {
        let path = "/v2/workout/monthly_stats?year=2026&month=4&activity_type=running"
        let response = makeResponse(
            dailyStats: [
                DailyStatsDTO(date: "2026-04-18", totalDistanceKm: 8.0, avgPacePerKm: 320, workoutCount: 1)
            ]
        )
        try mockHTTPClient.setJSONResponse(for: path, response: response)

        let result = try await sut.fetchMonthlyStats(year: 2026, month: 4)

        XCTAssertEqual(result.data.year, 2026)
        XCTAssertEqual(result.data.month, 4)
        XCTAssertEqual(result.data.dailyStats.count, 1)
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .GET)
        XCTAssertEqual(mockParser.parseCount, 1)
    }

    func testFetchMonthlyStatsRejectsInvalidMonthBeforeMakingRequest() async {
        do {
            _ = try await sut.fetchMonthlyStats(year: 2026, month: 13)
            XCTFail("Expected invalid month to throw")
        } catch let error as DomainError {
            XCTAssertEqual(error, .validationFailure("Month must be between 1-12"))
            XCTAssertEqual(mockHTTPClient.requestCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchMonthlyStatsRejectsInvalidYearBeforeMakingRequest() async {
        do {
            _ = try await sut.fetchMonthlyStats(year: 1800, month: 4)
            XCTFail("Expected invalid year to throw")
        } catch let error as DomainError {
            XCTAssertEqual(error, .validationFailure("Year must be between 1900-2100"))
            XCTAssertEqual(mockHTTPClient.requestCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeResponse(dailyStats: [DailyStatsDTO]) -> MonthlyStatsDTO {
        MonthlyStatsDTO(
            success: true,
            message: nil,
            data: MonthlyStatsDataDTO(
                year: 2026,
                month: 4,
                timezone: "Asia/Tokyo",
                dailyStats: dailyStats,
                monthlySummary: MonthlySummaryDTO(
                    totalDistanceKm: dailyStats.reduce(0) { $0 + $1.totalDistanceKm },
                    totalWorkouts: dailyStats.reduce(0) { $0 + $1.workoutCount },
                    daysWithWorkouts: dailyStats.filter { $0.workoutCount > 0 }.count
                )
            )
        )
    }
}
