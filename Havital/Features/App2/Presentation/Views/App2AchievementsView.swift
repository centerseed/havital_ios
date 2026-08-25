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
/// 版面對照設計：最新解鎖 hero（圓章 ＋ 名稱 ＋ 敘事 ＋ 下一個目標進度條）
/// → 個人最佳 2 欄 → 徽章收藏（每條主線一張卡：標題列 ＋ 進度條 ＋ 橫向徽章列）。
struct App2AchievementsView: View {

    /// 既有成就 feature 的 ViewModel（`GET /v2/achievements/summary`），
    /// 由 `App2RootView` 持有。這一頁只是第二個版面，不是第二套成就系統。
    @ObservedObject var viewModel: PersonalAchievementsViewModel

    private let pbColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

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
    }

    // MARK: - 最新解鎖 hero

    private func heroCard(_ summary: AchievementSummary) -> some View {
        let latest = latestUnlocked(summary)
        let track = nextTrack(summary)

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

    /// 設計的銅色圓章：主數字 ＋ 單位。數字取 nextBadge 的目標值不合適（那是「下一個」），
    /// 這裡取**已解鎖徽章自己的進度目標**，沒有就退成徽章代號的首段。
    private func medal(_ badge: AchievementBadge?) -> some View {
        let target = badge?.progress?.target
        return Circle()
            .fill(
                LinearGradient(
                    colors: [App2Theme.medalGradient.from, App2Theme.medalGradient.to],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 96, height: 96)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 3))
            .overlay {
                VStack(spacing: 1) {
                    Text(target.map { Self.grouped($0) } ?? "★")
                        .font(.app2Mono(22))
                    if let unit = badge?.progress?.unitKey?.localizedOrFallback(default: "") ,
                       !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 13, weight: .heavy))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            .shadow(color: App2Theme.medalGradient.to.opacity(0.6), radius: 9, x: 0, y: 8)
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
            if let detail = track.nextBadge?.progress,
               let current = detail.current, let target = detail.target {
                let unit = detail.unitKey?.localizedOrFallback(default: "") ?? ""
                let suffix = unit.isEmpty ? "" : " \(unit)"
                let remaining = max(0, target - current)
                Text(
                    verbatim: "\(Self.grouped(current)) / \(Self.grouped(target))\(suffix) · "
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.displayDistance)
                            .font(.system(size: 15, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(App2Theme.inkMuted)
                        Text(record.time)
                            .font(.app2Mono(24))
                            .foregroundStyle(App2Theme.accentBlueDeep)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .app2CardSurface(cornerRadius: 15)
                }
            }
            .padding(.bottom, 22)
            .accessibilityIdentifier("App2_AchievementsPBGrid")
        }
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(App2Theme.accentBlue.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "rosette")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(App2Theme.accentBlueDeep)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(track.titleKey.localizedOrFallback(default: track.trackId))
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Spacer(minLength: 6)
                        Text(L10n.App2.Achievements.seeMore.localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(App2Theme.accentBlueDeep)
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
        let unlocked = badge.status == .unlocked
        return VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        // 設計 frame-11 的徽章圓章是銅色，不是品牌藍 —— 與 hero 的
                        // 大圓章同一顆漸層，收藏牆才看得出是「獎章」。
                        unlocked
                        ? LinearGradient(
                            colors: [App2Theme.medalGradient.from, App2Theme.medalGradient.to],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [App2Theme.insetBackground, App2Theme.insetBackgroundCool],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                          )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle().strokeBorder(
                            unlocked ? Color.white.opacity(0.5) : App2Theme.insetBorder,
                            lineWidth: unlocked ? 2 : 1
                        )
                    )
                    .overlay {
                        Image(systemName: unlocked ? "rosette" : "lock.fill")
                            .font(.system(size: unlocked ? 23 : 18, weight: .semibold))
                            .foregroundStyle(unlocked ? .white : App2Theme.chevron)
                    }
                    .shadow(color: App2Theme.shadowInk.opacity(0.22), radius: 6, x: 0, y: 5)

                if unlocked {
                    Circle()
                        .fill(App2Theme.accentGreenBright)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 1, y: 1)
                }
            }
            Text(badge.nameKey.localizedOrFallback(default: badge.badgeId))
                .font(.system(size: 13, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(unlocked ? App2Theme.inkPrimary : App2Theme.inkMuted)
                .lineLimit(2)
            Text(badge.unlockedAt.map { String($0.prefix(10)) } ?? "— —")
                .font(.app2Mono(9, weight: .semibold))
                .foregroundStyle(App2Theme.inkFaint)
        }
        .frame(width: 66)
    }

    // MARK: - Helpers
    //
    // 「最新解鎖」與「下一個目標」的挑法與 1.x 的 `PersonalAchievementsView` 相同
    // （最近解鎖時間最大者／未完成主線中進度比例最高者）。

    private func latestUnlocked(_ summary: AchievementSummary) -> AchievementBadge? {
        let all = summary.achievementTracks.isEmpty
            ? summary.badgeGroups.flatMap(\.badges)
            : summary.achievementTracks.flatMap(\.badges)
        return all
            .filter(AchievementBadgeSemanticPolicy.isDisplayable)
            .filter { $0.status == .unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
            .first
    }

    private func nextTrack(_ summary: AchievementSummary) -> AchievementTrack? {
        summary.achievementTracks
            .filter { ($0.nextBadge?.status ?? .unlocked) != .unlocked }
            .max {
                PersonalAchievementsView.trackProgressRatio($0)
                    < PersonalAchievementsView.trackProgressRatio($1)
            }
    }

    private static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value < 100 ? 1 : 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}
