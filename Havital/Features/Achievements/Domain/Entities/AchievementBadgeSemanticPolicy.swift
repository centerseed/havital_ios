import Foundation

enum AchievementBadgeSemanticPolicy {
    static let supersededLegacyBadgeIds: Set<String> = [
        "BADGE-START-PLAN-STARTED",
        "BADGE-START-FIRST-WEEK"
    ]

    static func isDisplayable(_ badgeId: String) -> Bool {
        !supersededLegacyBadgeIds.contains(badgeId)
    }

    static func isDisplayable(_ badge: AchievementBadge) -> Bool {
        isDisplayable(badge.badgeId)
    }
}
