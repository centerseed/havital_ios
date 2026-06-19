import XCTest
@testable import paceriz_dev

final class TodaysSessionDialogBuilderTests: XCTestCase {

    // MARK: - Rest day

    func test_noActionLine_speaksRest() {
        let card = DailyStateCard.fixture(actionLine: nil)
        XCTAssertEqual(
            TodaysSessionDialogBuilder.build(from: card),
            "今天是休息日，好好恢復。"
        )
    }

    // MARK: - Training day

    func test_actionLine_speaksSession() {
        let card = DailyStateCard.fixture(actionLine: "12K easy · 6:45")
        XCTAssertEqual(
            TodaysSessionDialogBuilder.build(from: card),
            "今天的課表是 12K easy · 6:45。"
        )
    }

    func test_actionLine_runTypeOnly_speaksSession() {
        let card = DailyStateCard.fixture(actionLine: "間歇跑")
        XCTAssertEqual(
            TodaysSessionDialogBuilder.build(from: card),
            "今天的課表是 間歇跑。"
        )
    }
}

// MARK: - Fixture

extension DailyStateCard {
    /// 最小測試工廠。僅設定與 DialogBuilder 相關的欄位，其餘填入佔位值。
    static func fixture(actionLine: String?) -> DailyStateCard {
        DailyStateCard(
            lens: .pre,
            source: "steady",
            headline: "今日訓練",
            factType: nil,
            narrativeText: nil,
            chips: [],
            causeChips: [],
            mileageProgression: nil,
            actionLine: actionLine,
            rizoScenario: nil,
            divergenceFlagText: nil,
            isPaid: false,
            isLocked: false,
            upsellReason: nil
        )
    }
}
