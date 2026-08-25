import SwiftUI

// MARK: - App2Card
/// 2.0 的卡片容器：白底、圓角 22、細邊、雙層陰影。
///
/// 對應設計 markup 的
/// `border-radius:22px;background:#ffffff;border:1px solid rgba(15,23,42,0.07);`
/// `box-shadow:0 1px 2px rgba(16,24,40,0.04), 0 10px 26px -16px rgba(16,24,40,0.22)`。
///
/// repo 內既有的卡片（`PersonalBestCardView`／`TrainingStageCard`）都是「特定內容
/// ＋容器」綁在一起的成品，沒有可重用的純容器，所以這裡新開一個容器而不是複製它們的樣式。
struct App2Card<Content: View>: View {
    var cornerRadius: CGFloat = App2Theme.cardCornerRadius
    var padding: CGFloat = App2Theme.cardPadding
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .app2CardSurface(cornerRadius: cornerRadius)
    }
}

// MARK: - App2AccentCard
/// 強調卡（目標賽事／本週跑量／紀錄 hero／成就 hero）：藍色對角漸層 ＋ 藍邊 ＋ 藍光暈。
struct App2AccentCard<Content: View>: View {
    var strength: Double = 0.12
    var padding: CGFloat = App2Theme.cardPadding
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(App2Theme.accentCardGradient(strength: strength))
        )
        .overlay(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(App2Theme.accentCardBorder, lineWidth: 1)
        )
        .shadow(
            color: App2Theme.shadowAccentColor,
            radius: App2Theme.shadowAccentRadius,
            x: 0,
            y: App2Theme.shadowAccentY
        )
    }
}

// MARK: - 卡面 modifier（白底＋邊＋雙層陰影，供不走 App2Card 的自訂版型重用）

extension View {
    func app2CardSurface(cornerRadius: CGFloat = App2Theme.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: App2Theme.shadowTightColor,
                radius: App2Theme.shadowTightRadius,
                x: 0,
                y: App2Theme.shadowTightY
            )
            .shadow(
                color: App2Theme.shadowSoftColor,
                radius: App2Theme.shadowSoftRadius,
                x: 0,
                y: App2Theme.shadowSoftY
            )
    }

    /// 卡中卡的淺底（`#f5f7fa` / `#f7f9fc` ＋ 1px 邊）。
    func app2InsetSurface(
        cornerRadius: CGFloat = App2Theme.insetCornerRadius,
        fill: Color = App2Theme.insetBackground
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(App2Theme.insetBorder, lineWidth: 1)
            )
    }
}

// MARK: - App2LeftStripCard
/// 左緣 3px 彩色邊的白卡（課表每日卡、紀錄每筆卡）。
struct App2LeftStripCard<Content: View>: View {
    let strip: Color
    var cornerRadius: CGFloat = App2Theme.dayCardCornerRadius
    var padding: EdgeInsets = EdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 14)
    var borderColor: Color = App2Theme.cardBorder
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(App2Theme.cardBackground)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(strip).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: App2Theme.shadowTightColor, radius: 1, x: 0, y: 1)
        .shadow(color: App2Theme.shadowInk.opacity(0.14), radius: 8, x: 0, y: 6)
    }
}

// MARK: - App2SectionLabel
/// 卡片左上角的小標（`目標賽事`）：13px / w700 / letterSpacing 2 / 藍。
struct App2SectionLabel: View {
    let text: String
    var color: Color = App2Theme.accentBlueDeep
    var tracking: CGFloat = 2

