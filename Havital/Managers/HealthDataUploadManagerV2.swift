import Foundation
import HealthKit
import BackgroundTasks

// MARK: - 健康數據類型
enum HealthDataType: String, CaseIterable, Codable {
    case hrv = "heart_rate_variability"
    case restingHeartRate = "resting_heart_rate"
    case heartRate = "heart_rate"
    case sleep = "sleep"
    case steps = "steps"
    case activeEnergy = "active_energy"
    
    var displayName: String {
        switch self {
        case .hrv: return "心率變異性"
        case .restingHeartRate: return "靜息心率"
        case .heartRate: return "心率"
        case .sleep: return "睡眠"
        case .steps: return "步數"
        case .activeEnergy: return "活動消耗"
        }
    }
}

// MARK: - 健康數據上傳狀態
struct HealthDataUploadStatus: Codable {
    let isUploading: Bool
    let uploadProgress: Double
    let lastUploadDate: Date?
    let pendingUploadCount: Int
    let failedUploadCount: Int
    let lastError: String?
    
    static let idle = HealthDataUploadStatus(
        isUploading: false,
        uploadProgress: 0.0,
        lastUploadDate: nil,
        pendingUploadCount: 0,
        failedUploadCount: 0,
        lastError: nil
    )
}

// MARK: - 健康數據日期範圍
struct HealthDataDateRange: Codable {
    let start: Date
    let end: Date
}

// MARK: - 健康數據集合
struct HealthDataCollection: Codable {
    let records: [HealthRecord]
    let dateRange: HealthDataDateRange
    let dataTypes: Set<HealthDataType>
    let lastUpdated: Date
    
    init(records: [HealthRecord], days: Int) {
        self.records = records
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        self.dateRange = HealthDataDateRange(start: startDate, end: endDate)
        self.dataTypes = Set(HealthDataType.allCases) // 假設包含所有類型
        self.lastUpdated = Date()
    }
}

