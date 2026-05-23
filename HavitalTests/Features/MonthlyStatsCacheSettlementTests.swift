import XCTest
@testable import paceriz_dev

/// 回歸測試：月度統計快取「結算」判斷。
///
/// 背景 bug（GitHub #70）：使用者在月中開過日曆，該月被永久快取成不完整資料，
/// 之後新增的訓練永遠不顯示。修法是「只信任在月底+寬限期後才抓取的快取」。
/// 本測試鎖死此邏輯，避免未來退化。
final class MonthlyStatsCacheSettlementTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    /// 月中抓取的快取（bug 場景）→ 不可信任。
    func testCacheFetchedMidMonthIsNotSettled() {
        // 4 月的快取在 4/5 抓取（當時只有月初資料）
        let synced = date(2026, 4, 5)
        XCTAssertFalse(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: synced),
            "月中抓取的快取不應被視為已結算（會漏掉月中後新增的訓練）"
        )
    }

    /// 月底前一天抓取 → 仍不可信任。
    func testCacheFetchedBeforeMonthEndIsNotSettled() {
        let synced = date(2026, 4, 30)
        XCTAssertFalse(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: synced)
        )
    }

    /// 在寬限期內抓取（5/2，月底+3 天 = 5/4 之前）→ 尚不可信任（容忍晚同步）。
    func testCacheFetchedWithinGraceIsNotSettled() {
        let synced = date(2026, 5, 2)
        XCTAssertFalse(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: synced)
        )
    }

    /// 結算後抓取（5/10）→ 可永久信任。
    func testCacheFetchedAfterSettlementIsSettled() {
        let synced = date(2026, 5, 10)
        XCTAssertTrue(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: synced),
            "結算點之後抓取的快取應可信任"
        )
    }

    /// 沒有同步時間戳 → 不可信任。
    func testNilTimestampIsNotSettled() {
        XCTAssertFalse(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: nil)
        )
    }

    /// 跨年 12 月：結算點應落在隔年 1 月。
    func testDecemberSettlementCrossesYear() {
        XCTAssertFalse(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2025, month: 12, syncTimestamp: date(2025, 12, 20))
        )
        XCTAssertTrue(
            MonthlyStatsRepositoryImpl.isCacheSettled(year: 2025, month: 12, syncTimestamp: date(2026, 1, 10))
        )
    }

    /// settlementDate = 下個月第一天 + 3 天寬限。
    func testSettlementDateBoundary() {
        guard let settlement = MonthlyStatsRepositoryImpl.settlementDate(year: 2026, month: 4) else {
            return XCTFail("settlementDate 不應為 nil")
        }
        // 5/4 00:00 之前不可信、之後可信
        XCTAssertFalse(MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: settlement.addingTimeInterval(-60)))
        XCTAssertTrue(MonthlyStatsRepositoryImpl.isCacheSettled(year: 2026, month: 4, syncTimestamp: settlement.addingTimeInterval(60)))
    }
}
