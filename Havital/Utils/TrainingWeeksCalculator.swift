//
//  TrainingWeeksCalculator.swift
//  Havital
//
//  訓練週數計算器
//  實現與後端一致的「週邊界」計算演算法
//
//  演算法說明：
//  1. 計算創建日期和比賽日期各自所在週的週一
//  2. 計算兩個週一之間的天數差
//  3. 使用公式：ceil(days_diff / 7) + 1
//
//  這與簡單的日期差計算不同，因為系統計算的是「週邊界」而非「實際日期」。
//
//  參考文檔：Docs/TRAINING_WEEKS_CALCULATION.md
//

import Foundation

struct TrainingWeeksCalculator {

    /// 計算訓練週數（與後端演算法一致）
    ///
    /// - Parameters:
    ///   - startDate: 目標創建日期
    ///   - raceDate: 比賽日期
    ///   - timeZone: 時區（預設為 UTC）
    /// - Returns: 訓練週數（整數，最少 1 週）
    ///
    /// - Note: 此函數使用「週邊界」計算方式，與簡單的日期差計算不同
    ///
    /// 示例：
    /// ```swift
    /// let start = Date() // 2025-10-26
    /// let race = Date() + 31 * 24 * 3600 // 2025-11-26
    /// let weeks = TrainingWeeksCalculator.calculateTrainingWeeks(
    ///     startDate: start,
    ///     raceDate: race
    /// )
    /// print(weeks) // 輸出: 6 (不是 4.4)
    /// ```
    static func calculateTrainingWeeks(
        startDate: Date,
        raceDate: Date,
        timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .current
    ) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Step 1: 提取日期部分（去除時間）
        let startDateOnly = calendar.startOfDay(for: startDate)
        let raceDateOnly = calendar.startOfDay(for: raceDate)

        // Step 2: 邊界檢查 - 比賽日期不能早於創建日期
        if raceDateOnly < startDateOnly {
            Logger.warn("比賽日期早於創建日期，返回最小值 1 週")
            return 1
        }

        // Step 3: 計算各日期所在週的週一
        let startMonday = getMonday(for: startDateOnly, calendar: calendar)
        let raceMonday = getMonday(for: raceDateOnly, calendar: calendar)

        // Step 4: 計算兩個週一之間的天數差
        let daysDiff = calendar.dateComponents([.day], from: startMonday, to: raceMonday).day ?? 0

        // Step 5: 計算週數
        // 公式：ceil(days_diff / 7) + 1
        // +1 表示創建的那一週本身就是第一週
        let trainingWeeks = Int(ceil(Double(daysDiff) / 7.0)) + 1

        // Debug logging
        Logger.debug("📅 [TrainingWeeksCalculator] 計算訓練週數:")
        Logger.debug("  ├─ 創建日期: \(formatDate(startDateOnly))")
        Logger.debug("  ├─ 比賽日期: \(formatDate(raceDateOnly))")
        Logger.debug("  ├─ 創建週一: \(formatDate(startMonday))")
        Logger.debug("  ├─ 比賽週一: \(formatDate(raceMonday))")
        Logger.debug("  ├─ 天數差: \(daysDiff) 天")
        Logger.debug("  └─ 訓練週數: \(trainingWeeks) 週")

        return trainingWeeks
    }

    /// 計算給定日期所在週的週一
    ///
    /// - Parameters:
    ///   - date: 輸入日期
    ///   - calendar: 日曆對象
    /// - Returns: 該週的週一日期
    private static func getMonday(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.weekday], from: date)
        let weekday = components.weekday ?? 1 // 1=週日, 2=週一, ..., 7=週六

        // 計算到週一的偏移
        // weekday: 1(日)→-6, 2(一)→0, 3(二)→-1, 4(三)→-2, 5(四)→-3, 6(五)→-4, 7(六)→-5
        let daysOffset = weekday == 1 ? -6 : -(weekday - 2)

        let monday = calendar.date(byAdding: .day, value: daysOffset, to: date) ?? date
        return calendar.startOfDay(for: monday)
    }

    /// 格式化日期為字符串（用於 debug）
    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    /// 計算實際日期差（用於對比）
    ///
    /// 此方法計算的是實際天數，與 `calculateTrainingWeeks` 的結果可能不同
    ///
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - raceDate: 結束日期
    /// - Returns: (天數, 週數（小數）)
    static func calculateActualDateDifference(
        startDate: Date,
        raceDate: Date
    ) -> (days: Int, weeks: Double) {
        let calendar = Calendar.current
        let startDateOnly = calendar.startOfDay(for: startDate)
        let raceDateOnly = calendar.startOfDay(for: raceDate)

        let days = calendar.dateComponents([.day], from: startDateOnly, to: raceDateOnly).day ?? 0
        let weeks = Double(days) / 7.0

        return (days, weeks)
    }
}
