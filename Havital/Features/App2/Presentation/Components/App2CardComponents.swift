import SwiftUI

// MARK: - App2Card
/// 2.0 的卡片容器：白底、圓角、柔陰影。
///
/// repo 內既有的卡片（`PersonalBestCardView`／`TrainingStageCard`）都是「特定內容
/// ＋容器」綁在一起的成品，沒有可重用的純容器，所以這裡新開一個容器而不是複製它們的樣式。
struct App2Card<Content: View>: View {
    var background: Color = App2Theme.cardBackground
    var padding: CGFloat = App2Theme.cardPadding
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: App2Theme.sectionSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(background)
        )
        .shadow(
            color: App2Theme.shadowColor,
            radius: App2Theme.shadowRadius,
            x: 0,
            y: App2Theme.shadowY
        )
    }
}

// MARK: - App2SectionLabel
/// 卡片左上角的小標（`目標賽事`／`訓練狀況`）。
struct App2SectionLabel: View {
    let text: String
    var color: Color = App2Theme.accentBlue

    var body: some View {
        Text(text)
            .font(.app2SectionLabel)
            .foregroundStyle(color)
    }
}

// MARK: - App2Pill
/// 膠囊徽章（`全馬`／`基礎期`／`高強度`）。
struct App2Pill: View {
    let text: String
    var foreground: Color = .white
    var background: Color = App2Theme.accentBlue

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, PacerizTokens.spacing.m)
            .padding(.vertical, PacerizTokens.spacing.xs + 2)
            .background(Capsule().fill(background))
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
            HStack(spacing: PacerizTokens.spacing.xs) {
                Image(systemName: "flask")
                    .font(.system(size: 9, weight: .bold))
                Text(L10n.App2.Common.stubBadge.localized)
                    .font(.system(size: 10, weight: .semibold))
                Text(section)
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundStyle(App2Theme.stubTint)
            .padding(.horizontal, PacerizTokens.spacing.s)
            .padding(.vertical, 3)
            .background(Capsule().fill(App2Theme.stubBackground))
            .accessibilityIdentifier("App2_StubBadge")
        }
    }
}

// MARK: - App2FieldColumn
/// 「標籤在上、大數字在下」的欄（`目標 / 2:34:00`）。
struct App2FieldColumn: View {
    let label: String
    let value: String
    var valueColor: Color = App2Theme.inkPrimary
    var valueSize: CGFloat = 22
    /// 附在數字後面的小字（`/22`、`km`）。
    var suffix: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.app2FieldLabel)
                .foregroundStyle(App2Theme.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.app2Numeric(valueSize))
                    .foregroundStyle(valueColor)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            // 四位數的 YTD 跑量（1483 km）在窄欄會折行，縮字不換行。
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App2InsightCell
/// 指標網格一格（§3.1a `insights[]`）。
struct App2InsightCell: View {
    let insight: App2Insight

    private var arrow: (symbol: String, color: Color)? {
        switch insight.direction {
        case .up:      return ("arrow.up", App2Theme.accentGreen)
        case .down:    return ("arrow.down", App2Theme.accentOrange)
        case .flat:    return ("arrow.right", App2Theme.inkTertiary)
        case .unknown: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(arrow?.color ?? App2Theme.inkTertiary)
                    .frame(width: 6, height: 6)
                Text(insight.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineLimit(1)
                if let arrow {
                    Image(systemName: arrow.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(arrow.color)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(insight.value ?? "—")
                    .font(.app2Numeric(18))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let verdict = insight.verdict {
                    Text(verdict)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PacerizTokens.spacing.m)
        .padding(.vertical, PacerizTokens.spacing.s + 2)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                .fill(App2Theme.insetBackground)
        )
    }
}

// MARK: - App2TrackBar
/// §3.1a 的三色軌道條：落後 — 正常軌道 — 超乎預期。
///
/// 三色帶依設計文件是「預估線 ± 固定容差推導，app 端算 path」的呈現層，
/// 沒有資料缺口；落點 `position` 由 ViewModel 給。
struct App2TrackBar: View {
    /// 0（落後）～1（超乎預期）。
    let position: Double

    var body: some View {
        VStack(spacing: PacerizTokens.spacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [App2Theme.trackBehind, App2Theme.trackOnTrack, App2Theme.trackAhead],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())

                    Circle()
                        .fill(App2Theme.accentBlue)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(1, position)) * (geo.size.width - 12))
                }
            }
            .frame(height: 8)

            HStack {
                Text(L10n.App2.Home.trackBehind.localized)
                    .foregroundStyle(App2Theme.trackBehind)
                Spacer()
                Text(L10n.App2.Home.trackOnTrack.localized)
                    .foregroundStyle(App2Theme.trackOnTrack)
                Spacer()
                Text(L10n.App2.Home.trackAhead.localized)
                    .foregroundStyle(App2Theme.trackAhead)
            }
            .font(.system(size: 10, weight: .medium))
        }
    }
}

// MARK: - App2InlineNotice
/// 卡片底部的一行說明（載入失敗改用樣本、stub 出處…）。
struct App2InlineNotice: View {
    let text: String
    var systemImage: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: PacerizTokens.spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(App2Theme.inkTertiary)
    }
}
