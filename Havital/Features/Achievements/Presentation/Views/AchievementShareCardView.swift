import SwiftUI
import UIKit

// MARK: - AchievementShareCardView
//
// 徽章分享卡 — 「獎牌聚光燈」風格的可分享圖（2026-05 改版）。
// 設計意圖：徽章是主角，用聚光光暈 + 柔影把透明去背獎牌烘成有立體感的獎章；
// 漸層上濃下深（頂端鮮明品牌藍當「舞台燈」，底部近黑深藍給文字對比）；
// UNLOCKED eyebrow 用金色（成就色，避開紫漸層通用感），建立「金 eyebrow → 大標題 → 摘要 → 數據」清楚層次。
// 4:5 社群直式比例（340×460）。字級全用固定 .system(size:)，匯出圖不隨動態字級縮放（同 RecapShareCard 模式）。
// dateString 由呼叫端傳入；AchievementSharePreviewSheet 負責解析並提供 fallback。

struct AchievementShareCardView: View {
    let shareable: AchievementShareable
    /// "YYYY.MM.DD" 格式的日期字串
    let dateString: String
    /// 由呼叫端解析的真實徽章 asset 名（用 AchievementBadge.assetName，fallback 才用 badgeId switch）
    let badgeAssetName: String

    // MARK: - Layout constants（固定尺寸 — ImageRenderer 匯出用，絕不可隨裝置縮放）

    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 460
    private let cardRadius: CGFloat = 26
    private let badgeSize: CGFloat = 168

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

    // MARK: - Chapter accent（依章節給背景一個次要 accent 色，建立區辨度但保持同調）
    //
    // 主舞台燈永遠是品牌藍；accent 只在 mesh 的次要 blob 出現，讓不同成就有不同氛圍但仍是同一個藍底家族。
    // 全部低明度冷／暖色，避免破壞底部對比與整體品牌感。

