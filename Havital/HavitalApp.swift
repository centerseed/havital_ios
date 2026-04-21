import SwiftUI
import HealthKit
import FirebaseCore
import FirebaseAppCheck
import FirebaseRemoteConfig
import BackgroundTasks
import UserNotifications
import FirebaseAuth
import RevenueCat
import StoreKit

/// 判斷當前是否為 Debug 建置
private var isDebugBuild: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}

@main
struct HavitalApp: App {
    // 注入 AppDelegate 以處理推播與 FCM token
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Clean Architecture: Use AuthenticationViewModel for authentication state
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager: HealthKitManager
    @StateObject private var appViewModel: AppViewModel
    @StateObject private var authViewModel: AuthenticationViewModel
    @State private var featureFlagManager: FeatureFlagManager? = nil
    @State private var shouldRefreshForLanguage = false
    @State private var hasLaunched = false  // ✅ 追蹤是否已完成啟動
    
    init() {
        // 1. 初始化 Firebase（必須最先執行，因為 Logger 依賴它，且 Auth.auth() 等服務需要它）
        let configFileName = "GoogleService-Info-" + (isDebugBuild ? "dev" : "prod")
        print("🔍 啟動 HavitalApp 初始化...")
        print("🔍 當前建置環境: \(isDebugBuild ? "DEBUG" : "PRODUCTION")")
        print("🔍 嘗試使用 Firebase 配置文件: \(configFileName)")
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            print("✅ 找到標準 Firebase 配置文件: \(path)")
            FirebaseApp.configure()
        } else if let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
            print("✅ Firebase 初始化成功 - 使用: \(path)")
        } else {
            print("❌ 找不到 Firebase 配置文件 (GoogleService-Info.plist 或 \(configFileName).plist)")
            // 退回預設配置
            FirebaseApp.configure()
        }

        // 2. 初始化 RevenueCat（Firebase 之後，DI 之前）
        let revenueCatAppUserID = Auth.auth().currentUser?.uid
        let revenueCatConfiguration = Configuration
            .builder(withAPIKey: RevenueCatConfig.apiKey)
            .with(appUserID: revenueCatAppUserID)
            .build()
        Purchases.configure(with: revenueCatConfiguration)
        print("✅ RevenueCat 已初始化 - appUserID: \(revenueCatAppUserID ?? "anonymous")")

        #if DEBUG
        // 🧪 StoreKit diagnostic: 僅 DEBUG 檢查本地產品是否可被讀取
        Task {
            do {
                let products = try await StoreKit.Product.products(for: ["paceriz.sub.monthly", "paceriz.sub.yearly"])
                print("🧪 StoreKit direct test: \(products.count) products found")
                for p in products {
                    print("🧪 Product: \(p.id) - \(p.displayPrice) - \(p.subscription?.subscriptionPeriod.debugDescription ?? "no period")")
                }
            } catch {
                print("🧪 StoreKit direct test ERROR: \(error)")
            }
        }
        #endif

        // 2.5 Install attribution — fire-and-forget, must run before onboarding reads source
        AttributionManager.shared.fetchIfNeeded()

        // 3. ✅ Clean Architecture: 使用集中式 Bootstrap 註冊所有模組依賴
        AppDependencyBootstrap.registerAllModules()
        print("📦 所有模組依賴已優先註冊")

        #if DEBUG
        if CommandLine.arguments.contains("-useStoreKitTestRepository") {
            DependencyContainer.shared.replace(
                StoreKitTestSubscriptionRepository() as SubscriptionRepository,
                for: SubscriptionRepository.self
            )
            print("🧪 [UI Test] 已切換為 StoreKitTestSubscriptionRepository")
        }
        if CommandLine.arguments.contains("-ui_testing_training_v2_gates") {
            UITestTrainingPlanV2GateHarness.registerDependencies()
            print("🧪 [UI Test] 已切換為 TrainingPlanV2 gating 測試依賴")
        }
        if CommandLine.arguments.contains("-ui_testing_onboarding") {
            UITestOnboardingHarness.registerDependencies()
            print("🧪 [UI Test] 已切換為 Onboarding 測試依賴")
        }
        if CommandLine.arguments.contains("-ui_testing_methodology_fixture") {
            UITestMethodologyHarness.registerDependencies()
            print("🧪 [UI Test] 已切換為 Methodology fixture 測試依賴")
        }
        #endif

        // 🔍 DEBUG: 驗證 MonthlyStatsRepository 是否註冊
        let testRepo: MonthlyStatsRepository? = DependencyContainer.shared.tryResolve()
        print("🔍 MonthlyStatsRepository 註冊驗證: \(testRepo != nil ? "✅ 成功" : "❌ 失敗")")
        
        // 3. 🚀 必須在訪問 self 之前初始化所有屬性
        // 注意：此時 Firebase 已就緒，DI Container 已填充，可以安全創建單例和 ViewModels
        self._healthKitManager = StateObject(wrappedValue: HealthKitManager())
        self._appViewModel = StateObject(wrappedValue: AppViewModel())
        // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
        self._authViewModel = StateObject(wrappedValue: AuthenticationViewModel.shared)
        
        // [TEST HELPER] 檢查是否需要重置 Onboarding (用於 UI 測試)
        if CommandLine.arguments.contains("-resetOnboarding") {
            print("🧪 [UI Test] 檢測到 -resetOnboarding 標誌，清除所有本地狀態...")
            // 強制登出 Firebase 用戶
            do {
                try Auth.auth().signOut()
                print("🧪 [UI Test] Firebase 用戶已登出")
            } catch {
                print("🧪 [UI Test] Firebase 登出失敗: \(error)")
            }
            
            // 清除 UserDefaults
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            print("🧪 [UI Test] 用戶已登出且 UserDefaults 已清除")
            
            // 由於 AuthenticationViewModel 使用 UserDefaults 儲存狀態，這裡清除後
            // 在下面初始化的 authViewModel 應該會是未登入狀態
        }
        
        // 3. 設定其他 Firebase 服務
        FirebaseLogConfigurator.setup()
        
        // 4. 註冊背景任務處理器
        registerBackgroundTasks()
        
        // 5. 檢查 Firebase 初始化狀態
        if FirebaseApp.app() == nil {
            print("❌ Firebase 初始化失敗！")
        } else {
            print("✅ Firebase 已成功初始化")

            // 6. 初始化語言管理器（Firebase 完成後才能安全使用 Logger.firebase）
            _ = LanguageManager.shared
            print("🌍 LanguageManager 已初始化")

            // 7. 動態載入 Onest 字體（如果未被 Info.plist 載入）
            print("🔤 開始動態載入 Onest 字體...")
            AppFont.loadOnestFontsIfNeeded()

            // 8. 檢查字體載入情況（DEBUG only）
            print("🔍 檢查字體載入結果...")
            AppFont.debugCheckFonts()

            // 9. 設定 Tab Bar 字體（根據語言選擇）
            self.configureTabBarFont()
        }

        // 10. 檢查是否因語言變更而重啟
        checkLanguageChangeRestart()
    }
    
    var body: some Scene {
        WindowGroup {
            if isRunningTests && !shouldRenderRealUIInTests {
                Text("Running Tests...")
            } else if shouldLaunchMethodologyUITestHarness {
                methodologyUITestHarnessView
            } else if shouldLaunchTrainingPlanV2GatesUITestHarness {
                trainingPlanV2GateHarnessView
            } else if shouldLaunchLoadingCacheUITestHarness {
                loadingCacheUITestHarnessView
            } else if shouldLaunchPaywallUITestHarness {
                paywallUITestHarnessView
            } else if shouldLaunchTypographyAuditHarness {
                typographyAuditHarnessView
            } else {
                Group {
                    if let featureFlagManager = featureFlagManager {
                        ContentView() // 使用 ContentView 作為根視圖
                            .environmentObject(authViewModel)      // Clean Architecture: AuthenticationViewModel
                            // ✅ AuthenticationService removed - LoginView now uses LoginViewModel
                            .environmentObject(healthKitManager)   // 注入 HealthKitManager
                            .environmentObject(appViewModel)       // 注入 AppViewModel
                            .environmentObject(featureFlagManager) // 注入 FeatureFlagManager
                            .id(shouldRefreshForLanguage ? "refreshed" : "original") // Force UI refresh
                            .onAppear {
                                // App 啟動時使用新的狀態管理進行序列化初始化
                                Task {
                                    print("🚀 HavitalApp: 開始序列化初始化流程")

                                    // Step 1: App 核心初始化（用戶狀態優先）
                                    await appViewModel.initializeApp()

                                    // Step 2: 只有在用戶資料載入完成後才設置權限和背景處理
                                    await setupPermissionsBasedOnUserState()

                                    // Step 3: 檢查並初始化時區設定（僅限已認證用戶）
                                    await checkAndInitializeTimezone()

                                    #if DEBUG
                                    await IAPTestHarness.shared.bootstrapFromLaunchScenarioIfNeeded()
                                    #endif

                                    print("✅ HavitalApp: 初始化流程完成")
                                }
                                
                                // 監聽語言變更通知
                                NotificationCenter.default.addObserver(
                                    forName: NSNotification.Name("AppShouldRefreshForLanguageChange"),
                                    object: nil,
                                    queue: .main
                                ) { _ in
                                    print("🌍 收到語言變更通知，刷新 UI")
                                    shouldRefreshForLanguage.toggle() // Trigger UI refresh
                                }
                            }
                    } else {
                        // Firebase 和 FeatureFlagManager 初始化中
                        ProgressView("初始化中...")
                            .onAppear {
                                // 在 Firebase 初始化完成後創建 FeatureFlagManager
                                if FirebaseApp.app() != nil {
                                    print("🎛️ 創建 FeatureFlagManager")
                                    featureFlagManager = FeatureFlagManager.shared
                                    
                                    // 延遲調試檢查和手動刷新
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        #if DEBUG
                                        print("🔍 DEBUG: 3 秒後檢查 Feature Flag 狀態")
                                        FeatureFlagManager.shared.debugPrintAllFlags()
                                        
                                        // 手動刷新 Remote Config
                                        print("🔄 DEBUG: 手動刷新 Remote Config")
                                        Task {
                                            await FeatureFlagManager.shared.refreshConfig()
                                            print("🔍 DEBUG: 刷新後再次檢查狀態")
                                            FeatureFlagManager.shared.debugPrintAllFlags()
                                        }
                                        #endif
                                    }
                                }
                            }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
            }
        }
        // 添加應用程式生命週期事件處理
        .onChange(of: UIApplication.shared.applicationState) { state in
            if state == .active {
                // ✅ 只有在 App 已啟動後才觸發刷新（避免啟動時重複調用）
                if hasLaunched {
                    print("📱 應用從背景回到前景，觸發刷新")
                    Task {
                        await appViewModel.onAppBecameActive()
                    }
                    Task {
                        await checkForPendingHealthUpdates()
                    }
                    // P0-4: 前景恢復時刷新訂閱狀態
                    Task {
                        await refreshSubscriptionOnForeground()
                    }
                    let analytics: AnalyticsService = DependencyContainer.shared.resolve()
                    analytics.track(.sessionStart(sessionCountToday: UserDefaults.standard.incrementSessionCount()))
                } else {
                    print("📱 應用首次啟動變為 active，跳過刷新（已在初始化時載入）")
                    hasLaunched = true
                }
            }
        }
    }
    
    // 判斷是否正在運行測試
    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    private var shouldRenderRealUIInTests: Bool {
        let arguments = CommandLine.arguments
        return arguments.contains("-ui_testing")
            || arguments.contains("-resetOnboarding")
            || arguments.contains("-iapTestMode")
            || arguments.contains("-iapScenario")
            || arguments.contains("-ui_testing_paywall")
            || arguments.contains("-useStoreKitTestRepository")
            || arguments.contains("-ui_testing_training_v2_gates")
            || arguments.contains("-ui_testing_methodology_fixture")
            || arguments.contains("-ui_testing_loading_cache")
            || arguments.contains("-ui_testing_typography_audit")
    }

    private var shouldLaunchPaywallUITestHarness: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-ui_testing_paywall")
        #else
        false
        #endif
    }

    @ViewBuilder
    private var paywallUITestHarnessView: some View {
        #if DEBUG
        UITestPaywallHostView()
        #else
        EmptyView()
        #endif
    }

    private var shouldLaunchTrainingPlanV2GatesUITestHarness: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-ui_testing_training_v2_gates")
        #else
        false
        #endif
    }

    private var shouldLaunchMethodologyUITestHarness: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-ui_testing_methodology_fixture")
        #else
        false
        #endif
    }

    private var shouldLaunchLoadingCacheUITestHarness: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-ui_testing_loading_cache")
        #else
        false
        #endif
    }

    private var shouldLaunchTypographyAuditHarness: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-ui_testing_typography_audit")
        #else
        false
        #endif
    }

    @ViewBuilder
    private var loadingCacheUITestHarnessView: some View {
        #if DEBUG
        LocalUITestTrainingLoadingCacheHostView()
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var trainingPlanV2GateHarnessView: some View {
        #if DEBUG
        UITestTrainingPlanV2GateHostView()
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var methodologyUITestHarnessView: some View {
        #if DEBUG
        UITestMethodologyHostView()
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var typographyAuditHarnessView: some View {
        #if DEBUG
        UITestTypographyAuditHostView()
        #else
        EmptyView()
        #endif
    }

    /// P0-4: 前景恢復時刷新訂閱狀態，偵測降級
    private func refreshSubscriptionOnForeground() async {
        guard AppStateManager.shared.isUserAuthenticated else { return }
        let repo: SubscriptionRepository? = DependencyContainer.shared.tryResolve()
        guard let repo else { return }

        do {
            let status = try await repo.refreshStatus()
            Logger.debug("[HavitalApp] 前景恢復：訂閱狀態已刷新")
            // P1-9/P1-10: 前景恢復時也檢查提醒
            await SubscriptionReminderManager.shared.checkAndShowReminder(status: status)
        } catch {
            Logger.debug("[HavitalApp] 前景恢復：訂閱狀態刷新失敗 \(error.localizedDescription)")
        }
    }

    /// 基於已確定用戶狀態的權限設置
    func setupPermissionsBasedOnUserState() async {
        print("🔐 HavitalApp: 開始基於用戶狀態設置權限")

        // 獲取用戶狀態
        let appStateManager = AppStateManager.shared
        let isAuthenticated = appStateManager.isUserAuthenticated
        let dataSource = appStateManager.userDataSource

        print("🔐 用戶認證狀態: \(isAuthenticated)")
        print("🔐 數據源: \(dataSource.rawValue)")

        // 📊 關鍵診斷：記錄入口狀態
        Logger.firebase(
            "setupPermissions 入口狀態",
            level: .info,
            labels: ["module": "HavitalApp", "action": "setup_permissions_entry", "cloud_logging": "true"],
            jsonPayload: [
                "isAuthenticated": isAuthenticated,
                "dataSource": dataSource.rawValue,
                "userPrefsDataSource": UserPreferencesManager.shared.dataSourcePreference.rawValue,
                "hasCompletedOnboarding": UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            ]
        )
        
        if isAuthenticated {
            // 🔧 多來源判定：避免 AppStateManager 未同步完成時漏判
            let userPrefsDataSource = UserPreferencesManager.shared.dataSourcePreference
            let isAppleHealthUser = dataSource == .appleHealth || userPrefsDataSource == .appleHealth

            if isAppleHealthUser {
                print("🍎 設置 Apple Health 用戶權限 (appState=\(dataSource.rawValue), prefs=\(userPrefsDataSource.rawValue))")
                // 1. 請求 HealthKit 授權
                await requestHealthKitAuthorization()

                // 2. 請求通知授權
                await requestNotificationAuthorization()

                // 3. 設置背景健身記錄同步
                await setupWorkoutBackgroundProcessing()
            } else if dataSource == .garmin {
                print("⌚ 設置 Garmin 用戶權限")
                await requestNotificationAuthorization()
            } else if dataSource == .strava {
                print("🏃 設置 Strava 用戶權限")
                await requestNotificationAuthorization()
            } else {
                print("🔓 用戶未綁定數據源 (appState=\(dataSource.rawValue), prefs=\(userPrefsDataSource.rawValue))，設置基本權限")
                await requestNotificationAuthorization()
            }
            
            // 啟動健康數據同步（支援所有數據源）
            await startHealthDataSync()
            
        } else {
            print("👤 訪客用戶，設置基本權限")
            // 訪客模式只需要基本通知權限
            await requestNotificationAuthorization()
        }
        
        print("✅ HavitalApp: 權限設置完成")
    }
    
    /// 一次性請求所有必要的權限並設置背景處理（舊方法，保留作為備用）
    func setupAllPermissionsAndBackgroundProcessing() {
        Task {
            await setupPermissionsBasedOnUserState()
        }
    }
    
    /// 啟動健康數據同步
    private func startHealthDataSync() async {
        print("啟動健康數據同步...")
        await HealthDataUploadManagerV2.shared.initialize()
    }
    
    /// 請求 HealthKit 授權
    private func requestHealthKitAuthorization() async {
        do {
            try await healthKitManager.requestAuthorization()
            await MainActor.run {
                isHealthKitAuthorized = true
                print("HealthKit 授權成功")
            }
        } catch {
            print("HealthKit 授權失敗: \(error)")
            await MainActor.run {
                isHealthKitAuthorized = false
            }
        }
    }
    
    /// 請求通知授權
    private func requestNotificationAuthorization() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("通知授權\(granted ? "成功" : "失敗")")
        } catch {
            print("請求通知授權失敗: \(error)")
        }
    }
    
    // MARK: - 背景健身記錄同步功能
    
    private func setupWorkoutBackgroundProcessing() async {
        // 設置通知代理
        UNUserNotificationCenter.current().delegate = WorkoutBackgroundManager.shared
        
        // 標記首次登入狀態
        if authViewModel.isFirstLogin {
            WorkoutBackgroundManager.shared.markFirstLogin()
            authViewModel.isFirstLogin = false
        }
        
        // 🚨 關鍵修復：只有 Apple Health 用戶才設置觀察者
        let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference

        // 📊 診斷：記錄進入 setupWorkoutBackgroundProcessing 的狀態
        Logger.firebase(
            "setupWorkoutBackgroundProcessing 開始",
            level: .info,
            labels: ["module": "HavitalApp", "action": "setup_workout_bg", "cloud_logging": "true"],
            jsonPayload: [
                "dataSourcePreference": dataSourcePreference.rawValue,
                "isFirstLogin": authViewModel.isFirstLogin
            ]
        )

        if dataSourcePreference == .appleHealth {
            print("設置健身記錄觀察者（Apple Health 用戶）...")
            await WorkoutBackgroundManager.shared.setupWorkoutObserver()
        } else {
            print("跳過健身記錄觀察者設置（數據源: \(dataSourcePreference.displayName)）")
            Logger.firebase(
                "跳過 Observer 設置：非 Apple Health",
                level: .warn,
                labels: ["module": "HavitalApp", "action": "setup_workout_bg_skipped", "cloud_logging": "true"],
                jsonPayload: ["dataSource": dataSourcePreference.rawValue]
            )
            // 確保停止任何可能已經啟動的觀察者
            WorkoutBackgroundManager.shared.stopAndCleanupObserving()
        }
        
        // 安排背景工作 (scheduleBackgroundWorkoutSync 內部會檢查數據來源)
        scheduleBackgroundWorkoutSync()
    }
    
    // 檢查是否有待處理的健身記錄
    private func checkForPendingHealthUpdates() async {
        // 確保用戶已登入且完成引導
        guard authViewModel.isAuthenticated && authViewModel.hasCompletedOnboarding else {
            return
        }
        
        // 再次確認數據來源（WorkoutBackgroundManager 內部也會檢查）
        let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
        guard dataSourcePreference == .appleHealth else {
            print("數據來源為 \(dataSourcePreference.displayName)，跳過 HealthKit 數據檢查")
            return
        }
        
        // 在背景檢查待上傳記錄，不阻塞主畫面顯示
        print("在背景檢查待上傳健身記錄...")
        Task {
            await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()
        }
    }
    
    // 註冊背景任務 - 只在初始化時呼叫一次
    private func registerBackgroundTasks() {
        // 1. 註冊健身記錄同步任務
        registerWorkoutSyncTask()

        // 2. 註冊健康數據同步任務
        registerHealthDataSyncTask()
    }

    private func registerWorkoutSyncTask() {
        let taskIdentifier = "com.havital.workout-sync"

        // ✅ 修復：不要全局清除所有任務，只檢查任務是否已註冊
        // BGTaskScheduler.shared.cancelAllTaskRequests() 已移除

        // 只註冊一次背景處理任務
        do {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
                // 背景同步任務
                print("背景任務開始執行: \(taskIdentifier)")

                // 設置任務到期處理
                task.expirationHandler = {
                    print("背景健身記錄同步任務到期")
                }

                Task {
                    // 確保用戶已登入
                    // Clean Architecture: Use AuthenticationViewModel
                    guard AuthenticationViewModel.shared.isAuthenticated else {
                        (task as? BGProcessingTask)?.setTaskCompleted(success: false)
                        return
                    }

                    // 確認當前數據來源是 Apple Health
                    let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
                    guard dataSourcePreference == .appleHealth else {
                        print("背景任務 - 數據來源為 \(dataSourcePreference.displayName)，跳過 HealthKit 同步")
                        (task as? BGProcessingTask)?.setTaskCompleted(success: true)
                        return
                    }

                    // 執行背景同步
                    await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()

                    // 任務完成
                    (task as? BGProcessingTask)?.setTaskCompleted(success: true)

                    // 安排下一次執行
                    scheduleBackgroundWorkoutSync()
                }
            }
            print("已註冊背景任務: \(taskIdentifier)")
        } catch {
            print("❌ 背景任務註冊失敗: \(error.localizedDescription)")
        }
    }

    private func registerHealthDataSyncTask() {
        let taskIdentifier = "com.havital.health-data-sync"

        do {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
                print("健康數據同步後台任務開始執行: \(taskIdentifier)")

                // 設置任務到期處理
                task.expirationHandler = {
                    print("健康數據同步後台任務到期")
                }

                Task {
                    // 確保用戶已登入
                    // Clean Architecture: Use AuthenticationViewModel
                    guard AuthenticationViewModel.shared.isAuthenticated else {
                        (task as? BGAppRefreshTask)?.setTaskCompleted(success: false)
                        return
                    }

                    // 確認當前數據來源是 Apple Health
                    let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
                    guard dataSourcePreference == .appleHealth else {
                        print("健康數據同步任務 - 數據來源為 \(dataSourcePreference.displayName)，跳過")
                        (task as? BGAppRefreshTask)?.setTaskCompleted(success: true)
                        return
                    }

                    // 執行健康數據上傳
                    await HealthDataUploadManagerV2.shared.syncHealthDataNow()

                    // 任務完成
                    (task as? BGAppRefreshTask)?.setTaskCompleted(success: true)
                }
            }
            print("已註冊背景任務: \(taskIdentifier)")
        } catch {
            print("❌ 健康數據同步任務註冊失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 深度連結處理
    
    /// 處理深度連結
    private func handleDeepLink(url: URL) {
        print("🔗 收到深度連結: \(url)")
        print("🔗 URL 組件分析:")
        print("  - scheme: \(url.scheme ?? "nil")")
        print("  - host: \(url.host ?? "nil")")
        print("  - path: \(url.path)")
        print("  - query: \(url.query ?? "nil")")
        
        // 檢查是否為 Garmin OAuth 回調
        if url.scheme?.lowercased() == "paceriz" && url.host == "callback" && url.path == "/garmin" {
            print("✅ 識別為 Garmin OAuth 回調，開始處理")
            Task {
                await GarminManager.shared.handleCallback(url: url)
            }
        }
        // 檢查是否為 Strava OAuth 回調
        else if url.scheme?.lowercased() == "paceriz" && url.host == "callback" && url.path == "/strava" {
            print("✅ 識別為 Strava OAuth 回調，開始處理")
            Task {
                await StravaManager.shared.handleCallback(url: url)
            }
        } else {
            print("❌ 未知的深度連結:")
            print("  - 期望 scheme: paceriz，實際: \(url.scheme ?? "nil")")
            print("  - 期望 host: callback，實際: \(url.host ?? "nil")")
            print("  - 期望 path: /garmin 或 /strava，實際: \(url.path)")
        }
    }
    
    /// 設定 Tab Bar 字體（根據當前語言）
    private func configureTabBarFont() {
        let language = LanguageManager.shared.currentLanguage

        // 根據語言選擇字體
        let font: UIFont
        switch language {
        case .english:
            // 英文使用 Onest
            font = UIFont(name: "Onest-Medium", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .medium)
        case .japanese, .traditionalChinese:
            // 日文和中文使用系統字體
            font = UIFont.systemFont(ofSize: 10, weight: .medium)
        }

        // 設定 Tab Bar Item 的字體
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .selected)

        print("✅ Tab Bar 字體已設定: \(language == .english ? "Onest-Medium" : "System Font")")
    }

    /// 檢查是否因語言變更而重啟
    private func checkLanguageChangeRestart() {
        if UserDefaults.standard.bool(forKey: "language_changed_restart") {
            // 清除標記
            UserDefaults.standard.removeObject(forKey: "language_changed_restart")

            // 可以在這裡添加額外的語言變更後處理邏輯
            print("🌍 App 因語言變更而重啟")
        }
    }

    /// 檢查並初始化時區設定
    private func checkAndInitializeTimezone() async {
        // 僅在用戶已認證時執行
        guard authViewModel.isAuthenticated else {
            print("⏰ 用戶未認證，跳過時區初始化")
            return
        }

        let userPreferenceManager = UserPreferencesManager.shared

        // 檢查是否需要初始化時區
        if userPreferenceManager.needsTimezoneInitialization() {
            print("⏰ 開始自動偵測並初始化時區")

            // 獲取裝置時區
            let deviceTimezone = UserPreferencesManager.getDeviceTimezone()
            print("⏰ 偵測到裝置時區: \(deviceTimezone)")

            // 更新本地偏好
            userPreferenceManager.timezonePreference = deviceTimezone

            // ✅ 優化：使用 UserPreferencesManager 同步到後端
            do {
                try await UserPreferencesManager.shared.updatePreferences(timezone: deviceTimezone)
                print("✅ 時區已自動初始化並同步到後端: \(deviceTimezone)")
            } catch {
                print("❌ 時區同步到後端失敗: \(error.localizedDescription)")
                // 即使同步失敗，本地仍保留偵測到的時區
            }
        } else {
            print("⏰ 時區已存在，無需初始化")

            // ✅ 優化：使用 UserPreferencesManager 檢查本地時區與後端是否一致
            if let preferences = await UserPreferencesManager.shared.getPreferences(),
               let localTimezone = userPreferenceManager.timezonePreference,
               localTimezone != preferences.timezone {
                print("⚠️ 本地時區與後端不一致，同步後端時區")
                userPreferenceManager.timezonePreference = preferences.timezone
            }
        }
    }
}

