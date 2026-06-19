import Foundation

// MARK: - WeeklyMileageDialogBuilder

/// 把這週跑步距離彙總轉成 Siri 念出的口語句子。
/// 純函式，無副作用，無 I/O，可單元測試。
/// 呼叫端負責篩選時間範圍（本週）與活動類型，這裡只做格式化。
enum WeeklyMileageDialogBuilder {

    /// - Parameter workouts: 本週已完成的跑步紀錄（由呼叫端預先篩選）
    /// - Returns: zh-TW 口語句子，供 Siri 朗讀
    static func build(from workouts: [WorkoutV2]) -> String {
        // TODO(i18n): localize before non-zh-TW rollout
        guard !workouts.isEmpty else {
            return "你這週還沒有跑步紀錄。"
        }
        // distanceMeters is Double? — treat nil as 0 m
        let totalKm = workouts.reduce(0.0) { $0 + (($1.distanceMeters ?? 0) / 1000.0) }
        let kmText = String(format: "%.1f", totalKm)
        return "你這週已經跑了 \(kmText) 公里，共 \(workouts.count) 次。"
    }
}
