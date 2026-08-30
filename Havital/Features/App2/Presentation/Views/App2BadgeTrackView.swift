import SwiftUI

// MARK: - App2BadgeTile
/// 收藏牆的一格 —— **徽章美術用既有 asset**，與 hero 及 1.4 的收藏區同一支
/// （`AchievementBadgeImage`：已解鎖畫 art，未解鎖是灰底問號）。
///
/// 2026-08-30（8/28 盤點 F21）從 `App2AchievementsView` 的私有 `badgeTile` **原樣搬出來**：
/// 群組完整清單頁畫的是同一格，抄一份過去就會有兩種一格。
struct App2BadgeTile: View {
    let badge: AchievementBadge
    /// 目前展示在首頁的那一顆（給一圈藍框）。
    let isDisplayed: Bool
    /// 點已解鎖的徽章 → 由呼叫端彈確認、設為展示徽章。未解鎖不可點。
    let onPick: (AchievementBadge) -> Void

    private let tileSize: CGFloat = 60

    private var unlocked: Bool { badge.status == .unlocked }

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: tileSize
                )
                .clipShape(RoundedRectangle(cornerRadius: tileSize * 0.22, style: .continuous))
                .shadow(
                    color: App2Theme.shadowInk.opacity(unlocked ? 0.22 : 0.08),
                    radius: unlocked ? 6 : 2,
                    x: 0, y: unlocked ? 5 : 1
                )
                .overlay {
                    // 目前展示中的那一顆給一圈藍框（未解鎖的不會有）。
                    if isDisplayed {
                        RoundedRectangle(cornerRadius: tileSize * 0.22, style: .continuous)
                            .strokeBorder(App2Theme.accentBlue, lineWidth: 2.5)
                    }
                }
                .accessibilityIdentifier("App2_AchievementsBadge_\(badge.badgeId)")

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
            // 沒有解鎖日期就不畫這一行（8/28 盤點 V24）。原本印「— —」佔位，於是
            // 已解鎖的徽章下面掛著兩條槓，讀起來像「解鎖日期壞掉了」——後端本來就
            // 不保證每一顆都帶 `unlocked_at`（舊的補頒徽章沒有）。
            if let unlockedAt = badge.unlockedAt.map({ String($0.prefix(10)) }), !unlockedAt.isEmpty {
                Text(unlockedAt)
                    .font(.app2Mono(9, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
            }
        }
        .frame(width: 66)
        .contentShape(Rectangle())
        // **補缺口**：設計包沒有替成就頁定義「換一顆展示徽章」的入口，
        // 但 pin 這件事在 repo 裡早就有（`AchievementRepository.setPinnedBadgeId`
        // ＋ 1.4 的 `BadgeShowcasePickerView`），Android 也有。這裡把入口補在
        // 收藏牆的 tile 上：點已解鎖的徽章 → 確認 → 設為展示徽章。
        // 未解鎖的不可點（點了也沒有東西可展示）。
        .onTapGesture {
            guard unlocked else { return }
            onPick(badge)
        }
        .accessibilityAddTraits(unlocked ? [.isButton] : [])
    }
}

