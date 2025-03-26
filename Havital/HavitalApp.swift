import SwiftUI
import HealthKit
import FirebaseCore
import FirebaseAppCheck
import BackgroundTasks
import UserNotifications

@main
struct HavitalApp: App {
    // 不再使用 AppStorage 來儲存 onboarding 狀態，而是使用 AuthenticationService 提供的狀態
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var authService = AuthenticationService.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        FirebaseLogConfigurator.setup()
        
        // 註冊背景任務
        registerBackgroundTasks()
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
        
        // 設置健身記錄觀察者（已經在主界面，所以已確認用戶登入且完成引導）
        print("設置健身記錄觀察者...")
        await WorkoutBackgroundManager.shared.setupWorkoutObserver()
        
        // 主動檢查待上傳記錄
        print("檢查待上傳健身記錄...")
        await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()
        
        // 安排背景工作
        scheduleBackgroundWorkoutSync()
    }
    
    private func registerBackgroundTasks() {
        let taskIdentifier = "com.havital.workout-sync"
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            Task {
                // 確保用戶已登入
                guard AuthenticationService.shared.isAuthenticated else {
                    (task as? BGProcessingTask)?.setTaskCompleted(success: false)
                    return
                }
                
                // 執行背景同步
                await WorkoutBackgroundManager.shared.checkAndUploadPendingWorkouts()
                
                // 標記任務完成並安排下一次執行
                (task as? BGProcessingTask)?.setTaskCompleted(success: true)
                scheduleBackgroundWorkoutSync()
            }
        }
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
