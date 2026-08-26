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

    /// 週日嗎（裝置日曆）。首頁的週回顧 CTA 依它分「本週／上週」。
    static func isSunday(date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    /// 每日卡標題的日期（設計 frame-01：`週一 8/10`）。週起點 ＋ `day_index - 1` 天。
    static func dateLabel(dayIndex: Int, weekStart: Date, calendar: Calendar = .current) -> String {
        guard let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: weekStart) else { return "" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)"
    }
}
