import Foundation

/// 提供週日期計算功能
public struct WeekDateInfo {
    public let startDate: Date  // 週一凌晨00:00:00
    public let endDate: Date    // 週日晚上23:59:59
    public let daysMap: [Int: Date]  // 1-7 對應週一到週日
}

public enum WeekDateService {
    private static let calendar = Calendar(identifier: .gregorian)
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 計算指定週日期資訊
    public static func weekDateInfo(createdAt: String, weekNumber: Int) -> WeekDateInfo? {
        // 解析 createdAt
        guard let rawDate = isoFormatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) else {
            return nil
        }
        // 計算建立週週一
        let weekday = calendar.component(.weekday, from: rawDate)
        let offsetToMonday = (weekday + 5) % 7
        guard let overviewMonday = calendar.date(byAdding: .day,
                                                 value: -offsetToMonday,
                                                 to: calendar.startOfDay(for: rawDate)) else {
            return nil
        }
        // 計算目標週的週一(weekNumber 從1開始)
        guard let weekStart = calendar.date(byAdding: .day,
                                            value: (weekNumber - 1) * 7,
                                            to: overviewMonday) else { return nil }
        // 週日結束時間
        guard let weekEnd = calendar.date(byAdding: .day,
                                          value: 6,
                                          to: weekStart)?.addingTimeInterval(86399) else { return nil }
        // daysMap
        var days = [Int: Date]()
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: weekStart) {
                days[i + 1] = d
            }
        }
        return WeekDateInfo(startDate: weekStart, endDate: weekEnd, daysMap: days)
    }

    /// 取得上兩週日期範圍 (MM/dd-MM/dd)
    public static func lastTwoWeeksRange() -> String {
        let today = Date()
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else {
            return ""
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd"
        return "\(fmt.string(from: twoWeeksAgo)) - \(fmt.string(from: today))"
    }

    /// 取得上週一到上週日的日期範圍 (MM/dd - MM/dd)
    public static func lastWeekRange() -> String {
        let today = Date()
        // 計算本週一
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday,
                                              to: calendar.startOfDay(for: today)) else {
            return ""
        }
        // 上週一 = 本週一 - 7 天
        guard let lastMonday = calendar.date(byAdding: .day, value: -7,
                                              to: thisMonday) else {
            return ""
        }
        // 上週日 = 上週一 + 6 天
        guard let lastSunday = calendar.date(byAdding: .day, value: 6,
                                              to: lastMonday) else {
            return ""
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd"
        return "\(fmt.string(from: lastMonday)) - \(fmt.string(from: lastSunday))"
    }
}
