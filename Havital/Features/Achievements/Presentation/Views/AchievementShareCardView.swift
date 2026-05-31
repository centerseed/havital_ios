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
    /// App 內預覽用圓角卡片（true）；匯出分享圖時用 false → 滿版直角矩形，
    /// 讓 Threads/IG 等平台用「自己的」圓角去裁，不會出現雙重圓角對不齊的缺角/白邊。
    var roundedCorners: Bool = true

    // MARK: - Layout constants（固定尺寸 — ImageRenderer 匯出用，絕不可隨裝置縮放）

    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 460
    private let cardRadius: CGFloat = 26
    private let badgeSize: CGFloat = 168
    private let badgePlatePadding: CGFloat = 24        // 底板比徽章大多少（plate = badgeSize + padding）
    private let badgePlateCornerRatio: CGFloat = 0.20  // 底板圓角比例（刻意比 app 內 hero 0.22 略方）
    private let badgeImageInset: CGFloat = 11           // 徽章圖在底板內的四周邊距

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
        // 預覽：圓角卡片；匯出：直角滿版（cornerRadius 0 → 無透明角落）
        .clipShape(RoundedRectangle(cornerRadius: roundedCorners ? cardRadius : 0, style: .continuous))
        // 內描邊只在預覽圓角時加（滿版匯出不需要邊框，避免變成貼邊白線）
        .overlay {
            if roundedCorners {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: - Background（精緻深色：單一深藍→黑漸層 + 一道柔和聚光 + 暈影）
    //
    // 設計意圖（2026-05 二次改版，使用者選定「精緻深色」方向）：
    // 移除原本堆疊過多的 mesh blob×2 / 放射光線 rays / 重噪點——特效堆疊只會更雜、不會更高級
    // （通用 AI 美學陷阱）。改走克制的「單一平滑深色漸層」奠定沉穩基調。
    //   - 基底：頂端深藍 → 底部近黑的單一線性漸層。上方略亮讓徽章成主角，底部夠深給白字高對比。
    //   - 聚光：徽章正後一道柔和 radial 光暈，色相由章節 accent 微帶入（不同成就微妙差異，仍同一深色家族）。
    //   - 暈影：四角輕收，聚焦中央、強化底部對比。
    //   - 微噪點：極低 opacity，純為消除單一漸層在 ImageRenderer 匯出時的色帶（banding），非裝飾。

    private var backgroundGradient: some View {
        ZStack {
            // 1) 基底：深藍 → 近黑的單一平滑漸層
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.094, green: 0.133, blue: 0.243), location: 0.0),
                    .init(color: Color(red: 0.051, green: 0.067, blue: 0.125), location: 0.55),
                    .init(color: Color(red: 0.027, green: 0.035, blue: 0.063), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 2) 聚光：徽章正後一道柔和光暈，色相由章節 accent 微帶入
            RadialGradient(
                colors: [
                    Color.white.opacity(0.16),
                    chapterAccent.opacity(0.30),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 0,
                endRadius: 250
            )

            // 3) 暈影：四角輕收
            vignette

            // 4) 微噪點：消除漸層色帶（極低 opacity，非裝飾）
            noiseOverlay
        }
    }

    /// 暈影：透明中心 → 半透明黑邊角，加深四周與底部。
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.5),          // 中心到一半保持透明
                .init(color: .black.opacity(0.45), location: 1.0)  // 之後往邊角漸暗
            ],
            center: UnitPoint(x: 0.5, y: 0.42),
            startRadius: 80,
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
            let count = 1400
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let bright = next() > 0.5
                let alpha = 0.022 * next()
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
            // 左：Paceriz 跑鞋 logomark + PACERIZ 字樣
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.5)
                        )
                    // 品牌跑鞋 logomark（透明去背藍色 shoe），取代原本的「P」字母佔位
                    Image("paceriz_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
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

    // MARK: - Badge Section（嵌入式獎章框，解決淺底插畫白邊問題）
    //
    // 設計意圖（2026-05 二次改版）：徽章資產形狀不一致——rhythm 系列是「淺奶油底圓角方形插畫」、
    // results/mileage 系列是「透明去背圓形獎章/錢幣」。原本一律當透明懸浮獎牌處理（不裁切 + 聚光 + 雙陰影），
    // 淺色方形插畫貼在深底上 → 圓角露出奶油色 = 看起來像便利貼（使用者反映的「白邊」）。
    // 改為：把每個徽章都嵌進一個「乾淨的霜面圓角方形底板 + 髮絲框」。
    //   - 淺底方形插畫：裁成略小的圓角方形、四周留底板邊距 → 變成「裱框的圖」，白邊成為有意圖的外框。
    //   - 透明圓形獎章：透明角落露出底板 → 變成「裱框的獎章」。兩種形狀都被統一收進同一個框，視覺一致。
    //   - 圓角刻意比 app 內 hero（0.22）略方（plate 0.20 / image 內縮），更像獎座銘牌、less bubbly，
    //     呼應使用者「圓角太圓」的回饋。

    private var badgeSection: some View {
        let plateSize: CGFloat = badgeSize + badgePlatePadding         // 192
        let plateRadius: CGFloat = plateSize * badgePlateCornerRatio   // ~38
        let imageSize: CGFloat = plateSize - badgeImageInset * 2       // 170
        let imageRadius: CGFloat = plateRadius - badgeImageInset       // ~27

        return ZStack {
            // 底板：霜面填色 + 上亮下暗髮絲框 + 柔影，把徽章烘成裱框獎章
            RoundedRectangle(cornerRadius: plateRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: plateRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.30), Color.white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: plateSize, height: plateSize)
                .shadow(color: Color.black.opacity(0.40), radius: 16, x: 0, y: 10)

            // 徽章本體：裁成圓角方形（淺底插畫不再露原始奶油邊；透明圓章角落露底板）
            Image(badgeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .clipShape(RoundedRectangle(cornerRadius: imageRadius, style: .continuous))
        }
        .frame(height: plateSize)
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
            badgeAssetName: badgeAssetName,
            roundedCorners: false   // 匯出滿版直角，交給目的平台自己圓角
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