#if DEBUG
private enum LocalUITestLoadingScenario: String {
    case cacheThenRefreshSuccess = "cache_then_refresh_success"
    case cacheThenRefreshFailure = "cache_then_refresh_failure"
    case noCacheSuccess = "no_cache_success"
    case noCacheFailure = "no_cache_failure"

    static func current() -> LocalUITestLoadingScenario {
        let raw = ProcessInfo.processInfo.environment["UITEST_LOADING_SCENARIO"]?.lowercased()
            ?? LocalUITestLoadingScenario.cacheThenRefreshSuccess.rawValue
        return LocalUITestLoadingScenario(rawValue: raw) ?? .cacheThenRefreshSuccess
    }
}

private enum LocalUITestLoadingOutcome {
    case success
    case failure

    static func fromEnvironment(_ key: String, defaultValue: LocalUITestLoadingOutcome = .success) -> LocalUITestLoadingOutcome {
        let raw = ProcessInfo.processInfo.environment[key]?.lowercased()
        guard let raw else { return defaultValue }
        return raw == "failure" ? .failure : .success
    }
}

private final class LocalUITestTrainingLoadingCacheViewModel: ObservableObject {
    @Published var cacheStatus = "idle"
    @Published var refreshStatus = "idle"
    @Published var visibleDistance = "--"
    @Published var nonBlockingBanner = "none"
    @Published var actionTapCount = 0
    @Published var refreshTick = 0
    @Published var blockingOverlayVisible = false

