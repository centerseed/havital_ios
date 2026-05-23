import Foundation
import Combine

protocol AchievementRepository {
    var cachedSummary: AchievementSummary? { get }
    var pinnedBadgeIdDidChange: AnyPublisher<String?, Never> { get }

    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary
    func markFeedbackSeen(feedbackId: String) async throws
    func ackBackfill() async throws

    /// 取得用戶 pin 在 Training 首頁的徽章 ID（local-first）
    func getPinnedBadgeId() -> String?

    /// 設定 pinned 徽章（傳 nil = unpin）
    func setPinnedBadgeId(_ badgeId: String?)

    /// 取得首頁應展示徽章：pinned > 演算法 fallback > 任一 in-progress > unlocked recent
    /// 完全本地推導，不打 network；caller 必須在 fetchSummary 至少一次後呼叫
    func getDisplayBadge() -> AchievementBadge?

    /// 取所有 status == .inProgress 徽章
    func getInProgressBadges() -> [AchievementBadge]

    /// 取所有 status == .unlocked 徽章，依 unlockedAt 由新到舊排序（展示徽章 picker 用）
    func getUnlockedBadges() -> [AchievementBadge]

    /// 從快取裡找特定 badge by ID
    func findBadge(byId badgeId: String) -> AchievementBadge?
}
