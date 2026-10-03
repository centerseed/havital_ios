import Foundation

struct TrainingDateUtils {
    /// 計算 timestamp 日期距今天數；timestamp 的日期取用戶時區。
    /// - Parameters:
    ///   - raceDate: 賽事日期的時間戳（秒）
    ///   - timezone: 賽事時區（選填，預設使用當前時區）
    /// - Returns: 剩餘天數
    static func calculateDaysRemaining(raceDate: Int, timezone: String? = nil, now: Date = Date()) -> Int {
        let raceDay = Date(timeIntervalSince1970: TimeInterval(raceDate))
        let timeZone = timezone.flatMap(TimeZone.init(identifier:)) ?? Self.calendar.timeZone
        return max(calculateDaysBetween(raceDate: raceDay, now: now, timezone: timeZone), 0)
    }

    /// 以同一個用戶當地日曆比較兩個日期；不以 UTC 秒數除以 86400。
    static func calculateDaysBetween(raceDate: Date, now: Date, timezone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: now)
        let raceStartDay = calendar.startOfDay(for: raceDate)
        return calendar.dateComponents([.day], from: today, to: raceStartDay).day ?? 0
    }

    /// 非負倒數版本，供 timestamp target card 使用。
    static func calculateDaysRemaining(raceDate: Date, timezone: TimeZone, now: Date = Date()) -> Int {
        max(calculateDaysBetween(raceDate: raceDate, now: now, timezone: timezone), 0)
    }

    /// 非負倒數版本，供 API `YYYY-MM-DD` 賽事 catalog 使用。
    /// Catalog date 以 UTC midnight 傳輸，先取 UTC 日期元件再放入用戶日曆，
    /// 避免西半球把日期往前移一天。
    static func calculateCatalogDaysRemaining(raceDate: Date, timezone: TimeZone, now: Date = Date()) -> Int {
        max(calculateCatalogDaysBetween(raceDate: raceDate, now: now, timezone: timezone), 0)
    }

    /// 推薦卡保留「幾週後」文案，但週數先由同一個 catalog 日期 projection 推導。
    static func calculateCatalogWeeksRemaining(raceDate: Date, timezone: TimeZone, now: Date = Date()) -> Int {
        let days = calculateCatalogDaysBetween(raceDate: raceDate, now: now, timezone: timezone)
        guard days > 0 else { return 0 }
        return (days + 6) / 7
    }

    private static func calculateCatalogDaysBetween(raceDate: Date, now: Date, timezone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: now)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let raceComponents = utcCalendar.dateComponents([.year, .month, .day], from: raceDate)
        guard let raceStartDay = calendar.date(from: raceComponents) else { return 0 }
        return calendar.dateComponents([.day], from: today, to: raceStartDay).day ?? 0
    }
    
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZoneManager.shared.getCurrentTimeZone()
        return calendar
    }
    
    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZoneManager.shared.getCurrentTimeZone()
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    /// 計算從訓練開始到當前的週數（改進版）
    /// - Parameters:
    ///   - createdAt: ISO8601 字串，可帶小數秒或不帶
    ///   - now: 當前時間，預設為 Date()
    static func calculateCurrentTrainingWeek(createdAt: String, now: Date = Date(), timeZone: TimeZone? = nil) -> Int? {
        guard !createdAt.isEmpty else {
            Logger.debug("無法計算訓練週數: 缺少建立時間")
            return nil
        }
        var createdAtDate: Date?
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAtDate = isoFormatter.date(from: createdAt)
        if createdAtDate == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            createdAtDate = isoFormatter.date(from: createdAt)
        }
        guard let startDate = createdAtDate else {
            Logger.debug("無法解析建立時間: \(createdAt)")
            return nil
        }
        var calendar = Self.calendar
        if let tz = timeZone {
            calendar.timeZone = tz
        }

        let createdWeekday = calendar.component(.weekday, from: startDate)
        let createdIndex = (createdWeekday + 5) % 7  // Monday=0
        guard let createdMonday = calendar.date(byAdding: .day,
                                               value: -createdIndex,
                                               to: calendar.startOfDay(for: startDate)) else {
            Logger.debug("無法計算建立日期所在週的週一")
            return nil
        }
        let today = now
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayIndex = (todayWeekday + 5) % 7
        guard let todayMonday = calendar.date(byAdding: .day,
                                              value: -todayIndex,
                                              to: calendar.startOfDay(for: today)) else {
            Logger.debug("無法計算今天所在週的週一")
            return nil
        }
        // 移除冗餘的 DEBUG 日誌以減少日誌噪音
        // 只在需要時才記錄詳細信息
        let seconds = todayMonday.timeIntervalSince(createdMonday)
        let weekCount = Int(floor(seconds / (7 * 24 * 3600))) + 1
        return max(weekCount, 1)
    }
}