    private let scenario = LocalUITestLoadingScenario.current()
    private let cacheDistance: String
    private let refreshedDistance: String
    private let manualRefreshedDistance: String
    private let refreshDelayNanos: UInt64
    private let manualOutcome: LocalUITestLoadingOutcome
    private var didStart = false
    private var inFlightTask: Task<Void, Never>?

    init() {
        cacheDistance = ProcessInfo.processInfo.environment["UITEST_LOADING_CACHE_DISTANCE"] ?? "5.0"
        refreshedDistance = ProcessInfo.processInfo.environment["UITEST_LOADING_REFRESH_DISTANCE"] ?? "12.0"
        manualRefreshedDistance = ProcessInfo.processInfo.environment["UITEST_LOADING_MANUAL_REFRESH_DISTANCE"] ?? "18.0"

        let delayMsRaw = ProcessInfo.processInfo.environment["UITEST_LOADING_REFRESH_DELAY_MS"] ?? "1200"
        let delayMs = UInt64(delayMsRaw) ?? 1200
        refreshDelayNanos = delayMs * 1_000_000

        manualOutcome = LocalUITestLoadingOutcome.fromEnvironment("UITEST_LOADING_MANUAL_OUTCOME", defaultValue: .success)
    }

    deinit {
        inFlightTask?.cancel()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        switch scenario {
        case .cacheThenRefreshSuccess:
            cacheStatus = "cache_hit"
            visibleDistance = cacheDistance
            performRefresh(isManual: false, outcome: .success)
        case .cacheThenRefreshFailure:
            cacheStatus = "cache_hit"
            visibleDistance = cacheDistance
            performRefresh(isManual: false, outcome: .failure)
        case .noCacheSuccess:
            cacheStatus = "cache_miss"
            visibleDistance = "--"
            performRefresh(isManual: false, outcome: .success)
        case .noCacheFailure:
            cacheStatus = "cache_miss"
            visibleDistance = "--"
            performRefresh(isManual: false, outcome: .failure)
        }
    }

