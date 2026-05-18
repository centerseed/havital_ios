import SwiftUI

// MARK: - AchievementBadgeHeroView
/// Displays an achievement badge in the WeekOverviewCardV2 hero section.
///
/// Rendering rules:
/// - badge != nil && isUnlocked  → real badge image at full color
/// - badge != nil && !isUnlocked → real badge image with grayscale + locked overlay
/// - badge == nil               → PRPlaceholderBadge fallback (no crash)
///
/// Asset naming: uses badge.assetName if set, falls back to "badge_\(badge.badgeId)".
/// If the asset is missing, falls back to PRPlaceholderBadge.
struct AchievementBadgeHeroView: View {

    let badge: AchievementBadge?
    let isUnlocked: Bool
    let size: CGFloat

    init(badge: AchievementBadge?, isUnlocked: Bool, size: CGFloat = 72) {
        self.badge = badge
        self.isUnlocked = isUnlocked
        self.size = size
    }

    var body: some View {
        if let badge = badge {
            let assetName = badge.assetName ?? "badge_\(badge.badgeId)"
            if UIImage(named: assetName) != nil {
                // Real badge asset found
                realBadgeView(assetName: assetName, badge: badge)
            } else {
                // Asset not bundled — use placeholder
                PRPlaceholderBadge(size: size)
            }
        } else {
            // No badge data — use placeholder
            PRPlaceholderBadge(size: size)
        }
    }

    @ViewBuilder
    private func realBadgeView(assetName: String, badge: AchievementBadge) -> some View {
        let base = Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())

        if isUnlocked {
            base.shadow(
                color: PacerizColor.blue.opacity(0.30),
                radius: 9,
                x: 0,
                y: 8
            )
        } else {
            base
                .grayscale(1.0)
                .overlay(Circle().fill(Color.black.opacity(0.35)))
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.25, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 9,
                    x: 0,
                    y: 8
                )
        }
    }
}
