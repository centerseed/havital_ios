import Foundation

// MARK: - RizoScenarioLabel
/// scenario 代碼 → 使用者可見情境標籤（i18n）。
enum RizoScenarioLabel {
    static func text(_ scenario: String) -> String {
        switch scenario {
        case "body_status":
            return NSLocalizedString("rizo.history.scenario.body_status", comment: "Today's state")
        case "weekly_situation":
            return NSLocalizedString("rizo.history.scenario.weekly_situation", comment: "Weekly review")
        case "journal":
            return NSLocalizedString("rizo.history.scenario.journal", comment: "Training reflection")
        case "workout_question":
            return NSLocalizedString("rizo.history.scenario.workout_question", comment: "Workout question")
        case "pace_question":
            return NSLocalizedString("rizo.history.scenario.pace_question", comment: "Pace question")
        default:
            return NSLocalizedString("rizo.history.scenario.generic", comment: "Conversation")
        }
    }
}

// MARK: - RizoHistoryDateFormatter
/// ISO8601 UTC 字串 → 使用者本地日期時間顯示。
enum RizoHistoryDateFormatter {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// ISO 字串 → `Date`。解析失敗回 nil。
    ///
    /// 兩種格式（帶／不帶小數秒）都收——後端兩種都寫得出來，只認一種會讓
    /// 「這一輪是什麼時候」在一半的資料上變成 nil。
    static func date(_ iso8601: String?) -> Date? {
        guard let s = iso8601 else { return nil }
        return isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    /// ISO 字串 → 本地「中等日期 + 短時間」。解析失敗回 nil。
    static func medium(_ iso8601: String?) -> String? {
        guard let date = date(iso8601) else { return nil }
        return display.string(from: date)
    }
}