    func triggerManualRefresh() {
        guard refreshStatus != "refreshing" else { return }
        performRefresh(isManual: true, outcome: manualOutcome)
    }

    func tapUserAction() {
        actionTapCount += 1
    }

    private func performRefresh(isManual: Bool, outcome: LocalUITestLoadingOutcome) {
        inFlightTask?.cancel()
        refreshStatus = "refreshing"
        nonBlockingBanner = "none"
        blockingOverlayVisible = false
        refreshTick += 1

        inFlightTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.refreshDelayNanos)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                switch outcome {
                case .success:
                    self.visibleDistance = isManual ? self.manualRefreshedDistance : self.refreshedDistance
                    self.cacheStatus = "fresh"
                    self.refreshStatus = "idle"
                    self.nonBlockingBanner = "none"
                case .failure:
                    self.refreshStatus = "failed_non_blocking"
                    self.nonBlockingBanner = "refresh_failed"
                }
            }
        }
    }
}

private struct LocalUITestTrainingLoadingCacheHostView: View {
    @StateObject private var viewModel = LocalUITestTrainingLoadingCacheViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("UITest Loading Cache Host")
                    .font(AppFont.headline())
                    .accessibilityIdentifier("UITest_Loading_HostTitle")

                Text("scenario:\(LocalUITestLoadingScenario.current().rawValue)")
                    .font(AppFont.subheadline())
                    .accessibilityIdentifier("UITest_Loading_Scenario")

