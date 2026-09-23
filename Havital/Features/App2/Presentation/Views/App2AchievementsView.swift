import SwiftUI

// MARK: - App2AchievementsView
/// 2.0 成就頁 —— 設計 **frame-11「成就」**。
///
/// **資料全是真的，沒有樣本。** repo 內既有的 `Features/Achievements/` 已經接上
/// `GET /v2/achievements/summary`（`AchievementRemoteDataSource.swift:5`），
/// 而且 `PersonalAchievementsViewModel` 是零參數可構造的（自己向
/// `DependencyContainer` 註冊 `registerAchievementModule()`）。所以這一頁只是
/// **第二個版面**，不是第二套成就系統 —— ViewModel、Repository、端點、
/// 徽章語意政策（`AchievementBadgeSemanticPolicy`）全部沿用。
///
/// 版面對照設計：最新解鎖 hero（徽章圖 ＋ 名稱 ＋ 敘事 ＋ 下一個目標進度條）
/// → 個人最佳 2 欄 → 徽章收藏（每條主線一張卡：標題列 ＋ 進度條 ＋ 橫向徽章列）。
///
/// **2026-08-25 用戶裁決：這一頁基本上跟 1.4 一樣。** API、徽章美術 asset、
/// 「最新解鎖／下一個目標」的挑選邏輯全部沿用 1.4；2.0 只調外型
/// （間距、圓角、字級對齊 app2 視覺語言）與數字格式（整數不帶 `.0`）。
struct App2AchievementsView: View {

    /// 既有成就 feature 的 ViewModel（`GET /v2/achievements/summary`），
    /// 由 `App2RootView` 持有。這一頁只是第二個版面，不是第二套成就系統。
    @ObservedObject var viewModel: PersonalAchievementsViewModel

    /// 距離類的目標進度要跟著單位制走，切換後當場重畫。
    @ObservedObject private var unitManager = UnitManager.shared

    /// 點開的那一顆徽章（8/28 盤點 F17）。
    ///
    /// 點徽章原本直接彈「設為顯示徽章」確認框——**點徽章看不到徽章**：那一顆的故事、
    /// 解鎖原因、進度全都沒有出口。入口改成詳情頁，設為顯示徽章的動作搬進那一頁
    /// （裁決：「詳情頁內保留該動作」）。
    ///
    /// 詳情頁是 1.4 既有的 `AchievementDetailView`（hero 200pt 徽章圖、篇章 chip、
    /// 狀態與解鎖日、故事與解鎖原因、未解鎖時的進度、已解鎖時的來源）——那一頁畫的
    /// 就是這一顆徽章 payload 上有的每一欄，2.0 沒有第二份要畫。本票只把
    /// 「設為顯示徽章」加進去（那一頁原本也沒有這個動作）。
    @State private var detailBadge: AchievementBadge?

    /// The PB detail sheet reuses the existing 1.4 view.
    @State private var selectedPBDetailItem: PersonalBestDetailItem?

    private var cachedUser: User? {
        UserProfileLocalDataSource().getUserProfile()
    }

    /// 「看更多」開的那一組完整清單（8/28 盤點 F21）。nil ＝ 沒開。
    @State private var expandedTrack: AchievementTrack?

    private let pbColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    /// 目前實際展示的那一顆（pin 優先，否則最近解鎖）。
    private var displayedBadgeId: String? {
        viewModel.summary
            .flatMap { Self.displayBadge($0, pinnedBadgeId: viewModel.pinnedBadgeId) }?
            .badgeId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                App2PageHeader(title: L10n.App2.Achievements.title.localized) { EmptyView() }
                    .padding(.bottom, 16)

                if let summary = viewModel.summary {
                    heroCard(summary).padding(.bottom, 20)
                    personalBests(summary)
                    badgeCollection(summary)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, App2Theme.tabBarClearance)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_AchievementsView")
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
        .sheet(item: $detailBadge) { badge in
            App2BadgeDetailSheet(
                badge: badge,
                isDisplayBadge: badge.badgeId == displayedBadgeId,
                onSetDisplayBadge: { picked in viewModel.setPinnedBadge(picked.badgeId) }
            )
        }
        // 一組徽章的完整清單（8/28 盤點 F21）。二層頁一律 fullScreenCover，
        // 與這個 app 的其他二層頁同一種呈現。
        .fullScreenCover(item: $expandedTrack) { track in
            App2BadgeTrackView(
                track: track,
                displayedBadgeId: displayedBadgeId,
                onSetDisplayBadge: { picked in viewModel.setPinnedBadge(picked.badgeId) },
                onClose: { expandedTrack = nil }
            )
        }
    }

