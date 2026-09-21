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
    #if DEBUG
    case weeklyReviewDev  // 週回顧開發工具（DEBUG-only，Release build 沒有這一格）
    case planEndDev       // 計畫結束態開發工具（同上）
    #endif

    var id: String { rawValue }
}

// MARK: - App2SettingsSupportEntry
/// 設定頁的「聯絡 Paceriz／社群」列（T-0432）。
///
/// 目的地是 **1.4 既有的 `FeedbackReportView`** —— Threads、Facebook 與問題回報表單
/// 都在那一頁裡，2.0 不另做一份社群入口，也不複製連結。設計稿 frame-21 沒畫這一列，
/// 以 T-0432 與 `STATUS/decisions.md` 2026-09-05 為準。
///
/// 標題 key、a11y id 與圖示抽在這裡，讓 view 與測試引用同一份；
/// 「列還在、點下去去哪」由 `App2SettingsSupportEntryTests` 讀本檔的接線鎖住。
enum App2SettingsSupportEntry {
    static let systemImage = "bubble.left.and.bubble.right"
    static let titleKey = L10n.Feedback.settingsEntry
    static let identifier = "App2_SettingsFeedbackEntry"
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
    @ObservedObject private var appearanceStore = App2AppearanceStore.shared
    @State private var destination: App2SettingsDestination?
    /// 登出前的二次確認（破壞性樣式）。
    @State private var isConfirmingLogout = false
    /// 「聯絡 Paceriz／社群」→ 1.4 的 `FeedbackReportView`。它自帶 `NavigationView`
    /// 與自己的關閉鈕，1.4 也是用 sheet 開的，這裡沿用同一種呈現而不是推進導航堆疊。
    @State private var isPresentingFeedback = false
    /// 「重設目標」是唯一**不能**走 push 的子頁：`App2OnboardingContainerView` 自己帶一個
    /// `NavigationStack`，推進設定頁這個堆疊就成了巢狀，內層只認第一次 push——
    /// 目標賽事按繼續後 `path` 已是 `[raceSetup, heartRate]`，畫面卻停在原頁（T-0670）。
    /// 其餘三個 re-onboarding 入口（首頁、課表、計畫總覽）本來就是 cover，這裡與它們一致。
    @State private var isPresentingReonboarding = false

    // MARK: - 訂閱卡的第二行（2026-08-27 晚走查裁決（h））
    //
    // **不自建第二條訂閱資料路徑**：狀態走 `SubscriptionStateManager.shared`
    // （設定 VM 的訂閱狀態字也是它），在地化價格走 `PaywallViewModel.displayPackages`
    // ——與「方案與訂閱」頁（`App2PlansView`）同一組出口。

    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    /// 訂閱卡「兌換優惠碼」（設計稿）的兌換流程 —— 與方案頁同一條。
    @State private var redemptionMessage: String?
    @State private var otherStoreMessage: String?
    private let redemptionCoordinator = OfferRedemptionCoordinator()
    @StateObject private var paywallViewModel = PaywallViewModel(trigger: .settingsTier)

    private var subscriptionStatus: SubscriptionStatusEntity? { subscriptionState.currentStatus }

    /// 續訂中＝這一卡只留「管理訂閱」一顆鈕（設計稿）。其餘狀態維持原本兩顆。
    private var isRenewing: Bool {
        switch subscriptionStatus?.status {
        case .active, .gracePeriod: return true
        default: return false
        }
    }

    /// `2026-09-15`。沒有到期日就沒有這一段（不畫空字串）。
    private var nextRenewalDate: String? {
        guard isRenewing, let timestamp = subscriptionStatus?.expiresAt else { return nil }
        return DateFormatterHelper.formatSubscriptionExpiryDate(
            Date(timeIntervalSince1970: timestamp)
        )
    }

    /// `NT$1,790/年` —— RevenueCat 的在地化字串已經帶週期，不自己補。
    /// 還沒載到 offerings 就沒有這一段（不填樣本價）。
    private var renewalPrice: String? {
        paywallViewModel.displayPackages
            .first { $0.package.period == .yearly }?
            .displayPrice
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Paceriz v\(short) (\(build))"
    }

