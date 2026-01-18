import SwiftUI
import FirebaseAuth
import HealthKit

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
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
    @State private var showOnboardingConfirmation = false  // 重新 OnBoarding 確認對話框狀態
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
    @State private var showDebugFailedWorkouts = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var body: some View {
        List {
            profileSection
            weeklyDistanceSection
            dataSourceSection
            heartRateSection
            trainingDaysSection
            settingsSection
            logoutSection
            appVersionSection
            #if DEBUG
            developerSection
            #endif
        }
        .navigationTitle(NSLocalizedString("profile.title", comment: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common.done", comment: "Done")) {
                    dismiss()
                }
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
            await TrackedTask("UserProfileView: loadHeartRateZonesOnRefresh") {
                await viewModel.loadHeartRateZones()
            }.value
        }
        .task {
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
        .sheet(isPresented: $showDebugFailedWorkouts) {
            DebugFailedWorkoutsView()
        }
        // 重新 OnBoarding 確認對話框
        .confirmationDialog(
            NSLocalizedString("profile.reset_goal_confirm_title", comment: "Are you sure you want to restart the goal setting process?"),
            isPresented: $showOnboardingConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("common.confirm", comment: "Confirm"), role: .destructive) {
                // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                authViewModel.startReonboarding()
            }
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("profile.reset_goal_confirm_message", comment: "This will reset all your training settings and require you to reconfigure your training preferences. Your current training plan will be cleared and cannot be recovered."))
        }
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
    private var weeklyDistanceSection: some View {
        if let userData = viewModel.userData {
            Section(header: Text(NSLocalizedString("profile.training_info", comment: "Training Info"))) {
                HStack {
                    Label(NSLocalizedString("profile.weekly_mileage", comment: "Weekly Mileage"), systemImage: "figure.walk")
                        .foregroundColor(.blue)
                    Spacer()
                    Text("\(userData.currentWeekDistance ?? 0) \(NSLocalizedString("unit.km", comment: "km"))")
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
                showOnboardingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(NSLocalizedString("profile.reset_goal", comment: "Reset Goal"))
                }
            }

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
                    .font(.footnote)
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
                    
                    Text("\(Int(zone.range.lowerBound))-\(Int(zone.range.upperBound))")
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
        UserProfileView()
    }
}
