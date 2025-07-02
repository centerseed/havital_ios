import SwiftUI

class AppViewModel: ObservableObject {
    @Published var showHealthKitAlert = false
    @Published var healthKitAlertMessage = ""
    
    // 新增 Garmin 數據源不一致相關的狀態
    @Published var showGarminMismatchAlert = false
    @Published var isHandlingGarminMismatch = false
    
    // 統一的運動數據管理器
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
    
    /// App 啟動時的初始化
    func initializeApp() async {
        await unifiedWorkoutManager.initialize()
        await unifiedWorkoutManager.loadWorkouts()
    }
    
    /// App 回到前台時刷新數據
    func onAppBecameActive() async {
        await unifiedWorkoutManager.refreshWorkouts()
    }
    
    /// 手動刷新數據（下拉刷新等）
    func refreshData() async {
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
