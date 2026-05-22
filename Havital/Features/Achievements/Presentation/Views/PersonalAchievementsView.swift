import SwiftUI
import UIKit

// MARK: - PersonalAchievementsView (Redesigned 2026-05)
struct PersonalAchievementsView: View {
    @StateObject private var viewModel: PersonalAchievementsViewModel
    @State private var shareActivityItem: AchievementActivityItem?
    @State private var selectedPBDetailItem: PersonalBestDetailItem?
    @State private var showTracksPath = false

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
                .sheet(isPresented: $showTracksPath) {
                    AchievementTracksPathView(tracks: viewModel.summary?.achievementTracks ?? [])
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
                .refreshable { await viewModel.refresh() }
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

                // 1. Stats Banner
                statsBannerCard

                // 2. Combined Hero Card (latest unlock + next target)
                heroCard

                // 3. PB Section
                pbSection

                // 4. Badge Collection (chapter cards)
                badgeCollectionSection
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Stats Banner

    private var statsBannerCard: some View {
        let summary = viewModel.summary
        let unlocked = summary?.storySummary.unlockedCount ?? 0
        let total = summary?.storySummary.totalCount ?? 0
        let pbCount = summary?.pbOverview?.records.filter { !$0.time.isEmpty && $0.time != "-" }.count ?? 0
        let pbTotal = 4
        // AchievementLifetimeStats has no streak field — always show "—"
        let streakText: String? = nil

        return HStack(spacing: 0) {
            statsBannerColumn(
                label: L10n.Achievements.StatsBanner.unlockedLabel.localized,
                number: "\(unlocked)",
                suffix: "/ \(total)",
                numberColor: .primary
            )
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 12)
            statsBannerColumn(
                label: L10n.Achievements.StatsBanner.pbLabel.localized,
                number: "\(pbCount)",
                suffix: "/ \(pbTotal)",
                numberColor: PacerizColor.blueDeep
            )
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 12)
            statsBannerColumn(
                label: L10n.Achievements.StatsBanner.streakLabel.localized,
                number: streakText ?? "—",
                suffix: "",
                numberColor: PacerizColor.orangeDeep
            )
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }

    private func statsBannerColumn(
        label: String,
        number: String,
        suffix: String,
        numberColor: Color
    ) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(label)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(number)
                    .font(AppFont.numberLarge().monospacedDigit())
                    .foregroundColor(numberColor)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero Card (Latest unlock + Next target)