                VStack(spacing: 8) {
                    Text("main_content_visible")
                        .accessibilityIdentifier("UITest_Loading_MainContent")
                    Text("cache_status:\(viewModel.cacheStatus)")
                        .accessibilityIdentifier("UITest_Loading_CacheStatus")
                    Text("refresh_status:\(viewModel.refreshStatus)")
                        .accessibilityIdentifier("UITest_Loading_RefreshStatus")
                    Text("distance_km:\(viewModel.visibleDistance)")
                        .accessibilityIdentifier("UITest_Loading_Distance")
                    Text("refresh_tick:\(viewModel.refreshTick)")
                        .accessibilityIdentifier("UITest_Loading_RefreshTick")
                    Text("action_tap_count:\(viewModel.actionTapCount)")
                        .accessibilityIdentifier("UITest_Loading_ActionTapCount")
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                if viewModel.nonBlockingBanner != "none" {
                    Text(viewModel.nonBlockingBanner)
                        .foregroundColor(.orange)
                        .accessibilityIdentifier("UITest_Loading_NonBlockingBanner")
                }

                HStack(spacing: 12) {
                    Button("Manual Refresh") {
                        viewModel.triggerManualRefresh()
                    }
                    .disabled(viewModel.refreshStatus == "refreshing")
                    .accessibilityIdentifier("UITest_Loading_ManualRefreshButton")

                    Button("Try User Action") {
                        viewModel.tapUserAction()
                    }
                    .accessibilityIdentifier("UITest_Loading_UserActionButton")
                }
            }
            .padding(20)

