import XCTest
@testable import paceriz_dev

final class NextRaceDialogBuilderTests: ZhHantLocalizedTestCase {

    // MARK: - Helpers

    /// 把 "yyyy-MM-dd" 字串（Asia/Taipei 午夜）轉成 Unix timestamp（秒）。
    private func ts(_ s: String) -> Int {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy-MM-dd"
        return Int(f.date(from: s)!.timeIntervalSince1970)
    }

    /// 把 "yyyy-MM-dd" 字串（Asia/Taipei 午夜）轉成 Date，供 today 參數使用。
    private func day(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    // MARK: - Tests

    func test_upcomingRace_speaksCountdown() {
        let target = Target.fixture(name: "台北馬拉松", raceDate: ts("2026-07-19"))
        XCTAssertEqual(
            NextRaceDialogBuilder.build(from: target, today: day("2026-06-19")),
            "距離台北馬拉松還有 30 天。"
        )
    }

    func test_noRace_speaksNone() {
        XCTAssertEqual(
            NextRaceDialogBuilder.build(from: nil, today: day("2026-06-19")),
            "你目前沒有設定比賽目標。"
        )
    }

    func test_raceToday_speaksToday() {
        let target = Target.fixture(name: "繞圈賽", raceDate: ts("2026-06-19"))
        XCTAssertEqual(
            NextRaceDialogBuilder.build(from: target, today: day("2026-06-19")),
            "繞圈賽就是今天，加油！"
        )
    }
}

// MARK: - Fixture

extension Target {
    /// 最小測試工廠。僅設定與 NextRaceDialogBuilder 相關的欄位，其餘填入佔位值。
    static func fixture(name: String, raceDate: Int) -> Target {
        Target(
            id: "test-id",
            type: "race_run",
            name: name,
            distanceKm: 42,
            targetTime: 14400,
            targetPace: "5:41",
            raceDate: raceDate,
            isMainRace: true,
            trainingWeeks: 12
        )
    }
}
