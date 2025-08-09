import SwiftUI

class AppViewModel: ObservableObject {
    @Published var showHealthKitAlert = false
    @Published var healthKitAlertMessage = ""
    
    // 新增 Garmin 數據源不一致相關的狀態
    @Published var showGarminMismatchAlert = false
    @Published var isHandlingGarminMismatch = false
    
    // 使用新的狀態管理中心
    private let appStateManager = AppStateManager.shared
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared
    
    init() {
        // 監聽 HealthKit 權限提示通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowHealthKitPermissionAlert"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let message = notification.userInfo?["message"] as? String {
                self?.healthKitAlertMessage = message
                self?.showHealthKitAlert = true
            }
        }
        
        // 監聽 Garmin 數據源不一致通知
        NotificationCenter.default.addObserver(
            forName: .garminDataSourceMismatch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("收到 Garmin 數據源不一致通知，顯示重新綁定對話框")
            self?.showGarminMismatchAlert = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - App 生命週期管理
    
    /// App 啟動時的初始化 - 委託給 AppStateManager
    func initializeApp() async {
        print("📱 AppViewModel: 開始委託 AppStateManager 初始化")
        
        // 註冊所有快取管理器
        registerCacheManagers()
        
        // 委託給 AppStateManager 進行完整初始化
        await appStateManager.initializeApp()
        
        print("✅ AppViewModel: 初始化委託完成")
    }
    
    /// 註冊所有快取管理器到快取事件總線
    private func registerCacheManagers() {
        CacheEventBus.shared.register(WorkoutV2CacheManager.shared)
        CacheEventBus.shared.register(TrainingPlanStorage.shared)
        CacheEventBus.shared.register(TargetStorage.shared)
        CacheEventBus.shared.register(WeeklySummaryStorage.shared)
        
        Logger.firebase("所有快取管理器已註冊到 CacheEventBus", level: .info, labels: [
            "module": "AppViewModel",
            "action": "register_cache_managers"
        ])
    }
    
    /// App 回到前台時刷新數據
    func onAppBecameActive() async {
        // 只有在 App 就緒狀態才執行刷新
        guard await appStateManager.currentState.isReady else {
            print("⚠️ AppViewModel: App 未就緒，跳過前台刷新")
            return
        }
        
        await unifiedWorkoutManager.refreshWorkouts()
    }
    
    /// 手動刷新數據（下拉刷新等）
    func refreshData() async {
        // 只有在 App 就緒狀態才執行刷新
        guard await appStateManager.currentState.isReady else {
            print("⚠️ AppViewModel: App 未就緒，跳過手動刷新")
            return
        }
        
        await unifiedWorkoutManager.refreshWorkouts()
    }
    
    // MARK: - Garmin 數據源處理方法
    
    /// 用戶選擇重新綁定 Garmin
    func reconnectGarmin() {
        isHandlingGarminMismatch = true
        Task {
            await GarminManager.shared.startConnection()
            
            // 切換到 Garmin 數據來源
            await unifiedWorkoutManager.switchDataSource(to: .garmin)
            
            await MainActor.run {
                isHandlingGarminMismatch = false
                showGarminMismatchAlert = false
            }
        }
    }
    
    /// 用戶選擇切換回 Apple Health
    func switchToAppleHealth() {
        isHandlingGarminMismatch = true
        Task {
            do {
                // 先解除Garmin綁定
                if GarminManager.shared.isConnected {
                    do {
                        try await GarminDisconnectService.shared.disconnectGarmin()
                        print("Garmin解除綁定成功")
                        
                        // 本地斷開Garmin連接（不再呼叫後端）
                        await GarminManager.shared.disconnect(remote: false)
                        
                    } catch {
                        print("Garmin解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await GarminManager.shared.disconnect(remote: false)
                    }
                }
                
                // 先同步到後端
                try await UserService.shared.updateDataSource(DataSourceType.appleHealth.rawValue)
                
                // 使用 UnifiedWorkoutManager 切換數據來源
                await unifiedWorkoutManager.switchDataSource(to: .appleHealth)
                
                await MainActor.run {
                    print("已切換到 Apple Health 並同步到後端")
                    
                    isHandlingGarminMismatch = false
                    showGarminMismatchAlert = false
                }
            } catch {
                print("切換到 Apple Health 失敗: \(error.localizedDescription)")
                await MainActor.run {
                    isHandlingGarminMismatch = false
                    // 保持對話框開啟，讓用戶可以重試
                }
            }
        }
    }
}