    /// 章節對應的次要 accent（mesh 右側 blob 用），未知章節退回品牌藍。
    private var chapterAccent: Color {
        switch shareable.chapter ?? .unknown {
        case .start:    return Color(red: 0.16, green: 0.62, blue: 0.74)   // 青藍 — 起步、清新
        case .build:    return Color(red: 0.32, green: 0.45, blue: 0.92)   // 靛藍 — 累積、穩定
        case .adapt:    return Color(red: 0.45, green: 0.40, blue: 0.86)   // 藍紫 — 轉變（克制，不是通用紫漸層）
        case .prove:    return Color(red: 0.86, green: 0.52, blue: 0.30)   // 暖橘金 — 證明、奪牌
        case .identity: return Color(red: 0.20, green: 0.66, blue: 0.62)   // 藍綠 — 成形、沉穩
        case .unknown:  return RecapPalette.brandDeep
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                topRow
                    .padding(.top, 22)
                    .padding(.horizontal, 22)

                Spacer(minLength: 8)

                badgeSection

                unlockedLabel
                    .padding(.top, 20)

                titleSection
                    .padding(.top, 12)
                    .padding(.horizontal, 26)

                summarySection
                    .padding(.top, 8)
                    .padding(.horizontal, 30)

                Spacer(minLength: 14)

                if !shareable.publicFields.isEmpty {
                    statsRow
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                }

                footer
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        // 內描邊：1px 白色高光，讓卡片在淺色背景上有清楚邊界、更精緻
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Background（極光 mesh + 獎章光線 + 暈影 + 微噪點）
    //
    // 設計意圖：用多顆偏移的 radial blob 疊出有層次的「mesh / 極光」場，取代單一藍→黑線性漸層的扁平塑膠感。
    //   - 底色：近黑深藍，確保整體深沉、底部文字高對比。
    //   - 上半部仍有品牌藍「舞台燈」把徽章烘成主角（保留 spotlight）。
    //   - 右上注入章節 accent blob（依 chapter 變色），左下注入一抹冷藍，讓色場有左右流動與深淺。
    //   - 徽章後方放極淡的同心「獎章光線」(rays)，營造證書／獎座氛圍，opacity 壓很低不搶徽章。
    //   - 四角暈影 (vignette) 收束視線、加深邊緣與底部 → 更有質感且強化白字對比。
    //   - 最上層蓋固定 seed 的細噪點，消除純漸層的「平滑塑膠」感（ImageRenderer 下完全確定，不含隨機/時間）。

    private var backgroundGradient: some View {
        ZStack {
            // 1) 基底：近黑深藍（比 darkNavy 再深一點，讓上方光更跳）
            Color(red: 0.043, green: 0.047, blue: 0.071)

            // 2) 上半舞台燈：頂端品牌藍往下漸隱，奠定「上亮下深」基調
            LinearGradient(
                stops: [
                    .init(color: RecapPalette.brand.opacity(0.92), location: 0.0),
                    .init(color: RecapPalette.brandDeep.opacity(0.70), location: 0.30),
                    .init(color: Color.clear, location: 0.66)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 3) mesh blob：右上章節 accent（給不同成就不同氛圍）
            RadialGradient(
                colors: [chapterAccent.opacity(0.55), Color.clear],
                center: UnitPoint(x: 0.86, y: 0.14),
                startRadius: 0,
                endRadius: 260
            )
            .blendMode(.screen)

            // 4) mesh blob：左下冷藍，與右上 accent 形成對角張力，色場有流動感
            RadialGradient(
                colors: [RecapPalette.brandDeep.opacity(0.50), Color.clear],
                center: UnitPoint(x: 0.10, y: 0.74),
                startRadius: 0,
                endRadius: 240
            )
            .blendMode(.screen)

            // 5) 獎章光線：徽章後方極淡同心錐光，像獎座反光放射（壓很低，只在亮部隱約可見）
            awardRays

            // 6) 聚光燈：徽章正後一圈藍白光暈，把獎牌打亮成主角（保留原本 hero spotlight）
            RadialGradient(
                colors: [
                    Color.white.opacity(0.30),
                    RecapPalette.brand.opacity(0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 0,
                endRadius: 230
            )

            // 7) 暈影：四角加深，收束視線、強化底部白字對比
            vignette

            // 8) 微噪點：固定 seed 的細點，殺掉純漸層的扁平塑膠感
            noiseOverlay
        }
    }

    /// 獎章光線：以徽章中心為原點的角度漸層做出極淡放射錐光，營造證書／獎座感。
    private var awardRays: some View {
        AngularGradient(
            stops: [
                .init(color: Color.white.opacity(0.05), location: 0.00),
                .init(color: Color.clear,               location: 0.06),
                .init(color: Color.white.opacity(0.05), location: 0.12),
                .init(color: Color.clear,               location: 0.18),
                .init(color: Color.white.opacity(0.05), location: 0.25),
                .init(color: Color.clear,               location: 0.31),
                .init(color: Color.white.opacity(0.05), location: 0.37),
                .init(color: Color.clear,               location: 0.43),
                .init(color: Color.white.opacity(0.05), location: 0.50),
                .init(color: Color.clear,               location: 0.56),
                .init(color: Color.white.opacity(0.05), location: 0.62),
                .init(color: Color.clear,               location: 0.68),
                .init(color: Color.white.opacity(0.05), location: 0.75),
                .init(color: Color.clear,               location: 0.81),
                .init(color: Color.white.opacity(0.05), location: 0.87),
                .init(color: Color.clear,               location: 0.93),
                .init(color: Color.white.opacity(0.05), location: 1.00)
            ],
            center: UnitPoint(x: 0.5, y: 0.36)
        )
        // 只讓光線出現在徽章周圍：用 radial 遮罩限制範圍、邊緣柔化
        .mask(
            RadialGradient(
                colors: [Color.white, Color.white.opacity(0.0)],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 36,
                endRadius: 210
            )
        )
        .blendMode(.plusLighter)
    }

    /// 暈影：透明中心 → 半透明黑邊角，加深四周與底部。
    private var vignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(0.55)
            ],
            center: UnitPoint(x: 0.5, y: 0.42),
            startRadius: 60,
            endRadius: 330
        )
        .blendMode(.multiply)
    }

    /// 微噪點：以固定算式生成的細點陣，opacity 極低。完全確定性 → ImageRenderer 匯出穩定。
    private var noiseOverlay: some View {
        Canvas { context, size in
            // 固定 seed 的線性同餘產生器，不用 Date/隨機 → 每次匯出像素一致
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(UInt64(1) << 31)
            }
            let dot = CGSize(width: 1, height: 1)
            let count = 2200
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let bright = next() > 0.5
                let alpha = 0.035 * next()
                let color: Color = bright ? .white : .black
                context.fill(
                    Path(CGRect(origin: CGPoint(x: x, y: y), size: dot)),
                    with: .color(color.opacity(alpha))
                )
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左：P logo + PACERIZ 字樣
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.5)
                        )
                    Text("P")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                }
                Text("PACERIZ")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(2.5)
                    .foregroundColor(.white)
            }

            Spacer()

            // 右：章節 chip
            if let chapter = chapterName {
                Text(String(format: NSLocalizedString("achievements.share.card.chapter_label", comment: ""), chapter))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.16), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Badge Section（主角：聚光光暈 + 柔影 + 透明去背獎牌）

    private var badgeSection: some View {
        ZStack {
            // 1) 後方光暈：放在獎牌正後，模擬獎牌反光打亮
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            RecapPalette.gold.opacity(0.32),
                            RecapPalette.brand.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: badgeSize * 0.62
                    )
                )
                .frame(width: badgeSize * 1.4, height: badgeSize * 1.4)
                .blur(radius: 6)

            // 2) 獎牌本體：透明去背，雙層柔影做出懸浮立體感
            Image(badgeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 12)
                .shadow(color: RecapPalette.brand.opacity(0.35), radius: 26, x: 0, y: 0)
        }
        .frame(height: badgeSize)
    }

    // MARK: - UNLOCKED eyebrow（金色成就色）

    private var unlockedLabel: some View {
        HStack(spacing: 7) {
            line
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("UNLOCKED")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(3.5)
            }
            .foregroundColor(RecapPalette.gold)
            line
        }
    }

    /// eyebrow 兩側的金色漸隱細線
    private var line: some View {
        LinearGradient(
            colors: [RecapPalette.gold.opacity(0.0), RecapPalette.gold.opacity(0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 26, height: 1)
    }

    // MARK: - Title Section（第二焦點：大標題）

    private var titleSection: some View {
        Text(titleText)
            .font(.system(size: 27, weight: .heavy))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Text(summaryText)
            .font(.system(size: 13.5, weight: .regular))
            .foregroundColor(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Row（最多 3 欄 — 霜面數據條，取代灰色暗塊）

    private var statsRow: some View {
        let fields = Array(shareable.publicFields.prefix(3))
        return HStack(spacing: 0) {
            ForEach(fields.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 30)
                }
                statCell(field: fields[i])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func statCell(field: AchievementPublicField) -> some View {
        VStack(spacing: 3) {
            Text(field.value)
                .font(.system(size: 19, weight: .heavy).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(field.labelKey.localizedOrFallback(default: field.key))
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Footer（金點 + 日期）

    private var footer: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(RecapPalette.gold)
                .frame(width: 5, height: 5)
            Text(dateString)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
            Spacer()
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
    /// 分享完成後的追蹤回呼（實際的系統分享表單由本 sheet 自己呈現，避免 sheet-over-sheet 失效）。
    let onShared: () -> Void

    @State private var activityItem: AchievementActivityItem?

    // dateString 在 init 時產生，保持呼叫端 API 不變
    private let dateString: String
    private let badgeAssetName: String

    init(shareable: AchievementShareable, badgeAssetName: String, onShared: @escaping () -> Void) {
        self.shareable = shareable
        self.badgeAssetName = badgeAssetName
        self.onShared = onShared

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
                        dateString: dateString,
                        badgeAssetName: badgeAssetName
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding(.top)

                    Button {
                        if let image = renderCard() {
                            activityItem = AchievementActivityItem(image: image)
                        }
                    } label: {
                        Label(L10n.Achievements.Share.action.localized, systemImage: "square.and.arrow.up")
                            .font(AppFont.bodyStrong())
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
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
            // 系統分享表單由本 sheet 自己呈現（preview 為 presenter），避免從父層 sheet-over-sheet 而無反應。
            .sheet(item: $activityItem) { item in
                AchievementActivityViewController(items: [item.image]) {
                    onShared()
                    activityItem = nil
                }
            }
        }
    }

    private func renderCard() -> UIImage? {
        let card = AchievementShareCardView(
            shareable: shareable,
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
    titleKey: "賽季節奏跑者",
    summaryKey: "連續累積 12 週有效訓練節奏",
    summaryParams: [:],
    publicFields: [
        AchievementPublicField(key: "distance", labelKey: "總距離", value: "32.4km"),
        AchievementPublicField(key: "count", labelKey: "次數", value: "5次"),
        AchievementPublicField(key: "pace", labelKey: "配速", value: "5:42/km")
    ],
    defaultSensitiveFieldsEnabled: false,
    badgeId: "BADGE-RHYTHM-12-SEASON-RUNNER",
    chapter: .build
)

#Preview("AchievementShareCardView") {
    ZStack {
        Color(UIColor.systemGroupedBackground)
        AchievementShareCardView(
            shareable: previewShareable,
            dateString: "2026.05.22",
            badgeAssetName: "achievement_badge_rhythm_12_season_runner"
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
#endif
