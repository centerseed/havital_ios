import Foundation

struct TrainingDateUtils {
    /// 計算從訓練開始到當前的週數（改進版）
    /// - Parameters:
    ///   - createdAt: ISO8601 字串，可帶小數秒或不帶
    ///   - now: 當前時間，預設為 Date()
    static func calculateCurrentTrainingWeek(createdAt: String, now: Date = Date()) -> Int? {
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
        let calendar = Calendar(identifier: .gregorian)
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
        let seconds = todayMonday.timeIntervalSince(createdMonday)
        let weekCount = Int(floor(seconds / (7 * 24 * 3600))) + 1
        return max(weekCount, 1)
    }
}
