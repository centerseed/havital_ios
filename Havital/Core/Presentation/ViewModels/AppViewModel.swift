import SwiftUI

@MainActor
class AppViewModel: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()

    @Published var showHealthKitAlert = false
    @Published var healthKitAlertMessage = ""

    // 新增 Garmin 數據源不一致相關的狀態
    @Published var showGarminMismatchAlert = false
    @Published var isHandlingGarminMismatch = false

    // 新增數據源未綁定相關的狀態
    @Published var showDataSourceNotBoundAlert = false

    // 使用新的狀態管理中心
    private let appStateManager: any AppStateManagerProtocol
    private let workoutRepository: WorkoutRepository

    // MARK: - Clean Architecture Dependencies
    private var userProfileRepository: UserProfileRepository {
        DependencyContainer.shared.resolve()
    }

    init(
        appStateManager: any AppStateManagerProtocol = AppStateManager.shared,
        workoutRepository: WorkoutRepository = DependencyContainer.shared.resolve()
    ) {
        self.appStateManager = appStateManager
        self.workoutRepository = workoutRepository
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

        // 監聽數據源未綁定通知
        NotificationCenter.default.addObserver(
            forName: .dataSourceNotBound,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("收到數據源未綁定通知，顯示綁定提示對話框")
            self?.showDataSourceNotBoundAlert = true
        }
    }
    
    deinit {
        cancelAllTasks()
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
        CacheEventBus.shared.register(WorkoutV2CacheManager.shared) // 暫時保留，直到完全移除
        CacheEventBus.shared.register(TrainingPlanStorage.shared)
        CacheEventBus.shared.register(TargetStorage.shared)
        CacheEventBus.shared.register(WeeklySummaryStorage.shared)
        // WorkoutRepository 的 LocalDataSource 不需要在此註冊，因為它自己管理過期
        
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
        
        _ = try? await workoutRepository.refreshWorkouts()
    }
    
    /// 手動刷新數據（下拉刷新等）
    func refreshData() async {
        // 只有在 App 就緒狀態才執行刷新
        guard await appStateManager.currentState.isReady else {
            print("⚠️ AppViewModel: App 未就緒，跳過手動刷新")
            return
        }
        
        _ = try? await workoutRepository.refreshWorkouts()
    }
    
    // MARK: - Garmin 數據源處理方法
    
    /// 用戶選擇重新綁定 Garmin
    func reconnectGarmin() {
        isHandlingGarminMismatch = true
        Task { @MainActor in
            await GarminManager.shared.startConnection()

            // 切換到 Garmin 數據來源
            await switchDataSource(to: .garmin)

            isHandlingGarminMismatch = false
            showGarminMismatchAlert = false
        }
    }
    
    /// 用戶選擇切換回 Apple Health
    func switchToAppleHealth() {
        isHandlingGarminMismatch = true
        Task { @MainActor in
            do {
                // 先解除Garmin綁定
                let isGarminConnected = GarminManager.shared.isConnected
                if isGarminConnected {
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

                // 先同步到後端 (Clean Architecture: ViewModel → Repository)
                try await userProfileRepository.updateDataSource(DataSourceType.appleHealth.rawValue)

                // 切換數據來源
                await switchDataSource(to: .appleHealth)

                print("已切換到 Apple Health 並同步到後端")

                isHandlingGarminMismatch = false
                showGarminMismatchAlert = false
            } catch {
                print("切換到 Apple Health 失敗: \(error.localizedDescription)")
                isHandlingGarminMismatch = false
                // 保持對話框開啟，讓用戶可以重試
            }
        }
    }
    
    /// 私有輔助方法：切換數據源
    private func switchDataSource(to newSource: DataSourceType) async {
        // 1. 更新本地偏好設置
        UserPreferencesManager.shared.dataSourcePreference = newSource
        
        // 2. 清除舊數據源的緩存
        await workoutRepository.clearCache()
        
        // 3. 刷新數據（這會觸發使用新數據源的加載）
        _ = try? await workoutRepository.refreshWorkouts()
    }
}
