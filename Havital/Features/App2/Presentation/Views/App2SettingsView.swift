import SwiftUI

// MARK: - App2SettingsView
/// 2.0 設定頁 —— 設計 **frame-21「設定 · 首頁」**（語意見
/// `DESIGN-app2-decision-chain-api.md` §3.9a）。
///
/// **不是 tab**：設計把第四格留給成就，設定改由課表頁右上角的頭像進入，
/// 左上是返回鍵（設計 frame-21 第一列）。
///
/// 版面：profile 卡 → 訂閱（藍卡 ＋ 兩顆按鈕）→ 訓練設定（分組清單）
/// → 數據來源（分組清單，右側連接狀態）。
/// 設計另有「生理指標」「系統」兩組（frame-26／27／28），app 端目前沒有讀口，
/// 本輪不擺空殼 —— 列在票面剩餘差異。
struct App2SettingsView: View {

    let onClose: () -> Void

    @ObservedObject var viewModel: App2SettingsViewModel
    /// 「重新設定目標賽事」走 2.0 的 onboarding 流程（`App2OnboardingContainerView`，
    /// 設計 frame-31 起）。**邏輯不是第二份**：它底下仍是 `OnboardingCoordinator` /
    /// `OnboardingFeatureViewModel`，與首次 onboarding 同一條提交路徑。
    @State private var isShowingGoalSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 16)

                if let sourced = viewModel.snapshot {
                    profileCard(sourced)
                    goalSection
                    subscriptionSection(sourced)
                    trainingSection(sourced)
                    dataSourceSection(sourced)
                    accountSection
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_SettingsView")
        .onAppear { viewModel.loadIfNeeded() }
        .fullScreenCover(isPresented: $isShowingGoalSetup) {
            App2OnboardingContainerView(isReonboarding: true) {
                isShowingGoalSetup = false
            }
        }
    }

    // MARK: - 目標賽事

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.goalSection.localized)
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "flag.checkered.2.crossed",
                    title: L10n.App2.Settings.resetGoalRace.localized,
                    value: "",
                    showsDivider: false
                )
            }
            // Button 會吃掉 identifier（同 repo 既有註解），用容器 + onTapGesture。
            .contentShape(Rectangle())
            .onTapGesture { isShowingGoalSetup = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_SettingsResetGoalRace")
        }
    }

    // MARK: - 帳號（登出）

    /// 登出走既有的 `AuthenticationViewModel.shared.signOut()`，不另寫一份 2.0 版。
    /// 這一列在 1.x 是在個人檔案頁；2.0 的設定頁沒有它就換不了帳號。
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2GroupedList {
                App2SettingsRow(
                    systemImage: "rectangle.portrait.and.arrow.right",
                    iconTint: App2Theme.accentRed,
                    iconBackground: App2Theme.accentRed.opacity(0.1),
                    title: NSLocalizedString("common.logout", comment: ""),
                    value: "",
                    showsDivider: false
                )
            }
            .padding(.top, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                Task { await AuthenticationViewModel.shared.signOut() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_SettingsLogout")
        }
    }

    /// 頁首走共用的 `App2PageHeader`（設計 frame-12／20／21 是同一個構造），
    /// 不在這裡留第二份返回鍵樣式。
    private var header: some View {
        App2PageHeader(
            title: L10n.App2.Settings.title.localized,
            titleSize: 22,
            onBack: onClose,
            backIdentifier: "App2_SettingsClose"
        ) { EmptyView() }
    }

    // MARK: - Profile

    private func profileCard(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        HStack(spacing: 14) {
            App2Avatar(initial: viewModel.avatarInitial, size: 56, showsRing: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayName ?? "—")
                    .font(.system(size: 18, weight: .black))
                    .tracking(0.3)
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // email 拿不到就不渲染這一行 —— 不用 `—` 佔位，更不用樣本 email。
                if let email = sourced.value.accountEmail {
                    Text(email)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.chevron)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .app2CardSurface(cornerRadius: App2Theme.listCardCornerRadius)
        .accessibilityIdentifier("App2_SettingsAccountCard")
    }

    // MARK: - 訂閱

    private func subscriptionSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.subscriptionSection.localized)
                .padding(.top, 20)

            App2AccentCard(strength: 0.13, padding: 16, spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(App2Theme.accentBlue)
                    Text(verbatim: "Paceriz Premium")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 6)
                    if let label = sourced.value.subscriptionLabel {
                        App2Pill(text: label)
                    }
                }

                HStack(spacing: 10) {
                    subscriptionButton(
                        title: L10n.App2.Settings.manageSubscription.localized,
                        filled: false
                    )
                    subscriptionButton(
                        title: L10n.App2.Settings.viewPlans.localized,
                        filled: true
                    )
                }
                .padding(.top, 14)

                Text(L10n.App2.Settings.redeemCode.localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 13)
            }
        }
    }

    private func subscriptionButton(title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(filled ? .white : App2Theme.accentBlueDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? App2Theme.accentBlue : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        filled ? Color.clear : App2Theme.accentBlue.opacity(0.32),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - 訓練設定

    private func trainingSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let snapshot = sourced.value
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                App2SectionCaption(text: L10n.App2.Settings.trainingSection.localized)
                App2StubBadge(origin: sourced.origin)
            }
            .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "bolt.horizontal",
                    title: L10n.App2.Settings.weeklyDistance.localized,
                    value: snapshot.weeklyDistanceKm.map { String(format: "%.0f km", $0) } ?? "—",
                    monospaced: true
                )
                App2SettingsRow(
                    systemImage: "calendar",
                    title: L10n.App2.Settings.trainingDays.localized,
                    value: snapshot.trainingDays.isEmpty
                        ? "—"
                        : snapshot.trainingDays.joined(
                            separator: L10n.App2.Settings.trainingDaysSeparator.localized
                          )
                )
                App2SettingsRow(
                    systemImage: "flag.checkered",
                    title: L10n.App2.Settings.raceCountdown.localized,
                    // 天數走既有的三語格式字，不硬寫 `d`（與訂閱膠囊同一個缺陷）。
                    value: String(
                        format: NSLocalizedString("profile.subscription.days_remaining", comment: ""),
                        snapshot.raceCountdownDays
                    ),
                    monospaced: true,
                    showsDivider: false
                )
            }
        }
        .accessibilityIdentifier("App2_SettingsTrainingCard")
    }

    // MARK: - 數據來源

    private func dataSourceSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let sources = sourced.value.dataSources
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                App2SectionCaption(text: L10n.App2.Settings.dataSourceSection.localized)
                App2StubBadge(origin: sourced.origin)
            }
            .padding(.top, 20)

            App2GroupedList {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    App2SettingsRow(
                        systemImage: source.isConnected ? "applewatch" : "heart.fill",
                        iconTint: source.isConnected ? .white : App2Theme.appleHealthRed,
                        iconBackground: source.isConnected
                            ? App2Theme.sourceDarkTile
                            : App2Theme.sourceLightTile,
                        title: source.name,
                        showsDivider: index < sources.count - 1
                    ) {
                        connectionStatus(source)
                    }
                }
            }
        }
        .accessibilityIdentifier("App2_SettingsDataSourceCard")
    }

    @ViewBuilder
    private func connectionStatus(_ source: App2DataSourceStatus) -> some View {
        if source.isConnected {
            HStack(spacing: 5) {
                Circle().fill(App2Theme.accentGreenDot).frame(width: 7, height: 7)
                Text(L10n.App2.Settings.connected.localized)
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(App2Theme.accentGreenDot)
        } else {
            Text(L10n.App2.Settings.notConnected.localized)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.accentBlueDeep)
        }
    }
}
