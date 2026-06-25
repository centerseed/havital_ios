import Foundation

// MARK: - WeeklyMileageDialogBuilder

/// 把這週訓練距離彙總轉成 Siri 念出的口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
/// 呼叫端負責篩選時間範圍（本週）與活動類型，這裡只做格式化。
enum WeeklyMileageDialogBuilder {

    // MARK: - V1 path (running-only array)

    /// V1 專用：接收本週跑步紀錄陣列，自行加總。
    /// - Parameter workouts: 本週已完成的跑步紀錄（由呼叫端以 activityType == "running" 預先篩選）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from workouts: [WorkoutV2]) -> String {
        guard !workouts.isEmpty else {
            return NSLocalizedString("siri.mileage.no_runs", comment: "")
        }
        // distanceMeters is Double? — treat nil as 0 m
        let totalKm = workouts.reduce(0.0) { $0 + (($1.distanceMeters ?? 0) / 1000.0) }
        let kmText = String(format: "%.1f", totalKm)
        return String(format: NSLocalizedString("siri.mileage.summary", comment: ""), kmText, workouts.count)
    }

    // MARK: - V2 path (precomputed totals from WeekMetricsCalculator)

    /// V2 專用：接收由 WeekMetricsCalculator 預先算好的總距離（公里）與訓練次數，
    /// 直接格式化，避免在此重複加總而與 WeekMetricsCalculator 的計算結果產生分歧。
    /// - Parameters:
    ///   - totalKm: WeekMetricsCalculator.metrics(for:weekInfo:).totalDistanceKm
    ///   - count: 本週所有活動類型的訓練次數
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(totalKm: Double, count: Int) -> String {
        guard count > 0 else {
            return NSLocalizedString("siri.mileage.no_training", comment: "")
        }
        let kmText = String(format: "%.1f", totalKm)
        return String(format: NSLocalizedString("siri.mileage.training_summary", comment: ""), kmText, count)
    }
}
