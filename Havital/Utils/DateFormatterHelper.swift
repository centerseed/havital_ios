//
//  DateFormatterHelper.swift
//  Havital
//
//  統一的日期格式化工具，確保所有日期顯示都使用用戶設定的時區
//

import Foundation

struct DateFormatterHelper {

    /// 獲取配置好用戶時區的 DateFormatter
    /// - Parameters:
    ///   - dateFormat: 日期格式字串（例如："yyyy/MM/dd HH:mm"）
    ///   - locale: 本地化設定，預設為當前 locale
    ///   - useUserTimezone: 是否使用用戶設定的時區，預設為 true
    /// - Returns: 配置好的 DateFormatter
    static func formatter(
        dateFormat: String,
        locale: Locale = Locale.current,
        useUserTimezone: Bool = true
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = locale

        // ✅ 統一使用用戶設定的時區
        if useUserTimezone {
            if let userTimezone = UserPreferencesManager.shared.timezonePreference {
                formatter.timeZone = TimeZone(identifier: userTimezone)
            } else {
                // 如果用戶未設定時區，使用設備當前時區
                formatter.timeZone = TimeZone.current
            }
        } else {
            formatter.timeZone = TimeZone.current
        }

        return formatter
    }

    // MARK: - 常用格式化方法

    /// 格式化為完整日期時間（yyyy/MM/dd HH:mm）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："2025/11/19 14:30"
    static func formatDateTime(_ date: Date) -> String {
        return formatter(dateFormat: "yyyy/MM/dd HH:mm").string(from: date)
    }

    /// 格式化為短日期（MM/dd）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："11/19"
    static func formatShortDate(_ date: Date) -> String {
        return formatter(dateFormat: "MM/dd").string(from: date)
    }

    /// 格式化為時間（HH:mm）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："14:30"
    static func formatTime(_ date: Date) -> String {
        return formatter(dateFormat: "HH:mm").string(from: date)
    }

    /// 格式化為長日期（yyyy年MM月dd日）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："2025年11月19日"
    static func formatLongDate(_ date: Date, locale: Locale = Locale(identifier: "zh_TW")) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = locale

        if let userTimezone = UserPreferencesManager.shared.timezonePreference {
            formatter.timeZone = TimeZone(identifier: userTimezone)
        } else {
            formatter.timeZone = TimeZone.current
        }

