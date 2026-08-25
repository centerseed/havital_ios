import SwiftUI

// MARK: - App2SettingsPageScaffold
/// 設定子頁（設計 frame-22 ~ frame-29）共用的外殼：返回鍵＋標題 → 捲動內容 →
/// 釘在底部的主 CTA。
///
/// 為什麼不直接用 `App2OnboardingPage`：那支的 header 綁著 onboarding 的三段
/// 進度指示器（`App2OnboardingSegment`），設定子頁沒有進度概念。共用的是
/// `App2PageHeader` 與 `App2OnboardingPrimaryButton` 這兩個元件本身，
/// 這裡只把它們的排版收成一份，避免七個子頁各寫一次。
struct App2SettingsPageScaffold<Content: View>: View {

    let title: String
    let onBack: () -> Void
    var backIdentifier: String
    var titleIdentifier: String
    /// nil = 這一頁沒有底部 CTA（frame-24／25／28 就沒有）。
    var ctaTitle: String?
    var ctaEnabled: Bool = true
    var ctaBusy: Bool = false
    var ctaIdentifier: String = "App2_SettingsPageCta"
    /// 破壞性動作（frame-29 的「永久刪除帳戶」）用紅底而不是藍底。
    var ctaIsDestructive: Bool = false
    var ctaAction: (() -> Void)?
    /// CTA 底下的次要文字鈕（frame-22「取消訂閱」、frame-29「取消」）。
    var secondaryTitle: String?
    var secondaryIsDestructive: Bool = false
    var secondaryIdentifier: String = "App2_SettingsPageSecondary"
    var secondaryAction: (() -> Void)?

    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: title,
                titleSize: 22,
                onBack: onBack,
                backIdentifier: backIdentifier,
                titleIdentifier: titleIdentifier
            ) { EmptyView() }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 16)

            ScrollView {
                content()
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.bottom, 28)
            }

            if ctaTitle != nil || secondaryTitle != nil {
                VStack(spacing: 10) {
                    if let ctaTitle, let ctaAction {
                        if ctaIsDestructive {
                            Button(action: ctaAction) {
                                Text(ctaTitle)
                                    .font(.system(size: 17, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(App2Theme.accentRed)
                                    )
                                    .opacity(ctaEnabled && !ctaBusy ? 1 : 0.45)
                            }
                            .buttonStyle(.plain)
                            .disabled(!ctaEnabled || ctaBusy)
                            .accessibilityIdentifier(ctaIdentifier)
                        } else {
                            App2OnboardingPrimaryButton(
                                title: ctaTitle,
                                enabled: ctaEnabled,
                                busy: ctaBusy,
                                identifier: ctaIdentifier,
                                action: ctaAction
                            )
                        }
                    }
                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(
                                    secondaryIsDestructive
                                        ? App2Theme.accentRed
                                        : App2Theme.inkTertiary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(secondaryIdentifier)
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 12)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }
}

// MARK: - App2DataSourceRow
/// Garmin／Apple Health 的來源列（設計 frame-24／25，與 onboarding frame-34 同一款）。
///
/// 原本只長在 `App2OnboardingDeviceLinkView.sourceRow`；2.0 設定頁的「數據來源」子頁
/// 是同一個視覺與同一組狀態，所以抽出來共用，**不在設定頁再畫一次**。
struct App2DataSourceRow<Leading: View>: View {
    @ViewBuilder let leading: () -> Leading
    let title: String
    /// 未連接時顯示的說明；已連接時改顯示綠點狀態列。
    var subtitle: String?
    let isConnected: Bool
    /// nil = 這一列沒有動作鈕。
    var actionTitle: String?
    var actionIdentifier: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            leading()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                if isConnected {
                    HStack(spacing: 6) {
                        Circle().fill(App2Theme.accentGreenDot).frame(width: 6, height: 6)
                        Text(L10n.App2.Onboarding.deviceConnected.localized)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(App2Theme.accentGreenDot)
                    }
                } else if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSubtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(isConnected ? App2Theme.inkSubtle : .white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isConnected ? Color(hex: "#EEF2F7") : App2Theme.accentBlue)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(actionIdentifier ?? "App2_DataSourceRowAction")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isConnected
                      ? AnyShapeStyle(App2Theme.accentGreenBright.opacity(0.07))
                      : AnyShapeStyle(App2Theme.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isConnected
                        ? App2Theme.accentGreenBright.opacity(0.35)
                        : Color(hex: "#0F172A").opacity(0.07),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - 來源圖示磚
/// Garmin（深色）／Apple Health（淺色紅心）的 46×46 圖示格。
enum App2DataSourceTile {
    static var garmin: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(App2Theme.sourceDarkTile)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "applewatch")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }

    static var appleHealth: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(App2Theme.sourceLightTile)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(App2Theme.appleHealthRed)
            )
    }
}
