import SwiftUI
import UIKit

// MARK: - PersonalAchievementsView (Redesigned 2026-05)
struct PersonalAchievementsView: View {
    @StateObject private var viewModel: PersonalAchievementsViewModel
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
                        shareable: badge.status == .unlocked ? resolvedShareable(for: badge) : nil,
                        onShare: { shareable in
                            viewModel.selectedBadge = nil
                            viewModel.selectShareable(shareable, entry: "badge_detail")
                        }
                    )
                }
                .sheet(item: $viewModel.selectedShareable, onDismiss: {
                    viewModel.closeShare()
                }) { shareable in
                    AchievementSharePreviewSheet(
                        shareable: shareable,
                        badgeAssetName: shareBadgeAssetName(for: shareable),
                        onShared: { viewModel.completeShare() }
                    )
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
        // PB 數量＝所有距離內擁有的個人最佳筆數（無固定分母）。
        let pbCount = summary?.pbOverview?.records.filter { !$0.time.isEmpty && $0.time != "-" }.count ?? 0
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
                suffix: "",
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

                    // Share button
                    Button {
                        viewModel.selectShareable(resolvedShareable(for: badge), entry: "hero_card")
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
            // Card header — 所有距離已在下方橫向列出，無需「查看全部」（每張卡片點擊即看詳情）。
            HStack(spacing: 6) {
                Text("🏆")
                    .font(AppFont.bodyRegular())
                Text(L10n.Achievements.PBCard.cardTitle.localized)
                    .font(AppFont.bodyStrong())
                Image(systemName: "info.circle")
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                Spacer()
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
                // 水平捲動，全部距離都列出；卡片依內容寬、時間不縮放（字級一致）。
                let sorted = sortedPBRecords(records)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sorted) { record in
                            Button {
                                openPBDetail(for: record)
                            } label: {
                                pbRecordCell(record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Achievements_PBTile_\(record.distance)")
                        }
                    }
                    .padding(.vertical, 2)   // 給陰影/邊框一點呼吸空間
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
                    .fixedSize(horizontal: true, vertical: false)   // 不縮放，所有時間同字級
                    .padding(.top, 2)
                // 日期在窄卡只會顯示成「2026-…」截斷、無意義 → 不顯示。
            }
            .frame(minWidth: 72, alignment: .leading)   // 卡片依內容寬、最短也有底寬，水平捲動
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

        // 里程軌跡碑獨立成一張卡，因此把它的徽章從章節卡裡濾掉，避免同一顆顯示兩次。
        let mileageTrack = viewModel.summary?.achievementTracks.first { $0.trackId == "mileage_markers" }
        let mileageIds = Set(mileageTrack?.badges.map(\.badgeId) ?? [])

        // 聰明調整（adapt）、跑者身份（identity）章節暫不展示
        let groups = allGroups
            .filter { $0.chapter != .adapt && $0.chapter != .identity }
            .map { group in
                AchievementBadgeGroup(
                    chapter: group.chapter,
                    titleKey: group.titleKey,
                    badges: group.badges.filter { !mileageIds.contains($0.badgeId) }
                )
            }
            .filter { !$0.badges.isEmpty }

        let mileageBadges = mileageTrack?.badges ?? []
        guard !groups.isEmpty || !mileageBadges.isEmpty else { return AnyView(EmptyView()) }

        let totalUnlocked = (groups.flatMap(\.badges) + mileageBadges).filter { $0.status == .unlocked }.count
        let totalBadges = groups.flatMap(\.badges).count + mileageBadges.count

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

                // Chapter cards + 里程軌跡碑（同款式，第三條線）
                VStack(spacing: 12) {
                    ForEach(groups) { group in
                        chapterCard(group: group)
                    }
                    if let mileageTrack, !mileageBadges.isEmpty {
                        mileageTrackCard(track: mileageTrack)
                    }
                }
            }
        )
    }

    private func chapterCard(group: AchievementBadgeGroup) -> some View {
        collectionCard(
            glyph: chapterGlyph(for: group.chapter),
            accentColor: AchievementChapterTheme.primaryColor(for: group.chapter),
            title: group.titleKey?.localizedOrFallback(default: group.chapter.localizedName) ?? group.chapter.localizedName,
            badges: group.badges,
            libraryGroup: group,
            entry: "chapter_card",
            accessibilityId: "Achievements_ChapterCard_\(group.chapter.rawValue)"
        )
    }

    // 里程軌跡碑：把 mileage track 當成徽章收藏的一張卡，與其他章節卡同款式（第三條線）。
    private func mileageTrackCard(track: AchievementTrack) -> some View {
        let libraryGroup = AchievementBadgeGroup(chapter: .build, titleKey: track.titleKey, badges: track.badges)
        return collectionCard(
            glyph: "🛣️",
            accentColor: PacerizColor.indigo,
            title: track.titleKey.localizedOrFallback(default: track.trackId),
            badges: track.badges,
            libraryGroup: libraryGroup,
            entry: "mileage_track_card",
            accessibilityId: "Achievements_TrackCard_mileage_markers"
        )
    }

    private func collectionCard(
        glyph: String,
        accentColor: Color,
        title: String,
        badges: [AchievementBadge],
        libraryGroup: AchievementBadgeGroup,
        entry: String,
        accessibilityId: String
    ) -> some View {
        let unlocked = badges.filter { $0.status == .unlocked }.count
        let total = badges.count
        let pct = total > 0 ? Double(unlocked) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .center) {
                // Glyph icon 38×38
                Text(glyph)
                    .font(AppFont.titleM())
                    .frame(width: 38, height: 38)
                    .background(accentColor.opacity(0.22))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
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
                    AchievementBadgeLibraryView(groups: [libraryGroup]) { badge in
                        viewModel.openBadge(badge, entry: entry)
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
                    ForEach(badges) { badge in
                        Button {
                            viewModel.openBadge(badge, entry: entry)
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
        .accessibilityIdentifier(accessibilityId)
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
                    .font(AppFont.label())
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
        guard let summary = viewModel.summary else { return [] }
        if !summary.achievementTracks.isEmpty {
            return summary.achievementTracks.flatMap(\.badges)
        }
        return summary.badgeGroups.flatMap(\.badges)
    }

    private var latestUnlockedBadge: AchievementBadge? {
        // Always the genuinely most-recently unlocked badge, independent of pin.
        // (Previously preferred the pinned badge, so pinning/unpinning from this card
        // swapped the displayed badge — the "按了就換徽章" bug.)
        allBadges
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

    /// Resolve the real badge artwork asset for the share card. Looks up the full
    /// AchievementBadge by id so `assetName(for:)` can use `badge.assetName` (the backend
    /// artwork) instead of the badgeId-switch fallback, which left the card image blank.
    private func shareBadgeAssetName(for shareable: AchievementShareable) -> String {
        if let id = shareable.badgeId,
           let badge = allBadges.first(where: { $0.badgeId == id }) {
            return AchievementBadgeArtwork.assetName(for: badge)
        }
        return AchievementBadgeArtwork.assetNameForBadgeId(shareable.badgeId ?? "")
    }

    /// Build a shareable for any unlocked badge with one context stat per track/chapter.
    private func resolvedShareable(for badge: AchievementBadge) -> AchievementShareable {
        let track = viewModel.summary?.achievementTracks.first {
            $0.badges.contains { $0.badgeId == badge.badgeId }
        }
        let stats = viewModel.summary?.lifetimeStats
        let weeksFormat = NSLocalizedString("achievements.share.stat.weeks_value", comment: "")

        let field: AchievementPublicField? = {
            if let track {
                switch track.trackId {
                case "mileage_markers":
                    if let km = track.current {
                        return AchievementPublicField(key: "annual_distance",
                            labelKey: "achievements.share.stat.annual_distance",
                            value: "\(Int(km.rounded())) km")
                    }
                case "rhythm":
                    if let runs = stats?.totalRuns, runs > 0 {
                        return AchievementPublicField(key: "total_runs",
                            labelKey: "achievements.share.stat.total_runs",
                            value: "\(runs)")
                    }
                case "plan":
                    if let weeks = track.current {
                        return AchievementPublicField(key: "qualified_weeks",
                            labelKey: "achievements.share.stat.qualified_weeks",
                            value: String(format: weeksFormat, Int(weeks)))
                    }
                case "results":
                    if let count = track.current {
                        return AchievementPublicField(key: "major_results",
                            labelKey: "achievements.share.stat.major_results",
                            value: "\(Int(count))")
                    }
                default: break
                }
            }
            switch badge.chapter {
            case .start:
                if let runs = stats?.totalRuns, runs > 0 {
                    return AchievementPublicField(key: "total_runs",
                        labelKey: "achievements.share.stat.total_runs", value: "\(runs)")
                }
            case .build:
                if let km = stats?.totalDistanceKm {
                    return AchievementPublicField(key: "total_distance",
                        labelKey: "achievements.share.stat.total_distance",
                        value: "\(Int(km.rounded())) km")
                }
            case .adapt:
                if let weeks = stats?.completedWeeks {
                    return AchievementPublicField(key: "completed_weeks",
                        labelKey: "achievements.share.stat.completed_weeks",
                        value: String(format: weeksFormat, weeks))
                }
            case .prove:
                if let km = stats?.longestRunKm, km > 0 {
                    return AchievementPublicField(key: "longest_run",
                        labelKey: "achievements.share.stat.longest_run",
                        value: "\(Int(km.rounded())) km")
                }
            case .identity:
                if let km = stats?.totalDistanceKm {
                    return AchievementPublicField(key: "total_distance",
                        labelKey: "achievements.share.stat.total_distance",
                        value: "\(Int(km.rounded())) km")
                }
            default: break
            }
            return nil
        }()

        return AchievementShareable(
            materialId: "badge_\(badge.badgeId)",
            materialType: .badge,
            titleKey: badge.nameKey,
            summaryKey: badge.storyKey,
            summaryParams: [:],
            publicFields: field.map { [$0] } ?? [],
            defaultSensitiveFieldsEnabled: false,
            badgeId: badge.badgeId,
            chapter: badge.chapter
        )
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

struct AchievementActivityItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AchievementActivityViewController: UIViewControllerRepresentable {
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
