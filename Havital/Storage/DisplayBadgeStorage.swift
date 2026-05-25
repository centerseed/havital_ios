import Foundation

/// 持久化「課表首頁展示徽章」的最近一次快照。
///
/// 為什麼需要：pinnedBadgeId 雖然有存（PinnedBadgeStorage），但徽章本體（名字、圖、解鎖狀態）
/// 只存在記憶體版 AchievementSummary 裡，冷啟動要等網路才有資料。在 summary 回來前，
/// getDisplayBadge() 找不到 pin 徽章 → fallback 到「最近解鎖」→ 畫面先閃一個暫代值再跳成
/// 真正選的那顆。把已解析的展示徽章快照存本地，冷啟動就能即時、穩定渲染，網路回來值一樣就不跳。
enum DisplayBadgeStorage {
    private static let key = "paceriz.achievement.displayBadgeSnapshot"

    private struct Record: Codable {
        let badgeId: String
        let chapter: String
        let nameKey: String
        let storyKey: String
        let status: String
        let unlockedAt: String?
        let assetName: String?
        let shareable: Bool
    }

    static func save(_ badge: AchievementBadge?) {
        guard let badge else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let record = Record(
            badgeId: badge.badgeId,
            chapter: badge.chapter.rawValue,
            nameKey: badge.nameKey,
            storyKey: badge.storyKey,
            status: badge.status.rawValue,
            unlockedAt: badge.unlockedAt,
            assetName: badge.assetName,
            shareable: badge.shareable
        )
        guard let data = try? JSONEncoder().encode(record) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> AchievementBadge? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let record = try? JSONDecoder().decode(Record.self, from: data) else {
            return nil
        }
        return AchievementBadge(
            badgeId: record.badgeId,
            chapter: AchievementChapter(rawValue: record.chapter),
            nameKey: record.nameKey,
            storyKey: record.storyKey,
            status: AchievementBadgeStatus(rawValue: record.status),
            progress: nil,
            unlockedAt: record.unlockedAt,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: record.shareable,
            assetName: record.assetName
        )
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
