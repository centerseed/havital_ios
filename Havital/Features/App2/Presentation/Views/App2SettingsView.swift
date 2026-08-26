import SwiftUI

// MARK: - App2SettingsDestination
/// 設定首頁能推出去的子頁（設計 frame-22 ~ frame-29）。
enum App2SettingsDestination: String, Identifiable {
    case plans          // frame-22
    case training       // frame-23
    case dataSource     // frame-24／25
    case heartRate      // frame-26
    case paceZones      // frame-27
    case system         // frame-28
    case deleteAccount  // frame-29
    case climate        // 高溫適應（1.4 既有頁）
    case reonboarding   // 重設目標（既有 onboarding 流程）
    #if DEBUG
    case weeklyReviewDev  // 週回顧開發工具（DEBUG-only，Release build 沒有這一格）
    #endif

    var id: String { rawValue }
}

// MARK: - App2SettingsView
/// 2.0 設定頁 —— 設計 **frame-21「設定 · 首頁」**（語意見
/// `DESIGN-app2-decision-chain-api.md` §3.9a）。
///
/// **不是 tab**：入口是首頁右上「…」menu 的「個人資料」（2026-08-25 裁決），
/// 左上是返回鍵。
///
/// 版面（照 dc.html「設定 · 首頁」逐段）：profile 卡 → 訂閱 → 訓練設定 →
/// 數據來源 → 生理指標 → 系統 → 帳戶 → 版本 ＋ 刪除帳戶。
/// 每一列都推到對應子頁，子頁的讀寫全部落在 1.4 既有出口（見各子頁檔首）。
struct App2SettingsView: View {

    let onClose: () -> Void

