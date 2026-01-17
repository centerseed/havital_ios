import Foundation

// MARK: - DailyStat Entity
/// 每日運動統計 - Domain Layer 業務實體
/// 純粹的業務模型，不包含 API 相關邏輯
/// ✅ 符合 Codable 以支援本地緩存
struct DailyStat: Codable, Equatable {

    // MARK: - Properties

    /// 日期（yyyy-MM-dd 格式）
    let date: String

    /// 該日總里程（公里）
    let totalDistanceKm: Double

    /// 加權平均配速（秒/公里），nil 表示無有效數據
    let avgPacePerKm: Int?

    /// 該日運動次數
    let workoutCount: Int

    // MARK: - Computed Properties

    /// 轉換為 Date 對象
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: date)
    }

    /// 總里程（米）
    var totalDistanceMeters: Double {
        return totalDistanceKm * 1000
    }

    /// 配速字串（格式：5'30"/km）
    var paceString: String? {
        guard let paceSeconds = avgPacePerKm else { return nil }
        let minutes = paceSeconds / 60
        let seconds = paceSeconds % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    /// 是否有運動記錄
    var hasWorkout: Bool {
        return workoutCount > 0
    }

    // MARK: - Initialization

    init(date: String, totalDistanceKm: Double, avgPacePerKm: Int?, workoutCount: Int) {
        self.date = date
        self.totalDistanceKm = totalDistanceKm
        self.avgPacePerKm = avgPacePerKm
        self.workoutCount = workoutCount
    }
}

// MARK: - Business Logic Methods
extension DailyStat {

    /// 判斷是否為同一天
    func isSameDate(_ other: Date) -> Bool {
        guard let selfDate = dateValue else { return false }
        return Calendar.current.isDate(selfDate, inSameDayAs: other)
    }

    /// 判斷是否在日期範圍內
    func isInRange(start: Date, end: Date) -> Bool {
        guard let selfDate = dateValue else { return false }
        return selfDate >= start && selfDate <= end
    }
}