    var body: some View {
        // header 釘在捲動區**之外**（8/28 盤點 V7）。它原本是 `ScrollView` 的第一個子項，
        // 於是捲起來之後整頁的卡片會從狀態列底下穿過去——時間與電量疊在訂閱卡上。
        // 這一頁是二層頁，其餘二層頁（指標詳情、訓練詳情）本來就是「固定 header ＋
        // 捲動內容」，設定頁是唯一的例外。
        // **子頁走 push（T-0388 試點）**：`NavigationStack` ＋ `navigationDestination`，
        // 這樣才有邊緣滑動返回。先前一律 `fullScreenCover` 的理由（巢狀 sheet 不進
        // a11y tree）2026-09-02 在乾淨模擬器上證實不成立，而 cover 沒有返回手勢。
        // 系統 navigation bar 全程隱藏：每一頁都有自己的 App2 header。
        NavigationStack {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 4)
                .padding(.bottom, 16)

            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
            .padding(.bottom, 40)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .onAppear { viewModel.loadIfNeeded() }
        // 訂閱卡第二行的價格要在地化字串，來源同「方案與訂閱」頁。
        .task { await paywallViewModel.loadOfferings() }
        .navigationDestination(item: $destination) { destination in
            // `onClose` 仍是把 `destination` 設回 nil —— 綁定回 nil 即 pop，
            // 子頁的關閉語意不用重寫。
            subpage(destination)
                .toolbar(.hidden, for: .navigationBar)
        }
        .toolbar(.hidden, for: .navigationBar)
        // 隱藏 nav bar 會讓 UIKit 一併停掉邊緣滑回手勢；只把這一個堆疊的 delegate 接回來。
        .background(App2InteractivePopGesture().frame(width: 0, height: 0))
        // 設定頁是 `fullScreenCover`，自己一個 hosting controller：`App2RootView` 掛的
        // `preferredColorScheme` 只在 present 當下傳一次，present 之後改的偏好進不來
        // ——切成淺色要退回首頁才生效（2026-09-02 實機回報）。這裡再宣告一次，
        // 讀的是同一個 `App2AppearanceStore.shared`，不是第二份偏好。
        .preferredColorScheme(appearanceStore.preference.colorScheme)
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
        .sheet(isPresented: $isPresentingFeedback) {
            FeedbackReportView(userEmail: viewModel.snapshot?.value.accountEmail ?? "")
        }
        .fullScreenCover(isPresented: $isPresentingReonboarding) {
            // 「重設目標」走 2.0 版面的 onboarding，底下仍是 `OnboardingCoordinator`。
            App2OnboardingContainerView(
                isReonboarding: true,
                onFinished: { isPresentingReonboarding = false },
                onCancel: { isPresentingReonboarding = false }
            )
        }
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
            App2ClimateSettingsView(onClose: dismiss)
        #if DEBUG
        case .weeklyReviewDev:
            App2WeeklyReviewDevView(onClose: dismiss)
        case .planEndDev:
            App2PlanEndDevView(onClose: dismiss)
        #endif
        }
    }

    /// 頁首走共用的 `App2PageHeader`（設計 frame-12／20／21 是同一個構造）。
    private var header: some View {
        App2PageHeader(
            // 入口叫「個人資料」（首頁「…」menu），頁首要跟入口同名
            // （2026-08-27 走查：點「個人資料」進來標題卻是「設定」）。
            title: L10n.Profile.title.localized,
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

                // 第二行「下次續訂 2026-09-15 · NT$1,790/年」（設計稿）。
                // 日期與價格各自可缺：兩段都拿不到就整行不出現（不畫空字串）。
                renewalLine

                // 兩顆鈕**恆在**（設計稿：管理訂閱＝白底藍框、查看方案＝藍底），
                // 2026-08-27 走查退掉「續訂中只留一顆」的舊裁定 —— 卡片要跟設計稿一致。
                HStack(spacing: 10) {
                    subscriptionButton(
                        title: L10n.App2.Settings.manageSubscription.localized,
                        filled: false,
                        identifier: "App2_SettingsManageSubscription"
                    ) {
                        OtherStoreManagement.run(status: subscriptionStatus, message: $otherStoreMessage) {
                            guard let url = URL(string: "https://apps.apple.com/account/subscriptions")
                            else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                    .otherStoreManagementDisabledUntilReady()
                    subscriptionButton(
                        title: L10n.App2.Settings.viewPlans.localized,
                        filled: true,
                        identifier: "App2_SettingsViewPlans"
                    ) {
                        destination = .plans
                    }
                }
                .padding(.top, 14)

                // 「兌換優惠碼」置中連結（設計稿）。兌換流程與方案頁同一條
                // （`OfferRedemptionCoordinator` → Apple 系統 sheet）。
                Text(L10n.App2.Settings.redeemCode.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 13)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        OtherStoreManagement.run(status: subscriptionStatus, message: $otherStoreMessage) {
                            Task {
                                let result = await redemptionCoordinator.redeem(entryPoint: .profile)
                                redemptionMessage = App2OfferRedemptionMessage.text(for: result)
                            }
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_SettingsRedeemCode")
                    .otherStoreManagementDisabledUntilReady()
            }
        }
        .alert(
            NSLocalizedString("profile.subscription.redeem_alert_title", comment: "Offer Code"),
            isPresented: Binding(
                get: { redemptionMessage != nil },
                set: { if !$0 { redemptionMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { redemptionMessage = nil }
        } message: {
            Text(redemptionMessage ?? "")
        }
        .otherStoreManagementAlert(message: $otherStoreMessage)
    }

    /// `下次續訂 2026-09-15 · NT$1,790/年`。日期粗體等寬（設計稿），價格接在中點後。
    @ViewBuilder
    private var renewalLine: some View {
        if nextRenewalDate != nil || (isRenewing && renewalPrice != nil) {
            HStack(spacing: 5) {
                if let nextRenewalDate {
                    Text(L10n.App2.Settings.nextRenewal.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                    Text(nextRenewalDate)
                        .font(.app2Mono(13, weight: .heavy))
                        .foregroundStyle(App2Theme.inkSecondary)
                }
                if let renewalPrice, isRenewing {
                    if nextRenewalDate != nil {
                        Text(verbatim: "·")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkFaint)
                    }
                    Text(renewalPrice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.top, 6)
            .accessibilityIdentifier("App2_SettingsRenewalLine")
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
                    .fill(filled ? App2Theme.accentBlue : App2Theme.cardBackground)
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

    /// **一列**，不是每個來源一列（2026-08-27 走查：兩列點進去都是同一頁，
    /// 沒必要擺成兩個項目）。列上顯示**目前連接中的來源**；一個都沒連＝「連接」。
    private func dataSourceSection(_ sourced: App2Sourced<App2SettingsSnapshot>) -> some View {
        let connected = sourced.value.dataSources.first { $0.isConnected }
        let isAppleHealth = connected?.name == "Apple Health"
        return VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.dataSourceSection.localized)
                .padding(.top, 20)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: isAppleHealth ? "heart.fill" : "applewatch",
                    iconTint: isAppleHealth ? App2Theme.appleHealthRed : .white,
                    iconBackground: isAppleHealth
                        ? App2Theme.sourceLightTile
                        : App2Theme.sourceDarkTile,
                    title: connected?.name ?? L10n.App2.Settings.dataSourceSection.localized,
                    showsDivider: false
                ) {
                    if let connected {
                        connectionStatus(connected)
                    } else {
                        Text(NSLocalizedString("datasource.connect", comment: "Connect"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(App2Theme.accentBlueDeep)
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
                    systemImage: "circle.lefthalf.filled",
                    title: L10n.App2.Settings.appearance.localized,
                    value: appearanceStore.preference.displayName
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .system }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsAppearanceRow")

                App2SettingsRow(
                    systemImage: "clock",
                    title: NSLocalizedString("settings.timezone", comment: ""),
                    value: timezoneSummary
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .system }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsTimezoneRow")

                // 英制／公制切換住在「系統」子頁，但首層要有一列讓人找得到
                // （2026-08-27 走查：「沒看到英制/公制的轉換設定」）。
                App2SettingsRow(
                    systemImage: "ruler",
                    title: L10n.App2.Settings.unitSection.localized,
                    value: UnitManager.shared.currentUnitSystem.displayName
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .system }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsUnitRow")

                App2SettingsRow(
                    systemImage: "thermometer.sun",
                    title: L10n.Performance.heatAdaptation.localized,
                    value: ""
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .climate }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsClimateRow")

                // 「聯絡 Paceriz／社群」——1.4 有、2.0 一路到發表前都沒有的入口（T-0432）。
                App2SettingsRow(
                    systemImage: App2SettingsSupportEntry.systemImage,
                    title: App2SettingsSupportEntry.titleKey.localized,
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { isPresentingFeedback = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(App2SettingsSupportEntry.identifier)
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
                .onTapGesture { isPresentingReonboarding = true }
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
                    value: ""
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .weeklyReviewDev }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsWeeklyReviewDev")

                App2SettingsRow(
                    systemImage: "flag.checkered",
                    title: "Plan End Dev Tools",
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { destination = .planEndDev }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_SettingsPlanEndDev")
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
