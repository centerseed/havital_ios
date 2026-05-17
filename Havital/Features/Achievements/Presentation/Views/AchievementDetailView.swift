import SwiftUI

struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let badge: AchievementBadge
    let shareable: AchievementShareable?
    let onShare: (AchievementShareable) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    storySection
                    if let progress = badge.progress {
                        progressSection(progress)
                    }
                    if let source = badge.sourceRef {
                        sourceSection(source)
                    }
                    if badge.historicalBackfill {
                        historicalSection
                    }
                    if let shareable {
                        Button {
                            onShare(shareable)
                        } label: {
                            Label(L10n.Achievements.Share.action.localized, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Detail.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 76
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(badge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                        .font(AppFont.title3())
                    Text(badge.chapter.localizedName)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(badge.status.localizedName)
                .font(AppFont.caption())
                .foregroundColor(.blue)

            if let unlockedAt = badge.unlockedAt {
                Text(L10n.Achievements.Detail.unlockedAt.localized(with: unlockedAt))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Achievements.Detail.story.localized)
                .font(AppFont.headline())
            Text(badge.storyKey.localizedOrFallback(default: ""))
                .font(AppFont.bodySmall())
                .foregroundColor(.primary)
            if let reasonKey = badge.unlockReasonKey {
                Text(reasonKey.localizedOrFallback(default: ""))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private func progressSection(_ progress: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Achievements.Detail.progress.localized)
                .font(AppFont.headline())
            if let summaryKey = progress.summaryKey {
                Text(summaryKey.achievementLocalized(params: progress.summaryParams))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            }
            if let current = progress.current, let target = progress.target, target > 0 {
                ProgressView(value: min(current / target, 1))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private func sourceSection(_ source: AchievementSourceRef) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Achievements.Detail.source.localized)
                .font(AppFont.headline())
            Text(source.labelKey?.localizedOrFallback(default: source.type) ?? source.type)
                .font(AppFont.bodyMedium())
            if let summaryKey = source.summaryKey {
                Text(summaryKey.achievementLocalized(params: source.summaryParams))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private var historicalSection: some View {
        Text(L10n.Achievements.Detail.historical.localized)
            .font(AppFont.bodySmall())
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}
