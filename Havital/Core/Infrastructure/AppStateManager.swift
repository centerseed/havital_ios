import Foundation
import SwiftUI
import Combine

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
    
    /// App 層本地使用的精簡訂閱狀態
    enum LocalSubscriptionStatus: String, CaseIterable {
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
    @Published var subscriptionStatus: LocalSubscriptionStatus = .free
    @Published var initializationProgress: Double = 0.0
    
    // MARK: - Private Properties

    // Clean Architecture: Use AuthSessionRepository instead of AuthenticationService
    private let authSessionRepository: AuthSessionRepository
    private var userService: UserService?
    private let workoutRepository: WorkoutRepository
    private var healthDataUploadManager: HealthDataUploadManagerV2?

    // Lazy resolve: SubscriptionRepository 在 DI 註冊完成後才可用
    private var subscriptionRepository: SubscriptionRepository {
        DependencyContainer.shared.resolve()
    }

    private var analyticsService: AnalyticsService {
        DependencyContainer.shared.resolve()
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Initialize repositories via DI
        self.authSessionRepository = DependencyContainer.shared.resolve()
        self.workoutRepository = DependencyContainer.shared.resolve()
        print("🏁 AppStateManager: 已初始化")

        // Keep the GA4 subscription_status user property in sync with live state changes.
        SubscriptionStateManager.shared.$currentStatus
            .compactMap { $0 }
            .removeDuplicates { $0.status == $1.status }
            .sink { [weak self] entity in
                guard let self else { return }
                let statusString = analyticsStatusString(for: entity.status)
                self.analyticsService.setUserProperty(statusString, forName: "subscription_status")
            }
            .store(in: &cancellables)
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

            trackAppOpen()

            print("✅ AppStateManager: 初始化完成")
            Logger.firebase("App 初始化完成", level: .info, labels: [
                "module": "AppStateManager",
                "action": "initialize_complete",
                "cloud_logging": "true",
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
        UserPreferencesManager.shared.dataSourcePreference = newDataSource
        
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

        // Clean Architecture: Use AuthSessionRepository instead of AuthenticationService
        isUserAuthenticated = authSessionRepository.isAuthenticated()

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
            await SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
            return
        }
        
        do {
            userService = UserService.shared
            
            print("📥 AppStateManager: 從後端 User API 獲取用戶資料...")

            // 🚨 正確的流程：從後端 User API 獲取用戶的實際數據源設定
            guard let userService = userService else {
                Logger.firebase("UserService 未初始化", level: .error, labels: [
                    "module": "AppStateManager",
                    "action": "load_user_data"
                ])
                throw NSError(domain: "AppStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "UserService 未初始化"])
            }
            let user = try await userService.getUserProfileAsync()

            print("📥 AppStateManager: 成功獲取用戶資料")
            print("   - 後端數據源: \(user.dataSource ?? "未設定")")

            // 同步用戶偏好設定（包括數據源）
            userService.syncUserPreferences(with: user)

            // 🔥 重要：將用戶資料保存到本地快取（Clean Architecture）
            UserProfileLocalDataSource().saveUserProfile(user)

            // 使用同步後的數據源設定
            userDataSource = UserPreferencesManager.shared.dataSourcePreference

            // 從 API 拉取訂閱狀態（更新 SubscriptionStateManager + 本地緩存）
            await loadSubscriptionStatus()

            print("✅ AppStateManager: 用戶資料同步完成")
            print("   - 最終數據源: \(userDataSource.rawValue)")
            print("   - 訂閱狀態: \(subscriptionStatus.rawValue)")
            print("   - UserProfile cache 已設置: \(UserProfileLocalDataSource().getUserProfile() != nil)")
            
        } catch {
            // 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("載入用戶資料任務被取消，忽略錯誤")
                return
            }

            print("❌ AppStateManager: 載入用戶資料失敗 - \(error.localizedDescription)")
            print("   使用本地設定作為備用")

            // 使用本地設定作為備用
            userDataSource = UserPreferencesManager.shared.dataSourcePreference
            // 嘗試用 cached subscription status，避免離線時誤顯示免費
            await loadSubscriptionStatus()

            Logger.firebase("用戶資料載入失敗，使用本地設定", level: .error, labels: [
                "module": "AppStateManager",
                "action": "load_user_data_fallback"
            ], jsonPayload: [
                "error": error.localizedDescription,
                "fallback_data_source": userDataSource.rawValue
            ])
        }
    }
    
    /// 載入訂閱狀態（優先直打 API，失敗才回退緩存）
    /// 符合 ADR：後端 status API 為 SSOT，本地 cache 只作離線 fallback
    private func loadSubscriptionStatus() async {
        do {
            let status = try await subscriptionRepository.refreshStatus()
            subscriptionStatus = resolveLocalSubscriptionStatus(from: status)
            Logger.debug("[AppStateManager] 訂閱狀態載入成功（backend refresh）: \(status.status.rawValue)")
        } catch {
            // API 失敗時才回退到本地 cache，避免冷啟動先吃舊狀態
            if let cached = subscriptionRepository.getCachedStatus() {
                subscriptionStatus = resolveLocalSubscriptionStatus(from: cached)
                Logger.debug("[AppStateManager] backend refresh 失敗，使用緩存訂閱狀態: \(cached.status.rawValue)")
            } else {
                subscriptionStatus = .free
                Logger.debug("[AppStateManager] 無訂閱資訊，預設免費")
            }
        }
    }

    /// 將 Domain Entity 的訂閱狀態映射為 AppStateManager 的本地枚舉
    private func resolveLocalSubscriptionStatus(from entity: SubscriptionStatusEntity) -> LocalSubscriptionStatus {
        switch entity.status {
        case .active, .trial, .gracePeriod:
            return .premium
        case .cancelled:
            // cancelled 但未到期，仍有服務權限
            return .premium
        case .expired:
            return .expired
        case .none:
            return .free
        }
    }

    /// Phase 3: 設置服務
    private func setupServices() async {
        print("⚙️ AppStateManager: 開始設置服務")
        
        // 初始化核心服務
        healthDataUploadManager = HealthDataUploadManagerV2.shared
        
        // 根據用戶狀態初始化服務
        if isUserAuthenticated {
            // 初始化運動 Repository (預載入數據)
            await workoutRepository.preloadData()
            
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

// MARK: - Analytics

extension AppStateManager {

    private func trackAppOpen() {
        let installDate = UserDefaults.standard.analyticsFirstInstallDate
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0

        let subscriptionString = analyticsSubscriptionString()

        analyticsService.track(.appOpen(
            daysSinceInstall: daysSinceInstall,
            subscriptionStatus: subscriptionString
        ))

        // User properties (AC-12)
        analyticsService.setUserProperty(subscriptionString, forName: "subscription_status")
        analyticsService.setUserProperty(userDataSource.rawValue, forName: "data_source")

        // target_type: read from UserDefaults (set by OnboardingCoordinator)
        if let targetTypeId = UserDefaults.standard.string(forKey: "selectedTargetTypeId") {
            analyticsService.setUserProperty(targetTypeId, forName: "target_type")
        }
    }

    private func analyticsSubscriptionString() -> String {
        guard let entity = SubscriptionStateManager.shared.currentStatus else {
            return "free"
        }
        return analyticsStatusString(for: entity.status)
    }
}

/// Free function outside AppStateManager to avoid shadowing by AppStateManager.SubscriptionStatus.
private func analyticsStatusString(for domainStatus: SubscriptionStatus) -> String {
    switch domainStatus {
    case .trial:       return "trial"
    case .active:      return "active"
    case .expired:     return "expired"
    case .none:        return "free"
    case .cancelled:   return "active"
    case .gracePeriod: return "active"
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