// MARK: - 重構後的健康數據上傳管理器
/// 遵循 DataManageable 協議，整合統一快取系統
class HealthDataUploadManagerV2: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = [HealthRecord]
    typealias ServiceType = APIClient
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - Health Data Specific Properties
    @Published var uploadStatus: HealthDataUploadStatus = .idle
    @Published var healthDataCollections: [Int: HealthDataCollection] = [:] // days -> collection
    @Published var observedDataTypes: Set<HealthDataType> = []
    @Published var backgroundSyncEnabled: Bool = false
    
    // MARK: - Dependencies
    let service: APIClient
    private let cacheManager: HealthDataCacheManager
    private let healthKitManager = HealthKitManager()
    private let userPreferenceManager = UserPreferenceManager.shared
    
    // MARK: - Configuration
    private let maxRetries = 3
    private let retryInterval: TimeInterval = 300 // 5分鐘
    private let supportedDaysRanges = [7, 14, 30]
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "HealthDataUploadManagerV2" }
    
    // MARK: - Background Task Management
    private var healthKitObservers: [HKObserverQuery] = []
    
    // MARK: - Singleton
    static let shared = HealthDataUploadManagerV2()
    
    // MARK: - Initialization
    private init() {
        self.service = APIClient.shared
        self.cacheManager = HealthDataCacheManager()
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
        loadCachedState()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "HealthDataUploadManagerV2 初始化",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "initialize"]
        )
        
        // 載入健康數據
        await loadData()
        
        // 根據數據源設置同步
        await setupDataSourceSync()
    }
    
    func loadData() async {
        await executeDataLoadingTask(id: "load_health_data") {
            try await self.performLoadHealthData()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_health_data") {
            try await self.performRefreshHealthData()
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            healthDataCollections = [:]
            uploadStatus = .idle
            observedDataTypes = []
            backgroundSyncEnabled = false
            lastSyncTime = nil
            syncError = nil
        }
        
        // 停止所有觀察者
        stopHealthKitObservers()
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "健康數據已清除",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "clear_all_data"]
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
    
    // MARK: - Core Health Data Logic
    
    private func performLoadHealthData() async throws {
        // 載入所有支援的天數範圍的數據
        for days in supportedDaysRanges {
            try await loadHealthDataForRange(days: days)
        }
        
        // 載入上傳狀態
        loadUploadStatus()
    }
    
    private func performRefreshHealthData() async throws {
        // 強制刷新所有數據
        for days in supportedDaysRanges {
            try await refreshHealthDataForRange(days: days)
        }
        
        // 觸發上傳
        await syncHealthDataNow()
    }
    
    private func loadHealthDataForRange(days: Int) async throws {
        // 優先從快取載入
        if let cachedCollection = cacheManager.loadHealthDataCollection(for: days),
           !cacheManager.shouldRefresh() {
            await MainActor.run {
                self.healthDataCollections[days] = cachedCollection
            }
            return
        }
        
        // 從 API 獲取
        do {
            let response = try await service.fetchHealthDaily(limit: days)
            let healthData = response.data.healthData
            let collection = HealthDataCollection(records: healthData, days: days)
            
            await MainActor.run {
                self.healthDataCollections[days] = collection
            }
            
            cacheManager.saveHealthDataCollection(collection, for: days)
            
            Logger.firebase(
                "健康數據載入成功",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "load_health_data"],
                jsonPayload: [
                    "days": days,
                    "records_count": healthData.count
                ]
            )
            
        } catch {
            // 回退到本地 HealthKit 數據
            let localData = await getLocalHealthData(days: days)
            let collection = HealthDataCollection(records: localData, days: days)
            
            await MainActor.run {
                self.healthDataCollections[days] = collection
            }
            
            Logger.firebase(
                "從 API 載入失敗，使用本地數據",
                level: .warn,
                labels: ["module": "HealthDataUploadManagerV2", "action": "fallback_to_local"],
                jsonPayload: [
                    "days": days,
                    "local_records_count": localData.count,
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    private func refreshHealthDataForRange(days: Int) async throws {
        // 強制從 API 獲取
        let response = try await service.fetchHealthDaily(limit: days)
        let healthData = response.data.healthData
        let collection = HealthDataCollection(records: healthData, days: days)
        
        await MainActor.run {
            self.healthDataCollections[days] = collection
        }
        
        cacheManager.forceRefreshHealthDataCollection(collection, for: days)
    }
    
    // MARK: - Data Source Sync Setup
    
    private func setupDataSourceSync() async {
        let dataSource = userPreferenceManager.dataSourcePreference
        
        Logger.firebase(
            "設置健康數據同步",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "setup_sync"],
            jsonPayload: ["data_source": dataSource.rawValue]
        )
        
        switch dataSource {
        case .appleHealth:
            await setupAppleHealthSync()
        case .garmin:
            await setupGarminSync()
        case .unbound:
            Logger.firebase(
                "數據源未綁定，跳過健康數據同步",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "skip_sync"]
            )
        }
    }
    
    private func setupAppleHealthSync() async {
        // 上傳待處理數據
        await uploadPendingHealthData()
        
        // 設置 HealthKit 觀察者
        await setupHealthKitObservers()
        
        // 啟用背景同步
        await enableBackgroundSync()
        
        await MainActor.run {
            self.backgroundSyncEnabled = true
        }
    }
    
    private func setupGarminSync() async {
        // Garmin 數據由後台自動同步，只需定期刷新
        await schedulePeriodicRefresh()
        
        await MainActor.run {
            self.backgroundSyncEnabled = true
        }
    }
    
    // MARK: - HealthKit Observer Management
    
    private func setupHealthKitObservers() async {
        let healthStore = HKHealthStore()
        
        // 監聽 HRV 數據
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let hrvQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, _, _ in
                Task {
                    // HRV 數據通常在早晨可用，延遲處理
                    try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30分鐘
                    await self?.handleHealthDataUpdate(.hrv)
                }
            }
            
            healthStore.execute(hrvQuery)
            healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { _, _ in }
            healthKitObservers.append(hrvQuery)
        }
        
        // 監聽靜息心率數據
        if let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            let rhrQuery = HKObserverQuery(sampleType: rhrType, predicate: nil) { [weak self] _, _, _ in
                Task {
                    await self?.handleHealthDataUpdate(.restingHeartRate)
                }
            }
            
            healthStore.execute(rhrQuery)
            healthStore.enableBackgroundDelivery(for: rhrType, frequency: .immediate) { _, _ in }
            healthKitObservers.append(rhrQuery)
        }
        
        // 更新觀察的數據類型
        await MainActor.run {
            self.observedDataTypes = [.hrv, .restingHeartRate]
        }
    }
    
    private func stopHealthKitObservers() {
        let healthStore = HKHealthStore()
        
        for observer in healthKitObservers {
            healthStore.stop(observer)
        }
        
        // 禁用背景傳遞
        for dataType in observedDataTypes {
            if let hkType = dataType.healthKitType {
                healthStore.disableBackgroundDelivery(for: hkType) { _, _ in }
            }
        }
        
        healthKitObservers.removeAll()
        observedDataTypes.removeAll()
    }
    
    private func handleHealthDataUpdate(_ dataType: HealthDataType) async {
        Logger.firebase(
            "檢測到健康數據更新",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "data_update"],
            jsonPayload: ["data_type": dataType.rawValue]
        )
        
        // 上傳最新數據
        await uploadRecentHealthData()
        
        // 刷新快取
        await refreshData()
        
        // 發送通知
        NotificationCenter.default.post(
            name: .appleHealthDataRefresh,
            object: nil,
            userInfo: [String.dataTypeKey: dataType.rawValue]
        )
    }
    
    // MARK: - Data Upload Management
    
    func syncHealthDataNow() async {
        await executeDataLoadingTask(id: "sync_health_data_now") {
            await self.uploadRecentHealthData()
        }
    }
    
    private func uploadPendingHealthData() async {
        await executeDataLoadingTask(id: "upload_pending_health_data") {
            // 實現待處理數據上傳邏輯
            await self.performUploadPendingData()
        }
    }
    
    private func uploadRecentHealthData() async {
        await executeDataLoadingTask(id: "upload_recent_health_data") {
            // 上傳最近的健康數據
            await self.performUploadRecentData()
        }
    }
    
    private func performUploadPendingData() async {
        await MainActor.run {
            self.uploadStatus = HealthDataUploadStatus(
                isUploading: true,
                uploadProgress: 0.0,
                lastUploadDate: self.uploadStatus.lastUploadDate,
                pendingUploadCount: self.uploadStatus.pendingUploadCount,
                failedUploadCount: self.uploadStatus.failedUploadCount,
                lastError: nil
            )
        }
        
        // 實現實際的上傳邏輯
        // 這裡應該調用 API 上傳數據
        
        await MainActor.run {
            self.uploadStatus = HealthDataUploadStatus(
                isUploading: false,
                uploadProgress: 1.0,
                lastUploadDate: Date(),
                pendingUploadCount: 0,
                failedUploadCount: 0,
                lastError: nil
            )
        }
        
        // 保存上傳狀態
        saveUploadStatus()
    }
    
    private func performUploadRecentData() async {
        // 實現最近數據上傳邏輯
        await performUploadPendingData()
    }
    
    // MARK: - Background Tasks
    
    private func enableBackgroundSync() async {
        // 註冊背景任務
        let identifier = "com.havital.healthdata.sync"
        
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60 * 60) // 1小時後
        
        do {
            try BGTaskScheduler.shared.submit(request)
            
            Logger.firebase(
                "背景同步任務已註冊",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "enable_background_sync"]
            )
        } catch {
            Logger.firebase(
                "背景同步任務註冊失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "HealthDataUploadManagerV2", "action": "enable_background_sync"]
            )
        }
    }
    
    private func schedulePeriodicRefresh() async {
        // Garmin 數據的定期刷新
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30分鐘
                await refreshData()
            }
        }
    }
    
    // MARK: - Local HealthKit Data
    
    private func getLocalHealthData(days: Int) async -> [HealthRecord] {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
            
            // 獲取各種健康數據
            async let hrvData = healthKitManager.fetchHRVData(start: startDate, end: endDate)
            let restingHR = await healthKitManager.fetchRestingHeartRate()
            
            let hrv = try await hrvData
            
            // 轉換為 HealthRecord 格式
            var records: [HealthRecord] = []
            
            // 將 HRV 數據按日期分組並轉換為 HealthRecord
            let groupedHRV = Dictionary(grouping: hrv) { record in
                Calendar.current.startOfDay(for: record.0)
            }
            
            for (date, values) in groupedHRV {
                let avgHRV = values.map { $0.1 }.reduce(0, +) / Double(values.count)
                let dateString = ISO8601DateFormatter().string(from: date)
                
                let record = HealthRecord(
                    date: dateString,
                    dailyCalories: nil,
                    hrvLastNightAvg: avgHRV,
                    restingHeartRate: nil
                )
                records.append(record)
            }
            
            // 添加靜息心率記錄（如果有值）
            if restingHR > 0 {
                let today = Calendar.current.startOfDay(for: Date())
                let dateString = ISO8601DateFormatter().string(from: today)
                
                let record = HealthRecord(
                    date: dateString,
                    dailyCalories: nil,
                    hrvLastNightAvg: nil,
                    restingHeartRate: Int(restingHR)
                )
                records.append(record)
            }
            
            return records
            
        } catch {
            Logger.firebase(
                "獲取本地 HealthKit 數據失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "HealthDataUploadManagerV2", "action": "get_local_health_data"]
            )
            return []
        }
    }
    
    // MARK: - State Management
    
    private func loadCachedState() {
        // 載入上傳狀態
        loadUploadStatus()
        
        // 載入快取的健康數據集合
        for days in supportedDaysRanges {
            if let collection = cacheManager.loadHealthDataCollection(for: days) {
                healthDataCollections[days] = collection
            }
        }
    }
    
    private func loadUploadStatus() {
        uploadStatus = cacheManager.loadUploadStatus() ?? .idle
    }
    
    private func saveUploadStatus() {
        cacheManager.saveUploadStatus(uploadStatus)
    }
    
    // MARK: - Public Interface
    
    /// 獲取健康數據（優先從緩存）
    func getHealthData(days: Int = 7) async -> [HealthRecord] {
        if let collection = healthDataCollections[days] {
            return collection.records
        }
        
        // 如果沒有快取，觸發載入
        try? await loadHealthDataForRange(days: days)
        return healthDataCollections[days]?.records ?? []
    }
    
    /// 檢查特定數據類型是否被觀察
    func isObserving(_ dataType: HealthDataType) -> Bool {
        return observedDataTypes.contains(dataType)
    }
    
    /// 獲取上傳進度百分比
    var uploadProgressPercentage: String {
        return String(format: "%.0f%%", uploadStatus.uploadProgress * 100)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.setupDataSourceSync()
            }
        }
        
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
        stopHealthKitObservers()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - HealthDataType Extensions
