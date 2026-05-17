import SwiftUI
import UIKit

struct PersonalAchievementsView: View {
    @StateObject private var viewModel: PersonalAchievementsViewModel
    @State private var shareActivityItem: AchievementActivityItem?

    private var cachedUser: User? {
        UserProfileLocalDataSource().getUserProfile()
    }

    private var cachedPersonalBestData: [String: [PersonalBestRecordV2]]? {
        cachedUser?.personalBestV2?["race_run"]
    }

    private var personalBestCount: Int {
        if let records = viewModel.summary?.pbOverview?.records, !records.isEmpty {
            return records.count
        }
        return cachedPersonalBestData?.count ?? 0
    }

    @MainActor
    init(viewModel: PersonalAchievementsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? PersonalAchievementsViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle(L10n.Achievements.title.localized)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.trackTabOpenIfNeeded()
                    viewModel.load()
                }
                .sheet(item: $viewModel.selectedBadge) { badge in
                    AchievementDetailView(
                        badge: badge,
                        shareable: matchingShareable(for: badge),
                        onShare: { shareable in
                            viewModel.selectedBadge = nil
                            viewModel.selectShareable(shareable, entry: "badge_detail")
                        },
                        pinnedBadgeId: viewModel.pinnedBadgeId,
                        onTogglePin: { badgeId in viewModel.togglePin(badgeId: badgeId) }
                    )
                }
                .sheet(item: $viewModel.selectedShareable, onDismiss: {
                    viewModel.closeShare()
                }) { shareable in
                    AchievementSharePreviewSheet(
                        shareable: shareable,
                        onShare: { image in
                            shareActivityItem = AchievementActivityItem(image: image)
                        }
                    )
                }
                .sheet(item: $shareActivityItem) { item in
                    AchievementActivityViewController(items: [item.image]) {
                        viewModel.completeShare()
                        shareActivityItem = nil
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .empty:
            ScrollView { emptyView.padding(.vertical) }
        case .error(let message):
            errorView(message)
        case .loaded:
            loadedView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L10n.Achievements.loading.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadedView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.showBackfillBanner {
                    backfillBanner
                }

                achievementOverviewCard

                if let pbOverview = viewModel.summary?.pbOverview, !pbOverview.records.isEmpty {
                    pbRecordsCard(pbOverview)
                } else {
                    PersonalBestCardView(personalBestData: cachedPersonalBestData)
                }

                if let lifetimeStats = viewModel.summary?.lifetimeStats, lifetimeStats.hasAnyValue {
                    lifetimeStatsCard(lifetimeStats)
                }

                badgeLibraryEntry
            }
            .padding(.vertical)
        }
    }

    private var achievementOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitleWithInfo(
                title: L10n.Achievements.Story.title.localized,
                explanation: L10n.Achievements.Story.explanation.localized
            )

            if let story = viewModel.summary?.storySummary {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    DataItem(
                        title: L10n.Achievements.Status.unlocked.localized,
                        value: "\(story.unlockedCount)/\(story.totalCount)",
                        icon: "trophy"
                    )
                    DataItem(
                        title: L10n.Achievements.PB.title.localized,
                        value: "\(personalBestCount)",
                        icon: "crown"
                    )
                    DataItem(
                        title: L10n.Achievements.Stats.completedWeeks.localized,
                        value: "\(viewModel.summary?.lifetimeStats.completedWeeks ?? 0)",
                        icon: "checkmark.circle"
                    )
                }

                VStack(spacing: 8) {
                    storySnapshotRow(
                        title: L10n.Achievements.Story.recentUnlock.localized,
                        snapshot: story.recentUnlock,
                        fallback: L10n.Achievements.Story.noRecentUnlock.localized
                    )
                    storySnapshotRow(
                        title: L10n.Achievements.Story.nextBadge.localized,
                        snapshot: story.nextBadge,
                        fallback: story.emptyStateKey?.localizedOrFallback(default: L10n.Achievements.Empty.start.localized) ?? L10n.Achievements.Empty.start.localized
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_OverviewCard")
    }

    private func storySnapshotRow(title: String, snapshot: AchievementBadgeSnapshot?, fallback: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let snapshot {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: snapshot),
                    status: snapshot.status ?? .unlocked,
                    size: 44
                )
            } else {
                Image(systemName: "flag.checkered")
                    .font(AppFont.title3())
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                Text(snapshot?.nameKey.localizedOrFallback(default: fallback) ?? fallback)
                    .font(AppFont.bodyMedium())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                if let storyKey = snapshot?.storyKey {
                    Text(storyKey.localizedOrFallback(default: ""))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    }
                }
            Spacer()
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func pbRecordsCard(_ overview: AchievementPBOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: overview.titleKey?.localizedOrFallback(default: L10n.Achievements.PB.title.localized) ?? L10n.Achievements.PB.title.localized,
                explanation: L10n.Achievements.PB.explanation.localized
            )

            if overview.records.isEmpty {
                Text(L10n.Achievements.PB.empty.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sortedPBRecords(overview.records)) { record in
                            pbRecordTile(record)
                                .frame(width: 128)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_PBCard")
    }

    private func pbRecordTile(_ record: AchievementPBRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(record.displayDistance)
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if record.isRecent {
                    Image(systemName: "sparkle")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.blue)
                }
            }

            Text(record.time)
                .font(AppFont.systemScaled(size: 20, weight: .bold))
                .foregroundColor(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(record.achievedAt ?? L10n.Achievements.PB.record.localized)
                .font(AppFont.captionSmall())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 70)
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func sortedPBRecords(_ records: [AchievementPBRecord]) -> [AchievementPBRecord] {
        records.sorted { lhs, rhs in
            let lhsDistance = pbDistanceValue(lhs)
            let rhsDistance = pbDistanceValue(rhs)
            if lhsDistance == rhsDistance {
                return lhs.displayDistance < rhs.displayDistance
            }
            return lhsDistance > rhsDistance
        }
    }

    private func pbDistanceValue(_ record: AchievementPBRecord) -> Double {
        distanceValue(from: record.distance) ?? distanceValue(from: record.displayDistance) ?? 0
    }

    private func distanceValue(from text: String) -> Double? {
        let numericText = text.filter { $0.isNumber || $0 == "." }
        return Double(numericText)
    }

    private func lifetimeStatsCard(_ stats: AchievementLifetimeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: L10n.Achievements.Stats.title.localized,
                explanation: L10n.Achievements.Stats.explanation.localized
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                DataItem(
                    title: L10n.Achievements.Stats.totalRuns.localized,
                    value: "\(stats.totalRuns)",
                    icon: "figure.run"
                )
                DataItem(
                    title: L10n.Achievements.Stats.totalDistance.localized,
                    value: L10n.Achievements.Stats.kilometers.localized(with: distanceText(stats.totalDistanceKm)),
                    icon: "location"
                )
                DataItem(
                    title: L10n.Achievements.Stats.completedWeeks.localized,
                    value: "\(stats.completedWeeks)",
                    icon: "checkmark.circle"
                )
                DataItem(
                    title: L10n.Achievements.Stats.longestRun.localized,
                    value: L10n.Achievements.Stats.kilometers.localized(with: distanceText(stats.longestRunKm)),
                    icon: "arrow.up.right"
                )
            }

            if let firstWorkoutDate = stats.firstWorkoutDate {
                HStack {
                    Text(L10n.Achievements.Stats.firstWorkout.localized)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(firstWorkoutDate)
                        .font(AppFont.caption())
                        .foregroundColor(.primary)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_LifetimeStatsCard")
    }

    private var badgeLibraryEntry: some View {
        guard let groups = viewModel.summary?.badgeGroups else {
            return AnyView(EmptyView())
        }
        let featuredBadges = groups
            .flatMap(\.badges)
            .filter { $0.status == .unlocked || $0.status == .inProgress }
            .prefix(4)
        let unlocked = groups.flatMap(\.badges).filter { $0.status == .unlocked }.count
        let total = groups.flatMap(\.badges).count

        return AnyView(
            NavigationLink {
                AchievementBadgeLibraryView(groups: groups) { badge in
                    viewModel.openBadge(badge, entry: "badge_library")
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Achievements.Badges.title.localized)
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                            Text(L10n.Achievements.Badges.explanation.localized)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }

                    if !featuredBadges.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(Array(featuredBadges), id: \.badgeId) { badge in
                                featuredBadgePreview(badge)
                            }
                        }
                    } else {
                        Text(L10n.Achievements.Badges.emptyPreview.localized)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 8) {
                        Text(L10n.Achievements.Badges.progress.localized(with: unlocked, total))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(.horizontal)
                .accessibilityIdentifier("Achievements_BadgeLibraryEntry")
            }
            .buttonStyle(.plain)
        )
    }

    private func featuredBadgePreview(_ badge: AchievementBadge) -> some View {
        VStack(spacing: 6) {
            AchievementBadgeImage(
                assetName: AchievementBadgeArtwork.assetName(for: badge),
                status: badge.status,
                size: 54
            )
            Text(badge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                .font(AppFont.captionSmall())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var backfillBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.blue)
                .font(AppFont.title3())

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.summary?.backfill.bannerKey?.localizedOrFallback(default: L10n.Achievements.Backfill.ready.localized) ?? L10n.Achievements.Backfill.ready.localized)
                    .font(AppFont.bodyMedium())
                Text(L10n.Achievements.Backfill.count.localized(with: viewModel.summary?.backfill.historicalUnlockCount ?? 0))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.Common.done.localized) {
                viewModel.acknowledgeBackfill()
            }
            .font(AppFont.caption())
            .disabled(viewModel.isAcknowledgingBackfill)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(AppFont.dataMedium())
                .foregroundColor(.secondary)
            Text(L10n.Achievements.Empty.title.localized)
                .font(AppFont.headline())
            Text(L10n.Achievements.Empty.start.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(L10n.Common.reload.localized) {
                viewModel.load(forceRefresh: true)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.title2())
                .foregroundColor(.orange)
            Text(L10n.Achievements.Error.loadFailed.localized)
                .font(AppFont.headline())
            Text(message)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(L10n.Common.retry.localized) {
                viewModel.load(forceRefresh: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func matchingShareable(for badge: AchievementBadge) -> AchievementShareable? {
        viewModel.summary?.recentShareables.first {
            $0.materialType == .badge && $0.badgeId == badge.badgeId
        }
    }

    private func distanceText(_ kilometers: Double) -> String {
        let rounded = (kilometers * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

private struct AchievementBadgeLibraryView: View {
    let groups: [AchievementBadgeGroup]
    let onOpenBadge: (AchievementBadge) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.titleKey?.localizedOrFallback(default: group.chapter.localizedName) ?? group.chapter.localizedName)
                                    .font(AppFont.headline())
                                    .foregroundColor(.primary)
                                Text("\(group.badges.filter { $0.status == .unlocked }.count) / \(group.badges.count)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        LazyVGrid(columns: badgeColumns, spacing: 12) {
                            ForEach(group.badges) { badge in
                                AchievementBadgeTile(badge: badge) {
                                    onOpenBadge(badge)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(L10n.Achievements.Badges.title.localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var badgeColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
}

private struct AchievementBadgeTile: View {
    let badge: AchievementBadge
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 70
                )

                Text(badge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                    .font(AppFont.caption())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)

                Text(statusText)
                    .font(AppFont.captionSmall())
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if badge.historicalBackfill {
            return L10n.Achievements.Badges.historical.localized
        }
        if let progress = badge.progress, let summaryKey = progress.summaryKey, badge.status == .inProgress {
            return summaryKey.achievementLocalized(params: progress.summaryParams)
        }
        return badge.status.localizedName
    }

    private var statusColor: Color {
        switch badge.status {
        case .unlocked: return .blue
        case .inProgress: return .green
        case .insufficientData: return .secondary
        case .locked, .unknown: return .gray
        }
    }
}

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}

private struct AchievementActivityItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AchievementActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
