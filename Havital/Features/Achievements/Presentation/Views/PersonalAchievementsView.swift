import SwiftUI
import UIKit

struct PersonalAchievementsView: View {
    @StateObject private var viewModel: PersonalAchievementsViewModel
    @State private var shareActivityItem: AchievementActivityItem?
    @State private var selectedPBDetailItem: PersonalBestDetailItem?

    private var cachedUser: User? {
        UserProfileLocalDataSource().getUserProfile()
    }

    private var cachedPersonalBestData: [String: [PersonalBestRecordV2]]? {
        cachedUser?.personalBestV2?["race_run"]
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
                // Library-tab "share a badge" entry point intentionally keeps
                // AchievementSharePreviewSheet — AchievementShareable carries
                // backend-shaped fields (materialType / publicFields) that don't
                // map cleanly to CelebrationContent. Celebration flow uses
                // CelebrationSharePreviewSheet (result-type info); this path uses
                // the shareable-shaped variant. Two paths by design (decided 2026-05-17).
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
                .sheet(item: $selectedPBDetailItem) { item in
                    PersonalBestDetailView(distance: item.distance, records: item.records)
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

                achievementTrackRoutes

                badgeHeroCard

                if let pbOverview = viewModel.summary?.pbOverview, !pbOverview.records.isEmpty {
                    pbRecordsCard(pbOverview)
                } else {
                    PersonalBestCardView(personalBestData: cachedPersonalBestData)
                }

                badgeLibraryEntry
            }
            .padding(.vertical)
        }
    }

    private var allBadges: [AchievementBadge] {
        routeBadgeGroups.flatMap(\.badges)
    }

    private var routeBadgeGroups: [AchievementRouteBadgeGroup] {
        guard let summary = viewModel.summary else { return [] }
        if !summary.achievementTracks.isEmpty {
            return summary.achievementTracks.map { track in
                AchievementRouteBadgeGroup(
                    id: track.trackId,
                    titleKey: track.titleKey,
                    fallbackTitle: track.trackId.capitalized,
                    badges: track.badges
                )
            }
        }
        return []
    }

    private var unlockedBadges: [AchievementBadge] {
        allBadges
            .filter { $0.status == .unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
    }

    private var selectedHeroBadge: AchievementBadge? {
        SelectDisplayBadgeUseCase().execute(
            pinnedBadgeId: viewModel.pinnedBadgeId,
            allBadges: allBadges
        )
    }

    private var badgeHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitleWithInfo(
                title: L10n.Achievements.Hero.title.localized,
                explanation: L10n.Achievements.Hero.explanation.localized
            )

            heroBadgeDisplay

            heroPickerRow
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_HeroCard")
    }

    @ViewBuilder
    private var heroBadgeDisplay: some View {
        if let badge = selectedHeroBadge {
            VStack(spacing: 10) {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 140
                )
                .accessibilityIdentifier("Achievements_HeroBadge")

                Text(badge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                    .font(AppFont.title3())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let unlockedAt = badge.unlockedAt, let formatted = Self.formatUnlockedAt(unlockedAt) {
                    Text(L10n.Achievements.Hero.unlockedAt.localized(with: formatted))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "rosette")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                Text(L10n.Achievements.Hero.noSelection.localized)
                    .font(AppFont.bodyMedium())
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var heroPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Achievements.Hero.pickerTitle.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            if unlockedBadges.isEmpty {
                Text(L10n.Achievements.Hero.pickerEmpty.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(unlockedBadges, id: \.badgeId) { badge in
                            heroPickerThumbnail(badge)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func heroPickerThumbnail(_ badge: AchievementBadge) -> some View {
        let isSelected = selectedHeroBadge?.badgeId == badge.badgeId
        return Button {
            viewModel.togglePin(badgeId: badge.badgeId)
        } label: {
            AchievementBadgeImage(
                assetName: AchievementBadgeArtwork.assetName(for: badge),
                status: badge.status,
                size: 56
            )
            .padding(4)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? PacerizTokens.color.brand.primary : Color.clear,
                        lineWidth: 2.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isSelected ? "Achievements_HeroPicker_Selected" : "Achievements_HeroPicker_Item")
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
                            Button {
                                openPBDetail(for: record)
                            } label: {
                                pbRecordTile(record)
                                    .frame(width: 128)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Achievements_PBTile_\(record.distance)")
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

    private var badgeLibraryEntry: some View {
        let groups = routeBadgeGroups
        guard !groups.isEmpty else {
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

    @ViewBuilder
    private var achievementTrackRoutes: some View {
        if let tracks = viewModel.summary?.achievementTracks, !tracks.isEmpty {
            VStack(spacing: 12) {
                ForEach(tracks) { track in
                    achievementTrackCard(track)
                }
            }
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Achievements_TrackRoutes")
        }
    }

    @ViewBuilder
    private func achievementTrackCard(_ track: AchievementTrack) -> some View {
        if let nextBadge = track.nextBadge {
            Button {
                viewModel.openBadge(nextBadge, entry: "achievement_track")
            } label: {
                achievementTrackCardContent(track, nextBadge: nextBadge)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(track.titleKey.localizedOrFallback(default: track.trackId.capitalized))
            .accessibilityIdentifier("Achievements_TrackCard_\(track.trackId)")
        } else {
            achievementTrackCardContent(track, nextBadge: nil)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(track.titleKey.localizedOrFallback(default: track.trackId.capitalized))
                .accessibilityIdentifier("Achievements_TrackCard_\(track.trackId)")
        }
    }

    private func achievementTrackCardContent(_ track: AchievementTrack, nextBadge: AchievementBadge?) -> some View {
        let progress = achievementTrackProgress(track, nextBadge: nextBadge)
        return HStack(alignment: .top, spacing: 12) {
            if let nextBadge {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: nextBadge),
                    status: nextBadge.status,
                    size: 62
                )
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.titleKey.localizedOrFallback(default: track.trackId.capitalized))
                        .font(AppFont.headline())
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(track.storyKey.localizedOrFallback(default: ""))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let nextBadge {
                    Text(nextBadge.nameKey.localizedOrFallback(default: L10n.Achievements.Badges.badge.localized))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: progress.value)
                        .progressViewStyle(.linear)
                        .tint(nextBadge.map { AchievementChapterTheme.primaryColor(for: $0.chapter) } ?? PacerizTokens.color.brand.primary)
                        .frame(height: 5)

                    Text(L10n.Achievements.Detail.progress.localized + " · " + progress.text)
                        .font(AppFont.captionSmall())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if nextBadge != nil {
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private func achievementTrackProgress(_ track: AchievementTrack, nextBadge: AchievementBadge?) -> (value: Double, text: String) {
        let rawCurrent = nextBadge?.progress?.current ?? track.current ?? 0
        let rawTarget = nextBadge?.progress?.target ?? 1
        let target = rawTarget > 0 ? rawTarget : 1
        let value = min(max(rawCurrent / target, 0), 1)
        let unitKey = nextBadge?.progress?.unitKey
        let currentText = achievementProgressValueText(rawCurrent, unitKey: unitKey)
        let targetText = achievementProgressValueText(target, unitKey: unitKey)
        return (
            value: value,
            text: "achievement.progress.current_target".localized(with: currentText, targetText)
        )
    }

    private func achievementProgressValueText(_ value: Double, unitKey: String?) -> String {
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
        guard let unitKey else { return formatted }
        let unit = unitKey.localizedOrFallback(default: "")
        return unit.isEmpty ? formatted : "\(formatted) \(unit)"
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

    private func openPBDetail(for record: AchievementPBRecord) {
        guard let distance = RaceDistanceV2(rawValue: record.distance) else { return }
        let records = cachedPersonalBestData?[distance.rawValue] ?? []
        guard !records.isEmpty else { return }
        selectedPBDetailItem = PersonalBestDetailItem(distance: distance, records: records)
    }

    private func matchingShareable(for badge: AchievementBadge) -> AchievementShareable? {
        viewModel.summary?.recentShareables.first {
            $0.materialType == .badge && $0.badgeId == badge.badgeId
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// 把 `unlockedAt`（ISO8601 UTC 或 yyyy-MM-dd）格式化為使用者時區的短日期。
    static func formatUnlockedAt(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let date = iso8601Formatter.date(from: trimmed) ?? iso8601FormatterNoFraction.date(from: trimmed) {
            return DateFormatterHelper.formatter(dateFormat: "yyyy/MM/dd").string(from: date)
        }
        return String(trimmed.prefix(10))
    }
}

private struct AchievementRouteBadgeGroup: Identifiable, Equatable {
    let id: String
    let titleKey: String?
    let fallbackTitle: String
    let badges: [AchievementBadge]
}

private struct AchievementBadgeLibraryView: View {
    let groups: [AchievementRouteBadgeGroup]
    let onOpenBadge: (AchievementBadge) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.titleKey?.localizedOrFallback(default: group.fallbackTitle) ?? group.fallbackTitle)
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

                if badge.status == .inProgress, let progress = badge.progress,
                   let current = progress.current, let target = progress.target, target > 0 {
                    ProgressView(value: min(current / target, 1))
                        .progressViewStyle(.linear)
                        .tint(chapterAccentColor)
                        .frame(height: 4)
                }

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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(chapterAccentColor.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var chapterAccentColor: Color {
        AchievementChapterTheme.primaryColor(for: badge.chapter)
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
        case .unlocked:          return PacerizTokens.color.brand.primary
        case .inProgress:        return PacerizTokens.color.semantic.success
        case .insufficientData:  return Color.secondary
        case .locked, .unknown:  return Color.gray
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
