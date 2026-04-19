import XCTest
@testable import paceriz_dev

final class MonthlyStatsLocalDataSourceTests: XCTestCase {
    private var sut: MonthlyStatsLocalDataSource!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MonthlyStatsLocalDataSourceTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = MonthlyStatsLocalDataSource(userDefaults: userDefaults)
    }

    override func tearDown() {
        sut.clearAll()
        userDefaults.removePersistentDomain(forName: suiteName)
        sut = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveMonthlyStatsPersistsAndReturnsCachedData() {
        let stats = [
            DailyStat(date: "2026-04-01", totalDistanceKm: 10.5, avgPacePerKm: 305, workoutCount: 1),
            DailyStat(date: "2026-04-02", totalDistanceKm: 0, avgPacePerKm: nil, workoutCount: 0)
        ]

        sut.saveMonthlyStats(stats, year: 2026, month: 4)

        XCTAssertEqual(sut.getMonthlyStats(year: 2026, month: 4), stats)
    }

    func testTimestampLifecycleTracksSyncedState() {
        XCTAssertFalse(sut.hasSynced(year: 2026, month: 5))
        XCTAssertNil(sut.getSyncTimestamp(year: 2026, month: 5))

        sut.setSyncTimestamp(year: 2026, month: 5)

        XCTAssertTrue(sut.hasSynced(year: 2026, month: 5))
        XCTAssertNotNil(sut.getSyncTimestamp(year: 2026, month: 5))

        sut.clearSyncTimestamp(year: 2026, month: 5)

        XCTAssertFalse(sut.hasSynced(year: 2026, month: 5))
        XCTAssertNil(sut.getSyncTimestamp(year: 2026, month: 5))
    }

    func testGetAllSyncedMonthsReturnsDescendingYearMonthOrder() {
        sut.setSyncTimestamp(year: 2025, month: 12)
        sut.setSyncTimestamp(year: 2026, month: 1)
        sut.setSyncTimestamp(year: 2026, month: 3)

        let result = sut.getAllSyncedMonths()

        XCTAssertEqual(
            result.map { "\($0.year)-\($0.month)" },
            ["2026-3", "2026-1", "2025-12"]
        )
        XCTAssertEqual(result.count, 3)
    }

    func testClearAllRemovesTimestampsAndCachedStats() {
        let stats = [
            DailyStat(date: "2026-06-01", totalDistanceKm: 8.2, avgPacePerKm: 315, workoutCount: 1)
        ]
        sut.saveMonthlyStats(stats, year: 2026, month: 6)
        sut.setSyncTimestamp(year: 2026, month: 6)

        sut.clearAll()

        XCTAssertNil(sut.getMonthlyStats(year: 2026, month: 6))
        XCTAssertFalse(sut.hasSynced(year: 2026, month: 6))
        XCTAssertTrue(sut.getAllSyncedMonths().isEmpty)
    }
}