    /// 群組圖用的代表徽章：這一組最新解鎖的那顆，都沒解鎖就取第一顆（8/28 盤點 V23）。
    static func representativeBadge(_ badges: [AchievementBadge]) -> AchievementBadge? {
        let unlocked = badges.filter { $0.status == .unlocked }
        if let latest = unlocked.max(by: { ($0.unlockedAt ?? "") < ($1.unlockedAt ?? "") }) {
            return latest
        }
        return badges.first
    }

    // MARK: - 最新解鎖 hero

    private func heroCard(_ summary: AchievementSummary) -> some View {
        // 使用者選過就顯示他選的那一顆，沒選過才自動挑最近解鎖（`displayBadge`）。
        let latest = Self.displayBadge(summary, pinnedBadgeId: viewModel.pinnedBadgeId)
        let track = Self.nextTrack(summary)

        return App2AccentCard(strength: 0.14, padding: 18, spacing: 0) {
            HStack(alignment: .top, spacing: 15) {
                medal(latest)
                VStack(alignment: .leading, spacing: 0) {
                    App2Pill(text: L10n.App2.Achievements.latestUnlock.localized)
                    Text(latest?.nameKey.localizedOrFallback(default: latest?.badgeId ?? "—") ?? "—")
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(latest?.storyKey.localizedOrFallback(default: "") ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let track {
                Rectangle()
                    .fill(App2Theme.shadowInk.opacity(0.1))
                    .frame(height: 1)
                    .padding(.top, 15)

                nextGoal(track).padding(.top, 14)
            }
        }
        .accessibilityIdentifier("App2_AchievementsHero")
    }

    /// hero 的徽章圖 —— **用既有的正式徽章美術 asset**，與 1.4 同一支
    /// （`AchievementBadgeImage` ＋ `AchievementBadgeArtwork.assetName(for:)`）。
    ///
    /// 原本畫成 2.0 自己的銅色圓章＋目標數字，等於在成就頁另立一套徽章視覺；
    /// 2026-08-25 用戶裁決：徽章圖沿用既有 asset、完整呈現（`scaledToFit`，不裁切）。
    @ViewBuilder
    private func medal(_ badge: AchievementBadge?) -> some View {
        if let badge {
            AchievementBadgeImage(
                assetName: AchievementBadgeArtwork.assetName(for: badge),
                status: badge.status,
                size: 96
            )
            .accessibilityIdentifier("App2_AchievementsHeroBadge")
        } else {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(App2Theme.insetBackground)
                .frame(width: 96, height: 96)
                .overlay(
                    Text(verbatim: "—")
                        .font(.app2Mono(22))
                        .foregroundStyle(App2Theme.inkTertiary)
                )
        }
    }

    private func nextGoal(_ track: AchievementTrack) -> some View {
        let progress = PersonalAchievementsView.trackProgressRatio(track)
        let name = track.nextBadge?.nameKey.localizedOrFallback(default: track.trackId) ?? track.trackId
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "\(L10n.App2.Achievements.nextGoal.localized) · \(name)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text(verbatim: "\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
            }
            .padding(.bottom, 9)

            App2ProgressBar(progress: progress)

            // 設計 frame-11 的量化列：`1,141.5 / 2,400 km · 還差 1,258.5 km`。
            // 單位取 badge 自己的 `unitKey`（沒有就不加單位，不假設是公里）。
            //
            // 後端的 `unit_key` 只有三種（`badge_projector._track_threshold_unit_key`）：
            // `…unit.km`／`…unit.week`／`…unit.count`。**只有 km 那一種是距離**，
            // 英制時數值換算＋單位字換成 `…unit.mi`；週數與次數照原樣，不換算。
            if let detail = track.nextBadge?.progress,
               let current = detail.current, let target = detail.target {
                let converted = Self.convertProgress(
                    current: current, target: target,
                    unitKey: detail.unitKey, unitSystem: unitManager.currentUnitSystem
                )
                let unit = converted.unitKey?.localizedOrFallback(default: "") ?? ""
                let suffix = unit.isEmpty ? "" : " \(unit)"
                let remaining = max(0, converted.target - converted.current)
                Text(
                    verbatim: "\(Self.grouped(converted.current)) / \(Self.grouped(converted.target))\(suffix) · "
                        + String(
                            format: L10n.App2.Achievements.remainingFormat.localized,
                            "\(Self.grouped(remaining))\(suffix)"
                        )
                )
                .font(.app2Mono(13, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
                .padding(.top, 7)
            }
        }
    }

    // MARK: - 個人最佳

    @ViewBuilder
    private func personalBests(_ summary: AchievementSummary) -> some View {
        let records = summary.pbOverview?.records ?? []
        if !records.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.App2.Achievements.personalBests.localized)
                    .font(.app2CardTitle)
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)

            LazyVGrid(columns: pbColumns, spacing: 10) {
                ForEach(records, id: \.distance) { record in
                    Button {
                        selectedPBDetailItem = openPBDetail(for: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.displayDistance)
                                .font(.system(size: 15, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(App2Theme.inkMuted)
                            Text(record.time)
                                .font(.app2Mono(21, weight: .bold))
                                .foregroundStyle(App2Theme.accentBlueDeep)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .app2CardSurface(cornerRadius: 15)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("App2_AchievementsPBTile_\(record.distance)")
                }
            }
            .sheet(item: $selectedPBDetailItem) { item in
                PersonalBestDetailView(distance: item.distance, records: item.records)
            }
            .padding(.bottom, 22)
            .accessibilityIdentifier("App2_AchievementsPBGrid")
        }
    }

    func openPBDetail(for record: AchievementPBRecord) -> PersonalBestDetailItem? {
        guard let distance = RaceDistanceV2(rawValue: record.distance) else { return nil }
        let records = cachedUser?.personalBestV2?["race_run"]?[record.distance] ?? []
        return PersonalBestDetailItem(
            distance: distance,
            records: records
        )
    }

    // MARK: - 徽章收藏（每條主線一張卡）

    @ViewBuilder
    private func badgeCollection(_ summary: AchievementSummary) -> some View {
        let tracks = summary.achievementTracks
        if !tracks.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.App2.Achievements.badges.localized)
                    .font(.app2CardTitle)
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer()
                // 設計 frame-11 是「18/20 已解鎖」，不是裸的比例。
                // 這條字串 1.x 的徽章收藏已經有（三語齊），沿用不另建。
                Text(
                    String(
                        format: L10n.Achievements.BadgeCollection.unlockedCountFormat.localized,
                        summary.storySummary.unlockedCount,
                        summary.storySummary.totalCount
                    )
                )
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)

            ForEach(tracks, id: \.trackId) { track in
                storylineCard(track).padding(.bottom, 14)
            }
        }
    }

