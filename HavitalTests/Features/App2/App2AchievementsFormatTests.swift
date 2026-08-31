import XCTest
@testable import paceriz_dev

/// 2.0 畫面上「帶千分位的量」的格式（`App2NumberFormat`）。
///
/// 這一組存在的理由是一個真缺陷（2026-08-25 用戶截圖退件）：成就頁原本用
/// `maximumFractionDigits = value < 100 ? 1 : 0`，於是週數這種本來就是整數的量
/// 被印成 **`11.0 / 24.0 週 · 還差 13.0 週`** —— 看起來像量測誤差。
///
/// 判準一條：**值是整數就不得帶小數點**；真的有小數才顯示小數。
///
/// 順帶鎖住收斂結果：紀錄頁與成就頁原本各有一份私有 `grouped(_:)`（規則還不同），
/// 現在兩邊都轉呼叫 `App2NumberFormat`。挑選邏輯（最新解鎖／下一個目標）與 1.4 相同，
/// 不在這裡另立判準 —— 用戶裁決：成就頁基本上跟 1.4 一樣，2.0 只改外型。
@MainActor
final class App2AchievementsFormatTests: XCTestCase {

    // MARK: - 共用格式器

    func test_grouped_wholeNumbersHaveNoDecimalPoint() {
        for value in [0.0, 1.0, 11.0, 13.0, 24.0, 99.0, 100.0, 2_400.0] {
            let text = App2NumberFormat.grouped(value, maximumFractionDigits: 1)
            XCTAssertFalse(text.contains("."), "整數 \(value) 不該印成 \(text)")
        }
    }

    func test_grouped_keepsFractionWhenValueIsNotWhole() {
        XCTAssertEqual(App2NumberFormat.grouped(11.5, maximumFractionDigits: 1), "11.5")
        XCTAssertEqual(App2NumberFormat.grouped(99.4, maximumFractionDigits: 1), "99.4")
    }

    func test_grouped_defaultsToNoFraction() {
        XCTAssertEqual(App2NumberFormat.grouped(1_141.5), "1,142")
    }

    func test_grouped_usesThousandSeparator() {
        XCTAssertEqual(App2NumberFormat.grouped(2_400), "2,400")
    }

    // MARK: - 成就頁的呼叫點

    /// 退件截圖裡的那三個數字。
    func test_achievementsGrouped_reproducesRejectedWeekCountsWithoutDecimals() {
        XCTAssertEqual(App2AchievementsView.grouped(11), "11")
        XCTAssertEqual(App2AchievementsView.grouped(24), "24")
        XCTAssertEqual(App2AchievementsView.grouped(13), "13")
    }

    /// 累積里程這種真的有小數的量仍然保留一位（設計 frame-11 的 `1,141.5`）。
    func test_achievementsGrouped_keepsOneFractionBelowHundred() {
        XCTAssertEqual(App2AchievementsView.grouped(37.3), "37.3")
    }

    /// 同一行的三個數字同精度。原本按大小切精度（<100 一位、其餘取整），
    /// hero 量化列就出現 `263 / 300 公里 · 還差 37.3 公里` —— 263 + 37.3 ≠ 300。
    func test_achievementsGrouped_sameRowKeepsConsistentPrecision() {
        let current = 262.7, target = 300.0
        XCTAssertEqual(App2AchievementsView.grouped(current), "262.7")
        XCTAssertEqual(App2AchievementsView.grouped(target), "300")
        XCTAssertEqual(App2AchievementsView.grouped(target - current), "37.3")
    }

    // MARK: - 紀錄頁的呼叫點

    /// 本月跑量／今年累積保留一位小數 —— 四捨五入成 `73` 會跟同一份資料在
    /// Android 上顯示的 `72.6` 對不上。
    func test_recordsGrouped_keepsOneFraction() {
        XCTAssertEqual(App2RecordsView.grouped(72.6), "72.6")
        XCTAssertEqual(App2RecordsView.grouped(585.5), "585.5")
        XCTAssertEqual(App2RecordsView.grouped(1_284), "1,284")
    }

    /// 「較上月」與上方的本月跑量同精度 —— 否則同一欄出現 `77.9 km` 配 `+78`。
    func test_recordsMonthComparison_matchesTotalsPrecision() throws {
        let up = try XCTUnwrap(App2RecordsView.monthComparison(77.9, unit: .metric))
        XCTAssertTrue(up.contains("+77.9"), up)
        XCTAssertTrue(up.hasPrefix("↑"), up)

        let down = try XCTUnwrap(App2RecordsView.monthComparison(-12.4, unit: .metric))
        XCTAssertTrue(down.contains("-12.4"), down)
        XCTAssertTrue(down.hasPrefix("↓"), down)

        XCTAssertNil(App2RecordsView.monthComparison(nil, unit: .metric))
    }
}
