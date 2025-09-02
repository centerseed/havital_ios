import Foundation
import HealthKit

struct ViewModelUtils {
    /// 計算總距離 (公里)
    static func calculateTotalDistance(_ workouts: [HKWorkout]) -> Double {
        workouts.reduce(0) { total, workout in
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                return total + (distance / 1000)
            }
            return total
        }
    }

    /// 格式化距離, 若傳入單位則保留兩位小數
    static func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        if let unit = unit {
            return String(format: "%.2f %@", distance, unit)
        } else {
            return String(Int(distance))
        }
    }

    /// 短日期顯示 MM/dd
    static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    /// 時間顯示 HH:mm
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 配速格式化 分:秒 /km
    static func formatPace(_ paceInSeconds: Double) -> String {
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    /// 星期文字 (一~日)
    static func weekdayName(for index: Int) -> String {
        let weekdayKeys = [
            "weekday.monday",
            "weekday.tuesday", 
            "weekday.wednesday",
            "weekday.thursday",
            "weekday.friday",
            "weekday.saturday",
            "weekday.sunday"
        ]
        
        guard index >= 1 && index <= 7 else { return "" }
        let key = weekdayKeys[index - 1]
        return NSLocalizedString(key, comment: "Weekday name")
    }
    
    /// 短星期文字 (Mon~Sun)
    static func weekdayShortName(for index: Int) -> String {
        let weekdayShortKeys = [
            "weekday.mon_short",
            "weekday.tue_short", 
            "weekday.wed_short",
            "weekday.thu_short",
            "weekday.fri_short",
            "weekday.sat_short",
            "weekday.sun_short"
        ]
        
        guard index >= 1 && index <= 7 else { return "" }
        let key = weekdayShortKeys[index - 1]
        return NSLocalizedString(key, comment: "Short weekday name")
    }

    /// 除錯日期顯示 yyyy-MM-dd HH:mm:ss
    static func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// 檢查當前語言是否為中文
    static func isCurrentLanguageChinese() -> Bool {
        return LanguageManager.shared.currentLanguage == .traditionalChinese
    }
}