    private func storylineCard(_ track: AchievementTrack) -> some View {
        // 徽章清單過既有的語意政策，與 1.x 頁面看到的同一批。
        let badges = track.badges.filter(AchievementBadgeSemanticPolicy.isDisplayable)
        let done = badges.filter { $0.status == .unlocked }.count

        return VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 11) {
                // 群組的圖＝**這一組的代表徽章美術**（8/28 盤點 V23）。原本是通用的
                // `rosette` 圓章，於是「訓練節奏」「里程碑」…每一組的圖都一模一樣，
                // 群組標題成了唯一能分辨它們的東西。代表徽章＝這一組最新解鎖的那顆，
                // 都沒解鎖就取第一顆（灰底問號，仍看得出是哪一組的美術）。
                Group {
                    if let representative = Self.representativeBadge(badges) {
                        AchievementBadgeImage(
                            assetName: AchievementBadgeArtwork.assetName(for: representative),
                            status: representative.status,
                            size: 40
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(App2Theme.accentBlue.opacity(0.12))
                            .frame(width: 40, height: 40)
                    }
                }
                .accessibilityIdentifier("App2_AchievementsTrackBadge_\(track.trackId)")
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(track.titleKey.localizedOrFallback(default: track.trackId))
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Spacer(minLength: 6)
                        // 8/28 盤點 F21：「看更多」原本是不可點的死字。橫向列一次只看得到
                        // 四、五顆，而一組有十幾顆——這裡是唯一能看完一組的出口。
                        Text(L10n.App2.Achievements.seeMore.localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(App2Theme.accentBlueDeep)
                            .contentShape(Rectangle())
                            .onTapGesture { expandedTrack = track }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("App2_AchievementsSeeMore_\(track.trackId)")
                    }
                    HStack(spacing: 9) {
                        App2ProgressBar(
                            progress: badges.isEmpty ? 0 : Double(done) / Double(badges.count),
                            height: 6
                        )
                        Text(verbatim: "\(done) / \(badges.count)")
                            .font(.app2Mono(12, weight: .heavy))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
            }
            .padding(.trailing, 15)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(badges, id: \.badgeId) { badge in
                        badgeTile(badge)
                    }
                }
                .padding(.trailing, 15)
            }
        }
        .padding(.leading, 15)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2CardSurface(cornerRadius: 20)
    }

    private func badgeTile(_ badge: AchievementBadge) -> some View {
        App2BadgeTile(
            badge: badge,
            isDisplayed: badge.badgeId == displayedBadgeId,
            onPick: { detailBadge = $0 }
        )
    }

    // MARK: - Helpers
    //
    // 「最新解鎖」與「下一個目標」的挑法與 1.x 的 `PersonalAchievementsView` 相同
    // （最近解鎖時間最大者／未完成主線中進度比例最高者）。

    // MARK: - 挑選邏輯：與 1.4 完全相同，不另立一套
    //
    // 2026-08-25 用戶裁決：**成就頁基本上跟 1.4 一樣** —— API、徽章資源、
    // 「最新解鎖」與「下一個目標」的挑法全部沿用 `PersonalAchievementsView` 的既有行為。
    // 2.0 只做外型（間距／圓角／字級對齊 app2 視覺語言）。
    //
    // 這兩支刻意與 `PersonalAchievementsView.latestUnlockedBadge`／`nextTargetBadge`
    // 逐行對齊；那邊改了這邊要跟著改。

    /// 全域最近解鎖的一顆（與 1.4 同：不看 pin、只看 `unlockedAt`）。
    static func latestUnlocked(_ summary: AchievementSummary) -> AchievementBadge? {
        let all = summary.achievementTracks.isEmpty
            ? summary.badgeGroups.flatMap(\.badges)
            : summary.achievementTracks.flatMap(\.badges)
        return all
            .filter(AchievementBadgeSemanticPolicy.isDisplayable)
            .filter { $0.status == .unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
            .first
    }

    /// 實際要展示的那一顆：**使用者 pin 過的優先，否則退回最近解鎖**。
    /// 挑選規則走既有的 `SelectDisplayBadgeUseCase`（課表首頁展示位同一支），
    /// 不另寫一份。
    static func displayBadge(
        _ summary: AchievementSummary,
        pinnedBadgeId: String?
    ) -> AchievementBadge? {
        let all = (summary.achievementTracks.isEmpty
            ? summary.badgeGroups.flatMap(\.badges)
            : summary.achievementTracks.flatMap(\.badges))
            .filter(AchievementBadgeSemanticPolicy.isDisplayable)
        return SelectDisplayBadgeUseCase().execute(pinnedBadgeId: pinnedBadgeId, allBadges: all)
    }

    /// 下一個目標：尚未完成的主線中，進度比例最高的那條（與 1.4 同）。
    static func nextTrack(_ summary: AchievementSummary) -> AchievementTrack? {
        summary.achievementTracks
            .filter { ($0.nextBadge?.status ?? .unlocked) != .unlocked }
            .max {
                PersonalAchievementsView.trackProgressRatio($0)
                    < PersonalAchievementsView.trackProgressRatio($1)
            }
    }

    /// 量化列的數字格式 —— 走共用的 `App2NumberFormat`（整數不帶 `.0`）。
    ///
    /// **同一行的三個數字必須同精度。** 原本按大小切精度（<100 給一位、其餘取整），
    /// 於是同一行出現 `263 / 300 公里 · 還差 37.3 公里` —— 263 + 37.3 ≠ 300，
    /// 讀者一眼看得出來是錯的。一律保留一位，整數自然不帶 `.0`。
    static func grouped(_ value: Double) -> String {
        App2NumberFormat.grouped(value, maximumFractionDigits: 1)
    }

    /// 後端的 `unit_key` 只有公里那一種是距離（`achievements.progress.unit.km`）。
    /// 英制時把 current／target 一起換算並改用 `…unit.mi` 的字；
    /// 週數（`…unit.week`）、次數（`…unit.count`）與缺席的 `unit_key` 原樣通過。
    static let distanceUnitKey = "achievements.progress.unit.km"
    static let imperialDistanceUnitKey = "achievements.progress.unit.mi"

    static func convertProgress(
        current: Double,
        target: Double,
        unitKey: String?,
        unitSystem: UnitSystem
    ) -> (current: Double, target: Double, unitKey: String?) {
        guard unitKey == distanceUnitKey, unitSystem == .imperial else {
            return (current, target, unitKey)
        }
        return (
            unitSystem.convertedDistance(current),
            unitSystem.convertedDistance(target),
            imperialDistanceUnitKey
        )
    }
}