    private var heroCard: some View {
        let summary = viewModel.summary
        let latestUnlocked = latestUnlockedBadge
        let nextTarget = nextTargetBadge

        return VStack(alignment: .leading, spacing: 0) {
            // Latest unlocked section
            if let badge = latestUnlocked {
                latestUnlockedSection(badge: badge)
            }

            // Dotted divider if both sections exist
            if latestUnlocked != nil && nextTarget != nil {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundColor(Color.primary.opacity(0.12))
                    .frame(height: 1.5)
                    .padding(.vertical, 14)
            }

            // Next target section
            if let track = nextTarget {
                nextTargetSection(track: track)
            }

            // If no data at all, show placeholder
            if latestUnlocked == nil && nextTarget == nil {
                noHeroDataPlaceholder
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    PacerizColor.blue.opacity(0.12),
                    PacerizColor.blue.opacity(0.04),
                    Color(UIColor.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func latestUnlockedSection(badge: AchievementBadge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // "最新解鎖" chip
            Text(L10n.Achievements.HeroCard.latestUnlock.localized)
                .font(AppFont.micro())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PacerizColor.blue)
                .clipShape(Capsule())

            HStack(alignment: .center, spacing: 12) {
                // Badge hero image 120×120
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 120
                )
                .accessibilityIdentifier("Achievements_HeroBadge_Latest")

                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                        .font(AppFont.numberMedium())
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let unlockedAt = badge.unlockedAt,
                       let formatted = PersonalAchievementsView.formatUnlockedAt(unlockedAt) {
                        Text(formatted)
                            .font(AppFont.micro())
                            .foregroundColor(.secondary)
                    }

                    Text(badge.storyKey.localizedOrFallback(default: ""))
                        .font(AppFont.captionRegular())
                        .foregroundColor(.primary)
                        .lineSpacing(1.5)
                        .lineLimit(4)
                        .padding(.top, 2)

                    // Share + Pin buttons
                    HStack(spacing: 8) {
                        Button {
                            if let shareable = matchingShareable(for: badge) {
                                viewModel.selectShareable(shareable, entry: "hero_card")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(AppFont.micro())
                                Text(L10n.Achievements.HeroCard.share.localized)
                                    .font(AppFont.chip())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(PacerizColor.blue)
                            .cornerRadius(9)
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.togglePin(badgeId: badge.badgeId)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pin")
                                    .font(AppFont.micro())
                                Text(L10n.Achievements.HeroCard.pin.localized)
                                    .font(AppFont.micro())
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .cornerRadius(9)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func nextTargetSection(track: AchievementTrack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // "下一個目標" chip + 查看三條主線提示
            HStack(spacing: 6) {
                Text(L10n.Achievements.HeroCard.nextTarget.localized)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 2) {
                    Text(L10n.Achievements.HeroCard.viewAllTracks.localized)
                        .font(AppFont.micro())
                    Image(systemName: "chevron.right")
                        .font(AppFont.micro())
                }
                .foregroundColor(PacerizColor.blueDeep)
            }

            if let nextBadge = track.nextBadge {
                HStack(alignment: .center, spacing: 12) {
                    // Locked badge 56×56 grayscale + lock overlay
                    ZStack(alignment: .bottomTrailing) {
                        AchievementBadgeImage(
                            assetName: AchievementBadgeArtwork.assetName(for: nextBadge),
                            status: .locked,
                            size: 56
                        )
                    }
                    .frame(width: 56, height: 56)
                    .accessibilityIdentifier("Achievements_HeroBadge_Next")

                    // Progress info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(nextBadge.nameKey.localizedOrFallback(default: nextBadge.badgeId))
                                .font(AppFont.chip())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer()
                            if let progress = nextBadge.progress,
                               let current = progress.current,
                               let target = progress.target, target > 0 {
                                let pct = Int((current / target * 100).rounded())
                                Text("\(pct)%")
                                    .font(AppFont.chip().monospacedDigit())
                                    .foregroundColor(PacerizColor.blueDeep)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(PacerizColor.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // Progress bar 6pt height
                        if let progress = nextBadge.progress,
                           let current = progress.current,
                           let target = progress.target, target > 0 {
                            let ratio = min(current / target, 1.0)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.06))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(
                                            colors: [PacerizColor.blue, PacerizColor.blueDeep],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * ratio, height: 6)
                                }
                            }
                            .frame(height: 6)

                            // Footer hint "X / Y unit · 還差 Z"
                            let unitKey = progress.unitKey ?? ""
                            let unit = unitKey.localizedOrFallback(default: unitKey)
                            let currentInt = current.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(current))" : String(format: "%.1f", current)
                            let targetInt = target.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(target))" : String(format: "%.1f", target)
                            let remaining = target - current
                            let remainingStr = remaining.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(remaining))" : String(format: "%.1f", remaining)
                            let unitSuffix = unit.isEmpty ? "" : " \(unit)"

                            Text("\(currentInt)\(unitSuffix) / \(targetInt)\(unitSuffix) · \(L10n.Achievements.HeroCard.remaining.localized) \(remainingStr)\(unitSuffix)")
                                .font(AppFont.micro())
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(track.storyKey.localizedOrFallback(default: ""))
                                .font(AppFont.micro())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showTracksPath = true }
    }

    private var noHeroDataPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "rosette")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(L10n.Achievements.Hero.noSelection.localized)
                .font(AppFont.bodyMedium())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - PB Section

    @ViewBuilder
    private var pbSection: some View {
        let pbOverview = viewModel.summary?.pbOverview
        let records = pbOverview?.records ?? []
        let hasRecords = !records.isEmpty

        VStack(alignment: .leading, spacing: 10) {
            // Section header: "個人最佳" + "X / 4 已創下"
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Achievements.PBCard.sectionTitle.localized)
                    .font(AppFont.numberMedium())
                    .foregroundColor(.primary)
                Spacer()
                Text(L10n.Achievements.PBCard.setCountFormat.localized(with: records.count))
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // PBRecordsCard
            pbRecordsCard(records: records)
        }
        .accessibilityIdentifier("Achievements_PBSection")
    }

    private func pbRecordsCard(records: [AchievementPBRecord]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack {
                HStack(spacing: 6) {
                    Text("🏆")
                        .font(AppFont.bodyRegular())
                    Text(L10n.Achievements.PBCard.cardTitle.localized)
                        .font(AppFont.bodyStrong())
                    Image(systemName: "info.circle")
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                Spacer()
                Button {
                    // PB detail — show first record's detail if available
                    if let first = records.first {
                        openPBDetail(for: first)
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(L10n.Achievements.PBCard.viewAll.localized)
                            .font(AppFont.chip())
                        Image(systemName: "chevron.right")
                            .font(AppFont.captionRegular())
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if records.isEmpty {
                // Empty state
                VStack(spacing: 6) {
                    Text("🏃")
                        .font(AppFont.titleL())
                    Text(L10n.Achievements.PBCard.noPB.localized)
                        .font(AppFont.chip())
                        .foregroundColor(.secondary)
                    Text(L10n.Achievements.PBCard.noPBHint.localized)
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Grid: up to 4 columns
                let sorted = sortedPBRecords(records)
                let count = min(sorted.count, 4)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: count)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sorted.prefix(4)) { record in
                        Button {
                            openPBDetail(for: record)
                        } label: {
                            pbRecordCell(record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Achievements_PBTile_\(record.distance)")
                    }
                }

                if sorted.count > 4 {
                    Text(L10n.Achievements.PBCard.moreDistancesFormat.localized(with: sorted.count - 4))
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_PBCard")
    }

    private func pbRecordCell(_ record: AchievementPBRecord) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayDistance)
                    .font(AppFont.chip())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(record.time)
                    .font(AppFont.numberMedium().monospacedDigit())
                    .foregroundColor(PacerizColor.blueDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.top, 2)

                Text(record.achievedAt ?? "")
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .lineLimit(1)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        record.isRecent ? PacerizColor.blue : Color.gray.opacity(0.15),
                        lineWidth: record.isRecent ? 1.5 : 1
                    )
            )

            if record.isRecent {
                Text("NEW PB")
                    .font(AppFont.micro())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(PacerizColor.blue)
                    .clipShape(Capsule())
                    .offset(y: -7)
                    .padding(.trailing, 6)
            }
        }
    }

    // MARK: - Badge Collection (Chapter Cards)

    @ViewBuilder
    private var badgeCollectionSection: some View {
        guard let allGroups = viewModel.summary?.badgeGroups, !allGroups.isEmpty else {
            return AnyView(EmptyView())
        }

        // 聰明調整（adapt）、跑者身份（identity）章節暫不展示
        let groups = allGroups.filter { $0.chapter != .adapt && $0.chapter != .identity }
        guard !groups.isEmpty else { return AnyView(EmptyView()) }

        let totalUnlocked = groups.flatMap(\.badges).filter { $0.status == .unlocked }.count
        let totalBadges = groups.flatMap(\.badges).count

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.Achievements.BadgeCollection.title.localized)
                        .font(AppFont.numberMedium())
                        .foregroundColor(.primary)
                    Spacer()
                    Text(L10n.Achievements.BadgeCollection.unlockedCountFormat.localized(with: totalUnlocked, totalBadges))
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Chapter cards
                VStack(spacing: 12) {
                    ForEach(groups) { group in
                        chapterCard(group: group)
                    }
                }
            }
        )
    }

    private func chapterCard(group: AchievementBadgeGroup) -> some View {
        let accentColor = AchievementChapterTheme.primaryColor(for: group.chapter)
        let groupGlyph = chapterGlyph(for: group.chapter)
        let groupTitle = group.titleKey?.localizedOrFallback(default: group.chapter.localizedName) ?? group.chapter.localizedName
        let unlocked = group.badges.filter { $0.status == .unlocked }.count
        let total = group.badges.count
        let pct = total > 0 ? Double(unlocked) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 14) {
            // Chapter header row
            HStack(alignment: .center) {
                // Glyph icon 38×38
                Text(groupGlyph)
                    .font(AppFont.titleM())
                    .frame(width: 38, height: 38)
                    .background(accentColor.opacity(0.22))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(groupTitle)
                        .font(AppFont.labelStrong())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        // Progress bar 90×4
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black.opacity(0.06))
                                .frame(width: 90, height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor)
                                .frame(width: 90 * pct, height: 4)
                        }

                        Text("\(unlocked) / \(total)")
                            .font(AppFont.micro().monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 4)

                Spacer()

                // "看更多" button
                NavigationLink {
                    AchievementBadgeLibraryView(groups: [group]) { badge in
                        viewModel.openBadge(badge, entry: "chapter_card")
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(L10n.Achievements.BadgeCollection.viewMore.localized)
                            .font(AppFont.chip())
                        Image(systemName: "chevron.right")
                            .font(AppFont.captionRegular())
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Horizontal scrolling badge tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.badges) { badge in
                        Button {
                            viewModel.openBadge(badge, entry: "chapter_card")
                        } label: {
                            badgeTile(badge: badge, accentColor: accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .accessibilityIdentifier("Achievements_ChapterCard_\(group.chapter.rawValue)")
    }

    private func badgeTile(badge: AchievementBadge, accentColor: Color) -> some View {
        let isUnlocked = badge.status == .unlocked
        let tileSize: CGFloat = 84
        let cornerRadius: CGFloat = tileSize * 0.22

        return VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                // Badge image
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: tileSize
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                // Green checkmark for unlocked
                if isUnlocked {
                    Image(systemName: "checkmark")
                        .font(AppFont.micro())
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.green)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color(UIColor.secondarySystemGroupedBackground), lineWidth: 1.5))
                        .offset(x: 4, y: 4)
                }
            }
            .shadow(
                color: isUnlocked ? accentColor.opacity(0.25) : Color.black.opacity(0.05),
                radius: isUnlocked ? 8 : 2,
                x: 0, y: isUnlocked ? 4 : 1
            )

            VStack(spacing: 1) {
                Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                    .font(AppFont.chip())
                    .foregroundColor(isUnlocked ? .primary : Color(UIColor.tertiaryLabel))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: tileSize + 14)

                if isUnlocked, let unlockedAt = badge.unlockedAt,
                   let formatted = PersonalAchievementsView.formatUnlockedAt(unlockedAt) {
                    Text(formatted)
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                } else if !isUnlocked {
                    Text(hintText(for: badge))
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .frame(minWidth: tileSize + 8)
    }

    // MARK: - Backfill Banner

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

    // MARK: - Empty / Error

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

    // MARK: - Helpers

    private var allBadges: [AchievementBadge] {
        viewModel.summary?.badgeGroups.flatMap(\.badges) ?? []
    }

    private var latestUnlockedBadge: AchievementBadge? {
        // Prefer pinned badge if available
        if let pinnedId = viewModel.pinnedBadgeId,
           let pinned = allBadges.first(where: { $0.badgeId == pinnedId && $0.status == .unlocked }) {
            return pinned
        }
        // Otherwise most recently unlocked
        return allBadges
            .filter { $0.status == .unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
            .first
    }

    /// 下一個目標：三條主線中「尚未完成」且**離完成最近（進度比例最高）**的那條。
    /// 跳過已完成的主線（其 nextBadge 已是 unlocked），自動前進到下一條未完成主線。
    private var nextTargetBadge: AchievementTrack? {
        let incomplete = (viewModel.summary?.achievementTracks ?? []).filter {
            ($0.nextBadge?.status ?? .unlocked) != .unlocked
        }
        return incomplete.max { Self.trackProgressRatio($0) < Self.trackProgressRatio($1) }
    }

    /// 主線 nextBadge 的進度比例（current / target），無資料則 0。
    static func trackProgressRatio(_ track: AchievementTrack) -> Double {
        guard let p = track.nextBadge?.progress,
              let current = p.current, let target = p.target, target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    private func hintText(for badge: AchievementBadge) -> String {
        if badge.status == .insufficientData {
            return L10n.Achievements.BadgeTile.insufficientData.localized
        }
        if let progress = badge.progress, let summaryKey = progress.summaryKey {
            return summaryKey.achievementLocalized(params: progress.summaryParams)
        }
        return L10n.Achievements.BadgeTile.locked.localized
    }

    private func chapterGlyph(for chapter: AchievementChapter) -> String {
        switch chapter {
        case .start:    return "🌱"
        case .build:    return "📈"
        case .adapt:    return "🔥"
        case .prove:    return "🏆"
        case .identity: return "⭐"
        case .unknown:  return "🎖"
        }
    }

    private func sortedPBRecords(_ records: [AchievementPBRecord]) -> [AchievementPBRecord] {
        let weight: [String: Int] = ["42": 6, "21": 5, "10": 4, "5": 3, "3": 2, "1": 1]
        return records.sorted { lhs, rhs in
            let lv = pbDistanceValue(lhs)
            let rv = pbDistanceValue(rhs)
            if lv == rv { return lhs.displayDistance < rhs.displayDistance }
            return lv > rv
        }
    }

    private func pbDistanceValue(_ record: AchievementPBRecord) -> Double {
        distanceValue(from: record.distance) ?? distanceValue(from: record.displayDistance) ?? 0
    }

    private func distanceValue(from text: String) -> Double? {
        let numericText = text.filter { $0.isNumber || $0 == "." }
        return Double(numericText)
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

    static func formatUnlockedAt(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let date = iso8601Formatter.date(from: trimmed) ?? iso8601FormatterNoFraction.date(from: trimmed) {
            return DateFormatterHelper.formatter(dateFormat: "yyyy/MM/dd").string(from: date)
        }
        return String(trimmed.prefix(10))
    }
}

// MARK: - AchievementBadgeLibraryView (kept as internal navigation destination)
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

// MARK: - String helpers

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}

// MARK: - Private types

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
