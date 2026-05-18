import Foundation

// MARK: - AchievementRepository
/// Protocol for fetching achievement and badge data.
/// Phase B: implemented as a stub returning nil until backend badge endpoint is available.
protocol AchievementRepository: AnyObject {
    /// Fetches the achievement summary including story badges.
    /// - Parameter forceRefresh: If true, bypasses cache and fetches from remote.
    /// - Returns: Summary with storySummary.recentUnlock and .nextBadge, or nil if unavailable.
    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary?

    /// Returns the best badge to display for the current user:
    /// recentUnlock if available, otherwise nextBadge.
    func getDisplayBadge() async -> AchievementBadgeSnapshot?

    /// Returns all badges that are currently in progress (status == .inProgress).
    func getInProgressBadges() async -> [AchievementBadgeSnapshot]
}

// MARK: - Default implementations
extension AchievementRepository {
    func fetchSummary() async throws -> AchievementSummary? {
        return try await fetchSummary(forceRefresh: false)
    }

    func getDisplayBadge() async -> AchievementBadgeSnapshot? {
        guard let summary = try? await fetchSummary(forceRefresh: false) else { return nil }
        return summary.storySummary.recentUnlock ?? summary.storySummary.nextBadge
    }

    func getInProgressBadges() async -> [AchievementBadgeSnapshot] {
        guard let summary = try? await fetchSummary(forceRefresh: false) else { return [] }
        return [summary.storySummary.nextBadge].compactMap { $0 }.filter { $0.status == .inProgress }
    }
}