    var body: some View {
        Text(text)
            .font(.app2SectionLabel)
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

// MARK: - App2SectionCaption
/// 分組清單上方的灰色小標（`訂閱`／`數據來源`／`系統`）：13px / w800 / #94A0AD。
struct App2SectionCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(App2Theme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

// MARK: - App2Pill
/// 膠囊徽章（`全馬`／`基礎期`／`今日`）：`border-radius:999px;padding:4px 11px;font:13/800`。
struct App2Pill: View {
    let text: String
    var foreground: Color = .white
    var background: Color = App2Theme.accentBlue
    var border: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
            .overlay {
                if let border {
                    Capsule().strokeBorder(border, lineWidth: 1)
                }
            }
    }
}

// MARK: - App2Chip
/// 方角小徽章（課型／體感溫度／強度）：`border-radius:8px;padding:4px 9px;font:13/800`。
struct App2Chip: View {
    let text: String
    var foreground: Color
    var background: Color
    var monospaced: Bool = false

    var body: some View {
        Text(text)
            .font(monospaced
                  ? .app2Mono(13, weight: .heavy)
                  : .system(size: 13, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: App2Theme.chipCornerRadius, style: .continuous)
                    .fill(background)
            )
    }
}

// MARK: - App2StubBadge
/// 「這格是樣本」的可見標記。
///
/// 票面要求 stub 區塊在程式內標注來源；標成型別（`App2DataOrigin`）之後，
/// 這個 view 讓它在畫面上也看得見，避免 demo 時把樣本誤讀成真資料。
struct App2StubBadge: View {
    let origin: App2DataOrigin

    var body: some View {
        if let section = origin.pendingSectionLabel {
            HStack(spacing: 3) {
                Image(systemName: "flask")
                    .font(.system(size: 9, weight: .bold))
                Text(L10n.App2.Common.stubBadge.localized)
                    .font(.system(size: 10, weight: .semibold))
                Text(section)
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundStyle(App2Theme.stubTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(App2Theme.stubBackground))
            .accessibilityIdentifier("App2_StubBadge")
        }
    }
}

// MARK: - App2FieldColumn
/// 「標籤在上、大 mono 數字在下」的欄（`目標 / 2:34:00`）。
///
/// 設計：label 13px w700 #8A929C letterSpacing 1；value 21px w900 mono。
struct App2FieldColumn: View {
    let label: String
    let value: String
    var valueColor: Color = App2Theme.inkPrimary
    var valueSize: CGFloat = 21
    /// 附在數字後面的小字（`/22`、`km`）。
    var suffix: String?
    var suffixSize: CGFloat = 14
    var fillsWidth: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.app2FieldLabel)
                .tracking(1)
                .foregroundStyle(App2Theme.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.app2Mono(valueSize))
                    .foregroundStyle(valueColor)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: suffixSize, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            // 四位數的 YTD 跑量（1,284 km）在窄欄會折行，縮字不換行。
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
    }
}

// MARK: - App2InsightChip
/// 收合列上的指標小膠囊：`padding:5px 7px;border-radius:10px` ＋ icon ＋ 方向符號。
struct App2InsightChip: View {
    let insight: App2Insight

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(insight.tint)
            Text(insight.arrowGlyph)
                .font(.app2Mono(14))
                .foregroundStyle(insight.tint)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(insight.tint.opacity(0.12))
        )
    }
}

// MARK: - App2InsightCell
/// 指標網格一格（§3.1a `insights[]`）：左緣 3px 色條 ＋ 名稱 ＋ 方向 ＋ 評級／變化。
struct App2InsightCell: View {
    let insight: App2Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: insight.symbolName)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(insight.tint)
                Text(insight.label)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(insight.arrowGlyph)
                    .font(.app2Mono(17))
                    .foregroundStyle(insight.tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(insight.verdict ?? "—")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(insight.tint)
                if let value = insight.value {
                    Text(value)
                        .font(.app2Mono(13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 11))
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(App2Theme.insetBackground)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(insight.tint).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(App2Theme.insetBorder, lineWidth: 1)
        )
    }
}

// MARK: - App2InlineNotice
/// 卡片底部的一行說明（載入失敗改用樣本、stub 出處…）。
struct App2InlineNotice: View {
    let text: String
    var systemImage: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(App2Theme.inkFaint)
    }
}

