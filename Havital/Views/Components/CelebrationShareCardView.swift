import SwiftUI
import UIKit

// MARK: - CelebrationShareCardView
//
// 4:5 share card (display: 270×337.5, export: 1080×1350 @×4)
// Three rendering scenarios driven by CelebrationContent from CelebrationSheet.swift.

struct CelebrationShareCardView: View {

    // MARK: - ShareField

    struct ShareField: Identifiable {
        let id = UUID()
        let key: String
        let labelKey: String
        let value: String
    }

    // MARK: - ShareData

    struct ShareData: Identifiable {
        let id = UUID()
        let content: CelebrationContent
        let optionalFields: [ShareField]
        let date: String  // YYYY-MM-DD

        /// Sensitive key prefixes (compared case-insensitively).
        static let sensitiveKeyPrefixes: [String] = [
            "heart_rate", "hr_",
            "route", "gps", "location", "coord", "polyline",
            "pace_series", "split_", "lap_",
        ]

        /// Returns only fields whose key does not start with a sensitive prefix.
        func exposableFields() -> [ShareField] {
            optionalFields.filter { field in
                let lower = field.key.lowercased()
                return !Self.sensitiveKeyPrefixes.contains { lower.hasPrefix($0) }
            }
        }
    }

    // MARK: - Layout constants

    static let displayWidth: CGFloat = 270
    static let displayHeight: CGFloat = 337.5
    static let exportScale: CGFloat = 4.0

    let data: ShareData

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            brandRow
            mainContent
            Spacer(minLength: 0)
            footerRow
        }
        .padding(20)
        .frame(width: Self.displayWidth, height: Self.displayHeight)
        .background(
            LinearGradient(
                colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Brand Row

    private var brandRow: some View {
        HStack {
            Text("PACERIZ")
                .font(AppFont.systemScaled(size: 11, weight: .black))
                .foregroundStyle(PacerizTokens.color.brand.primary)
                .tracking(0.5)
            Spacer()
            eyebrowCapsule
        }
    }

    // MARK: - Eyebrow Capsule

    @ViewBuilder
    private var eyebrowCapsule: some View {
        switch data.content {
        case .pbOnly:
            tag(
                text: L10n.Achievements.Share.tagNewPB.localized,
                fg: Color(hex: "#B8860B"),
                bg: Color(hex: "#FFD700").opacity(0.18)
            )
        case .badgesOnly:
            tag(
                text: L10n.Achievements.Share.tagNewBadge.localized,
                fg: Color(hex: "#E65100"),
                bg: Color(hex: "#FFE0B2")
            )
        case .pbWithBadges:
            tag(
                text: L10n.Achievements.Share.tagPBAndBadge.localized,
                fg: Color(hex: "#E65100"),
                bg: Color(hex: "#FFE0B2")
            )
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch data.content {
        case .pbOnly(let pb):
            pbHero(pb, timeFontSize: 48)
        case .badgesOnly(let badges):
            if let badge = badges.first {
                badgeHeroBig(badge)
            } else {
                let _ = { assertionFailure("CelebrationShareCardView: .badgesOnly constructed with empty badges array") }()
                EmptyView()
            }
        case .pbWithBadges(let pb, let badges):
            pbHero(pb, timeFontSize: 36)
            if let badge = badges.first {
                badgeInlineBlock(badge)
            }
        }
    }

    // MARK: - PB Hero

    @ViewBuilder
    private func pbHero(_ pb: PersonalBestUpdate, timeFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let distance = RaceDistanceV2(rawValue: pb.distance) {
                Text(distance.displayName)
                    .font(AppFont.systemScaled(size: 11, weight: .regular))
                    .foregroundStyle(PacerizTokens.color.text.secondary)
                    .lineLimit(1)
            }

            Text(formatTime(pb.newTime))
                .font(.system(size: timeFontSize, weight: .black, design: .default))
                .monospacedDigit()
                .foregroundStyle(PacerizTokens.color.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if pb.improvementSeconds > 0 {
                Text("▲ \(formatImprovement(pb.improvementSeconds))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#27AE60"))
            }
        }
    }

    // MARK: - Badge Hero (big — badgesOnly scenario)

    @ViewBuilder
    private func badgeHeroBig(_ badge: AchievementBadge) -> some View {
        VStack(spacing: 6) {
            Image(AchievementBadgeArtwork.assetName(for: badge))
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                .font(AppFont.systemScaled(size: 14, weight: .bold))
                .foregroundStyle(PacerizTokens.color.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(badge.storyKey.localizedOrFallback(default: ""))
                .font(.system(size: 9))
                .foregroundStyle(PacerizTokens.color.text.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Badge Inline Block (pbWithBadges scenario)

    @ViewBuilder
    private func badgeInlineBlock(_ badge: AchievementBadge) -> some View {
        HStack(spacing: 10) {
            Image(AchievementBadgeArtwork.assetName(for: badge))
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Achievements.Share.alsoUnlocked.localized.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color(hex: "#E65100"))
                    .lineLimit(1)

                Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PacerizTokens.color.text.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#FFF8E1"))
        )
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        Text("paceriz.app · \(data.date)")
            .font(.system(size: 7))
            .foregroundStyle(Color.secondary)
    }

    // MARK: - Tag Capsule Helper

    private func tag(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(AppFont.systemScaled(size: 8, weight: .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
    }

    // MARK: - Time Formatting Helpers

    private func formatTime(_ seconds: Int) -> String {
        TimeFormatting.formatTime(seconds)
    }

    private func formatImprovement(_ seconds: Int) -> String {
        TimeFormatting.formatImprovement(seconds)
    }
}

// MARK: - Image Export

extension CelebrationShareCardView {
    /// Renders a 1080×1350 PNG image (4:5 ratio, ×4 scale).
    @MainActor
    static func render(data: ShareData) -> UIImage? {
        let view = CelebrationShareCardView(data: data)
        let renderer = ImageRenderer(content: view)
        renderer.scale = exportScale
        return renderer.uiImage
    }
}

// MARK: - String Extension (local)

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let localized = NSLocalizedString(self, comment: "")
        return localized == self ? fallback : localized
    }
}
