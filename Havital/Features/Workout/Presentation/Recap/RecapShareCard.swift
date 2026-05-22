import SwiftUI

// MARK: - Recap design tokens (對齊 Claude Design / recap.jsx)

enum RecapPalette {
    static let brand = PacerizColor.blue          // #3F86F6（recap 統一品牌色）
    static let brandDeep = Color(red: 0.118, green: 0.384, blue: 0.816)  // #1E62D0（固定深藍，不隨深色模式變淺）
    static let darkNavy = Color(red: 0.102, green: 0.102, blue: 0.125)  // #1A1A20
    static let gold = Color(red: 1.0, green: 0.843, blue: 0.353)        // #FFD75A
    static let peach = Color(red: 1.0, green: 0.616, blue: 0.455)       // #FF9D74

    /// rpeColor(v)：≤3 綠 / ≤5 琥珀 / ≤7 橘 / ≥8 紅（rpe.jsx）
    static func rpe(_ v: Int) -> Color {
        switch v {
        case ...3: return Color(red: 0.463, green: 0.784, blue: 0.576) // #76C893
        case 4...5: return Color(red: 0.961, green: 0.725, blue: 0.271) // #F5B945
        case 6...7: return Color(red: 1.0, green: 0.498, blue: 0.314)   // #FF7F50
        default: return Color(red: 0.898, green: 0.294, blue: 0.235)    // #E54B3C
        }
    }
}

// MARK: - RecapShareCard
//
// 可分享的訓練成果卡，對齊 recap.jsx 的 ShareCardPreview：
//   藍→深漸層底（或使用者照片）+ 右上 VDOT chip + 彩帶 + 置中「完成 X」+ 置中三項數據 + PACERIZ。
//
// 同時用於：(1) recap hero（onPhotoTap != nil 時於中上顯示「加入/換照片」鈕）
//          (2) 分享匯出（onPhotoTap == nil → 不畫照片鈕，圖乾淨）。
// 字級固定 .system，分享圖不隨動態字級改變。

struct RecapShareCard: View {
    let content: WorkoutRecapContent
    let photo: UIImage?
    /// 非 nil → 顯示中上「加入/換照片」鈕（互動）；nil → 匯出用，乾淨無鈕。
    var onPhotoTap: (() -> Void)? = nil
    /// 螢幕上用圓角；匯出傳 0 → 全出血不透明矩形（避免分享縮圖呈透明棋盤/空白）。
    var cornerRadius: CGFloat = 18

    private var titleText: String {
        if let type = content.trainingTypeName, !type.isEmpty { return "完成 \(type)" }
        return "訓練完成"
    }

    private var distanceValue: String {
        let parts = content.distanceText.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.first ?? content.distanceText
    }

    private var paceValue: String {
        let raw = content.paceText
        if let slash = raw.firstIndex(of: "/") {
            return String(raw[..<slash]).trimmingCharacters(in: .whitespaces)
        }
        return raw.trimmingCharacters(in: .whitespaces)
    }

    private var vdotText: String? {
        guard let v = content.vdot, v > 0 else { return nil }
        return String(format: "%.1f", v)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                backgroundLayer(geo.size)
                scrim
                confetti(in: geo.size)
                vdotChip
                infoBlock
                if let onPhotoTap {
                    photoButton(action: onPhotoTap)
                        .position(x: w / 2, y: h * 0.38)
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundLayer(_ size: CGSize) -> some View {
        if let photo {
            // 必須明確框成卡片尺寸 + clip，否則 scaledToFill 的內在尺寸會把整張卡撐爆（數據被推出邊界）。
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            ZStack {
                RecapPalette.darkNavy
                // 飽和藍：頂端保持鮮明品牌藍久一點，再經深藍過渡到深色，避免「太淡」。
                LinearGradient(
                    stops: [
                        .init(color: RecapPalette.brand, location: 0.0),
                        .init(color: RecapPalette.brand, location: 0.30),
                        .init(color: RecapPalette.brandDeep, location: 0.62),
                        .init(color: RecapPalette.darkNavy, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 左上柔光（大幅調降，避免沖淡藍色）
                RadialGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                    center: UnitPoint(x: 0.28, y: 0.16),
                    startRadius: 0,
                    endRadius: 200
                )
            }
        }
    }

    /// 由下而上加暗，保證文字在任何照片上可讀。
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.05), location: 0.0),
                .init(color: .black.opacity(0.0), location: 0.4),
                .init(color: .black.opacity(0.55), location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Confetti（靜態，烘進分享圖）

    private struct Particle { let x, y, r, sz: CGFloat; let c: Color; let circle: Bool }
    private let particles: [Particle] = [
        .init(x: 8,  y: 12, r: -18, sz: 6, c: RecapPalette.gold,  circle: false),
        .init(x: 88, y: 8,  r: 22,  sz: 5, c: .white,             circle: false),
        .init(x: 28, y: 22, r: 6,   sz: 4, c: RecapPalette.peach, circle: false),
        .init(x: 92, y: 28, r: -32, sz: 4, c: RecapPalette.gold,  circle: false),
        .init(x: 12, y: 32, r: 14,  sz: 3, c: .white,             circle: true),
        .init(x: 78, y: 18, r: 0,   sz: 3, c: RecapPalette.gold,  circle: true)
    ]

    private func confetti(in size: CGSize) -> some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                let p = particles[i]
                RoundedRectangle(cornerRadius: p.circle ? p.sz / 2 : 1.5)
                    .fill(p.c)
                    .frame(width: p.circle ? p.sz : p.sz * 1.6, height: p.sz)
                    .rotationEffect(.degrees(p.r))
                    .opacity(0.85)
                    .position(x: size.width * p.x / 100, y: size.height * p.y / 100)
            }
        }
    }

    // MARK: - VDOT chip（右上）

    @ViewBuilder
    private var vdotChip: some View {
        if let vdotText {
            HStack(spacing: 4) {
                Text("VDOT \(vdotText)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(14)
        }
    }

    // MARK: - Photo button（中上，互動；匯出時不畫）

    private func photoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: photo == nil ? "photo" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                Text(photo == nil ? "加入照片" : "換照片")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.55), in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 9, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom info block（置中標題 + 三項數據 + PACERIZ）

    private var infoBlock: some View {
        VStack(spacing: 0) {
            Text(titleText)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(alignment: .top, spacing: 4) {
                metric(distanceValue, "KM")
                metric(content.durationText, "時間")
                metric(paceValue, "配速")
            }
            .padding(.top, 12)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 12)

            Text("PACERIZ")
                .font(.system(size: 11, weight: .heavy))
                .tracking(4)
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold).monospacedDigit())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Gradient") {
    RecapShareCard(
        content: WorkoutRecapContent(
            id: "p1", date: Date(), trainingTypeName: "間歇訓練",
            distanceText: "5.74 公里", paceText: "5:27 /km", durationText: "33:39",
            vdot: 38.2, rpe: 7, aiAnalysis: nil,
            celebrationTitle: nil, encouragement: nil, streakDays: 7, isPremium: true
        ),
        photo: nil,
        onPhotoTap: {}
    )
    .padding()
}
#endif
