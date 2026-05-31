import SwiftUI

// MARK: - AchievementTrackCard
//
// 單一成就主線卡：標題 + 進度計數 + 故事 + 里程碑橫向路徑（已解鎖／進行中／鎖定）。
// 主畫面的「成就主線」區塊與「看全部主線」sheet 共用，所有主線一視同仁。

struct AchievementTrackCard: View {
    let track: AchievementTrack

    private static let badgeSize: CGFloat = 46

    var body: some View {
        let unlocked = track.badges.filter { $0.status == .unlocked }.count
        let total = track.badges.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(track.titleKey.localizedOrFallback(default: track.trackId))
                    .font(AppFont.titleM())
                Spacer()
                Text("\(unlocked) / \(total)")
                    .font(AppFont.label().monospacedDigit())
                    .foregroundColor(.secondary)
            }

            let story = track.storyKey.localizedOrFallback(default: "")
            if !story.isEmpty {
                Text(story)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(track.badges.enumerated()), id: \.element.badgeId) { index, badge in
                        milestone(badge)
                        if index < track.badges.count - 1 {
                            connector(done: badge.status == .unlocked)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    private func milestone(_ badge: AchievementBadge) -> some View {
        let isNext = badge.status == .inProgress
        let isUnlocked = badge.status == .unlocked
        let nameColor: Color = isUnlocked ? .primary : (isNext ? PacerizColor.blueDeep : .secondary)
        return VStack(spacing: 6) {
            AchievementBadgeImage(
                assetName: AchievementBadgeArtwork.assetName(for: badge),
                status: badge.status,
                size: Self.badgeSize
            )

            Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                .font(AppFont.micro())
                .foregroundColor(nameColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 36, alignment: .top)

            if isNext, let p = badge.progress, let c = p.current, let t = p.target, t > 0 {
                Text("\(Int((c / t * 100).rounded()))%")
                    .font(AppFont.chip().monospacedDigit())
                    .foregroundColor(PacerizColor.blueDeep)
            } else if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppFont.micro())
                    .foregroundColor(PacerizColor.green)
            } else {
                Text(" ")
                    .font(AppFont.micro())
            }
        }
        .frame(width: 80)
    }

    private func connector(done: Bool) -> some View {
        Rectangle()
            .fill(done ? PacerizColor.blue : Color.gray.opacity(0.25))
            .frame(width: 12, height: 2)
            .padding(.top, Self.badgeSize / 2 - 1)
    }
}

// MARK: - String helpers

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}
