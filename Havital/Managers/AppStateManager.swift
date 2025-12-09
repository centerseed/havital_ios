import Foundation
import SwiftUI

/// App 狀態管理中心 - 統一管理用戶狀態和初始化流程
@MainActor
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    /// App 狀態枚舉
    enum AppState: Equatable {
        case initializing                    // 初始化中
        case authenticating                  // 認證中
        case loadingUserData                // 載入用戶資料中
        case settingUpServices              // 設置服務中
        case ready                          // 就緒
        case error(String)                  // 錯誤狀態
        
        var description: String {
            switch self {
            case .initializing: return "初始化中..."
            case .authenticating: return "驗證用戶身份..."
            case .loadingUserData: return "載入用戶資料..."
            case .settingUpServices: return "設置服務中..."
            case .ready: return "就緒"
            case .error(let message): return "錯誤: \(message)"
            }
        }
        
        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }
    
    /// 用戶訂閱狀態
    enum SubscriptionStatus: String, CaseIterable {
        case free = "free"
        case premium = "premium"
        case expired = "expired"
        
        var displayName: String {
            switch self {
            case .free: return "免費版"
            case .premium: return "付費版"
            case .expired: return "已過期"
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var currentState: AppState = .initializing
    @Published var isUserAuthenticated = false
    @Published var userDataSource: DataSourceType = .unbound
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var initializationProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private var authService: AuthenticationService?
    private var userService: UserService?
    private var unifiedWorkoutManager: UnifiedWorkoutManager?
    private var healthDataUploadManager: HealthDataUploadManagerV2?
    
    private init() {
        print("🏁 AppStateManager: 已初始化")
    }
    
    // MARK: - Public Methods
    
    /// 完整的 App 初始化流程
    func initializeApp() async {
        print("🚀 AppStateManager: 開始完整初始化流程")

        do {
            // Phase 1: 認證檢查
            currentState = .authenticating
            initializationProgress = 0.1
            await TrackedTask("AppStateManager: authenticateUser") { [self] in
                await self.authenticateUser()
            }.value

            // Phase 2: 載入用戶資料
            currentState = .loadingUserData
            initializationProgress = 0.3
            await TrackedTask("AppStateManager: loadUserData") { [self] in
                await self.loadUserData()
            }.value

            // Phase 3: 設置服務
            currentState = .settingUpServices
            initializationProgress = 0.6
            await TrackedTask("AppStateManager: setupServices") { [self] in
                await self.setupServices()
            }.value

            // Phase 4: 完成初始化
            initializationProgress = 1.0
            currentState = .ready

            print("✅ AppStateManager: 初始化完成")
            Logger.firebase("App 初始化完成", level: .info, labels: [
                "module": "AppStateManager",
                "action": "initialize_complete",
                "data_source": userDataSource.rawValue,
                "subscription": subscriptionStatus.rawValue
            ])

        } catch {
            // 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("App 初始化任務被取消，忽略錯誤")
                return
            }

            print("❌ AppStateManager: 初始化失敗 - \(error.localizedDescription)")
            currentState = .error(error.localizedDescription)

            Logger.firebase("App 初始化失敗", level: .error, labels: [
                "module": "AppStateManager",
                "action": "initialize_failed"
            ], jsonPayload: [
                "error": error.localizedDescription
            ])
        }
    }
    
    /// 重新初始化（用於錯誤恢復）
    func reinitialize() async {
        print("🔄 AppStateManager: 重新初始化")
        await TrackedTask("AppStateManager: reinitialize") { [self] in
            currentState = .initializing
            initializationProgress = 0.0
            await self.initializeApp()
        }.value
    }
    
    /// 處理數據源變更
    func handleDataSourceChange(to newDataSource: DataSourceType) async {
        print("🔄 AppStateManager: 處理數據源變更到 \(newDataSource.rawValue)")
        
        guard currentState.isReady else {
            print("⚠️ AppStateManager: App 未就緒，無法變更數據源")
            return
        }
        
        // 更新數據源
        userDataSource = newDataSource
        UserPreferenceManager.shared.dataSourcePreference = newDataSource
        
        // 重新設置服務
        currentState = .settingUpServices
        await setupServices()
        currentState = .ready
        
        print("✅ AppStateManager: 數據源變更完成")
    }
    
    /// 檢查功能權限
    func hasPermission(for feature: String) -> Bool {
        // 基礎功能檢查
        guard isUserAuthenticated && currentState.isReady else {
            return false
        }
        
        // 付費功能檢查
        let premiumFeatures = ["advanced_analytics", "custom_training_plans", "unlimited_sync"]
        if premiumFeatures.contains(feature) {
            return subscriptionStatus == .premium
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    /// Phase 1: 用戶認證
    private func authenticateUser() async {
        print("🔐 AppStateManager: 開始用戶認證")
        
        authService = AuthenticationService.shared
        
        // 檢查認證狀態
        isUserAuthenticated = authService?.isAuthenticated ?? false
        
        if !isUserAuthenticated {
            print("⚠️ AppStateManager: 用戶未認證")
            // 這裡可以觸發登入流程或者允許訪客模式
        }
        
        print("✅ AppStateManager: 認證檢查完成 - 已認證: \(isUserAuthenticated)")
    }
    
    /// Phase 2: 載入用戶資料
    private func loadUserData() async {
        print("📥 AppStateManager: 開始載入用戶資料")
        
        guard isUserAuthenticated else {
            print("⚠️ AppStateManager: 用戶未認證，跳過資料載入")
            userDataSource = .unbound
            subscriptionStatus = .free
            return
        }
        
        do {
            userService = UserService.shared
            
            print("📥 AppStateManager: 從後端 User API 獲取用戶資料...")
            
            // 🚨 正確的流程：從後端 User API 獲取用戶的實際數據源設定
            let user = try await userService!.getUserProfile().async()
            
            print("📥 AppStateManager: 成功獲取用戶資料")
            print("   - 後端數據源: \(user.dataSource ?? "未設定")")
            
            // 同步用戶偏好設定（包括數據源）
            userService!.syncUserPreferences(with: user)

            // 🔥 重要：將用戶資料設置到 UserManager
            await UserManager.shared.updateCurrentUser(user)

            // 使用同步後的數據源設定
            userDataSource = UserPreferenceManager.shared.dataSourcePreference
            subscriptionStatus = .free // 暫時設為免費版，未來可從 user.data 中獲取

            print("✅ AppStateManager: 用戶資料同步完成")
            print("   - 最終數據源: \(userDataSource.rawValue)")
            print("   - 訂閱狀態: \(subscriptionStatus.rawValue)")
            print("   - UserManager.currentUser 已設置: \(UserManager.shared.currentUser != nil)")
            
        } catch {
            // 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("載入用戶資料任務被取消，忽略錯誤")
                return
            }

            print("❌ AppStateManager: 載入用戶資料失敗 - \(error.localizedDescription)")
            print("   使用本地設定作為備用")

            // 使用本地設定作為備用
            userDataSource = UserPreferenceManager.shared.dataSourcePreference
            subscriptionStatus = .free

            Logger.firebase("用戶資料載入失敗，使用本地設定", level: .error, labels: [
                "module": "AppStateManager",
                "action": "load_user_data_fallback"
            ], jsonPayload: [
                "error": error.localizedDescription,
                "fallback_data_source": userDataSource.rawValue
            ])
        }
    }
    
    /// Phase 3: 設置服務
    private func setupServices() async {
        print("⚙️ AppStateManager: 開始設置服務")
        
        // 初始化核心服務
        unifiedWorkoutManager = UnifiedWorkoutManager.shared
        healthDataUploadManager = HealthDataUploadManagerV2.shared
        
        // 根據用戶狀態初始化服務
        if isUserAuthenticated {
            // 初始化運動管理器
            await unifiedWorkoutManager?.initialize()
            await unifiedWorkoutManager?.loadWorkouts()
            
            // 啟動健康數據同步
            await APICallTracker.$currentSource.withValue("AppStateManager: setupServices") {
                await healthDataUploadManager?.initialize()
            }
            
            print("✅ AppStateManager: 已認證用戶服務設置完成")
        } else {
            print("ℹ️ AppStateManager: 訪客模式，跳過需認證的服務")
        }
        
        print("✅ AppStateManager: 服務設置完成")
    }
}

// MARK: - Extensions

extension AppStateManager {
    /// 獲取初始化狀態描述
    var statusDescription: String {
        let progress = Int(initializationProgress * 100)
        return "\(currentState.description) (\(progress)%)"
    }
    
    /// 是否顯示載入畫面
    var shouldShowLoadingScreen: Bool {
        !currentState.isReady
    }
}