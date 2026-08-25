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

    /// 破百之後只給整數 —— 但整數本來就不帶小數點，兩條規則不衝突。
    func test_achievementsGrouped_dropsFractionAboveHundred() {
        XCTAssertEqual(App2AchievementsView.grouped(263), "263")
        XCTAssertEqual(App2AchievementsView.grouped(300), "300")
    }
}
