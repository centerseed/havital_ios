import SwiftUI
import FirebaseAuth
import HealthKit

struct UserProfileView: View {
    @Binding var isShowing: Bool
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @StateObject private var garminManager = GarminManager.shared
    @StateObject private var stravaManager = StravaManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager
    @Environment(\.dismiss) private var dismiss
    @State private var showZoneEditor = false
    @State private var showWeeklyDistanceEditor = false  // 新增週跑量編輯器狀態
    @State private var currentWeekDistance: Int = 0  // 新增當前週跑量
    @State private var weeklyDistance: Int = 0
    @State private var showTrainingDaysEditor = false
    // Note: reset goal confirmation uses UIKit UIAlertController (see showResetGoalAlert)
    // because SwiftUI .alert button actions don't fire in iOS 26 sheet context
    @State private var showDeleteAccountConfirmation = false  // 刪除帳戶確認對話框狀態
    @State private var isDeletingAccount = false  // 刪除帳戶加載狀態
    @State private var showDataSourceSwitchConfirmation = false  // 數據源切換確認對話框
    @State private var pendingDataSourceType: DataSourceType?  // 待切換的數據源類型
    // 保留 DataSyncView 相關狀態變量供未來使用
    @State private var showDataSyncView = false  // 顯示數據同步畫面（已停用）
    @State private var syncDataSource: DataSourceType?  // 需要同步的數據源（已停用）
    @State private var showGarminAlreadyBoundAlert = false
    @State private var showStravaAlreadyBoundAlert = false
    @State private var showLanguageSettings = false
    @State private var showTimezoneSettings = false
    @State private var showClimateSettings = false
    @State private var showDebugFailedWorkouts = false
    @State private var showIAPTestConsole = false
    @State private var showPaceZoneDetail = false
    @State private var paywallTrigger: PaywallTrigger?
    @State private var offerRedemptionMessage: String?
    private let offerRedemptionCoordinator = OfferRedemptionCoordinator()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var body: some View {
        List {
            // Group 1: 帳戶 — 用戶每次進來都看的
            profileSection
            if subscriptionState.isEnforcementEnabled {
                subscriptionSection
            }

            // Group 2: 訓練設定 — 偶爾調整
            trainingSettingsSection

            // Group 3: 數據來源 — 設定一次很少改
            dataSourceSection

            // Group 4: 生理指標 — 參考用，收成導航入口
            physiologySection

            // Group 5: 系統設定 + 帳戶操作
            settingsSection
            accountActionsSection

            #if DEBUG
            // Group 6: 開發者工具 — 收成一行入口
            debugSection
            #endif
        }
        .accessibilityIdentifier("Profile_Screen")
        .navigationTitle(NSLocalizedString("profile.title", comment: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common.done", comment: "Done")) {
                    isShowing = false
                }
                .accessibilityIdentifier("Profile_DoneButton")
            }
        }
        // 保留 DataSyncView sheet 供未來使用（目前已停用）
        .sheet(isPresented: $showDataSyncView) {
            if let syncDataSource = syncDataSource {
                NavigationStack {
                    DataSyncView(dataSource: syncDataSource)
                }
            }
        }
        .refreshable {
            viewModel.fetchUserProfile()
            viewModel.loadVDOT()
            await TrackedTask("UserProfileView: loadHeartRateZonesOnRefresh") {
                await viewModel.loadHeartRateZones()
            }.value
        }
        .task {
            viewModel.loadVDOT()
            viewModel.fetchUserProfile()
            await TrackedTask("UserProfileView: loadHeartRateZonesOnAppear") {
                await viewModel.loadHeartRateZones()
            }.value
        }
        .sheet(isPresented: $showZoneEditor) {
            NavigationStack {
                HeartRateZoneInfoView()
            }
        }
        // 新增週跑量編輯器
        .sheet(isPresented: $showWeeklyDistanceEditor) {
            WeeklyDistanceEditorView(
                distance: $weeklyDistance,
                onSave: { newDistance in
                    Task {
                        await viewModel.updateWeeklyDistance(distance: newDistance)
                    }
                }
            )
        }
        // 編輯訓練日編輯器
        .alert(NSLocalizedString("settings.delete_account", comment: "Delete Account"), isPresented: $showDeleteAccountConfirmation) {
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
            Button(NSLocalizedString("common.delete", comment: "Delete"), role: .destructive) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await viewModel.deleteAccount()
                        // 刪除成功後會自動登出並導航到登入畫面
                    } catch {
                        print("刪除帳戶失敗: \(error.localizedDescription)")
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("settings.delete_confirm", comment: "Are you sure you want to delete your account? This action cannot be undone."))
        }
        .sheet(isPresented: $showTrainingDaysEditor) {
            if let ud = viewModel.userData {
                EditTrainingDaysView(
                    initialWeekdays: Set(ud.preferWeekDays ?? []),
                    initialLongRunDay: ud.preferWeekDaysLongrun?.first ?? 6
                ) {
                    viewModel.fetchUserProfile()
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showLanguageSettings) {
            LanguageSettingsView()
        }
        .sheet(isPresented: $showTimezoneSettings) {
            TimezoneSettingsView(currentTimezone: viewModel.timezonePreference)
        }
        .sheet(isPresented: $showClimateSettings) {
            ClimateSettingsView()
        }
        .sheet(isPresented: $showPaceZoneDetail) {
            NavigationStack {
                List {
                    paceZoneSection
                }
                .navigationTitle(NSLocalizedString("profile.pace_zones", comment: "Pace Zones"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("common.done", comment: "Done")) {
                            showPaceZoneDetail = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDebugFailedWorkouts) {
            DebugFailedWorkoutsView()
        }
        .onChange(of: paywallTrigger) { _, trigger in
            guard let trigger else { return }
            _ = InterruptCoordinator.shared.enqueue(.paywall(trigger))
            paywallTrigger = nil
        }
        .alert(
            NSLocalizedString("profile.subscription.redeem_alert_title", comment: "Offer Code"),
            isPresented: Binding(
                get: { offerRedemptionMessage != nil },
                set: { if !$0 { offerRedemptionMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) {
                offerRedemptionMessage = nil
            }
        } message: {
            Text(offerRedemptionMessage ?? "")
        }
        #if DEBUG
        .sheet(isPresented: $showIAPTestConsole) {
            IAPTestConsoleView()
        }
        #endif
        .onReceive(garminManager.$garminAlreadyBoundMessage) { msg in
            showGarminAlreadyBoundAlert = (msg != nil)
        }
        .alert(L10n.ProfileView.garminAlreadyBound.localized, isPresented: $showGarminAlreadyBoundAlert) {
            Button(L10n.ProfileView.ok.localized, role: .cancel) {
                garminManager.garminAlreadyBoundMessage = nil
            }
        } message: {
            Text(garminManager.garminAlreadyBoundMessage ?? L10n.ProfileView.garminAlreadyBoundMessage.localized)
        }
        .onReceive(stravaManager.$stravaAlreadyBoundMessage) { msg in
            showStravaAlreadyBoundAlert = (msg != nil)
        }
        .alert(L10n.ProfileView.stravaAlreadyBound.localized, isPresented: $showStravaAlreadyBoundAlert) {
            Button(L10n.ProfileView.ok.localized, role: .cancel) {
                stravaManager.stravaAlreadyBoundMessage = nil
            }
        } message: {
            Text(stravaManager.stravaAlreadyBoundMessage ?? L10n.ProfileView.stravaAlreadyBoundMessage.localized)
        }
    }
    
    // 使用者頭像與名稱標頭
    @ViewBuilder
    private func profileHeader(_ userData: User) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if let urlString = userData.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFill().opacity(0.3)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(userData.displayName ?? NSLocalizedString("profile.name", comment: "Name"))
                    .font(AppFont.title2()).bold()
                
                // 檢查是否為 Apple 登入且 email 為空或匿名
                if let providerData = Auth.auth().currentUser?.providerData.first,
                   providerData.providerID == "apple.com" &&
                   (userData.email?.isEmpty == true || userData.email?.contains("privaterelay.appleid.com") == true) {
                    Text(L10n.ProfileView.appleUser.localized)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                } else {
                    Text(userData.email ?? Auth.auth().currentUser?.email ?? "")
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical)
    }

    // MARK: - Section Computed Properties

    @ViewBuilder
    private var profileSection: some View {
        Section {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView(NSLocalizedString("common.loading", comment: "Loading..."))
                    Spacer()
                }
            } else if let userData = viewModel.userData {
                profileHeader(userData)
            } else if let error = viewModel.error {
                errorView(error)
            }
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            // 方案名稱
            HStack {
                Label(NSLocalizedString("profile.subscription.plan", comment: "Plan"), systemImage: "crown")
                Spacer()
                Text(subscriptionPlanDisplayName)
                    .foregroundColor(.secondary)
            }

            if let status = subscriptionState.currentStatus {
                // 狀態輔助資訊（依 Spec UI 矩陣）
                switch status.status {
                case .trial:
                    if let endAt = status.trialEndAt {
                        subscriptionDateRow(
                            title: NSLocalizedString("profile.subscription.trial_ends", comment: "Trial ends"),
                            systemImage: "clock",
                            expiresAt: endAt,
                            color: .orange
                        )
                    }
                    let days = status.trialRemainingDays ?? status.daysRemaining
                    if days > 0 {
                        Label(
                            String(format: NSLocalizedString("profile.subscription.trial_remaining_days", comment: ""), days),
                            systemImage: "hourglass"
                        )
                        .foregroundColor(.orange)
                    }
                    // expires_at 非 null = 試用期間已購買，訂閱待生效
                    if status.expiresAt != nil {
                        Label(
                            NSLocalizedString("profile.subscription.trial_purchased_note", comment: "Subscribed, activates after trial"),
                            systemImage: "checkmark.seal.fill"
                        )
                        .foregroundColor(.green)
                        .accessibilityIdentifier("Trial_PurchasedNote")
                    }

                case .active:
                    subscriptionDateRow(
                        title: NSLocalizedString("profile.subscription.renews_on", comment: "Renews on"),
                        systemImage: "calendar.badge.clock",
                        expiresAt: status.expiresAt,
                        color: .secondary
                    )

                case .gracePeriod:
                    subscriptionDateRow(
                        title: NSLocalizedString("profile.subscription.renews_on", comment: "Renews on"),
                        systemImage: "calendar.badge.clock",
                        expiresAt: status.expiresAt,
                        color: .secondary
                    )
                    Label(NSLocalizedString("profile.subscription.grace_period", comment: "Billing processing, service unaffected"), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                        .accessibilityIdentifier("GracePeriod_Warning")

                case .cancelled:
                    subscriptionDateRow(
                        title: NSLocalizedString("profile.subscription.valid_until", comment: "Service valid until"),
                        systemImage: "calendar.badge.clock",
                        expiresAt: status.expiresAt,
                        color: .orange
                    )

                case .expired:
                    subscriptionDateRow(
                        title: NSLocalizedString("profile.subscription.expires", comment: "Expires"),
                        systemImage: "calendar.badge.exclamationmark",
                        expiresAt: status.expiresAt,
                        color: .red
                    )

                case .none:
                    EmptyView()
                }

                // billing_issue 警告（gracePeriod 以外的 billing issue）
                if status.billingIssue && status.status != .gracePeriod {
                    Label(NSLocalizedString("profile.subscription.billing_issue", comment: "Billing Issue"), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .accessibilityIdentifier("BillingIssue_Warning")
                }
            }

            // 主要按鈕
            subscriptionPrimaryAction

            Button {
                redeemOfferCode(from: .profile)
            } label: {
                Label(
                    NSLocalizedString("profile.subscription.redeem_offer_code", comment: "Redeem Offer Code"),
                    systemImage: "ticket"
                )
                .foregroundColor(.secondary)
            }
            .accessibilityIdentifier("Subscription_RedeemOfferCodeButton")

            // 次要按鈕：管理訂閱（跳轉 Apple）
            if shouldShowManageSubscription {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(NSLocalizedString("profile.subscription.manage", comment: "Manage Subscription"), systemImage: "gear")
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier("Subscription_ManageButton")
            }
        } header: {
            Text(NSLocalizedString("profile.subscription.section_title", comment: "Subscription"))
        }
    }

    @ViewBuilder
    private var subscriptionPrimaryAction: some View {
        let status = subscriptionState.currentStatus
        switch status?.status {
        case .trial, .some(.none), .expired, nil:
            // 升級 / 重新訂閱
            Button {
                paywallTrigger = paywallEntryTrigger
            } label: {
                Label(
                    status?.status == .expired
                        ? NSLocalizedString("profile.subscription.resubscribe", comment: "Resubscribe")
                        : NSLocalizedString("paywall.title", comment: "Upgrade"),
                    systemImage: "crown.fill"
                )
                .foregroundColor(.orange)
            }
            .accessibilityIdentifier("Subscription_UpgradeButton")

        case .active:
            // 變更方案
            Button {
                paywallTrigger = .changePlan
            } label: {
                Label(NSLocalizedString("profile.subscription.change_plan", comment: "Change Plan"), systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
            }
            .accessibilityIdentifier("Subscription_ChangePlanButton")

        case .cancelled:
            // 重新訂閱
            Button {
                paywallTrigger = .resubscribe
            } label: {
                Label(NSLocalizedString("profile.subscription.resubscribe", comment: "Resubscribe"), systemImage: "crown.fill")
                    .foregroundColor(.orange)
            }
            .accessibilityIdentifier("Subscription_ResubscribeButton")

        case .gracePeriod:
            // 管理訂閱（帳務問題，主按鈕導向 Apple）
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(NSLocalizedString("profile.subscription.manage", comment: "Manage Subscription"), systemImage: "gear")
                    .foregroundColor(.orange)
            }
            .accessibilityIdentifier("Subscription_ManageButton_Primary")
        }
    }

    @ViewBuilder
    private func subscriptionDateRow(
        title: String,
        systemImage: String,
        expiresAt: TimeInterval?,
        color: Color
    ) -> some View {
        if let expiresAt {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(DateFormatterHelper.formatSubscriptionExpiryDate(Date(timeIntervalSince1970: expiresAt)))
                    .foregroundColor(color)
            }
        }
    }

    /// 是否顯示次要的「管理訂閱」按鈕（跳轉 Apple 訂閱管理）
    private var shouldShowManageSubscription: Bool {
        guard let status = subscriptionState.currentStatus else { return false }
        switch status.status {
        case .active, .cancelled:
            // gracePeriod 的管理已在主按鈕
            return true
        case .trial, .expired, .none, .gracePeriod:
            return false
        }
    }

    private var paywallEntryTrigger: PaywallTrigger {
        guard let status = subscriptionState.currentStatus else { return .featureLocked }
        switch status.status {
        case .expired:
            return .resubscribe
        case .trial, .none, .gracePeriod:
            return .featureLocked
        case .cancelled:
            return .resubscribe
        case .active:
            return .changePlan
        }
    }

    private var subscriptionPlanDisplayName: String {
        guard let status = subscriptionState.currentStatus else {
            return NSLocalizedString("profile.subscription.free", comment: "Free")
        }
        switch status.status {
        case .active, .gracePeriod:
            switch status.planType {
            case "yearly":
                return NSLocalizedString("profile.subscription.plan.yearly", comment: "年訂閱")
            case "monthly":
                return NSLocalizedString("profile.subscription.plan.monthly", comment: "月訂閱")
            default:
                return "Paceriz Premium"
            }
        case .trial:
            return NSLocalizedString("profile.subscription.trial", comment: "Trial")
        case .cancelled:
            return NSLocalizedString("profile.subscription.cancelled", comment: "Cancelled")
        case .expired:
            return NSLocalizedString("profile.subscription.expired", comment: "Expired")
        case .none:
            return NSLocalizedString("profile.subscription.free", comment: "Free")
        }
    }

    private func redeemOfferCode(from entryPoint: OfferEntryPoint) {
        Task { @MainActor in
            let result = await offerRedemptionCoordinator.redeem(entryPoint: entryPoint)
            switch result {
            case .success:
                offerRedemptionMessage = NSLocalizedString(
                    "profile.subscription.redeem_success",
                    comment: "Offer code redeemed successfully"
                )
            case .cancelled:
                break
            case .pendingProcessing:
                offerRedemptionMessage = NSLocalizedString(
                    "paywall.offer_code_pending_processing",
                    comment: "Offer code redemption is being processed"
                )
            case .failed(let error):
                offerRedemptionMessage = error.localizedDescription
            }
        }
    }


    @ViewBuilder
    private var weeklyDistanceSection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("profile.training_info", comment: "Training Info"))) {
                HStack {
                    Label(NSLocalizedString("profile.weekly_mileage", comment: "Weekly Mileage"), systemImage: "figure.walk")
                        .foregroundColor(.blue)
                    Spacer()
                    Text({
                        let dist = UnitManager.shared.convertedDistance(Double(userData.currentWeekDistance ?? 0))
                        return "\(Int(dist)) \(UnitManager.shared.currentUnitSystem.distanceSuffix)"
                    }())
                        .fontWeight(.medium)
                }

                Button(action: {
                    currentWeekDistance = Int(userData.currentWeekDistance ?? 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        weeklyDistance = Int(userData.currentWeekDistance ?? 0)
                        showWeeklyDistanceEditor = true
                    }
                }) {
                    HStack {
                        Text(NSLocalizedString("training.edit_volume", comment: "Edit Weekly Volume"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }
            }
        }
    }

    // MARK: - Group 2: 訓練設定（週跑量 + 訓練日合併）

    @ViewBuilder
    private var trainingSettingsSection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("profile.training_info", comment: "Training Info"))) {
                // 週跑量
                HStack {
                    Label(NSLocalizedString("profile.weekly_mileage", comment: "Weekly Mileage"), systemImage: "figure.walk")
                        .foregroundColor(.blue)
                    Spacer()
                    Text({
                        let dist = UnitManager.shared.convertedDistance(Double(userData.currentWeekDistance ?? 0))
                        return "\(Int(dist)) \(UnitManager.shared.currentUnitSystem.distanceSuffix)"
                    }())
                        .fontWeight(.medium)
                }

                Button(action: {
                    currentWeekDistance = Int(userData.currentWeekDistance ?? 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        weeklyDistance = Int(userData.currentWeekDistance ?? 0)
                        showWeeklyDistanceEditor = true
                    }
                }) {
                    HStack {
                        Text(NSLocalizedString("training.edit_volume", comment: "Edit Weekly Volume"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }

                // 訓練日（摘要 + 編輯入口合併）
                Button(action: { showTrainingDaysEditor = true }) {
                    HStack {
                        Label(NSLocalizedString("onboarding.training_days", comment: "Training Days"), systemImage: "calendar")
                        Spacer()
                        Text(trainingDaysSummary(userData))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }
            }
        }
    }

    /// 訓練日摘要文字（如「週二 週四 週六」）
    private func trainingDaysSummary(_ userData: User) -> String {
        guard let days = userData.preferWeekDays, !days.isEmpty else {
            return NSLocalizedString("common.not_set", comment: "Not Set")
        }
        return days.sorted().map { viewModel.weekdayShortName(for: $0) }.joined(separator: " ")
    }

    // MARK: - Group 4: 生理指標（收成導航入口）

    @ViewBuilder
    private var physiologySection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("profile.physiology", comment: "Physiology"))) {
                // 心率區間 — 摘要行 + 點進去看詳情
                Button(action: { showZoneEditor = true }) {
                    HStack {
                        Label(NSLocalizedString("training.heart_rate_zone", comment: "HR Zone"), systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Spacer()
                        if let maxHr = userData.maxHr, let restHr = userData.relaxingHr {
                            Text("\(restHr)-\(maxHr) bpm")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }

                // 配速區間 — 摘要行
                if viewModel.currentVDOT > 0 {
                    Button(action: { showPaceZoneDetail = true }) {
                        HStack {
                            Label(NSLocalizedString("profile.pace_zones", comment: "Pace Zones"), systemImage: "timer")
                                .foregroundColor(.blue)
                            Spacer()
                            Text("VDOT \(String(format: "%.1f", viewModel.currentVDOT))")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(AppFont.caption())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Group 5: 帳戶操作（登出 + 版本 + 刪除合併）

    @ViewBuilder
    private var accountActionsSection: some View {
        Section {
            Button(action: {
                showResetGoalAlert()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(NSLocalizedString("profile.reset_goal", comment: "Reset Goal"))
                }
            }
            .accessibilityIdentifier("Profile_ResetGoalButton")

            Button(role: .destructive) {
                Task {
                    do {
                        try await viewModel.signOut()
                        dismiss()
                    } catch {
                        print("登出失敗: \(error)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(NSLocalizedString("common.logout", comment: "Log Out"))
                }
            }

            HStack {
                Spacer()
                Text(NSLocalizedString("settings.version", comment: "Version") + " \(appVersion)")
                    .font(AppFont.footnote())
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(NSLocalizedString("settings.delete_account", comment: "Delete Account"))
                    if isDeletingAccount {
                        Spacer()
                        ProgressView()
                            .padding(.leading, 8)
                    }
                }
            }
            .disabled(isDeletingAccount)
        }
    }

    #if DEBUG
    // MARK: - Group 6: 開發者工具（收成一行）

    @ViewBuilder
    private var debugSection: some View {
        Section {
            NavigationLink {
                debugDetailView
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.purple)
                    Text(NSLocalizedString("userprofile.text_0", comment: "Developer Tools"))
                }
            }
        }
    }

    /// 開發者工具詳情頁
    private var debugDetailView: some View {
        List {
            developerSection
        }
        .navigationTitle("Developer Tools")
    }
    #endif

    // MARK: - Legacy sections (kept for reference, replaced by new groups)

    @ViewBuilder
    private var heartRateSection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("profile.heart_rate_info", comment: "Heart Rate Info"))) {
                HStack {
                    Label(NSLocalizedString("profile.max_hr", comment: "Max Heart Rate"), systemImage: "heart.fill")
                        .foregroundColor(.red)
                    Spacer()
                    Text(viewModel.formatHeartRate(userData.maxHr))
                        .fontWeight(.medium)
                }

                HStack {
                    Label(NSLocalizedString("profile.resting_hr", comment: "Resting Heart Rate"), systemImage: "heart")
                        .foregroundColor(.blue)
                    Spacer()
                    Text(viewModel.formatHeartRate(userData.relaxingHr))
                        .fontWeight(.medium)
                }

                Button(action: {
                    showZoneEditor = true
                }) {
                    HStack {
                        Text(NSLocalizedString("training.heart_rate_zone", comment: "HR Zone") + " " + NSLocalizedString("record.view_details", comment: "View Details"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }

                if viewModel.isLoadingZones {
                    HStack {
                        Spacer()
                        ProgressView(NSLocalizedString("common.loading", comment: "Loading..."))
                        Spacer()
                    }
                } else {
                    heartRateZonesView
                }
            }
        }
    }

    @ViewBuilder
    private var paceZoneSection: some View {
        if viewModel.currentVDOT > 0 {
            Section(header: Text(NSLocalizedString("profile.pace_zones", comment: "Pace Zones"))) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(PaceCalculator.PaceZone.allCases, id: \.self) { zone in
                        HStack {
                            Circle()
                                .fill(viewModel.paceZoneColor(for: zone))
                                .frame(width: 10, height: 10)

                            Text(zone.displayName)
                                .font(AppFont.bodySmall())

                            Spacer()

                            if let paceRange = PaceCalculator.getPaceRange(for: viewModel.paceZoneType(zone), vdot: viewModel.currentVDOT) {
                                Text("\(paceRange.min) - \(paceRange.max)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var trainingDaysSection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("onboarding.training_days", comment: "Training Days"))) {
                trainingDaysView(userData)
                Button(action: { showTrainingDaysEditor = true }) {
                    HStack {
                        Text(NSLocalizedString("training.edit_days", comment: "Edit Training Days"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.caption())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        Section(header: Text(NSLocalizedString("settings.title", comment: "Settings"))) {
            Button(action: {
                showLanguageSettings = true
            }) {
                HStack {
                    Image(systemName: "globe")
                    Text(NSLocalizedString("settings.language", comment: "Language"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(AppFont.caption())
                }
            }

            Button(action: {
                showTimezoneSettings = true
            }) {
                HStack {
                    Image(systemName: "clock")
                    Text(NSLocalizedString("settings.timezone", comment: "Timezone"))
                    Spacer()
                    if let timezone = viewModel.timezonePreference {
                        Text(TimezoneOption.getDisplayName(for: timezone))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(AppFont.caption())
                }
            }

            Button(action: {
                showClimateSettings = true
            }) {
                HStack {
                    Image(systemName: "thermometer.sun")
                    Text("熱適應")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(AppFont.caption())
                }
            }
        }
    }

    @ViewBuilder
    private var contactSection: some View {
        Section(header: Text(NSLocalizedString("profile.contact", value: "Contact", comment: "Contact"))) {
            if isChineseLanguage {
                // Facebook
                Link(destination: URL(string: "https://www.facebook.com/profile.php?id=61574822777267")!) {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundColor(.blue)
                        Text("FB 粉絲團")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
                
                // Threads
                Link(destination: URL(string: "https://www.threads.net/@paceriz_official")!) {
                    HStack {
                        Image(systemName: "at")
                            .foregroundColor(.primary)
                        Text("Threads")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Email
                Button(action: {
                    let email = "contact@paceriz.com"
                    if let url = URL(string: "mailto:\(email)") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text(NSLocalizedString("contact.contact_support", value: "Contact Support", comment: "Contact Support"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var isChineseLanguage: Bool {
        guard let lang = Bundle.main.preferredLocalizations.first else { return false }
        return lang.hasPrefix("zh")
    }

    @ViewBuilder
    private var logoutSection: some View {
        Section {
            Button(action: {
                showResetGoalAlert()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(NSLocalizedString("profile.reset_goal", comment: "Reset Goal"))
                }
            }
            .accessibilityIdentifier("Profile_ResetGoalButton")

            Button(role: .destructive) {
                Task {
                    do {
                        try await viewModel.signOut()
                        dismiss()
                    } catch {
                        print("登出失敗: \(error)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(NSLocalizedString("common.logout", comment: "Log Out"))
                }
            }
        }
    }

    @ViewBuilder
    private var appVersionSection: some View {
        Section {
            HStack {
                Spacer()
                Text(NSLocalizedString("settings.version", comment: "Version") + " \(appVersion)")
                    .font(AppFont.footnote())
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button(role: .destructive) {
                showDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(NSLocalizedString("settings.delete_account", comment: "Delete Account"))
                    if isDeletingAccount {
                        Spacer()
                        ProgressView()
                            .padding(.leading, 8)
                    }
                }
            }
            .disabled(isDeletingAccount)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        Section(header: Text(NSLocalizedString("userprofile.text_0", comment: ""))) {
            // Training Version Debug Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Training Version Debug")
                        .font(AppFont.headline())
                }

                if let userData = viewModel.userData {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("User.trainingVersion:")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(userData.trainingVersion ?? "nil (default: v1)")
                                .font(AppFont.caption())
                                .fontWeight(.bold)
                                .foregroundColor(userData.trainingVersion == "v2" ? .green : .orange)
                        }

                        Button {
                            Task {
                                let router: TrainingVersionRouter = DependencyContainer.shared.resolve()
                                let version = await router.getTrainingVersion()
                                let isV2 = await router.isV2User()
                                print("🔍 [Debug] TrainingVersionRouter Results:")
                                print("   - getTrainingVersion(): \(version)")
                                print("   - isV2User(): \(isV2)")
                                print("   - User.trainingVersion: \(userData.trainingVersion ?? "nil")")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Test Version Router")
                                    .font(AppFont.caption())
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 4)

            Divider()

            // 重新開始完整 Onboarding 流程
            Button {
                // 清除 onboarding 完成標記
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                authViewModel.hasCompletedOnboarding = false

                // 清除可能存在的重新 onboarding 標記
                authViewModel.isReonboardingMode = false

                print("✅ 已清除 onboarding 完成標記，應用將返回 OnboardingIntroView")
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle")
                    Text(NSLocalizedString("userprofile.onboarding", comment: ""))
                }
            }
            .foregroundColor(.purple)

            Divider()

            Button {
                Task {
                    await AppRatingManager.shared.forceShowRating()
                }
            } label: {
                HStack {
                    Image(systemName: "star.circle")
                    Text(L10n.ProfileView.Developer.testRating.localized)
                }
            }

            Button {
                AppRatingManager.shared.clearLocalRatingCache()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.ProfileView.Developer.clearRatingCache.localized)
                }
            }
            .foregroundColor(.orange)

            Button {
                showDebugFailedWorkouts = true
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(L10n.ProfileView.Developer.debugFailedWorkouts.localized)
                }
            }
            .foregroundColor(.red)

            Button {
                showIAPTestConsole = true
            } label: {
                HStack {
                    Image(systemName: "crown")
                    Text("IAP Test Console")
                }
            }
            .foregroundColor(.blue)

            // A-0b: V2 Fixture Export（DEBUG-only）
            NavigationLink {
                V2FixtureExportView()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .foregroundColor(.blue)
                    Text("V2 Fixture Export")
                }
            }

            Divider()

            Button {
                HeartRateDebugHelper.printAllHeartRateSettings()
            } label: {
                HStack {
                    Image(systemName: "heart.text.square")
                    Text(L10n.ProfileView.Developer.printHeartRate.localized)
                }
            }
            .foregroundColor(.blue)

            Button {
                HeartRateDebugHelper.forceClearAllHeartRateSettings()
            } label: {
                HStack {
                    Image(systemName: "heart.slash")
                    Text(L10n.ProfileView.Developer.clearHeartRate.localized)
                }
            }
            .foregroundColor(.red)

            Button {
                HeartRateDebugHelper.simulateRemindMeTomorrow()
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(L10n.ProfileView.Developer.simulateRemindTomorrow.localized)
                }
            }
            .foregroundColor(.orange)

            Divider()

            Button {
                Task {
                    do {
                        // 從 DependencyContainer 取得 Repository
                        let repository: TrainingPlanV2Repository = DependencyContainer.shared.resolve()

                        // 先取得 Overview 以計算當前週數
                        print("🔧 [Debug] 正在取得當前週數...")
                        let overview = try await repository.getOverview()

                        // 計算當前週數（與 TrainingPlanV2ViewModel 相同邏輯）
                        let calendar = Calendar.current
                        let now = Date()
                        guard let startDate = overview.createdAt else {
                            print("❌ [Debug] Overview createdAt 為 nil")
                            return
                        }

                        guard let weekDiff = calendar.dateComponents([.weekOfYear], from: startDate, to: now).weekOfYear else {
                            print("❌ [Debug] 無法計算週數差異")
                            return
                        }

                        let currentWeek = min(max(weekDiff + 1, 1), overview.totalWeeks)

                        print("🔧 [Debug] 開始產生第 \(currentWeek) 週回顧（強制更新）")

                        let summary = try await repository.generateWeeklySummary(
                            weekOfPlan: currentWeek,
                            forceUpdate: true
                        )

                        print("✅ [Debug] 週回顧產生成功！")
                        print("   - 週數: 第 \(currentWeek) 週 / 共 \(overview.totalWeeks) 週")
                        print("   - ID: \(summary.id)")
                        print("   - 完成度: \(Int(summary.trainingCompletion.percentage * 100))%")
                        print("   - 完成場次: \(summary.trainingCompletion.completedSessions)/\(summary.trainingCompletion.plannedSessions)")
                    } catch {
                        print("❌ [Debug] 產生週回顧失敗: \(error.localizedDescription)")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("🐛 產生當週回顧（強制）")
                }
            }
            .foregroundColor(.purple)
        }
    }
    #endif

    private var heartRateZonesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.heartRateZones, id: \.zone) { zone in
                HStack {
                    Circle()
                        .fill(viewModel.zoneColor(for: zone.zone))
                        .frame(width: 10, height: 10)
                    
                    Text(NSLocalizedString("training.heart_rate_zone", comment: "HR Zone") + " \(zone.zone): \(zone.name)")
                        .font(AppFont.bodySmall())
                    
                    Spacer()
                    
                    Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded()))")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func trainingDaysView(_ userData: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Regular training days
            HStack {
                Text(NSLocalizedString("onboarding.training_days", comment: "Training Days") + ":")
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                
                Spacer()
                
                ForEach(userData.preferWeekDays?.filter { !(userData.preferWeekDaysLongrun?.contains($0) ?? false) }.sorted() ?? [], id: \.self) { day in
                    Text(viewModel.weekdayShortName(for: day))
                        .font(AppFont.caption())
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Circle())
                }
            }
            
            // Long run days
            if !(userData.preferWeekDaysLongrun?.isEmpty ?? false) {
                HStack {
                    Text(NSLocalizedString("training.type.long", comment: "Long Run") + ":")
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    ForEach(userData.preferWeekDaysLongrun?.sorted() ?? [], id: \.self) { day in
                        Text(viewModel.weekdayShortName(for: day))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(NSLocalizedString("error.unknown", comment: "Unknown Error") + ": \(error.localizedDescription)")
                .font(AppFont.bodySmall())
                .foregroundColor(.red)
        }
        .padding()
    }
    
    private var dataSourceSection: some View {
        Section(header: Text(NSLocalizedString("profile.data_sources", comment: "Data Sources"))) {
            VStack(spacing: 12) {
                // 當沒有選擇數據源時顯示提示
                if viewModel.currentDataSource == .unbound {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("datasource.not_connected", comment: "Not Connected"))
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                            Text(NSLocalizedString("datasource.select_primary_message", comment: "Please select a primary data source to sync your training records"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Apple Health 選項
                dataSourceRow(
                    type: .appleHealth,
                    icon: "heart.fill",
                    title: "Apple Health",
                    subtitle: NSLocalizedString("datasource.apple_health_subtitle", comment: "Use health data from iPhone and Apple Watch")
                )
                .id("apple-health-row")
                // Garmin 選項（總是顯示）
                Divider()
                    .padding(.vertical, 8)

                dataSourceRow(
                    type: .garmin,
                    icon: "clock.arrow.circlepath",
                    title: "Garmin Connect™",
                    subtitle: NSLocalizedString("datasource.garmin_subtitle", comment: "Sync your Garmin account activities")
                )
                .id("garmin-row")
                
                // Strava 選項（總是顯示）
                Divider()
                    .padding(.vertical, 8)
                
                dataSourceRow(
                    type: .strava,
                    icon: "figure.run",
                    title: "Strava",
                    subtitle: NSLocalizedString("datasource.strava_subtitle", comment: "Sync your activities from Strava")
                )
                .id("strava-row")
                
                // 已隱藏 Garmin 連接錯誤訊息（使用者需求）
            }
            .padding(.vertical, 4)
        }
        .alert(NSLocalizedString("datasource.switch.title", comment: "Switch Data Source"), isPresented: $showDataSourceSwitchConfirmation) {
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                pendingDataSourceType = nil
            }
            Button(NSLocalizedString("common.confirm", comment: "Confirm")) {
                if let newDataSource = pendingDataSourceType {
                    switchDataSource(to: newDataSource)
                    pendingDataSourceType = nil
                }
            }
        } message: {
            if let pendingType = pendingDataSourceType {
                let currentDataSource = viewModel.currentDataSource

                switch (currentDataSource, pendingType) {
                case (.unbound, .garmin):
                    Text(NSLocalizedString("datasource.switch.garmin.select_auth", comment: "Selecting Garmin requires authorization"))
                case (.unbound, .appleHealth):
                    Text(NSLocalizedString("datasource.switch.apple_health.select", comment: "Select Apple Health"))
                case (.garmin, .appleHealth):
                    Text(NSLocalizedString("datasource.switch.garmin_to_apple", comment: "Switching to Apple Health"))
                case (.appleHealth, .garmin):
                    Text(NSLocalizedString("datasource.switch.apple_to_garmin", comment: "Switching to Garmin"))
                case (.unbound, .strava):
                    Text(NSLocalizedString("datasource.switch.unbound_to_strava", comment: "Selecting Strava"))
                case (.appleHealth, .strava):
                    Text(NSLocalizedString("datasource.switch.apple_to_strava", comment: "Switching to Strava"))
                case (.garmin, .strava):
                    Text(NSLocalizedString("datasource.switch.garmin_to_strava", comment: "Switching to Strava from Garmin"))
                case (.strava, .appleHealth):
                    Text(NSLocalizedString("datasource.switch.strava_to_apple", comment: "Switching from Strava to Apple Health"))
                case (.strava, .garmin):
                    Text(NSLocalizedString("datasource.switch.strava_to_garmin", comment: "Switching from Strava to Garmin"))
                case (_, .unbound):
                    Text(NSLocalizedString("datasource.switch.to_unbound", comment: "Switching to unbound"))
                default:
                    Text(NSLocalizedString("datasource.switch.default", comment: "Are you sure"))
                }
            }
        }
    }
    
    @ViewBuilder
    private func dataSourceRow(
        type: DataSourceType,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        let isCurrentSource = viewModel.currentDataSource == type
        let isGarminConnecting = type == .garmin && garminManager.isConnecting
        let isStravaConnecting = type == .strava && stravaManager.isConnecting
        let isConnecting = isGarminConnecting || isStravaConnecting
        let isUnbound = viewModel.currentDataSource == .unbound
        
        Button(action: {
            // 防止重複觸發
            guard !showDataSourceSwitchConfirmation else {
                return
            }
            
            // 如果已經是當前數據源，不需要切換
            if isCurrentSource {
                return
            }
            
            // 如果任何數據源正在連接中，不允許切換
            if isConnecting {
                return
            }
            
            // 顯示確認對話框
            pendingDataSourceType = type
            showDataSourceSwitchConfirmation = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // 圖示
                    if type == .garmin {
                        Image("Garmin Tag-black-high-res")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .frame(width: 24)
                    } else if type == .strava {
                        Image("btn_strava_connect_with_orange")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)  // 放大 Strava badge
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(isCurrentSource ? .blue : .secondary)
                            .frame(width: 24)
                    }

                    // 只有非 Strava 才在同一行顯示標題
                    if type != .strava {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                            Text(subtitle)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                    
                    // 狀態指示
                    if isCurrentSource {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(AppFont.caption())
                            Text(NSLocalizedString("datasource.connected", comment: "Connected"))
                                .font(AppFont.caption())
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if isUnbound {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.orange)
                    }
                    
                    // 連接狀態
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    }
                }

                // Strava subtitle 獨立顯示在下一行
                if type == .strava {
                    Text(subtitle)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }

                // 操作提示
                HStack {
                    if isCurrentSource {
                        Text(NSLocalizedString("datasource.currently_active", comment: "Currently active data source"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.green)
                    } else {
                        Text(isUnbound ? NSLocalizedString("datasource.connect", comment: "Connect") : NSLocalizedString("datasource.switch_to_this", comment: "Switch to this data source"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.leading, 32)
            }
            .padding(.vertical, 8)
        }
        .disabled(isCurrentSource || isConnecting)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .id("\(type.rawValue)-row")
    }
    
    // UIKit alert workaround: SwiftUI .alert/.confirmationDialog button actions
    // don't fire in iOS 26 when presented inside List > NavigationView > sheet.
    private func showResetGoalAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let alert = UIAlertController(
            title: NSLocalizedString("profile.reset_goal_confirm_title", comment: ""),
            message: NSLocalizedString("profile.reset_goal_confirm_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("common.cancel", comment: ""),
            style: .cancel
        ))
        let vm = authViewModel
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("common.confirm", comment: ""),
            style: .destructive
        ) { _ in
            vm.startReonboarding()
        })
        topVC.present(alert, animated: true)
    }

    // 處理數據源切換邏輯
    private func switchDataSource(to newDataSource: DataSourceType) {
        Task {
            switch newDataSource {
            case .unbound:
                // 切換到尚未綁定狀態
                viewModel.currentDataSource = .unbound
                
                // 同步到後端
                do {
                    try await viewModel.updateAndSyncDataSource(newDataSource)
                    print("數據源設定已同步到後端: \(newDataSource.displayName)")
                } catch {
                    print("同步數據源設定到後端失敗: \(error.localizedDescription)")
                }
                
            case .appleHealth:
                // 切換到Apple Health時，先解除Garmin和Strava綁定
                if garminManager.isConnected {
                    do {
                        // 調用後端API解除Garmin綁定
                        let disconnectResult = try await GarminDisconnectService.shared.disconnectGarmin()
                        print("Garmin解除綁定成功: \(disconnectResult.message)")

                        // 本地斷開Garmin連接（remote: false 避免重複調用）
                        await garminManager.disconnect(remote: false)

                    } catch {
                        print("Garmin解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await garminManager.disconnect(remote: false)
                    }
                }

                if stravaManager.isConnected {
                    do {
                        // 調用後端API解除Strava綁定
                        let disconnectResult = try await StravaDisconnectService.shared.disconnectStrava()
                        print("✅ Strava解除綁定成功: \(disconnectResult.message)")

                        // 本地斷開Strava連接（remote: false 避免重複調用）
                        await stravaManager.disconnect(remote: false)

                    } catch is CancellationError {
                        print("Strava解除綁定已取消")
                    } catch {
                        print("❌ Strava解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await stravaManager.disconnect(remote: false)

                        Logger.firebase("切換到Apple Health時Strava斷開失敗", level: .error, labels: [
                            "module": "UserProfileView",
                            "action": "switchDataSource",
                            "target": "appleHealth",
                            "error": error.localizedDescription
                        ])
                    }
                }
                
                // 請求 HealthKit 權限
                do {
                    try await healthKitManager.requestAuthorization()
                    print("Apple Health 權限請求成功")
                } catch {
                    print("Apple Health 權限請求失敗: \(error.localizedDescription)")
                    // 即使權限請求失敗，也繼續切換數據源
                }
                
                viewModel.currentDataSource = .appleHealth

                // 同步到後端
                print("🔄 開始同步數據源到後端: \(newDataSource.rawValue)")
                do {
                    try await viewModel.updateAndSyncDataSource(newDataSource)
                    print("✅ 數據源設定已同步到後端: \(newDataSource.displayName)")

                    Logger.firebase("切換到Apple Health成功", level: .info, labels: [
                        "module": "UserProfileView",
                        "action": "switchDataSource",
                        "target": "appleHealth"
                    ])

                    // 切換完成，不再顯示同步畫面
                    print("Apple Health 數據源切換完成")
                } catch is CancellationError {
                    print("同步數據源設定已取消")
                } catch {
                    print("❌ 同步數據源設定到後端失敗: \(error.localizedDescription)")

                    Logger.firebase("切換到Apple Health失敗", level: .error, labels: [
                        "module": "UserProfileView",
                        "action": "switchDataSource",
                        "target": "appleHealth",
                        "error": error.localizedDescription
                    ])
                }
                
            case .garmin:
                // 切換到Garmin時，先解除其他數據源的綁定
                if stravaManager.isConnected {
                    do {
                        // 調用後端API解除Strava綁定
                        let disconnectResult = try await StravaDisconnectService.shared.disconnectStrava()
                        print("Strava解除綁定成功: \(disconnectResult.message)")

                        // 本地斷開Strava連接
                        await stravaManager.disconnect(remote: false)

                    } catch {
                        print("Strava解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await stravaManager.disconnect(remote: false)
                    }
                }

                if viewModel.currentDataSource == .appleHealth {
                    // 如果當前是Apple Health，無需特殊斷開，直接切換即可
                    print("從Apple Health切換到Garmin")
                }

                // 總是啟動OAuth流程
                // 這樣可以確保連接狀態是最新的，並且處理token過期的情況
                await garminManager.startConnection()

                // 等待 OAuth 流程完成
                // 監聽連接狀態變化，最多等待 30 秒
                let maxWaitTime = 30.0 // 30 秒
                let startTime = Date()

                while garminManager.isConnecting && Date().timeIntervalSince(startTime) < maxWaitTime {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                }

                if garminManager.isConnected {
                    // OAuth 成功，切換完成
                    print("Garmin 數據源切換完成")
                } else if !garminManager.isConnecting {
                    // OAuth 流程已結束但未成功連接
                    print("Garmin OAuth 失敗或用戶取消")
                } else {
                    // 超時
                    print("Garmin OAuth 超時")
                }
                // 注意：數據源的更新會在OAuth成功後在GarminManager中處理
            
            case .strava:
                // 切換到Strava時，先解除其他數據源的綁定
                if garminManager.isConnected {
                    do {
                        // 調用後端API解除Garmin綁定
                        let disconnectResult = try await GarminDisconnectService.shared.disconnectGarmin()
                        print("Garmin解除綁定成功: \(disconnectResult.message)")

                        // 本地斷開Garmin連接
                        await garminManager.disconnect(remote: false)

                    } catch {
                        print("Garmin解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await garminManager.disconnect(remote: false)
                    }
                }

                if viewModel.currentDataSource == .appleHealth {
                    // 如果當前是Apple Health，無需特殊斷開，直接切換即可
                    print("從Apple Health切換到Strava")
                }

                // 啟動Strava OAuth流程
                // 這樣可以確保連接狀態是最新的，並且處理token過期的情況
                await stravaManager.startConnection()

                // 等待 OAuth 流程完成
                // 監聽連接狀態變化，最多等待 30 秒
                let maxWaitTime = 30.0 // 30 秒
                let startTime = Date()

                while stravaManager.isConnecting && Date().timeIntervalSince(startTime) < maxWaitTime {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                }

                if stravaManager.isConnected {
                    // OAuth 成功，切換完成
                    print("Strava 數據源切換完成")
                } else if !stravaManager.isConnecting {
                    // OAuth 流程已結束但未成功連接
                    print("Strava OAuth 失敗或用戶取消")
                } else {
                    // 超時
                    print("Strava OAuth 超時")
                }
                // 注意：數據源的更新會在OAuth成功後在StravaManager中處理
            }
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(isShowing: .constant(true))
    }
}
