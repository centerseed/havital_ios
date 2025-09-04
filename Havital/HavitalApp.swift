import SwiftUI
import HealthKit
import FirebaseCore
import FirebaseAppCheck
import FirebaseRemoteConfig
import BackgroundTasks
import UserNotifications

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
    // 不再使用 AppStorage 來儲存 onboarding 狀態，而是使用 AuthenticationService 提供的狀態
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var authService = AuthenticationService.shared
    @State private var featureFlagManager: FeatureFlagManager? = nil
    @State private var shouldRefreshForLanguage = false
    
    init() {
        // 1. 初始化 Firebase（必須最先執行，因為 Logger 依賴它）
        let configFileName = "GoogleService-Info-" + (isDebugBuild ? "dev" : "prod")
        print("🔍 當前建置環境: \(isDebugBuild ? "DEBUG" : "PRODUCTION")")
        print("🔍 嘗試使用 Firebase 配置文件: \(configFileName)")
        
        // 首先嘗試標準的 GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            print("✅ 找到標準 Firebase 配置文件: \(path)")
            FirebaseApp.configure()
        } else {
            // 如果沒有標準文件，嘗試環境特定的文件
            if let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
                print("✅ Firebase 初始化成功 - 使用: \(path)")
                print("✅ Firebase Project ID: \(options.projectID ?? "unknown")")
                print("✅ Bundle ID: \(options.bundleID ?? "unknown")")
            } else {
                print("❌ 找不到環境特定的 Firebase 配置文件: \(configFileName)")
                // 最後的備用方案
                FirebaseApp.configure()
            }
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
            
            // 7. Firebase 初始化完成後才創建 FeatureFlagManager
            // 注意：這裡不能直接設定 @State 變數，需要在 view 中設定
        }
        
        // 7. 檢查是否因語言變更而重啟
        checkLanguageChangeRestart()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let featureFlagManager = featureFlagManager {
                    ContentView() // 使用 ContentView 作為根視圖
                        .environmentObject(authService)       // 注入 AuthenticationService
                        .environmentObject(healthKitManager)  // 注入 HealthKitManager
                        .environmentObject(appViewModel)      // 注入 AppViewModel
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
        // 添加應用程式生命週期事件處理
        .onChange(of: UIApplication.shared.applicationState) { state in
            if state == .active {
                // 應用進入前景，使用統一的數據刷新
                print("應用進入前景")
                Task {
                    await appViewModel.onAppBecameActive()
                    // 注意：舊的 Auth 同步邏輯已移除，統一使用 UnifiedWorkoutManager
                }
            }
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
        
        if isAuthenticated {
            // 已認證用戶的權限設置
            switch dataSource {
            case .appleHealth:
                print("🍎 設置 Apple Health 用戶權限")
                // 1. 請求 HealthKit 授權
                await requestHealthKitAuthorization()
                
                // 2. 請求通知授權
                await requestNotificationAuthorization()
                
                // 3. 設置背景健身記錄同步
                await setupWorkoutBackgroundProcessing()
                
                // 4. setupWorkoutObserver 內部已包含上傳檢查，無需重複調用
                // await checkForPendingHealthUpdates() // 已移除重複調用
                
            case .garmin:
                print("⌚ 設置 Garmin 用戶權限")
                // 只需要通知授權
                await requestNotificationAuthorization()
                
            case .strava:
                print("🏃 設置 Strava 用戶權限")
                // 只需要通知授權
                await requestNotificationAuthorization()
                
            case .unbound:
                print("🔓 用戶未綁定數據源，設置基本權限")
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
        await HealthDataUploadManager.shared.startHealthDataSync()
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
        if authService.isFirstLogin {
            WorkoutBackgroundManager.shared.markFirstLogin()
            authService.isFirstLogin = false
        }
        
        // 🚨 關鍵修復：只有 Apple Health 用戶才設置觀察者
        let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
        if dataSourcePreference == .appleHealth {
            print("設置健身記錄觀察者（Apple Health 用戶）...")
            await WorkoutBackgroundManager.shared.setupWorkoutObserver()
        } else {
            print("跳過健身記錄觀察者設置（數據源: \(dataSourcePreference.displayName)）")
            // 確保停止任何可能已經啟動的觀察者
            WorkoutBackgroundManager.shared.stopAndCleanupObserving()
        }
        
        // 安排背景工作 (scheduleBackgroundWorkoutSync 內部會檢查數據來源)
        scheduleBackgroundWorkoutSync()
    }
    
    // 檢查是否有待處理的健身記錄
    private func checkForPendingHealthUpdates() async {
        // 確保用戶已登入且完成引導
        guard authService.isAuthenticated && authService.hasCompletedOnboarding else {
            return
        }
        
        // 再次確認數據來源（WorkoutBackgroundManager 內部也會檢查）
        let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
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
        let taskIdentifier = "com.havital.workout-sync"
        
        // 先取消現有的所有任務請求
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        // 註冊背景處理任務
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            // 背景同步任務
            print("背景任務開始執行")
            
            // 設置任務到期處理
            task.expirationHandler = {
                print("背景健身記錄同步任務到期")
            }
            
            Task {
                // 確保用戶已登入
                guard AuthenticationService.shared.isAuthenticated else {
                    (task as? BGProcessingTask)?.setTaskCompleted(success: false)
                    return
                }
                
                // 確認當前數據來源是 Apple Health
                let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
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
    
    /// 檢查是否因語言變更而重啟
    private func checkLanguageChangeRestart() {
        if UserDefaults.standard.bool(forKey: "language_changed_restart") {
            // 清除標記
            UserDefaults.standard.removeObject(forKey: "language_changed_restart")
            
            // 可以在這裡添加額外的語言變更後處理邏輯
            print("🌍 App 因語言變更而重啟")
        }
    }
}

// MARK: - 背景任務排程

func scheduleBackgroundWorkoutSync() {
    // 只有 Apple Health 用戶才需要背景同步任務
    let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
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

// 擴展 AuthenticationService 以追蹤第一次登入狀態
extension AuthenticationService {
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
