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
        guard let target else {
            return NSLocalizedString("siri.next_race.no_target", comment: "")
        }

        let tz = TimeZone(identifier: target.timezone) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: today),
            to: cal.startOfDay(for: raceDate)
        ).day ?? 0

        if days == 0 { return String(format: NSLocalizedString("siri.next_race.today", comment: ""), target.name) }
        if days < 0 { return String(format: NSLocalizedString("siri.next_race.ended", comment: ""), target.name) }
        return String(format: NSLocalizedString("siri.next_race.days_left", comment: ""), target.name, days)
    }
}