extension HealthDataType {
    var healthKitType: HKObjectType? {
        switch self {
        case .hrv:
            return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .restingHeartRate:
            return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRate:
            return HKObjectType.quantityType(forIdentifier: .heartRate)
        case .sleep:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .steps:
            return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .activeEnergy:
            return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        }
    }
}

// MARK: - Cache Manager
private class HealthDataCacheManager: BaseCacheManagerTemplate<HealthDataCacheData> {
    
    init() {
        super.init(identifier: "health_data", defaultTTL: 1800) // 30 minutes
    }
    
    // MARK: - Specialized Cache Methods
    
    func saveHealthDataCollection(_ collection: HealthDataCollection, for days: Int) {
        var cacheData = loadFromCache() ?? HealthDataCacheData()
        cacheData.collections[days] = collection
        saveToCache(cacheData)
    }
    
    func loadHealthDataCollection(for days: Int) -> HealthDataCollection? {
        return loadFromCache()?.collections[days]
    }
    
    func forceRefreshHealthDataCollection(_ collection: HealthDataCollection, for days: Int) {
        var cacheData = loadFromCache() ?? HealthDataCacheData()
        cacheData.collections[days] = collection
        forceRefresh(with: cacheData)
    }
    
    func saveUploadStatus(_ status: HealthDataUploadStatus) {
        var cacheData = loadFromCache() ?? HealthDataCacheData()
        cacheData.uploadStatus = status
        saveToCache(cacheData)
    }
    
    func loadUploadStatus() -> HealthDataUploadStatus? {
        return loadFromCache()?.uploadStatus
    }
}

// MARK: - Cache Data Structure
private struct HealthDataCacheData: Codable {
    var collections: [Int: HealthDataCollection] = [:]
    var uploadStatus: HealthDataUploadStatus?
}
