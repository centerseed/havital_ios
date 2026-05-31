import SwiftUI
import UIKit

// MARK: - Celebration Content Enum

enum CelebrationContent: Equatable {
    case pbOnly(PersonalBestUpdate)
    case badgesOnly([AchievementBadge])
    case pbWithBadges(PersonalBestUpdate, [AchievementBadge])

    var pb: PersonalBestUpdate? {
        switch self {
        case .pbOnly(let pb), .pbWithBadges(let pb, _): return pb
        case .badgesOnly: return nil
        }
    }

    var badges: [AchievementBadge] {
        switch self {
        case .pbOnly: return []
        case .badgesOnly(let b), .pbWithBadges(_, let b): return b
        }
    }
}

// MARK: - CelebrationContent → ShareData helper

extension CelebrationContent {
    /// Build a CelebrationShareCardView.ShareData from this content.
    /// - Parameter today: Override for the current date (used in tests); defaults to Date().
    func toShareData(today: Date = Date()) -> CelebrationShareCardView.ShareData {
        let date: String
        if let pb = self.pb {
            date = pb.workoutDate
        } else {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            date = df.string(from: today)
        }
        return CelebrationShareCardView.ShareData(
            content: self,
            optionalFields: [],
            date: date
        )
    }
}

// MARK: - Celebration Sheet

struct CelebrationSheet: View {
    let content: CelebrationContent
    let onDismiss: () -> Void
    let onShare: () -> Void