    @ObservedObject var viewModel: App2SettingsViewModel
    @State private var destination: App2SettingsDestination?
    /// 登出前的二次確認（破壞性樣式）。
    @State private var isConfirmingLogout = false

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Paceriz v\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 16)

                if let sourced = viewModel.snapshot {
                    profileCard(sourced)
                    subscriptionSection(sourced)
                    trainingSection(sourced)
                    dataSourceSection(sourced)
                    physiologySection
                    systemSection
                    accountSection
                    #if DEBUG
                    developerSection
                    #endif
                    footer
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .onAppear { viewModel.loadIfNeeded() }
        // 子頁一律 `fullScreenCover`：這一頁自己就開在 fullScreenCover 裡，
        // 巢狀 sheet 不會進 accessibility tree（repo 既有坑）。
        .fullScreenCover(item: $destination) { destination in
            subpage(destination)
        }
        .alert(
            NSLocalizedString("auth.logout_title", comment: "Log out"),
            isPresented: $isConfirmingLogout
        ) {
            Button(NSLocalizedString("common.logout", comment: "Log out"), role: .destructive) {
                Task { await viewModel.signOut() }
            }
            .accessibilityIdentifier("App2_SettingsLogoutConfirm")
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
                .accessibilityIdentifier("App2_SettingsLogoutCancel")
        } message: {
            Text(NSLocalizedString("auth.logout_confirm", comment: "Are you sure you want to log out?"))
        }
    }

    @ViewBuilder
    private func subpage(_ destination: App2SettingsDestination) -> some View {
        let dismiss = { self.destination = nil }
        switch destination {
        case .plans:
            App2PlansView(onClose: dismiss)
        case .training:
            App2TrainingSettingsView(onClose: dismiss, viewModel: viewModel)
        case .dataSource:
            App2DataSourceSettingsView(onClose: dismiss, viewModel: viewModel)
        case .heartRate:
            App2HeartRateZoneSettingsView(onClose: dismiss, viewModel: viewModel)
        case .paceZones:
            App2PaceZoneSettingsView(onClose: dismiss, viewModel: viewModel)
        case .system:
            App2SystemSettingsView(onClose: dismiss, viewModel: viewModel)
        case .deleteAccount:
            App2DeleteAccountView(onClose: dismiss, viewModel: viewModel)
        case .climate:
            // 1.4 既有頁，不在 2.0 重做一份。
            ClimateSettingsView()
        case .reonboarding:
            // 「重設目標」走 2.0 版面的 onboarding，底下仍是 `OnboardingCoordinator`。
            App2OnboardingContainerView(isReonboarding: true, onFinished: dismiss)
        #if DEBUG
        case .weeklyReviewDev:
            App2WeeklyReviewDevView(onClose: dismiss)
        #endif
        }
    }

    /// 頁首走共用的 `App2PageHeader`（設計 frame-12／20／21 是同一個構造）。
    private var header: some View {
        App2PageHeader(
            title: L10n.App2.Settings.title.localized,
            titleSize: 22,
            onBack: onClose,
            backIdentifier: "App2_SettingsClose",
            titleIdentifier: "App2_SettingsView"
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
                        filled: false,
                        identifier: "App2_SettingsManageSubscription"
                    ) {
                        guard let url = URL(string: "https://apps.apple.com/account/subscriptions")
                        else { return }
                        UIApplication.shared.open(url)
                    }
                    subscriptionButton(
                        title: L10n.App2.Settings.viewPlans.localized,
                        filled: true,
                        identifier: "App2_SettingsViewPlans"
                    ) {
                        destination = .plans
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private func subscriptionButton(
        title: String,
        filled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
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
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
    }

    // MARK: - 訓練設定

    private func trainingSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let snapshot = sourced.value
        return VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.trainingSection.localized)
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
                    // 天數走既有的三語格式字，不硬寫 `d`。
                    value: String(
                        format: NSLocalizedString("profile.race_countdown.days_value", comment: ""),
                        snapshot.raceCountdownDays
                    ),
                    monospaced: true,
                    showsDivider: false
                )
            }
            // 三列共用同一個目的地：設計 frame-23 就是把週跑量與訓練日放在同一頁。
            // 賽事倒數卡的偏好目前只有 1.4 設定頁能改（`@AppStorage`），
            // 2.0 這一列先只顯示現值，列在票面缺口。
            .contentShape(Rectangle())
            .onTapGesture { destination = .training }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_SettingsTrainingCard")
        }
    }

    // MARK: - 數據來源

    private func dataSourceSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let sources = sourced.value.dataSources
        return VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.dataSourceSection.localized)
                .padding(.top, 20)

            App2GroupedList {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    App2SettingsRow(
                        systemImage: source.name == "Apple Health" ? "heart.fill" : "applewatch",
                        iconTint: source.name == "Apple Health" ? App2Theme.appleHealthRed : .white,
                        iconBackground: source.name == "Apple Health"
                            ? App2Theme.sourceLightTile
                            : App2Theme.sourceDarkTile,
                        title: source.name,
                        showsDivider: index < sources.count - 1
                    ) {
                        connectionStatus(source)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { destination = .dataSource }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_SettingsDataSourceCard")
        }
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
            Text(NSLocalizedString("datasource.connect", comment: "Connect"))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.accentBlueDeep)
        }
    }

    // MARK: - 生理指標

    private var physiologySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: NSLocalizedString("profile.physiology", comment: ""))
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "heart.fill",
                    iconTint: App2Theme.appleHealthRed,
                    iconBackground: App2Theme.appleHealthRed.opacity(0.1),
                    title: NSLocalizedString("training.heart_rate_zone", comment: ""),
                    value: heartRateSummary,
                    monospaced: true
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .heartRate }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsHeartRateRow")

                App2SettingsRow(
                    systemImage: "timer",
                    title: NSLocalizedString("profile.pace_zones", comment: ""),
                    value: paceSummary,
                    monospaced: true,
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .paceZones }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsPaceZoneRow")
            }
        }
    }

    private var heartRateSummary: String {
        guard let max = viewModel.maxHeartRate, let rest = viewModel.restingHeartRate,
              max > 0, rest > 0 else { return "—" }
        return "\(rest)–\(max) bpm"
    }

    private var paceSummary: String {
        viewModel.currentVDOT > 0 ? String(format: "VDOT %.1f", viewModel.currentVDOT) : "—"
    }

    // MARK: - 系統

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.systemSection.localized)
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "globe",
                    title: NSLocalizedString("settings.language", comment: ""),
                    value: LanguageManager.shared.currentLanguage.displayName
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .system }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsLanguageRow")

                App2SettingsRow(
                    systemImage: "clock",
                    title: NSLocalizedString("settings.timezone", comment: ""),
                    value: timezoneSummary
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .system }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsTimezoneRow")

                App2SettingsRow(
                    systemImage: "thermometer.sun",
                    title: L10n.Performance.heatAdaptation.localized,
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .climate }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsClimateRow")
            }
        }
    }

    private var timezoneSummary: String {
        let identifier = viewModel.profile.timezonePreference ?? TimezoneOption.getDeviceTimezoneId()
        return "\(TimezoneOption.getDisplayName(for: identifier)) \(TimezoneOption.getCurrentOffset(for: identifier))"
    }

    // MARK: - 帳戶

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.accountSection.localized)
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "arrow.clockwise",
                    title: L10n.App2.PlanOverview.resetGoal.localized,
                    value: ""
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .reonboarding }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsResetGoalRace")

                App2SettingsRow(
                    systemImage: "rectangle.portrait.and.arrow.right",
                    iconTint: App2Theme.accentRed,
                    iconBackground: App2Theme.accentRed.opacity(0.1),
                    title: NSLocalizedString("common.logout", comment: ""),
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                // 登出是破壞性動作（回到登入頁、本機 session 清掉），設計 §30.8 那一列
                // 沒有 chevron 也不代表按一下就該直接執行 —— 先確認。
                .onTapGesture { isConfirmingLogout = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsLogout")
            }
        }
    }

    // MARK: - 版本 ＋ 刪除帳戶

    /// 開發者區。**整段在 `#if DEBUG` 內，Release build 連這一列都不存在。**
    /// 內容見 `Features/App2/Debug/App2WeeklyReviewDevView.swift`。
    #if DEBUG
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Developer (DEBUG)")
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "wrench.and.screwdriver",
                    title: "Weekly Review Dev Tools",
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .weeklyReviewDev }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsWeeklyReviewDev")
            }
        }
    }
    #endif

    private var footer: some View {
        VStack(spacing: 12) {
            Text(appVersion)
                .font(.app2Mono(12, weight: .bold))
                .foregroundStyle(App2Theme.inkFaint)

            Text(NSLocalizedString("settings.delete_account", comment: ""))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.accentRed)
                .contentShape(Rectangle())
                .onTapGesture { destination = .deleteAccount }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsDeleteAccount")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}