            if viewModel.blockingOverlayVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("UITest_Loading_BlockingOverlay")
            }
        }
        .onAppear {
            viewModel.startIfNeeded()
        }
    }
}

private enum UITestTypographyAuditScreen: String {
    case achievement
    case weekTimeline = "week_timeline"
    case editCard = "edit_card"
    case paywall

    static func current() -> UITestTypographyAuditScreen {
        let raw = ProcessInfo.processInfo.environment["UITEST_TYPOGRAPHY_SCREEN"]?.lowercased()
            ?? UITestTypographyAuditScreen.achievement.rawValue
        return UITestTypographyAuditScreen(rawValue: raw) ?? .achievement
    }
}

private struct UITestTypographyAuditHostView: View {
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()

    var body: some View {
        Group {
            switch UITestTypographyAuditScreen.current() {
            case .achievement:
                MyAchievementView()
            case .weekTimeline:
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Typography Audit: Week Timeline")
                                .font(AppFont.headline())
                                .accessibilityIdentifier("UITest_Typography_Title")

                            WeekTimelineView(
                                viewModel: trainingPlanViewModel,
                                plan: Self.mockWeeklyPlan
                            )
                        }
                        .padding(20)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            case .editCard:
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Typography Audit: Edit Card")
                                .font(AppFont.headline())
                                .accessibilityIdentifier("UITest_Typography_Title")

                            auditCard(
                                title: "Interval Card",
                                subtitle: "檢查 edit schedule 裡的小 badge、pace、recovery 文案",
                                content: TrainingDetailsEditView(
                                    day: Self.mockIntervalDay,
                                    isEditable: true,
                                    onEdit: { _ in }
                                )
                            )

                            auditCard(
                                title: "Combination Card",
                                subtitle: "檢查長文案與多段配速排版",
                                content: TrainingDetailsEditView(
                                    day: Self.mockCombinationDay,
                                    isEditable: true,
                                    onEdit: { _ in }
                                )
                            )
                        }
                        .padding(20)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            case .paywall:
                NavigationStack {
                    PaywallView(trigger: .featureLocked)
                }
            }
        }
    }

    @ViewBuilder
    private func auditCard<Content: View>(title: String, subtitle: String, content: Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFont.bodyMedium())
            Text(subtitle)
                .font(AppFont.bodySmall())
                .foregroundColor(Color.primary.opacity(0.72))
            content
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }

    private static let mockWeeklyPlan = WeeklyPlan(
        id: "ui-audit-week",
        purpose: "用來巡檢日文長字串與密集資訊字級",
        weekOfPlan: 8,
        totalWeeks: 16,
        totalDistance: 54.6,
        designReason: ["UI audit fixture"],
        days: [
            TrainingDay(
                dayIndex: "0",
                dayTarget: "回復跑",
                reason: nil,
                tips: nil,
                trainingType: "recovery_run",
                trainingDetails: TrainingDetails(
                    description: "呼吸要保持輕鬆，整體節奏以恢復為主。",
                    distanceKm: 8.0,
                    totalDistanceKm: 8.0,
                    timeMinutes: nil,
                    pace: "6:15/km",
                    work: nil,
                    recovery: nil,
                    repeats: nil,
                    heartRateRange: nil,
                    segments: nil,
                    warmup: nil,
                    cooldown: nil,
                    exercises: nil,
                    supplementary: nil
                )
            ),
            TrainingDay(
                dayIndex: "1",
                dayTarget: "巡航間歇",
                reason: nil,
                tips: nil,
                trainingType: "interval",
                trainingDetails: TrainingDetails(
                    description: "長めの巡航間歇で乳酸閾値を刺激しながら、フォームの再現性も維持する。",
                    distanceKm: nil,
                    totalDistanceKm: 12.6,
                    timeMinutes: nil,
                    pace: nil,
                    work: nil,
                    recovery: nil,
                    repeats: nil,
                    heartRateRange: nil,
                    segments: nil,
                    warmup: nil,
                    cooldown: nil,
                    exercises: nil,
                    supplementary: nil
                )
            ),
            TrainingDay(
                dayIndex: "2",
                dayTarget: "休息日",
                reason: nil,
                tips: nil,
                trainingType: "rest",
                trainingDetails: TrainingDetails(
                    description: "完全休養日。必要なら軽いストレッチだけ。",
                    distanceKm: nil,
                    totalDistanceKm: nil,
                    timeMinutes: nil,
                    pace: nil,
                    work: nil,
                    recovery: nil,
                    repeats: nil,
                    heartRateRange: nil,
                    segments: nil,
                    warmup: nil,
                    cooldown: nil,
                    exercises: nil,
                    supplementary: nil
                )
            ),
            TrainingDay(
                dayIndex: "3",
                dayTarget: "比賽配速跑",
                reason: nil,
                tips: nil,
                trainingType: "race_pace",
                trainingDetails: TrainingDetails(
                    description: "目標是在後半段也能維持穩定的半馬配速與姿勢。",
                    distanceKm: nil,
                    totalDistanceKm: 14.0,
                    timeMinutes: nil,
                    pace: nil,
                    work: nil,
                    recovery: nil,
                    repeats: nil,
                    heartRateRange: nil,
                    segments: nil,
                    warmup: nil,
                    cooldown: nil,
                    exercises: nil,
                    supplementary: nil
                )
            )
        ],
        intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 140, medium: 55, high: 20)
    )

    private static let mockIntervalDay = MutableTrainingDay(
        dayIndex: "1",
        dayTarget: "巡航間歇で閾値刺激を入れる",
        trainingType: "interval",
        trainingDetails: MutableTrainingDetails(
            description: "乳酸閾値を狙う主訓練。每一組都要維持穩定輸出，不要前快後崩。",
            totalDistanceKm: 11.2,
            work: MutableWorkoutSegment(
                description: "Cruise",
                timeMinutes: 5,
                pace: "4:35/km"
            ),
            recovery: MutableWorkoutSegment(
                description: "Jog",
                timeSeconds: 90,
                pace: "6:30/km"
            ),
            repeats: 5
        )
    )

    private static let mockCombinationDay = MutableTrainingDay(
        dayIndex: "4",
        dayTarget: "組合訓練：由輕鬆跑逐步推進到節奏跑",
        trainingType: "combination",
        trainingDetails: MutableTrainingDetails(
            description: "前段控制呼吸與步頻，中段進入穩定節奏，最後一段只微幅提速，不追求爆發。",
            totalDistanceKm: 13.5,
            segments: [
                MutableProgressionSegment(distanceKm: 4.0, pace: "5:55/km", description: "輕鬆暖身"),
                MutableProgressionSegment(distanceKm: 5.0, pace: "5:05/km", description: "穩定節奏"),
                MutableProgressionSegment(distanceKm: 4.5, pace: "4:45/km", description: "接近比賽配速")
            ]
        )
    )
}
#endif

