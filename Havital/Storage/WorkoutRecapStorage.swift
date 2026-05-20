import Foundation

/// Recap 時刻的已讀狀態：每筆 workout 只彈一次。
/// 對齊 PersonalBestCelebrationStorage 的去重思路，但僅需保存已看過的 workoutId 集合。
enum WorkoutRecapStorage {
    // v2：觸發邏輯改版（不再以 AI 當門檻、不再提早標記已讀），升版重置舊的（可能誤標）已讀狀態。
    private static let key = "workout_recap_seen_ids_v2"
    /// 上限，避免無限增長（保留最近 N 筆已讀）。
    private static let maxRetained = 300

    static func seenIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func hasSeen(_ workoutId: String) -> Bool {
        seenIds().contains(workoutId)
    }

    static func markSeen(_ workoutId: String) {
        var ids = seenIds()
        guard !ids.contains(workoutId) else { return }
        ids.append(workoutId)
        if ids.count > maxRetained {
            ids.removeFirst(ids.count - maxRetained)
        }
        UserDefaults.standard.set(ids, forKey: key)
        Logger.debug("[WorkoutRecap] marked seen: \(workoutId)")
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    #if DEBUG
    /// 測試用：清掉指定 workout 的已讀，讓它能再次觸發 recap。
    static func clearSeen(_ workoutId: String) {
        var ids = seenIds()
        ids.removeAll { $0 == workoutId }
        UserDefaults.standard.set(ids, forKey: key)
    }
    #endif
}
