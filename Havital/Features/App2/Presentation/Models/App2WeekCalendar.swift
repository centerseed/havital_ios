import Foundation

// MARK: - App2WeekCalendar
/// 層中立 — `day_index` ↔ 裝置日曆的換算。`day_index` **1 = 週一 … 7 = 週日**
/// （2026-08-25 對 dev 真實 payload 確認）。
///
/// **這不是新增的第二條路，是把既有的三支從 `App2PlanViewModel` 搬過來。**
/// 原因：`App2StubFixtures`（Data 層）要用同一組換算，而 Data 不得 import Presentation
/// （`.claude/rules/architecture.md`「Layer Direction」）。內容是純日曆算術，沒有任何
/// 呈現決定，搬到 Domain 之後兩層都能取用。
///
/// 為什麼不併進 `Havital/Utils/TrainingWeeksCalculator`：那一支的 `getMonday(for:calendar:)`
/// 是 `private`，且它擁有的語意是「兩個日期之間有幾個訓練週」，不是「`day_index` 落在哪一天」。
enum App2WeekCalendar {

    /// 當週週一的日起點（裝置日曆）。
    ///
    /// 不用 `dateInterval(of: .weekOfYear)`：那條的週首隨 locale 變（zh-TW 是週日），
    /// 而 `day_index` 的週首固定是週一。
    static func currentWeekStart(reference: Date = Date(), calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: reference)     // 1 = 週日
        let mondayBased = weekday == 1 ? 7 : weekday - 1                // 1 = 週一
        let startOfToday = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: -(mondayBased - 1), to: startOfToday) ?? startOfToday
    }

    /// 今天的 `day_index`（1 = 週一 … 7 = 週日）。
    static func todayDayIndex(reference: Date = Date(), calendar: Calendar = .current) -> Int {
        // Calendar.weekday: 1 = 週日 … 7 = 週六。
        let weekday = calendar.component(.weekday, from: reference)
        return weekday == 1 ? 7 : weekday - 1
    }

    /// 週日嗎。**呼叫端要自己決定 `calendar` 的時區。**
    ///
    /// 週回顧的時機**不得**用裝置時區判（`DESIGN-app2-weekly-review-and-plan-end-inventory`
    /// §A.1：時區權威是 `/v2/plan/status` 的 `metadata.user_timezone`）——那條路徑走
    /// `App2HomeViewModel.isSundayInUserTimezone(_:)`，它會把使用者時區的日曆餵進來。
    /// 這支只做「這個瞬間在這本日曆上是不是週日」的算術。
    static func isSunday(date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    /// 使用者時區的 gregorian 日曆。時區名解不開（後端給了 app 不認得的 identifier）
    /// 回 nil —— **不默默退回裝置時區**，那正是 §A.1 要擋的事，呼叫端要自己決定怎麼降級。
    static func calendar(inTimezone identifier: String?) -> Calendar? {
        guard let identifier, let timezone = TimeZone(identifier: identifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar
    }

    /// 這個瞬間在這本日曆上是哪一天（`YYYY-MM-DD`）。
    ///
    /// decision-chain 的 `as_of` 是**使用者當地日期**（`AGENTS.md`：`YYYY-MM-DD`
    /// 是用戶當地時間）。**呼叫端要自己決定 `calendar` 的時區**——與 `isSunday`
    /// 同一個分工，這支只做算術。
    static func isoDay(date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// ISO8601（帶不帶小數秒都吃）。後端的 `server_time` 帶小數秒、
    /// `current_week_start_date` 不帶，同一支要能解兩種。
    static func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// 每日卡標題的日期（設計 frame-01：`週一 8/10`）。週起點 ＋ `day_index - 1` 天。
    static func dateLabel(dayIndex: Int, weekStart: Date, calendar: Calendar = .current) -> String {
        guard let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: weekStart) else { return "" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)"
    }
}