        return formatter.string(from: date)
    }

    /// 格式化為完整日期（yyyy-MM-dd）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："2025-11-19"
    static func formatFullDate(_ date: Date) -> String {
        return formatter(dateFormat: "yyyy-MM-dd").string(from: date)
    }

    /// 格式化為完整日期時間，包含秒（yyyy-MM-dd HH:mm:ss）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化後的字串，例如："2025-11-19 14:30:00"
    static func formatFullDateTime(_ date: Date) -> String {
        return formatter(dateFormat: "yyyy-MM-dd HH:mm:ss").string(from: date)
    }

    // MARK: - 解析方法

    /// 從字串解析日期
    /// - Parameters:
    ///   - dateString: 日期字串
    ///   - dateFormat: 日期格式
    ///   - useUserTimezone: 是否使用用戶時區
    /// - Returns: 解析後的 Date，失敗返回 nil
    static func parseDate(
        from dateString: String,
        format dateFormat: String,
        useUserTimezone: Bool = true
    ) -> Date? {
        return formatter(
            dateFormat: dateFormat,
            useUserTimezone: useUserTimezone
        ).date(from: dateString)
    }

    // MARK: - Bundle Helper
    private static var bundle: Bundle {
        class BundleFinder {}
        let candidates = [Bundle(for: BundleFinder.self), Bundle.main]
        
        for candidate in candidates {
            if candidate.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en") != nil {
                return candidate
            }
            if candidate.path(forResource: "Localizable", ofType: "strings") != nil {
                return candidate
            }
        }
        
        return Bundle.main
    }
    
    // Removed hasLocalizableStrings as it's no longer used directly in the loop above


    // MARK: - 相對時間格式化

    /// 格式化為相對時間（例如："剛剛"、"5分鐘前"、"昨天"）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 相對時間字串
    static func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 未來時間
        if interval < 0 {
            return formatDateTime(date)
        }

        // 1分鐘內
        if interval < 60 {
            return NSLocalizedString("date.just_now", bundle: bundle, comment: "剛剛")
        }

        // 1小時內
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: NSLocalizedString("date.minutes_ago", bundle: bundle, comment: "%d分鐘前"), minutes)
        }


        // 今天
        var calendar = Calendar.current
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            calendar.timeZone = tz
        }

        if calendar.isDateInToday(date) {
            return String(format: NSLocalizedString("date.today_at", bundle: bundle, comment: "今天 %@"), formatTime(date))
        }

        // 昨天
        if calendar.isDateInYesterday(date) {
            return String(format: NSLocalizedString("date.yesterday_at", bundle: bundle, comment: "昨天 %@"), formatTime(date))
        }

        // 本週
        if interval < 7 * 24 * 3600 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE HH:mm"
            if let userTimezone = UserPreferencesManager.shared.timezonePreference {
                weekdayFormatter.timeZone = TimeZone(identifier: userTimezone)
            }
            return weekdayFormatter.string(from: date)
        }

        // 其他情況顯示完整日期時間
        return formatDateTime(date)
    }

    // MARK: - 訓練計劃相關工具

    /// 獲取星期名稱
    /// - Parameter dayIndex: 日期索引 (1-7，1=週一)
    /// - Returns: 星期名稱，例如："週一"
    static func weekdayName(for dayIndex: Int) -> String {
        let weekdays = [
            NSLocalizedString("weekday.monday", comment: "週一"),
            NSLocalizedString("weekday.tuesday", comment: "週二"),
            NSLocalizedString("weekday.wednesday", comment: "週三"),
            NSLocalizedString("weekday.thursday", comment: "週四"),
            NSLocalizedString("weekday.friday", comment: "週五"),
            NSLocalizedString("weekday.saturday", comment: "週六"),
            NSLocalizedString("weekday.sunday", comment: "週日")
        ]
        let index = dayIndex - 1
        return (index >= 0 && index < weekdays.count) ? weekdays[index] : ""
    }

    /// 檢查日期是否為今天
    /// - Parameter date: 要檢查的日期
    /// - Returns: 是否為今天
    static func isToday(_ date: Date) -> Bool {
        var calendar = Calendar.current
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            calendar.timeZone = tz
        }
        return calendar.isDateInToday(date)
    }

    /// 獲取指定日期索引對應的日期
    /// - Parameters:
    ///   - startDate: 起始日期
    ///   - dayIndex: 日期索引 (1 = 第一天)
    /// - Returns: 對應的日期，失敗返回 nil
    static func getDateForDay(startDate: Date, dayIndex: Int) -> Date? {
        var calendar = Calendar.current
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            calendar.timeZone = tz
        }
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: startDate)
    }

    /// 獲取指定日期所在月份的起始和結束日期
    /// - Parameter date: 任意日期
    /// - Returns: 月份範圍 (start, end)，結束日期為當月最後一天的 23:59:59；失敗返回 nil
    ///
    /// **用途**: 用於獲取月份的完整時間範圍，常用於篩選該月的所有訓練記錄
    ///
    /// **示例**:
    /// ```swift
    /// let date = Date() // 2024-01-15
    /// let range = DateFormatterHelper.monthRange(for: date)
    /// // range.start = 2024-01-01 00:00:00
    /// // range.end   = 2024-01-31 23:59:59
    /// ```
    static func monthRange(for date: Date) -> (start: Date, end: Date)? {
        var calendar = Calendar.current
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            calendar.timeZone = tz
        }

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let endOfMonthDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth),
              let endOfMonth = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonthDay) else {
            return nil
        }

        return (startOfMonth, endOfMonth)
    }

    // MARK: - 調試工具

    /// 獲取當前使用的時區資訊（用於調試）
    /// - Returns: 時區資訊字串
    static func getCurrentTimezoneInfo() -> String {
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            return "\(userTimezone) (GMT\(tz.secondsFromGMT() / 3600))"
        } else {
            let tz = TimeZone.current
            return "\(tz.identifier) (GMT\(tz.secondsFromGMT() / 3600))"
        }
    }
}

// MARK: - Date Extension for Convenience

extension Date {
    /// 使用用戶時區格式化為日期時間字串
    var formattedDateTime: String {
        DateFormatterHelper.formatDateTime(self)
    }

    /// 使用用戶時區格式化為短日期字串
    var formattedShortDate: String {
        DateFormatterHelper.formatShortDate(self)
    }

    /// 使用用戶時區格式化為時間字串
    var formattedTime: String {
        DateFormatterHelper.formatTime(self)
    }

    /// 格式化為相對時間
    var formattedRelativeTime: String {
        DateFormatterHelper.formatRelativeTime(self)
    }
}
