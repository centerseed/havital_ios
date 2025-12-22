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
}
