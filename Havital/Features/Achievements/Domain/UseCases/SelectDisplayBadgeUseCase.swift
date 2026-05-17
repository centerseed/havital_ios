import Foundation

/// 選擇首頁要展示哪一個徽章。
/// 優先序：pinned（有效）> in_progress 中 progress 最高 > 最近 unlocked > 任一徽章 > nil
struct SelectDisplayBadgeUseCase {
    func execute(pinnedBadgeId: String?, allBadges: [AchievementBadge]) -> AchievementBadge? {
        if let pinnedBadgeId,
           let pinned = allBadges.first(where: { $0.badgeId == pinnedBadgeId }),
           pinned.status == .unlocked || pinned.status == .inProgress {
            return pinned
        }

        let inProgress = allBadges.filter { $0.status == .inProgress }
        if let best = inProgress.max(by: { progressRatio($0) < progressRatio($1) }) {
            return best
        }

        let unlocked = allBadges.filter { $0.status == .unlocked && $0.unlockedAt != nil }
        if let recent = unlocked.max(by: { ($0.unlockedAt ?? "") < ($1.unlockedAt ?? "") }) {
            return recent
        }

        return allBadges.first
    }

    private func progressRatio(_ badge: AchievementBadge) -> Double {
        guard let p = badge.progress,
              let current = p.current,
              let target = p.target, target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
}
