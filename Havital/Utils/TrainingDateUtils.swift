import Foundation

struct TrainingDateUtils {
    /// 計算賽事日期距今天數
    /// - Parameter raceDate: 賽事日期的時間戳（秒）
    /// - Returns: 剩餘天數
    static func calculateDaysRemaining(raceDate: Int) -> Int {
        let raceDay = Date(timeIntervalSince1970: TimeInterval(raceDate))
        let calendar = Self.calendar
        
        // 取得今天的開始時間（00:00:00）
        let today = calendar.startOfDay(for: Date())
        // 取得賽事日期的開始時間（00:00:00）
        let raceStartDay = calendar.startOfDay(for: raceDay)
        
        // 計算兩個日期之間的天數差異
        let components = calendar.dateComponents([.day], from: today, to: raceStartDay)
        
        return max(components.day ?? 0, 0) // 確保不為負數
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
