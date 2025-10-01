import Foundation
import SwiftUI
import FirebaseAuth
import Combine

// MARK: - 用戶數據類型
enum UserDataUpdateType {
    case profile(User)
    case weeklyDistance(Int)
    case personalBest([String: Any])
    case dataSource(String)
    case heartRateZones([HeartRateZonesManager.HeartRateZone])
    case targets([Target])
}

// MARK: - 用戶統計信息
struct UserStatistics: Codable {
    let totalWorkouts: Int
    let totalDistance: Double
    let averageWeeklyDistance: Double
    let heartRateZoneCount: Int
    let targetCount: Int
    let lastActivityDate: Date?
    let accountCreatedDate: Date?
    
    init(userData: User, targets: [Target] = []) {
        // 從用戶數據計算統計信息
        self.totalWorkouts = 0 // 需要從其他數據源獲取
        self.totalDistance = Double(userData.currentWeekDistance ?? 0)
        self.averageWeeklyDistance = Double(userData.currentWeekDistance ?? 0)
        self.heartRateZoneCount = 5 // 固定 5 個區間
        self.targetCount = targets.count
        self.lastActivityDate = nil // 需要從運動記錄獲取
        self.accountCreatedDate = nil // 需要從用戶資料獲取
    }
}

// MARK: - 統一用戶管理器
/// 遵循 DataManageable 協議，提供標準化的用戶數據管理
class UserManager: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = User
    typealias ServiceType = UserService
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - User Specific Properties
    @Published var currentUser: User?
    @Published var heartRateZones: [HeartRateZonesManager.HeartRateZone] = []
    @Published var isLoadingZones = false
    @Published var userTargets: [Target] = []
    @Published var statistics: UserStatistics?
    
    // MARK: - Authentication Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    
    // MARK: - Dependencies
    let service: UserService
    private let cacheManager: UserCacheManager
    private let authService = AuthenticationService.shared
    private let heartRateZonesManager = HeartRateZonesManager.shared
    private let targetService = TargetService.shared
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - Combine Support
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "UserManager" }
    
    // MARK: - Singleton
    static let shared = UserManager()
    
    // MARK: - Initialization
    private init() {
        self.service = UserService.shared
        self.cacheManager = UserCacheManager()
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
        checkAuthenticationStatus()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "UserManager 初始化",
            level: .info,
            labels: ["module": "UserManager", "action": "initialize"]
        )
        
        // 檢查認證狀態
        checkAuthenticationStatus()
        
        if isAuthenticated {
            // 載入用戶數據
            await loadData()
            await loadHeartRateZones()
            await loadUserTargets()
        }
    }
    
    func loadData() async {
        await executeDataLoadingTask(id: "load_user_profile") {
            try await self.performLoadUserProfile()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_user_profile") {
            try await self.performRefreshUserProfile()
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            currentUser = nil
            heartRateZones = []
            userTargets = []
            statistics = nil
            isAuthenticated = false
            currentUserId = nil
            lastSyncTime = nil
            syncError = nil
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "用戶數據已清除",
            level: .info,
            labels: ["module": "UserManager", "action": "clear_all_data"]
        )
    }
    
    // MARK: - Cacheable Implementation
    
    func clearCache() {
        cacheManager.clearCache()
    }
    
    func getCacheSize() -> Int {
        return cacheManager.getCacheSize()
    }
    
    func isExpired() -> Bool {
        return cacheManager.isExpired()
    }
    
    // MARK: - Core User Data Logic
    
    private func performLoadUserProfile() async throws {
        // 優先從快取載入
        if let cachedData = cacheManager.loadFromCache(),
           !cacheManager.shouldRefresh() {
            await MainActor.run {
                self.updateUserData(cachedData.userProfile)
                self.userTargets = cachedData.targets
                self.updateStatistics()
            }
            return
        }
        
        // 從 API 獲取用戶資料
        let user = try await withCheckedThrowingContinuation { continuation in
            service.getUserProfile()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { user in
                        continuation.resume(returning: user)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        // 更新 UI 和快取
        await MainActor.run {
            self.updateUserData(user)
        }
        
        // 保存到快取
        let cacheData = UserCacheData(
            userProfile: user,
            targets: userTargets // 使用當前的 targets
        )
        cacheManager.saveToCache(cacheData)
        
        // 發送通知
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
        
        Logger.firebase(
            "用戶資料載入成功",
            level: .info,
            labels: ["module": "UserManager", "action": "load_user_profile"],
            jsonPayload: [
                "user_name": user.displayName ?? "unknown",
                "data_source": user.dataSource ?? "unknown"
            ]
        )
    }
    
    private func performRefreshUserProfile() async throws {
        // 強制從 API 獲取
        let user = try await withCheckedThrowingContinuation { continuation in
            service.getUserProfile()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { user in
                        continuation.resume(returning: user)
                    }
                )
                .store(in: &self.cancellables)
        }
        
        await MainActor.run {
            self.updateUserData(user)
        }
        
        // 強制更新快取
        let cacheData = UserCacheData(
            userProfile: user,
            targets: userTargets
        )
        cacheManager.forceRefresh(with: cacheData)
        
        // 發送通知
        NotificationCenter.default.post(name: .userDataDidUpdate, object: nil)
    }
    
    // MARK: - Authentication Management
    
    private func checkAuthenticationStatus() {
        if let user = Auth.auth().currentUser {
            isAuthenticated = true
            currentUserId = user.uid
        } else {
            isAuthenticated = false
            currentUserId = nil
        }
    }
    
    func signOut() async throws {
        try await authService.signOut()
        await clearAllData()
        
        Logger.firebase(
            "用戶登出完成",
            level: .info,
            labels: ["module": "UserManager", "action": "sign_out"]
        )
    }
    
    func deleteAccount() async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "UserManager", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "無法獲取當前用戶ID"
            ])
        }
        
        let result = await executeDataLoadingTask(id: "delete_account") {
            try await self.service.deleteUser(userId: userId)
            try await self.authService.signOut()
            await self.clearAllData()
            
            Logger.firebase(
                "用戶帳戶刪除完成",
                level: .info,
                labels: ["module": "UserManager", "action": "delete_account"],
                jsonPayload: ["user_id": userId]
            )
        }
        
        if result == nil {
            throw NSError(domain: "UserManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "刪除帳戶失敗"
            ])
        }
    }
    
    // MARK: - User Data Updates
    
    func updateUserData(_ updateType: UserDataUpdateType) async -> Bool {
        return await executeDataLoadingTask(id: "update_user_data") {
            switch updateType {
            case .profile(let profileData):
                // 更新完整的用戶資料
                try await self.service.updateUserData(profileData.toDictionary())
                
            case .weeklyDistance(let distance):
                let userData = ["current_week_distance": distance]
                try await self.service.updateUserData(userData)
                
            case .personalBest(let pbData):
                try await self.service.updatePersonalBestData(pbData)
                
            case .dataSource(let dataSource):
                try await self.service.updateDataSource(dataSource)
                
            case .heartRateZones(let zones):
                // 更新心率區間設定（如果後端支持）
                let zoneData = zones.map { ["zone": $0.zone, "min": Int($0.range.lowerBound), "max": Int($0.range.upperBound)] }
                try await self.service.updateUserData(["heart_rate_zones": zoneData])
                
            case .targets(let targets):
                // 更新目標列表
                for target in targets {
                    try await self.service.createTarget(target)
                }
            }
            
            // 重新載入用戶資料
            try await self.performRefreshUserProfile()
            return true
        } != nil
    }
    
    // MARK: - Heart Rate Zones Management
    
    func loadHeartRateZones() async {
        await executeDataLoadingTask(id: "load_heart_rate_zones", showLoading: false) {
            await MainActor.run {
                self.isLoadingZones = true
            }
            
            // 確保心率區間可用
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
            
            let zones = self.heartRateZonesManager.getHeartRateZones()
            
            await MainActor.run {
                self.heartRateZones = zones
                self.isLoadingZones = false
                self.updateStatistics()
            }
            
            Logger.firebase(
                "心率區間載入完成",
                level: .info,
                labels: ["module": "UserManager", "action": "load_heart_rate_zones"],
                jsonPayload: ["zones_count": zones.count]
            )
        }
    }
    
    // MARK: - Targets Management
    
    func loadUserTargets() async {
        await executeDataLoadingTask(id: "load_user_targets", showLoading: false) {
            let targets = try await self.targetService.getTargets()
            
            await MainActor.run {
                self.userTargets = targets
                self.updateStatistics()
            }
            
            Logger.firebase(
                "用戶目標載入完成",
                level: .info,
                labels: ["module": "UserManager", "action": "load_user_targets"],
                jsonPayload: ["targets_count": targets.count]
            )
        }
    }
    
    func createTarget(_ target: Target) async -> Bool {
        return await executeDataLoadingTask(id: "create_target") {
            try await self.service.createTarget(target)
            await self.loadUserTargets()
            return true
        } != nil
    }
    
    // MARK: - Helper Methods

    /// 公開方法：更新當前用戶資料（供外部調用）
    func updateCurrentUser(_ userData: User) async {
        await MainActor.run {
            updateUserData(userData)
            print("✅ [UserManager] currentUser 已更新")
        }
    }

    private func updateUserData(_ userData: User) {
        currentUser = userData
        updateStatistics()
    }
    
    private func updateStatistics() {
        guard let user = currentUser else { return }
        statistics = UserStatistics(userData: user, targets: userTargets)
    }
    
    // MARK: - Formatting Helpers
    
    func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        let adjustedIndex = (index - 1) % 7
        return "星期" + weekdays[adjustedIndex]
    }
    
    func formatHeartRate(_ rate: Int?) -> String {
        guard let rate = rate else { return "-- bpm" }
        return "\(rate) bpm"
    }
    
    func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // 監聽認證狀態變化
        NotificationCenter.default.addObserver(
            forName: .userDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAuthenticationStatus()
        }
        
        // 監聽數據源切換
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
        
        // 監聽全域數據刷新
        NotificationCenter.default.addObserver(
            forName: .globalDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extensions
extension UserManager {
    
    /// 檢查是否有完整的用戶資料
    var hasCompleteProfile: Bool {
        guard let user = currentUser else { return false }
        return user.displayName != nil && user.email != nil
    }
    
    /// 檢查是否需要完成 onboarding
    var needsOnboarding: Bool {
        // 根據用戶資料判斷是否需要完成 onboarding
        return !hasCompleteProfile || heartRateZones.isEmpty
    }
    
    /// 獲取當前數據源
    var currentDataSource: DataSourceType {
        return UserPreferenceManager.shared.dataSourcePreference
    }

    // MARK: - App Rating Management

    /// 檢查是否應顯示評分提示
    var shouldShowRatingPrompt: Bool {
        guard let user = currentUser else { return false }

        // 年度次數限制
        let promptCount = user.ratingPromptCount ?? 0
        if promptCount >= 3 { return false }

        return true
    }

    /// 獲取評分提示次數
    var ratingPromptCount: Int {
        return currentUser?.ratingPromptCount ?? 0
    }

    /// 獲取上次評分提示日期
    var lastRatingPromptDate: Date? {
        guard let dateString = currentUser?.lastRatingPromptDate else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
}

// MARK: - Cache Manager
private class UserCacheManager: BaseCacheManagerTemplate<UserCacheData> {
    
    init() {
        super.init(identifier: "user_cache", defaultTTL: 3600) // 1 hour
    }
}

// MARK: - Cache Data Structure  
private struct UserCacheData: Codable {
    let userProfile: User
    let targets: [Target]
}

// MARK: - User Extension
extension User {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let displayName = displayName { dict["display_name"] = displayName }
        if let email = email { dict["email"] = email }
        if let photoUrl = photoUrl { dict["photo_url"] = photoUrl }
        if let maxHr = maxHr { dict["max_heart_rate"] = maxHr }
        if let relaxingHr = relaxingHr { dict["resting_heart_rate"] = relaxingHr }
        if let currentWeekDistance = currentWeekDistance { dict["current_week_distance"] = currentWeekDistance }
        if let dataSource = dataSource { dict["data_source"] = dataSource }
        
        return dict
    }
}