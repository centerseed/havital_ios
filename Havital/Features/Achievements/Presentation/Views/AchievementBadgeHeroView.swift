import SwiftUI

// MARK: - AchievementBadgeHeroView
/// Displays an achievement badge in the WeekOverviewCardV2 hero section.
///
/// Rendering rules (2026-05 redesign):
/// - badge != nil (any status) → real badge image at full color, always colorful
/// - badge == nil              → PRPlaceholderBadge fallback (no crash)
///
/// Grayscale + lock overlay intentionally removed: if a plan exists, a badge always shows
/// in full color regardless of unlock status.
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
                // Real badge asset found — always full color
                realBadgeView(assetName: assetName)
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
    private func realBadgeView(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(
                color: PacerizColor.blue.opacity(0.30),
                radius: 9,
                x: 0,
                y: 8
            )
    }
}
