import SwiftUI
import FirebaseAuth

// MARK: - 重構後的用戶資料 ViewModel (遵循統一架構模式)
/// 使用 UserManager 和 BaseDataViewModel 的標準化實現
@MainActor
class UserProfileViewModelV2: BaseDataViewModel<User, UserManager> {
    
    // MARK: - User Specific Properties
    
    /// 當前用戶資料
    @Published var userData: User? {
        didSet {
            // 當用戶數據更新時，同步更新 data 數組以保持一致性
            data = userData != nil ? [userData!] : []
        }
    }
    
    /// 心率區間
    @Published var heartRateZones: [HeartRateZonesManager.HeartRateZone] = []
    @Published var isLoadingZones = false
    
    /// 用戶目標
    @Published var userTargets: [Target] = []
    
    /// 用戶統計信息
    @Published var statistics: UserStatistics?
    
    /// 認證狀態
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    
    // MARK: - UI State
    @Published var showDeleteAccountAlert = false
    @Published var showDataSourceSelector = false
    @Published var isDeletingAccount = false
    
    // MARK: - Initialization
    
    override init(manager: UserManager = UserManager.shared) {
        super.init(manager: manager)
        
        // 綁定 manager 的屬性到 ViewModel
        bindManagerProperties()
    }
    
    // MARK: - Setup & Initialization
    
    override func initialize() async {
        await manager.initialize()
        
        // 同步管理器狀態
        syncManagerState()
    }
    
    // MARK: - User Profile Management
    
    /// 載入用戶資料
    override func loadData() async {
        await manager.loadData()
        syncManagerState()
    }
    
    /// 刷新用戶資料
    override func refreshData() async {
        await manager.refreshData()
        syncManagerState()
    }
    
    /// 載入心率區間
    func loadHeartRateZones() async {
        await manager.loadHeartRateZones()
        syncManagerState()
    }
    
    /// 載入用戶目標
    func loadUserTargets() async {
        await manager.loadUserTargets()
        syncManagerState()
    }
    
    // MARK: - User Data Updates
    
    /// 更新週跑量
    func updateWeeklyDistance(_ distance: Int) async -> Bool {
        let success = await manager.updateUserData(.weeklyDistance(distance))
        
        if success {
            syncManagerState()
        }
        
        return success
    }
    
    /// 更新個人最佳成績
    func updatePersonalBest(_ performanceData: [String: Any]) async -> Bool {
        let success = await manager.updateUserData(.personalBest(performanceData))
        
        if success {
            syncManagerState()
        }
        
        return success
    }
    
    /// 更新數據源
    func updateDataSource(_ dataSource: String) async -> Bool {
        let success = await manager.updateUserData(.dataSource(dataSource))
        
        if success {
            syncManagerState()
            
            // 發送數據源變更通知
            NotificationCenter.default.post(name: .dataSourceChanged, object: nil)
        }
        
        return success
    }
    
    /// 創建新目標
    func createTarget(_ target: Target) async -> Bool {
        let success = await manager.createTarget(target)
        
        if success {
            syncManagerState()
        }
        
        return success
    }
    
    // MARK: - Authentication Management
    
    /// 登出
    func signOut() async {
        await executeWithErrorHandling {
            try await self.manager.signOut()
            self.syncManagerState()
        }
    }
    
    /// 刪除帳戶
    func deleteAccount() async -> Bool {
        isDeletingAccount = true
        
        let success = await executeWithErrorHandling {
            try await self.manager.deleteAccount()
            self.syncManagerState()
        } != nil
        
        isDeletingAccount = false
        return success
    }
    
    /// 顯示刪除帳戶確認對話框
    func showDeleteAccountConfirmation() {
        showDeleteAccountAlert = true
    }
    
    /// 處理刪除帳戶確認
    func handleDeleteAccountConfirmation() async {
        showDeleteAccountAlert = false
        let success = await deleteAccount()
        
        if !success {
            // 如果刪除失敗，可以顯示錯誤訊息
            Logger.firebase(
                "帳戶刪除失敗",
                level: .error,
                labels: ["module": "UserProfileViewModelV2", "action": "delete_account"]
            )
        }
    }
    
    // MARK: - Data Source Management
    
    /// 顯示數據源選擇器
    func showDataSourceSelection() {
        showDataSourceSelector = true
    }
    
    /// 處理數據源變更
    func handleDataSourceChange(_ newDataSource: DataSourceType) async {
        showDataSourceSelector = false
        
        let success = await updateDataSource(newDataSource.rawValue)
        
        if success {
            Logger.firebase(
                "數據源切換成功",
                level: .info,
                labels: ["module": "UserProfileViewModelV2", "action": "change_data_source"],
                jsonPayload: ["new_source": newDataSource.rawValue]
            )
        }
    }
    
    // MARK: - Formatting Methods
    
    /// 格式化星期名稱
    func weekdayName(for index: Int) -> String {
        return manager.weekdayName(for: index)
    }
    
