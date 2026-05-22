import SwiftUI
import UIKit

// MARK: - AchievementShareCardView
//
// 徽章分享卡 — 藍 → 深藍漸層底，整張圓角。
// 字級全用固定 .system(size:)，匯出圖不隨動態字級縮放（同 RecapShareCard 模式）。
// handle / dateString 由呼叫端傳入；AchievementSharePreviewSheet 負責從 UserProfileLocalDataSource 取值並提供 fallback。

struct AchievementShareCardView: View {
    let shareable: AchievementShareable
    /// "@username" 格式；由 AchievementSharePreviewSheet 從 UserProfile 取，找不到用 "@paceriz"
    let handle: String
    /// "YYYY.MM.DD" 格式的日期字串
    let dateString: String
    /// 由呼叫端解析的真實徽章 asset 名（用 AchievementBadge.assetName，fallback 才用 badgeId switch）
    let badgeAssetName: String

    // MARK: - Computed

    private var chapterName: String? {
        shareable.chapter?.localizedName
    }

    private var titleText: String {
        let localized = NSLocalizedString(shareable.titleKey, comment: "")
        return localized == shareable.titleKey ? shareable.titleKey : localized
    }

    private var summaryText: String {
        shareable.summaryKey.achievementLocalized(params: shareable.summaryParams)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                topRow
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                badgeSection
                    .padding(.top, 22)

                unlockedLabel
                    .padding(.top, 14)

                titleSection
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                summarySection
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if !shareable.publicFields.isEmpty {
                    statsCard
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 12)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 320, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            RecapPalette.darkNavy
            LinearGradient(
                stops: [
                    .init(color: RecapPalette.brand, location: 0.0),
                    .init(color: RecapPalette.brand, location: 0.25),
                    .init(color: RecapPalette.brandDeep, location: 0.58),
                    .init(color: RecapPalette.darkNavy, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: UnitPoint(x: 0.25, y: 0.14),
                startRadius: 0,
                endRadius: 180
            )
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左：P logo + PACERIZ 字樣
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Text("P")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                }
                Text("PACERIZ")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.white)
            }

            Spacer()

            // 右：章節 chip
            if let chapter = chapterName {
                Text(String(format: NSLocalizedString("achievements.share.card.chapter_label", comment: ""), chapter))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.20), in: Capsule())
            }
        }
    }

    // MARK: - Badge Section

    private var badgeSection: some View {
        ZStack {
            // 虛線圓環
            Circle()
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])
                )
                .foregroundColor(Color.white.opacity(0.30))
                .frame(width: 130, height: 130)

            Image(badgeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
        }
    }

    // MARK: - UNLOCKED Label

    private var unlockedLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
            Text("UNLOCKED")
                .font(.system(size: 11, weight: .heavy))
                .tracking(3)
                .foregroundColor(.white.opacity(0.90))
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Text(titleText)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Text(summaryText)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.78))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Card（最多 3 欄）

    private var statsCard: some View {
        let fields = Array(shareable.publicFields.prefix(3))
        return HStack(spacing: 0) {
            ForEach(fields.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
                statCell(field: fields[i])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statCell(field: AchievementPublicField) -> some View {
        VStack(spacing: 3) {
            Text(field.value)
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(field.labelKey.localizedOrFallback(default: field.key))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.60))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(handle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.70))
            Spacer()
            Text(dateString)
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundColor(.white.opacity(0.60))
        }
    }
}

// MARK: - AchievementBadgeArtwork extension for badgeId lookup

extension AchievementBadgeArtwork {
    /// 供 AchievementShareCardView 使用：只有 badgeId，沒有完整 AchievementBadge 時取 asset 名稱
    static func assetNameForBadgeId(_ badgeId: String) -> String {
        // 呼叫既有的 private fallbackAssetName，複用同樣的 switch 邏輯。
        // 因 fallbackAssetName 是 private，這裡透過一個假的 snapshot 代入。
        let snapshot = AchievementBadgeSnapshot(
            badgeId: badgeId,
            chapter: .unknown,
            nameKey: "",
            storyKey: nil,
            status: nil
        )
        return assetName(for: snapshot)
    }
}

// MARK: - AchievementSharePreviewSheet

struct AchievementSharePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareable: AchievementShareable
    let onShare: (UIImage) -> Void

    // handle 和 dateString 在 init 時從 UserProfileLocalDataSource 取，保持呼叫端 API 不變
    private let handle: String
    private let dateString: String
    private let badgeAssetName: String

    init(shareable: AchievementShareable, badgeAssetName: String, onShare: @escaping (UIImage) -> Void) {
        self.shareable = shareable
        self.badgeAssetName = badgeAssetName
        self.onShare = onShare

        // 取 displayName，加 "@" 前綴；找不到 fallback "@paceriz"
        let ds = UserProfileLocalDataSource()
        if let name = ds.getUserProfile()?.displayName, !name.isEmpty {
            self.handle = "@\(name)"
        } else {
            self.handle = "@paceriz"
        }

        // 今日日期作為 fallback（shareable 沒有解鎖日期欄位）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        self.dateString = formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AchievementShareCardView(
                        shareable: shareable,
                        handle: handle,
                        dateString: dateString,
                        badgeAssetName: badgeAssetName
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding(.top)

                    publicFieldsSection

                    Button {
                        if let image = renderCard() {
                            onShare(image)
                        }
                    } label: {
                        Label(L10n.Achievements.Share.action.localized, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Share.previewTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close.localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var publicFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Achievements.Share.publicFields.localized)
                .font(AppFont.headline())

            if shareable.publicFields.isEmpty {
                Text(L10n.Achievements.Share.defaultPublicFields.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            } else {
                ForEach(shareable.publicFields) { field in
                    HStack {
                        Text(field.labelKey.localizedOrFallback(default: field.key))
                            .font(AppFont.bodySmall())
                        Spacer()
                        Text(field.value)
                            .font(AppFont.bodyMedium())
                    }
                }
            }

            Text(L10n.Achievements.Share.sensitiveExcluded.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }

    private func renderCard() -> UIImage? {
        let card = AchievementShareCardView(
            shareable: shareable,
            handle: handle,
            dateString: dateString,
            badgeAssetName: badgeAssetName
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - String helpers

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}

// MARK: - Preview

#if DEBUG
private let previewShareable = AchievementShareable(
    materialId: "preview-badge-1",
    materialType: .badge,
    titleKey: "連續出賽者",
    summaryKey: "連續完成 7 天的訓練節奏",
    summaryParams: [:],
    publicFields: [
        AchievementPublicField(key: "distance", labelKey: "總距離", value: "32.4km"),
        AchievementPublicField(key: "count", labelKey: "次數", value: "5次"),
        AchievementPublicField(key: "pace", labelKey: "配速", value: "5:42/km")
    ],
    defaultSensitiveFieldsEnabled: false,
    badgeId: "BADGE-BUILD-SHOWING-UP",
    chapter: .build
)

#Preview("AchievementShareCardView") {
    ZStack {
        Color(UIColor.systemGroupedBackground)
        AchievementShareCardView(
            shareable: previewShareable,
            handle: "@runner_wu",
            dateString: "2026.05.22",
            badgeAssetName: "achievement_badge_build_showing_up_footprints"
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
#endif
