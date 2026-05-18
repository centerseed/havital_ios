import Foundation

// MARK: - AchievementBadgeSnapshot
/// A snapshot of an achievement badge suitable for display in UI components.
/// Used by WeekOverviewCardV2 to show the current progress badge.
struct AchievementBadgeSnapshot: Equatable {
    /// Unique identifier for the badge, used to look up the asset (e.g. "badge_rhythm_builder_01")
    let badgeId: String

    /// Display name of the badge
    let name: String

    /// Chapter / category the badge belongs to (e.g. "consistency", "distance")
    let chapter: String?

    /// Badge status
    let status: AchievementBadgeStatus

    /// Timestamp when the badge was unlocked; nil if still locked
    let unlockedAt: Date?

    var isUnlocked: Bool {
        status == .unlocked
    }
}

// MARK: - AchievementBadgeStatus
enum AchievementBadgeStatus: String, Equatable {
    case unlocked
    case inProgress = "in_progress"
    case locked
}

// MARK: - AchievementStorySummary
/// Aggregated story summary for displaying progress badges in the training plan.
struct AchievementStorySummary: Equatable {
    /// The most recently unlocked badge, if any.
    let recentUnlock: AchievementBadgeSnapshot?

    /// The next badge the user is working toward; may be nil if no next badge defined.
    let nextBadge: AchievementBadgeSnapshot?
}

// MARK: - AchievementSummary
/// Top-level summary returned by AchievementRepository.fetchSummary().
struct AchievementSummary: Equatable {
    let storySummary: AchievementStorySummary

    /// Total number of badges unlocked
    let totalUnlocked: Int
}
