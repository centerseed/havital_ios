import Foundation

// MARK: - NextRaceDialogBuilder

/// 把主要比賽目標轉成 Siri 念出的倒數口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
/// raceDate 欄位為 Unix timestamp（秒，Int），內部轉換為 Date 後計算天數差。
enum NextRaceDialogBuilder {

    /// - Parameter target: `Target?`（主要比賽目標；nil 表示未設定）
    /// - Parameter today: 計算基準日（由外部注入，確保純函式可確定性測試；請勿傳 `Date()` 以外的值於正式流程）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from target: Target?, today: Date) -> String {
        // TODO(i18n): localize before non-zh-TW rollout
        guard let target else {
            return "你目前沒有設定比賽目標。"
        }

        let tz = TimeZone(identifier: target.timezone) ?? TimeZone(identifier: "Asia/Taipei")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: today),
            to: cal.startOfDay(for: raceDate)
        ).day ?? 0

        if days == 0 { return "\(target.name)就是今天，加油！" }
        if days < 0 { return "\(target.name)已經結束了。" }
        return "距離\(target.name)還有 \(days) 天。"
    }
}
