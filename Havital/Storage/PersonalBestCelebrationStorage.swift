import Foundation

/// Personal Best 慶祝動畫的本地存儲管理器
class PersonalBestCelebrationStorage {

    private static let storageKey = "personal_best_celebration_cache"

    /// 保存慶祝緩存
    static func save(_ cache: PersonalBestCelebrationCache) {
        do {
            let data = try JSONEncoder().encode(cache)
            UserDefaults.standard.set(data, forKey: storageKey)
            Logger.debug("Personal Best 慶祝緩存已保存")
        } catch {
            Logger.error("保存 Personal Best 慶祝緩存失敗: \(error.localizedDescription)")
        }
    }

    /// 載入慶祝緩存
    static func load() -> PersonalBestCelebrationCache {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return PersonalBestCelebrationCache()
        }

        do {
            return try JSONDecoder().decode(PersonalBestCelebrationCache.self, from: data)
        } catch {
            Logger.error("讀取 Personal Best 慶祝緩存失敗: \(error.localizedDescription)")
            return PersonalBestCelebrationCache()
        }
    }

    /// 清除慶祝緩存
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        Logger.debug("Personal Best 慶祝緩存已清除")
    }

    // MARK: - Convenience Methods

    /// 標記慶祝動畫已顯示
    static func markCelebrationAsShown() {
        var cache = load()
        cache.hasShownCelebration = true
        if let update = cache.lastDetectedUpdate,
           !cache.shownWorkoutUpdateKeys.contains(update.dedupeKey) {
            cache.shownWorkoutUpdateKeys.append(update.dedupeKey)
        }
        save(cache)
        Logger.debug("慶祝動畫已標記為已顯示")
    }

    /// 標記指定 workout PB Moment 已顯示
    static func markCelebrationAsShown(for update: PersonalBestUpdate) {
        var cache = load()
        cache.hasShownCelebration = true
        if !cache.shownWorkoutUpdateKeys.contains(update.dedupeKey) {
            cache.shownWorkoutUpdateKeys.append(update.dedupeKey)
        }
        save(cache)
        Logger.debug("慶祝動畫已標記為已顯示: \(update.dedupeKey)")
    }

    /// 指定 workout + distance 是否已顯示過阻擋式 PB Moment
    static func hasShownCelebration(for update: PersonalBestUpdate) -> Bool {
        load().shownWorkoutUpdateKeys.contains(update.dedupeKey)
    }

    /// 獲取待顯示的慶祝更新
    static func getPendingCelebrationUpdate() -> PersonalBestUpdate? {
        let cache = load()
        guard let update = cache.lastDetectedUpdate else { return nil }
        return (!cache.hasShownCelebration && !cache.shownWorkoutUpdateKeys.contains(update.dedupeKey))
            ? cache.lastDetectedUpdate
            : nil
    }
}
