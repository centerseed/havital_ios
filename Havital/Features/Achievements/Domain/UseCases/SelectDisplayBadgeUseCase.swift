import Foundation

/// 選擇課表首頁展示位要放哪一個徽章。
/// 與個人成就頁 hero（latestUnlockedBadge）一致：使用者自選的 pinned 優先，
/// 否則自動挑「最近解鎖」的已解鎖徽章；無已解鎖徽章則 nil（→ 顯示佔位）。
/// 只展示已解鎖徽章，不顯示 in-progress。
struct SelectDisplayBadgeUseCase {
    func execute(pinnedBadgeId: String?, allBadges: [AchievementBadge]) -> AchievementBadge? {
        if let pinnedBadgeId,
           let pinned = allBadges.first(where: { $0.badgeId == pinnedBadgeId }),
           pinned.status == .unlocked {
            return pinned
        }

        return allBadges
            .filter { $0.status == .unlocked }
            .max(by: { ($0.unlockedAt ?? "") < ($1.unlockedAt ?? "") })
    }
}