// MARK: - App2Avatar
/// 右上角頭像（設定入口）。設計是藍漸層圓 ＋ 姓氏首字 ＋ 白邊。
struct App2Avatar: View {
    let initial: String
    var size: CGFloat = 32
    var showsRing: Bool = true

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [App2Theme.accentBlueLight, App2Theme.accentBlueDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(.white)
            }
            .overlay {
                if showsRing {
                    Circle().strokeBorder(.white, lineWidth: 1.5)
                }
            }
            .shadow(color: App2Theme.accentBlue.opacity(0.45), radius: 5, x: 0, y: 4)
    }
}

// MARK: - App2HexagonShape / App2LevelBadge
/// `clip-path:polygon(50% 0,100% 25%,100% 75%,50% 100%,0 75%,0 25%)`。
struct App2HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        path.addLine(to: CGPoint(x: 0, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}

/// 首頁右上的 LV 六角徽章（44×48）。
///
/// **不顯示等級數字。** 設計 frame-00 畫的是 `LV 7`，但 backend 沒有任何等級讀口
/// （§7-1 的語意缺口），先前硬寫的 `—` 看起來像「載入失敗」而不是「還沒有這個量」。
/// 這裡改成只留字標的乾淨樣式；等級落地後再把數字接上來。
struct App2LevelBadge: View {

    var body: some View {
        ZStack {
            App2HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [App2Theme.accentBlueLight, App2Theme.accentBlueDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            App2HexagonShape()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .padding(3)
            Text(verbatim: "LV")
                .font(.system(size: 15, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 48)
        .shadow(color: App2Theme.accentBlue.opacity(0.4), radius: 6, x: 0, y: 6)
        // identifier 掛在呼叫端（首頁 header 把它併成單一可點節點），這裡不重複掛：
        // 內層的會被外層的 `.accessibilityElement(children: .ignore)` 吃掉。
    }
}

// MARK: - App2GroupedList
/// 設定頁的分組白卡：圓角 20、內部列以 1px 分隔線（左縮 59pt）相連。
struct App2GroupedList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: App2Theme.listCardCornerRadius, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: App2Theme.listCardCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: App2Theme.listCardCornerRadius, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: App2Theme.shadowTightColor, radius: 1, x: 0, y: 1)
            .shadow(color: App2Theme.shadowSoftColor, radius: App2Theme.shadowSoftRadius, x: 0, y: 10)
    }
}

/// 分組清單裡的一列：圓角 icon 底 ＋ 標題 ＋ 右側值 ＋ chevron。
struct App2SettingsRow<Trailing: View>: View {
    let systemImage: String
    let iconTint: Color
    let iconBackground: Color
    let title: String
    var showsDivider: Bool = true
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(iconTint)
                    }
                Text(title)
                    .font(.app2RowTitle)
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                trailing()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.chevron)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)

            if showsDivider {
                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.leading, 59)
            }
        }
    }
}

extension App2SettingsRow where Trailing == Text {
    init(
        systemImage: String,
        iconTint: Color = App2Theme.accentBlueDeep,
        iconBackground: Color = App2Theme.accentBlue.opacity(0.1),
        title: String,
        value: String,
        monospaced: Bool = false,
        showsDivider: Bool = true
    ) {
        self.init(
            systemImage: systemImage,
            iconTint: iconTint,
            iconBackground: iconBackground,
            title: title,
            showsDivider: showsDivider
        ) {
            Text(value)
                .font(monospaced
                      ? .app2Mono(14, weight: .bold)
                      : .system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#6B7581"))
        }
    }
}

// MARK: - App2ProgressBar
/// 圓角進度條（成就 hero、徽章故事線）。
struct App2ProgressBar: View {
    let progress: Double
    var height: CGFloat = 8
    var fill: LinearGradient = LinearGradient(
        colors: [App2Theme.accentBlue, App2Theme.accentBlueLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(App2Theme.shadowInk.opacity(0.08))
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: height)
    }
}