    /// 格式化心率顯示
    func formatHeartRate(_ rate: Int?) -> String {
        return manager.formatHeartRate(rate)
    }
    
    /// 獲取心率區間顏色
    func zoneColor(for zone: Int) -> Color {
        return manager.zoneColor(for: zone)
    }
    
    // MARK: - Computed Properties
    
    /// 是否有完整的用戶資料
    var hasCompleteProfile: Bool {
        return manager.hasCompleteProfile
    }
    
    /// 是否需要完成 onboarding
    var needsOnboarding: Bool {
        return manager.needsOnboarding
    }
    
    /// 當前數據源
    var currentDataSource: DataSourceType {
        return manager.currentDataSource
    }
    
    /// 數據源顯示名稱
    var currentDataSourceDisplayName: String {
        switch currentDataSource {
        case .appleHealth:
            return "Apple Health"
        case .garmin:
            return "Garmin Connect"
        case .strava:
            return "Strava"
        case .unbound:
            return "未綁定"
        }
    }
    
    /// 用戶統計摘要
    var statisticsSummary: String {
        guard let stats = statistics else {
            return "暫無統計信息"
        }
        
        return """
        總距離: \(String(format: "%.1f", stats.totalDistance)) km
        平均週跑量: \(String(format: "%.1f", stats.averageWeeklyDistance)) km
        目標數量: \(stats.targetCount)
        心率區間: \(stats.heartRateZoneCount) 個
        """
    }
    
    // MARK: - Validation Helpers
    
    /// 驗證週跑量輸入
    func validateWeeklyDistance(_ distance: String) -> Int? {
        guard let intValue = Int(distance), intValue >= 0, intValue <= 300 else {
            return nil
        }
        return intValue
    }
    
    /// 驗證心率輸入
    func validateHeartRate(_ heartRate: String) -> Int? {
        guard let intValue = Int(heartRate), intValue >= 40, intValue <= 220 else {
            return nil
        }
        return intValue
    }
    
    // MARK: - Notification Setup Override
    
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        
        // 監聽用戶數據更新
        let userUpdateObserver = NotificationCenter.default.addObserver(
            forName: .userDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncManagerState()
        }
        notificationObservers.append(userUpdateObserver)
        
        // 監聽數據源變更
        let dataSourceChangeObserver = NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
        notificationObservers.append(dataSourceChangeObserver)
    }
    
    // MARK: - Private Helper Methods
    
    private func bindManagerProperties() {
        // 如果需要，可以使用 Combine 來綁定 manager 的屬性變化
        // 目前使用 syncManagerState() 的方式來同步狀態
    }
    
    private func syncManagerState() {
        userData = manager.currentUser
        heartRateZones = manager.heartRateZones
        isLoadingZones = manager.isLoadingZones
        userTargets = manager.userTargets
        statistics = manager.statistics
        isAuthenticated = manager.isAuthenticated
        currentUserId = manager.currentUserId
        
        // 同步基礎屬性
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
}

// MARK: - SwiftUI Helper Extensions
extension UserProfileViewModelV2 {
    
    /// 獲取用戶頭像 URL
    var userAvatarURL: URL? {
        guard let photoUrl = userData?.photoUrl else { return nil }
        return URL(string: photoUrl)
    }
    
    /// 獲取用戶顯示名稱
    var userDisplayName: String {
        return userData?.displayName ?? "未知用戶"
    }
    
    /// 獲取用戶電子郵件
    var userEmail: String {
        return userData?.email ?? "未知郵箱"
    }
    
    /// 獲取當前週跑量
    var currentWeekDistance: Double {
        return Double(userData?.currentWeekDistance ?? 0)
    }
    
    /// 獲取最大心率
    var maxHeartRate: Int? {
        return userData?.maxHr
    }
    
    /// 獲取靜息心率
    var restingHeartRate: Int? {
        return userData?.relaxingHr
    }
    
    /// 檢查是否有心率數據
    var hasHeartRateData: Bool {
        return maxHeartRate != nil && restingHeartRate != nil
    }
    
    /// 檢查是否有心率區間數據
    var hasHeartRateZones: Bool {
        return !heartRateZones.isEmpty
    }
    
    /// 檢查是否有用戶目標
    var hasUserTargets: Bool {
        return !userTargets.isEmpty
    }
}

// MARK: - Legacy Compatibility (漸進式遷移支援)
extension UserProfileViewModelV2 {
    
    /// 為了與現有 UI 代碼兼容，提供舊的方法名稱
    func fetchUserProfile() {
        Task {
            await loadData()
        }
    }
    
    /// 提供錯誤處理的兼容性
    var error: Error? {
        get {
            if let syncError = syncError {
                return NSError(domain: "UserProfileError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: syncError
                ])
            }
            return nil
        }
        set {
            syncError = newValue?.localizedDescription
        }
    }
}