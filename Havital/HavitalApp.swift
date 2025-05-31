import SwiftUI
import HealthKit
import FirebaseCore
import FirebaseAppCheck
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
    // 不再使用 AppStorage 來儲存 onboarding 狀態，而是使用 AuthenticationService 提供的狀態
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var authService = AuthenticationService.shared
    
    init() {
        // 1. 先嘗試從 Bundle 載入 Firebase 設定檔
        var firebaseConfigPath: String?
        
        // 先檢查是否已經有複製的 GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            firebaseConfigPath = path
            print("ℹ️ 找到 Firebase 設定檔: \(path)")
        }
        // 如果沒有，嘗試直接載入特定環境的設定檔
        else if let path = Bundle.main.path(forResource: "GoogleService-Info-" + (isDebugBuild ? "dev" : "prod"), ofType: "plist") {
            firebaseConfigPath = path
            print("ℹ️ 找到環境特定的 Firebase 設定檔: \(path)")
        }
        
        // 2. 初始化 Firebase
        if let path = firebaseConfigPath, let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
            print("✅ Firebase 初始化成功 - 使用: \(path)")
        } else {
            // 如果所有方法都失敗，嘗試使用預設初始化（會讀取預設位置的 GoogleService-Info.plist）
            print("⚠️ 無法載入 Firebase 設定檔，嘗試預設初始化...")
            FirebaseApp.configure()
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
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !authService.isAuthenticated {
                LoginView()
                    .environmentObject(appViewModel)
            } else if !authService.hasCompletedOnboarding {
                OnboardingView()
                   .environmentObject(appViewModel)
            } else {
                TabView {
                    TrainingPlanView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "figure.run")
                            Text("訓練計劃")
                        }
                    
                    TrainingRecordView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "chart.line.text.clipboard")
                            Text("訓練紀錄")
                        }
                    
                    MyAchievementView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            Text("表現數據")
                        }
                }
                .onAppear {
                    // 當主畫面出現時，一次性請求所有必要權限並設置背景處理
                    setupAllPermissionsAndBackgroundProcessing()
                }
                .alert("需要健康資料權限", isPresented: $appViewModel.showHealthKitAlert) {
                    Button("前往設定", role: .none) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text(appViewModel.healthKitAlertMessage)
                }
            }
        }
        // 添加應用程式生命週期事件處理
        .onChange(of: UIApplication.shared.applicationState) { state in
            if state == .active {
                // 應用進入前景
                print("應用進入前景")
                Task {
                    await checkForPendingHealthUpdates()
                }
            }
        }
    }
    
    /// 一次性請求所有必要的權限並設置背景處理
    private func setupAllPermissionsAndBackgroundProcessing() {
        Task {
            // 1. 請求 HealthKit 授權
            await requestHealthKitAuthorization()
            
            // 2. 請求通知授權（這是 WorkoutBackgroundManager 需要的）
            await requestNotificationAuthorization()
            
            // 3. 設置背景健身記錄同步（包括觀察者）
            await setupWorkoutBackgroundProcessing()
            
            // 4. 檢查是否有待處理的健身記錄
            await checkForPendingHealthUpdates()
        }
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
        
        // 設置健身記錄觀察者（已經在主界面，所以已確認用戶登入且完成引導）
        print("設置健身記錄觀察者...")
        await WorkoutBackgroundManager.shared.setupWorkoutObserver()
        
        // 安排背景工作
        scheduleBackgroundWorkoutSync()
    }
    
    // 檢查是否有待處理的健身記錄
    private func checkForPendingHealthUpdates() async {
        // 確保用戶已登入且完成引導
        guard authService.isAuthenticated && authService.hasCompletedOnboarding else {
            return
        }
        
        // 主動檢查待上傳記錄
        print("檢查待上傳健身記錄...")
        await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()
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
}

// MARK: - 背景任務排程

func scheduleBackgroundWorkoutSync() {
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
