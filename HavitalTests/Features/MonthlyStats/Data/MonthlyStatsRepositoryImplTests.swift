import XCTest
@testable import paceriz_dev

final class MonthlyStatsRepositoryImplTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var remoteDataSource: MonthlyStatsRemoteDataSource!
    private var localDataSource: MonthlyStatsLocalDataSource!
    private var sut: MonthlyStatsRepositoryImpl!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MonthlyStatsRepositoryImplTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)

        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        remoteDataSource = MonthlyStatsRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)
        localDataSource = MonthlyStatsLocalDataSource(userDefaults: userDefaults)
        sut = MonthlyStatsRepositoryImpl(remoteDataSource: remoteDataSource, localDataSource: localDataSource)
    }

    override func tearDown() {
        localDataSource.clearAll()
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = nil
        localDataSource = nil
        remoteDataSource = nil
        mockParser = nil
        mockHTTPClient = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testGetMonthlyStatsReturnsCachedDataWithoutCallingAPI() async throws {
        let cachedStats = [
            DailyStat(date: "2026-04-01", totalDistanceKm: 10.0, avgPacePerKm: 300, workoutCount: 1)
        ]
        localDataSource.saveMonthlyStats(cachedStats, year: 2026, month: 4)

        let result = try await sut.getMonthlyStats(year: 2026, month: 4)

        XCTAssertEqual(result, cachedStats)
        XCTAssertEqual(mockHTTPClient.requestCount, 0)
    }

    func testGetMonthlyStatsFetchesAndCachesWhenWorkoutCountIsPositive() async throws {
        let path = "/v2/workout/monthly_stats?year=2026&month=5&activity_type=running"
        let response = makeResponse(
            year: 2026,
            month: 5,
            dailyStats: [
                DailyStatsDTO(date: "2026-05-01", totalDistanceKm: 12.5, avgPacePerKm: 305, workoutCount: 1),
                DailyStatsDTO(date: "2026-05-02", totalDistanceKm: 0, avgPacePerKm: nil, workoutCount: 0)
            ]
        )
        try mockHTTPClient.setJSONResponse(for: path, response: response)

        let result = try await sut.getMonthlyStats(year: 2026, month: 5)
        let hasSynced = await sut.hasSyncedMonth(year: 2026, month: 5)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(hasSynced)
        XCTAssertEqual(localDataSource.getMonthlyStats(year: 2026, month: 5), result)
    }

    func testGetMonthlyStatsDoesNotCacheEmptyWorkoutMonth() async throws {
        let path = "/v2/workout/monthly_stats?year=2026&month=6&activity_type=running"
        let response = makeResponse(
            year: 2026,
            month: 6,
            dailyStats: [
                DailyStatsDTO(date: "2026-06-01", totalDistanceKm: 0, avgPacePerKm: nil, workoutCount: 0)
            ]
        )
        try mockHTTPClient.setJSONResponse(for: path, response: response)

        let result = try await sut.getMonthlyStats(year: 2026, month: 6)
        let hasSynced = await sut.hasSyncedMonth(year: 2026, month: 6)

        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(hasSynced)
        XCTAssertNil(localDataSource.getMonthlyStats(year: 2026, month: 6))
    }

    func testGetMonthlyStatsFallsBackToEmptyArrayOnRemoteFailure() async throws {
        let path = "/v2/workout/monthly_stats?year=2026&month=7&activity_type=running"
        mockHTTPClient.setError(for: path, error: HTTPError.noConnection)

        let result = try await sut.getMonthlyStats(year: 2026, month: 7)
        let hasSynced = await sut.hasSyncedMonth(year: 2026, month: 7)

        XCTAssertEqual(result, [])
        XCTAssertFalse(hasSynced)
    }

    private func makeResponse(year: Int, month: Int, dailyStats: [DailyStatsDTO]) -> MonthlyStatsDTO {
        MonthlyStatsDTO(
            success: true,
            message: nil,
            data: MonthlyStatsDataDTO(
                year: year,
                month: month,
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