// MARK: - 背景任務排程

func scheduleBackgroundWorkoutSync() {
    // 只有 Apple Health 用戶才需要背景同步任務
    let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
    guard dataSourcePreference == .appleHealth else {
        print("數據來源為 \(dataSourcePreference.displayName)，跳過背景同步任務排程")
        return
    }
    
    let taskIdentifier = "com.havital.workout-sync"
    
    let request = BGProcessingTaskRequest(identifier: taskIdentifier)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    
    // 至少 2 小時後執行
    request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
    
    do {
        try BGTaskScheduler.shared.submit(request)
        print("已安排背景健身記錄同步任務")
    } catch {
        print("無法安排背景同步任務: \(error.localizedDescription)")
    }
}

// Clean Architecture: 擴展 AuthenticationViewModel 以追蹤第一次登入狀態
extension AuthenticationViewModel {
    var isFirstLogin: Bool {
        get {
            UserDefaults.standard.bool(forKey: "isFirstLogin")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isFirstLogin")
        }
    }
}

class FirebaseLogConfigurator {
    static func setup() {
        // Option 1: Set minimum log level globally - this will hide most logs
        FirebaseConfiguration.shared.setLoggerLevel(.error)
        
        // Option 2: Set App Check specific environment variable to disable verbose debug logs
        setenv("FIRAppCheckDebugDisabled", "1", 1)
        
        // Option 3: Use OS_LOG_DEFAULT level control
        if #available(iOS 14.0, *) {
            // On iOS 14+, you can use more granular log filtering through the Console app
            // Add this as a launch argument for your app:
            // -OSLogPreferences OSLogPreferences.plist
            // Create a plist file that filters FirebaseAppCheck logs
        }
    }
}
