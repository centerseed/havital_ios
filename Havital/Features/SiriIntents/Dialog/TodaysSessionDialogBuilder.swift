import Foundation

// MARK: - TodaysSessionDialogBuilder

/// 把今日狀態卡片轉成 Siri 念出的口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
enum TodaysSessionDialogBuilder {

    /// - Parameter card: `DailyStateCard` domain entity（來自 `GET /v2/state/today`）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from card: DailyStateCard) -> String {
        guard let actionLine = card.actionLine,
              !actionLine.trimmingCharacters(in: .whitespaces).isEmpty else {
            return NSLocalizedString("siri.session.rest", comment: "")
        }
        return String(format: NSLocalizedString("siri.session.today", comment: ""), actionLine)
    }
}