    init(
        content: CelebrationContent,
        onDismiss: @escaping () -> Void,
        onShare: @escaping () -> Void = {}
    ) {
        self.content = content
        self.onDismiss = onDismiss
        self.onShare = onShare
    }

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var trophyScale: CGFloat = 0.3
    @State private var trophyOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 22) {
                // MARK: Header Row
                HStack {
                    HStack(spacing: 10) {
                        if content.pb != nil {
                            CelebrationTrophyMark()
                                .scaleEffect(trophyScale)
                                .opacity(trophyOpacity)
                        } else {
                            // badge-only: star icon instead of trophy
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#FF8C00").opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Color(hex: "#FF8C00"))
                            }
                            .scaleEffect(trophyScale)
                            .opacity(trophyOpacity)
                        }

                        eyebrowCapsule
                    }

                    Spacer()

                    if let pb = content.pb {
                        Text(pb.workoutDate)
                            .font(AppFont.captionMedium())
                            .foregroundStyle(PacerizTokens.color.text.secondary)
                    }
                }

                // MARK: PB Section (pbOnly / pbWithBadges)
                if let pb = content.pb {
                    pbSection(pb: pb)
                }

                // MARK: Badge Section (badgesOnly / pbWithBadges)
                if !content.badges.isEmpty {
                    badgeSection(badges: content.badges, isMixed: content.pb != nil)
                }

                // MARK: Action Buttons
                VStack(spacing: 12) {
                    Button {
                        onShare()
                    } label: {
                        Label(L10n.MyAchievement.Celebration.share.localized, systemImage: "square.and.arrow.up")
                            .font(AppFont.bodySmall())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        dismissWithAnimation()
                    } label: {
                        Text(L10n.Common.close.localized)
                            .font(AppFont.bodySmall())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 370, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, PacerizTokens.color.brand.primary.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(PacerizTokens.color.brand.primary.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 32, y: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Eyebrow Capsule

    @ViewBuilder
    private var eyebrowCapsule: some View {
        switch content {
        case .pbOnly:
            Text(L10n.MyAchievement.Celebration.newPB.localized)
                .font(AppFont.systemScaled(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#B8860B"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(hex: "#FFD700").opacity(0.18))
                .clipShape(Capsule())

        case .pbWithBadges:
            Text(L10n.MyAchievement.Celebration.newPBAndBadge.localized)
                .font(AppFont.systemScaled(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FF8C00"), Color(hex: "#FF6B00")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())

        case .badgesOnly:
            Text(L10n.MyAchievement.Celebration.newBadge.localized)
                .font(AppFont.systemScaled(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#FF8C00"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(hex: "#FF8C00").opacity(0.15))
                .clipShape(Capsule())
        }
    }

    // MARK: - PB Section

    @ViewBuilder
    private func pbSection(pb: PersonalBestUpdate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let distance = RaceDistanceV2(rawValue: pb.distance) {
                Text(distance.displayName)
                    .font(AppFont.title3())
                    .foregroundStyle(PacerizTokens.color.text.secondary)
                    .lineLimit(1)
            }

            Text(formatTime(pb.newTime))
                .font(.system(size: 76, weight: .black, design: .default))
                .monospacedDigit()
                .foregroundStyle(PacerizTokens.color.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
        }

        Group {
            if pb.isFirstRecord {
                Label(L10n.MyAchievement.Celebration.firstRecord.localized, systemImage: "flag.checkered.circle.fill")
            } else {
                Label(
                    "\(L10n.MyAchievement.Celebration.improved.localized) \(formatImprovement(pb.improvementSeconds))",
                    systemImage: "chevron.down.circle.fill"
                )
            }
        }
        .font(AppFont.systemScaled(size: 18, weight: .bold))
        .foregroundStyle(pb.isFirstRecord ? PacerizTokens.color.brand.primary : Color(hex: "#27AE60"))
        .lineLimit(1)
        .minimumScaleFactor(0.7)

        if pb.relatedUpdateCount > 0 {
            Text(L10n.MyAchievement.Celebration.otherPBs.localized(with: pb.relatedUpdateCount))
                .font(AppFont.captionMedium())
                .foregroundStyle(PacerizTokens.color.text.secondary)
        }
    }

    // MARK: - Badge Section

    @ViewBuilder
    private func badgeSection(badges: [AchievementBadge], isMixed: Bool) -> some View {
        if isMixed {
            // pbWithBadges: compact badge list below PB info
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.MyAchievement.Celebration.alsoUnlocked.localized)
                    .font(AppFont.captionMedium())
                    .foregroundStyle(PacerizTokens.color.text.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(badges) { badge in
                            VStack(spacing: 4) {
                                Image(AchievementBadgeArtwork.assetName(for: badge))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)

                                Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                                    .font(AppFont.captionSmall())
                                    .foregroundStyle(PacerizTokens.color.text.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 72)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 240)
            }
        } else if let heroBadge = badges.first {
            // badgesOnly: hero for first badge, smaller for rest
            let remaining = Array(badges.dropFirst())


            VStack(alignment: .center, spacing: 14) {
                // Hero badge
                VStack(spacing: 8) {
                    Image(AchievementBadgeArtwork.assetName(for: heroBadge))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)

                    Text(heroBadge.nameKey.localizedOrFallback(default: heroBadge.badgeId))
                        .font(AppFont.systemScaled(size: 18, weight: .bold))
                        .foregroundStyle(PacerizTokens.color.text.primary)
                        .multilineTextAlignment(.center)

                    Text(heroBadge.storyKey.localizedOrFallback(default: ""))
                        .font(AppFont.captionMedium())
                        .foregroundStyle(PacerizTokens.color.text.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity)

                // Additional badges
                if !remaining.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(remaining) { badge in
                                HStack(spacing: 10) {
                                    Image(AchievementBadgeArtwork.assetName(for: badge))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                                            .font(AppFont.bodySmall())
                                            .foregroundStyle(PacerizTokens.color.text.primary)
                                            .lineLimit(1)

                                        Text(badge.storyKey.localizedOrFallback(default: ""))
                                            .font(AppFont.captionSmall())
                                            .foregroundStyle(PacerizTokens.color.text.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
        } else {
            let _ = { assertionFailure("CelebrationSheet: .badgesOnly constructed with empty badges array") }()
            EmptyView()
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) {
            trophyScale = 1.0
            trophyOpacity = 1.0
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        TimeFormatting.formatTime(seconds)
    }

    private func formatImprovement(_ seconds: Int) -> String {
        TimeFormatting.formatImprovement(seconds)
    }
}

// MARK: - Trophy Mark (local copy for CelebrationSheet)

private struct CelebrationTrophyMark: View {
    @State private var pulse: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FFD700").opacity(0.35))
                .frame(width: 52, height: 52)
                .scaleEffect(pulse)
                .opacity(pulseOpacity)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: Color(hex: "#FFD700").opacity(0.55), radius: 16, y: 6)

            Image(systemName: "trophy.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: "#3D2000"))
                .offset(y: -1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = 1.5
                pulseOpacity = 0
            }
        }
    }
}

// MARK: - String Extension (local)

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let localized = NSLocalizedString(self, comment: "")
        return localized == self ? fallback : localized
    }
}