// MARK: - App2BadgeTrackView
/// 一個徽章群組的完整清單（8/28 盤點 F21）。
///
/// **為什麼要有這一頁**：成就頁的每一組只畫一條橫向捲動列，一次看得到四、五顆，
/// 而一組有十幾顆；「看更多」在 iOS 是不可點的死字、Android 根本沒有這個入口，
/// 於是沒有任何地方能看完一組。
///
/// **鐵則 0 查核**：1.4 有同一件事的實作 ——
/// `Features/Achievements/Presentation/Views/PersonalAchievementsView.swift` 的
/// `AchievementBadgeLibraryView`（3 欄 grid）＋ `AchievementBadgeTile`。**沒有沿用它**，
/// 因為那兩個型別是那一頁的 `private`、而且畫的是 1.4 的卡面（70pt 帶邊框卡、
/// 進度條、狀態文字）；把它原樣塞進 2.0 就是 2026-08-27 裁決（u）點名過的
/// 「像拼湊畫面」。**共用的是真正該共用的東西**：資料（`GET /v2/achievements/summary`
/// 的同一份 `AchievementTrack`）、語意政策（`AchievementBadgeSemanticPolicy`）、
/// 徽章美術（`AchievementBadgeArtwork` ＋ `AchievementBadgeImage`）與 pin 的動作。
/// 這一頁只是第二個版面，不是第二套成就系統 —— 與 `App2AchievementsView` 同一條理由。
struct App2BadgeTrackView: View {
    let track: AchievementTrack
    let displayedBadgeId: String?
    /// 在詳情頁按下「設為顯示徽章」時回呼（8/28 盤點 F17）。
    let onSetDisplayBadge: (AchievementBadge) -> Void
    let onClose: () -> Void

    /// 這一頁點開的那一顆（8/28 盤點 F17）。
    ///
    /// **詳情頁由這一頁自己presenting**，不是把選中的徽章丟回成就頁去開：這一頁本身
    /// 開在 `fullScreenCover` 裡，成就頁那一層的 `sheet` 被蓋住，按了不會有任何反應
    /// （同 `App2SessionDetailView` 記錄過的巢狀 presentation 坑）。
    @State private var detailBadge: AchievementBadge?

    private let columns = [
        GridItem(.adaptive(minimum: 66), spacing: 14)
    ]

    /// 徽章清單過既有的語意政策，與成就頁那一列看到的同一批。
    private var badges: [AchievementBadge] {
        track.badges.filter(AchievementBadgeSemanticPolicy.isDisplayable)
    }

    var body: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: track.titleKey.localizedOrFallback(default: track.trackId),
                titleSize: 19,
                onBack: onClose,
                backIdentifier: "App2_BadgeTrackBack",
                titleIdentifier: "App2_BadgeTrackTitle"
            ) {
                let done = badges.filter { $0.status == .unlocked }.count
                Text(verbatim: "\(done) / \(badges.count)")
                    .font(.app2Mono(13, weight: .heavy))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(badges, id: \.badgeId) { badge in
                        App2BadgeTile(
                            badge: badge,
                            isDisplayed: badge.badgeId == displayedBadgeId,
                            onPick: { detailBadge = $0 }
                        )
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 28)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_BadgeTrackView")
        .sheet(item: $detailBadge) { badge in
            App2BadgeDetailSheet(
                badge: badge,
                isDisplayBadge: badge.badgeId == displayedBadgeId,
                onSetDisplayBadge: onSetDisplayBadge
            )
        }
    }
}

// MARK: - App2BadgeDetailSheet
/// 點一顆徽章開出來的詳情頁（8/28 盤點 F17）。
///
/// **不是新做一頁。** 1.4 的 `AchievementDetailView` 畫的就是這一顆徽章 payload 上有的
/// 每一欄（200pt hero 徽章圖、篇章 chip、狀態與解鎖日、故事與解鎖原因、未解鎖時的進度、
/// 已解鎖時的來源），2.0 沒有第二份要畫；本票只把「設為顯示徽章」加進那一頁。
///
/// 這個 wrapper 只是把兩處（成就頁的收藏列、群組完整清單頁）的同一組參數收在一起，
/// 免得同一段呼叫抄兩份。
struct App2BadgeDetailSheet: View {
    let badge: AchievementBadge
    let isDisplayBadge: Bool
    let onSetDisplayBadge: (AchievementBadge) -> Void

    var body: some View {
        AchievementDetailView(
            badge: badge,
            // 分享徽章卡是 1.4 成就頁自己那條路（`AchievementShareable` 由那一頁的
            // ViewModel 組），2.0 這一頁沒有接，所以不給一顆假的分享鈕。
            shareable: nil,
            onShare: { _ in },
            onSetDisplayBadge: onSetDisplayBadge,
            isDisplayBadge: isDisplayBadge
        )
    }
}
