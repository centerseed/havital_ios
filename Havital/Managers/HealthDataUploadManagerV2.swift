import Foundation
import HealthKit
import BackgroundTasks
import UIKit

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
    typealias ServiceType = HealthDataService
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - Health Data Specific Properties
    @Published var uploadStatus: HealthDataUploadStatus = .idle
    @Published var healthDataCollections: [Int: HealthDataCollection] = [:] // days -> collection
    @Published var observedDataTypes: Set<HealthDataType> = []
    @Published var backgroundSyncEnabled: Bool = false

    // MARK: - Upload Tracking
    private let uploadedDatesKey = "health_data_uploaded_dates"
    private var uploadedDates: Set<String> {
        get {
            if let dates = UserDefaults.standard.array(forKey: uploadedDatesKey) as? [String] {
                return Set(dates)
            }
            return []
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: uploadedDatesKey)
        }
    }

    // MARK: - Dependencies
    let service: HealthDataService
    private let cacheManager: HealthDataCacheManager
    private let healthKitManager = HealthKitManager()
    private let userPreferenceManager = UserPreferencesManager.shared
    
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
        self.service = HealthDataService.shared
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
        // ✅ 直接調用 getHealthData，複用防重複邏輯
        _ = await getHealthData(days: 14)
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        // ✅ 強制刷新所有已載入的範圍
        // ⚠️ 必須在 MainActor 上訪問 @Published 屬性
        let loadedDays = await MainActor.run {
            Array(self.healthDataCollections.keys)
        }

        if loadedDays.isEmpty {
            // 沒有已載入的範圍，載入默認 14 天
            _ = await getHealthData(days: 14)
        } else {
            // 刷新所有已載入的範圍
            for days in loadedDays {
                await forceRefreshHealthData(days: days)
            }
        }

        return true
    }
    
    func clearAllData() async {
        // ⚠️ 必須在 MainActor 上修改 @Published 屬性
        await MainActor.run {
            self.healthDataCollections = [:]
            self.uploadStatus = .idle
            self.observedDataTypes = []
            self.backgroundSyncEnabled = false
            self.lastSyncTime = nil
            self.syncError = nil
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
    // ✅ performLoadHealthData 和 performRefreshHealthData 已移除
    // 統一使用 getHealthData() 和 forceRefreshHealthData() 防止重複調用
    
    private func loadHealthDataForRange(days: Int) async throws {
        print("📊 [loadHealthDataForRange] 開始載入數據，天數: \(days)")

        // 優先從快取載入
        if let cachedCollection = cacheManager.loadHealthDataCollection(for: days),
           !cacheManager.shouldRefresh() {
            print("📊 [loadHealthDataForRange] ✅ 使用快取數據，記錄數: \(cachedCollection.records.count)")
            let hrvCount = cachedCollection.records.filter { $0.hrvLastNightAvg != nil }.count
            print("📊 [loadHealthDataForRange] 快取中 HRV 記錄數: \(hrvCount)")
            for record in cachedCollection.records.prefix(3).filter({ $0.hrvLastNightAvg != nil }) {
                print("   - 快取日期: \(record.date), HRV: \(record.hrvLastNightAvg ?? 0)")
            }
            await MainActor.run {
                self.healthDataCollections[days] = cachedCollection
            }
            return
        }

        print("📊 [loadHealthDataForRange] 快取無效或需要刷新，從 API 獲取")

        // 從 API 獲取
        do {
            print("📊 [loadHealthDataForRange] 調用 API: service.getHealthDaily(limit: \(days))")
            let response = try await APICallTracker.$currentSource.withValue("HealthDataUploadManagerV2: loadHealthDataForRange") {
                try await service.getHealthDaily(limit: days)
            }
            let healthData = response.healthData
            print("📊 [loadHealthDataForRange] ✅ API 返回 \(healthData.count) 筆記錄")
            let hrvCount = healthData.filter { $0.hrvLastNightAvg != nil }.count
            print("📊 [loadHealthDataForRange] API 返回的 HRV 記錄數: \(hrvCount)")
            for record in healthData.prefix(3).filter({ $0.hrvLastNightAvg != nil }) {
                print("   - API 日期: \(record.date), HRV: \(record.hrvLastNightAvg ?? 0)")
            }

            // ⚠️ 如果 API 返回成功但沒有 HRV 數據，且用戶是 Apple Health，回退到本地數據
            if hrvCount == 0 && userPreferenceManager.dataSourcePreference == .appleHealth {
                print("📊 [loadHealthDataForRange] ⚠️ API 無 HRV 數據，Apple Health 用戶回退到本地")
                let localData = await getLocalHealthData(days: days)
                print("📊 [loadHealthDataForRange] 本地數據返回 \(localData.count) 筆記錄")
                let collection = HealthDataCollection(records: localData, days: days)

                await MainActor.run {
                    self.healthDataCollections[days] = collection
                }

                // 不保存到緩存，因為這是回退數據
                return
            }

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
            print("📊 [loadHealthDataForRange] ❌ API 調用失敗: \(error.localizedDescription)")
            print("📊 [loadHealthDataForRange] 回退到本地 HealthKit 數據")

            // 回退到本地 HealthKit 數據
            let localData = await getLocalHealthData(days: days)
            print("📊 [loadHealthDataForRange] 本地數據返回 \(localData.count) 筆記錄")
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
        let response = try await APICallTracker.$currentSource.withValue("HealthDataUploadManagerV2: refreshHealthDataForRange") {
            try await service.getHealthDaily(limit: days)
        }
        let healthData = response.healthData
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
        case .strava:
            await setupStravaSync()
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
        // ✅ 優化：Garmin 數據由後端自動同步，移除前端 30 分鐘輪詢
        // 數據會在 App 啟動時載入一次，用戶可以手動刷新

        await MainActor.run {
            self.backgroundSyncEnabled = true
        }

        Logger.firebase(
            "Garmin 健康數據同步設置完成（無輪詢）",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "setup_garmin_sync"]
        )
    }

    private func setupStravaSync() async {
        // ✅ 優化：Strava 數據由後端自動同步，移除前端 30 分鐘輪詢
        // 數據會在 App 啟動時載入一次，用戶可以手動刷新

        await MainActor.run {
            self.backgroundSyncEnabled = true
        }

        Logger.firebase(
            "Strava 健康數據同步設置完成（無輪詢）",
            level: .info,
            labels: ["module": "HealthDataUploadManagerV2", "action": "setup_strava_sync"]
        )
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
        print("📤 [performUploadPendingData] 開始上傳待處理的健康數據")

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

        do {
            // 收集未上傳的數據（最多 7 天）
            let healthRecords = await collectHealthDataForUpload(days: 7)

            guard !healthRecords.isEmpty else {
                print("📤 [performUploadPendingData] 沒有需要上傳的數據")
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
                return
            }

            print("📤 [performUploadPendingData] 收集到 \(healthRecords.count) 筆健康數據，準備批量上傳")

            // 批量上傳到雲端
            try await service.uploadHealthDataBatch(healthRecords)

            print("📤 [performUploadPendingData] ✅ 批量上傳成功")

            // 記錄已上傳的日期
            var newUploadedDates = uploadedDates
            for record in healthRecords {
                if let dateString = record["date"] as? String {
                    newUploadedDates.insert(dateString)
                    print("📤 [performUploadPendingData] 記錄已上傳日期: \(dateString)")
                }
            }
            uploadedDates = newUploadedDates

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

            Logger.firebase(
                "健康數據上傳成功",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "upload_pending_data"],
                jsonPayload: ["data_points": healthRecords.count]
            )

        } catch {
            // 任務取消是正常行為，不需要報錯或上傳到 Cloud Logging
            if error.isCancellationError {
                Logger.debug("上傳任務被取消，忽略錯誤")
                return
            }

            await MainActor.run {
                self.uploadStatus = HealthDataUploadStatus(
                    isUploading: false,
                    uploadProgress: 0.0,
                    lastUploadDate: self.uploadStatus.lastUploadDate,
                    pendingUploadCount: self.uploadStatus.pendingUploadCount,
                    failedUploadCount: self.uploadStatus.failedUploadCount + 1,
                    lastError: error.localizedDescription
                )
            }

            Logger.firebase(
                "健康數據上傳失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "HealthDataUploadManagerV2", "action": "upload_pending_data"]
            )
        }

        // 保存上傳狀態
        saveUploadStatus()
    }
    
    private func performUploadRecentData() async {
        print("📤 [performUploadRecentData] 開始上傳最近的健康數據")

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

        do {
            // 收集未上傳的數據（最多 7 天）
            let healthRecords = await collectHealthDataForUpload(days: 7)

            guard !healthRecords.isEmpty else {
                print("📤 [performUploadRecentData] 沒有需要上傳的數據")
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
                return
            }

            print("📤 [performUploadRecentData] 收集到 \(healthRecords.count) 筆健康數據，準備批量上傳")

            // 批量上傳到雲端
            try await service.uploadHealthDataBatch(healthRecords)

            print("📤 [performUploadRecentData] ✅ 批量上傳成功")

            // 記錄已上傳的日期
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current

            var newUploadedDates = uploadedDates
            for record in healthRecords {
                if let dateString = record["date"] as? String {
                    newUploadedDates.insert(dateString)
                    print("📤 [performUploadRecentData] 記錄已上傳日期: \(dateString)")
                }
            }
            uploadedDates = newUploadedDates

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

            Logger.firebase(
                "最近健康數據上傳成功",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "upload_recent_data"],
                jsonPayload: ["data_points": healthRecords.count]
            )

        } catch {
            // 任務取消是正常行為，不需要報錯或上傳到 Cloud Logging
            if error.isCancellationError {
                Logger.debug("上傳任務被取消，忽略錯誤")
                return
            }

            // 真正的錯誤才需要處理和記錄
            print("📤 [performUploadRecentData] ❌ 上傳失敗: \(error.localizedDescription)")

            await MainActor.run {
                self.uploadStatus = HealthDataUploadStatus(
                    isUploading: false,
                    uploadProgress: 0.0,
                    lastUploadDate: self.uploadStatus.lastUploadDate,
                    pendingUploadCount: self.uploadStatus.pendingUploadCount,
                    failedUploadCount: self.uploadStatus.failedUploadCount + 1,
                    lastError: error.localizedDescription
                )
            }

            Logger.firebase(
                "最近健康數據上傳失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "HealthDataUploadManagerV2", "action": "upload_recent_data"]
            )
        }

        // 保存上傳狀態
        saveUploadStatus()
    }
    
    // MARK: - Data Collection for Upload

    /// 從 HealthKit 收集健康數據並格式化為上傳格式（只收集未上傳的日期，最多7天）
    private func collectHealthDataForUpload(days: Int) async -> [[String: Any]] {
        // ✅ 檢查 1: 設備是否解鎖（受保護數據是否可訪問）
        let isProtectedDataAvailable = await MainActor.run {
            UIApplication.shared.isProtectedDataAvailable
        }

        guard isProtectedDataAvailable else {
            Logger.debug("設備被鎖定或受保護數據不可訪問，稍後自動重試")
            print("🔒 [collectHealthDataForUpload] 設備被鎖定，健康數據不可訪問")
            return []  // 靜默處理，這是正常情況（後台任務時設備通常是鎖定的）
        }

        // ✅ 檢查 2: HealthKit 授權狀態
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            Logger.error("HealthKit 數據類型不可用")
            print("❌ [collectHealthDataForUpload] HealthKit 數據類型不可用")
            return []
        }

        let hrvStatus = healthKitManager.healthStore.authorizationStatus(for: hrvType)
        let rhrStatus = healthKitManager.healthStore.authorizationStatus(for: rhrType)

        print("🔐 [collectHealthDataForUpload] HRV 授權狀態: \(hrvStatus.rawValue), 靜息心率授權狀態: \(rhrStatus.rawValue)")

        // 如果權限未確定，記錄日志但不阻止（可能是首次使用）
        if hrvStatus == .notDetermined || rhrStatus == .notDetermined {
            Logger.info("HealthKit 權限未確定，需要用戶授權")
            print("⚠️ [collectHealthDataForUpload] HealthKit 權限未確定")
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -min(days, 7), to: endDate) ?? endDate

        // 創建符合 API 格式的日期格式化器 (yyyy-MM-dd)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        // 獲取未上傳的日期
        let currentUploadedDates = uploadedDates
        var datesToUpload: [Date] = []

        for dayOffset in 0..<min(days, 7) {
            if let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: endDate) {
                let dateString = dateFormatter.string(from: Calendar.current.startOfDay(for: date))
                if !currentUploadedDates.contains(dateString) {
                    datesToUpload.append(Calendar.current.startOfDay(for: date))
                }
            }
        }

        print("📤 [collectHealthDataForUpload] 總共 \(days) 天，已上傳 \(currentUploadedDates.count) 天，待上傳 \(datesToUpload.count) 天")

        guard !datesToUpload.isEmpty else {
            print("📤 [collectHealthDataForUpload] 所有日期都已上傳，無需收集數據")
            return []
        }

        // 收集各種健康數據
        async let hrvData = healthKitManager.fetchHRVData(start: startDate, end: endDate)
        async let restingHRData = healthKitManager.fetchRestingHeartRateData(start: startDate, end: endDate)

        do {
            let hrv = try await hrvData
            let rhr = try await restingHRData

            print("📤 [collectHealthDataForUpload] 獲取到 \(hrv.count) 筆 HRV 原始數據")
            print("📤 [collectHealthDataForUpload] 獲取到 \(rhr.count) 筆靜息心率原始數據")

            // 將 HRV 數據按日期分組
            let groupedHRV = Dictionary(grouping: hrv) { record in
                Calendar.current.startOfDay(for: record.0).timeIntervalSince1970
            }

            // 將靜息心率數據按日期分組
            let groupedRHR = Dictionary(grouping: rhr) { record in
                Calendar.current.startOfDay(for: record.0).timeIntervalSince1970
            }

            print("📤 [collectHealthDataForUpload] 分組後有 \(groupedHRV.count) 天的 HRV 數據")
            print("📤 [collectHealthDataForUpload] 分組後有 \(groupedRHR.count) 天的靜息心率數據")

            // 構建上傳數據結構 - 只處理未上傳的日期
            var healthRecords: [[String: Any]] = []
            let datesToUploadSet = Set(datesToUpload.map { $0.timeIntervalSince1970 })

            // 合併所有有數據的日期
            let allDatesWithData = Set(groupedHRV.keys).union(Set(groupedRHR.keys))

            // 處理每個有數據的日期
            for dateInterval in allDatesWithData {
                // 只處理未上傳的日期
                guard datesToUploadSet.contains(dateInterval) else {
                    continue
                }

                let date = Date(timeIntervalSince1970: dateInterval)
                let dateString = dateFormatter.string(from: date)
                var record: [String: Any] = ["date": dateString]

                // 添加 HRV 數據（如果有）
                if let hrvValues = groupedHRV[dateInterval] {
                    let avgHRV = hrvValues.map { $0.1 }.reduce(0, +) / Double(hrvValues.count)
                    record["hrv_last_night_avg"] = avgHRV
                    print("📤 [collectHealthDataForUpload] 日期: \(dateString), HRV: \(avgHRV)")
                }

                // 添加靜息心率數據（如果有）
                if let rhrValues = groupedRHR[dateInterval] {
                    let avgRHR = rhrValues.map { $0.1 }.reduce(0, +) / Double(rhrValues.count)
                    record["resting_heart_rate"] = Int(avgRHR)
                    print("📤 [collectHealthDataForUpload] 日期: \(dateString), 靜息心率: \(Int(avgRHR))")
                }

                healthRecords.append(record)
            }

            print("📤 [collectHealthDataForUpload] 準備上傳 \(healthRecords.count) 筆健康記錄")

            Logger.firebase(
                "收集健康數據完成",
                level: .info,
                labels: ["module": "HealthDataUploadManagerV2", "action": "collect_health_data"],
                jsonPayload: [
                    "days": days,
                    "hrv_points": hrv.count,
                    "rhr_points": rhr.count,
                    "records_count": healthRecords.count
                ]
            )

            return healthRecords

        } catch {
            // ✅ 錯誤分類處理
            let nsError = error as NSError

            // 1. 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("收集健康數據任務被取消，忽略錯誤")
                print("🔄 [collectHealthDataForUpload] 任務被取消")
                return []
            }

            // 2. 設備鎖定或受保護數據不可訪問 - 靜默處理（這是正常情況）
            if nsError.domain == "com.apple.healthkit" &&
               error.localizedDescription.contains("Protected health data is inaccessible") {
                Logger.debug("設備鎖定或健康數據不可訪問，稍後自動重試")
                print("🔒 [collectHealthDataForUpload] 健康數據不可訪問（設備可能被鎖定）")
                return []  // 不記錄為錯誤
            }

            // 3. 真正的錯誤才記錄到 Firebase
            Logger.firebase(
                "收集健康數據失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "HealthDataUploadManagerV2", "action": "collect_health_data"],
                jsonPayload: [
                    "error_domain": nsError.domain,
                    "error_code": nsError.code,
                    "error_description": error.localizedDescription
                ]
            )

            print("❌ [collectHealthDataForUpload] 收集健康數據失敗: \(error.localizedDescription)")

            // 返回空數組
            return []
        }
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
    
    // ✅ 已移除：schedulePeriodicRefresh()
    // 原因：Garmin/Strava 數據由後端自動同步，前端 30 分鐘輪詢會造成每天 144 次不必要的 API 調用
    // 數據會在 App 啟動時載入，用戶可以通過下拉刷新手動更新
    
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

            // 創建符合 API 格式的日期格式化器 (yyyy-MM-dd)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current

            print("📊 [getLocalHealthData] 開始從 HealthKit 獲取數據，天數: \(days)")
            print("📊 [getLocalHealthData] 從 HealthKit 獲取到 \(hrv.count) 筆 HRV 原始數據")

            // 將 HRV 數據按日期分組並轉換為 HealthRecord
            // 使用 TimeInterval 作為 key 確保線程安全（避免 Date 對象作為 Dictionary key）
            let groupedHRV = Dictionary(grouping: hrv) { record in
                Calendar.current.startOfDay(for: record.0).timeIntervalSince1970
            }

            print("📊 [getLocalHealthData] 分組後有 \(groupedHRV.count) 天的數據")

            for (timeInterval, values) in groupedHRV {
                let date = Date(timeIntervalSince1970: timeInterval)
                let avgHRV = values.map { $0.1 }.reduce(0, +) / Double(values.count)
                let dateString = dateFormatter.string(from: date)

                print("📊 [getLocalHealthData] 日期: \(dateString), 平均HRV: \(avgHRV), 原始數據數量: \(values.count)")
                
                let record = HealthRecord(
                    date: dateString,
                    dailyCalories: nil,
                    hrvLastNightAvg: avgHRV,
                    restingHeartRate: nil,
                    atl: nil,
                    ctl: nil,
                    fitness: nil,
                    tsb: nil,
                    updatedAt: nil,
                    workoutTrigger: nil
                )
                records.append(record)
            }
            
            // 添加靜息心率記錄（如果有值）
            if restingHR > 0 {
                let today = Calendar.current.startOfDay(for: Date())
                let dateString = dateFormatter.string(from: today)
                
                let record = HealthRecord(
                    date: dateString,
                    dailyCalories: nil,
                    hrvLastNightAvg: nil,
                    restingHeartRate: Int(restingHR),
                    atl: nil,
                    ctl: nil,
                    fitness: nil,
                    tsb: nil,
                    updatedAt: nil,
                    workoutTrigger: nil
                )
                records.append(record)
            }

            print("📊 [getLocalHealthData] 最終返回 \(records.count) 筆 HealthRecord")
            for record in records.prefix(3) {
                print("   - 日期: \(record.date), HRV: \(record.hrvLastNightAvg ?? 0), RHR: \(record.restingHeartRate ?? 0)")
            }

            return records
            
        } catch {
            // 任務取消是正常行為，不記錄錯誤
            if error.isCancellationError {
                Logger.debug("獲取本地 HealthKit 數據任務被取消，忽略錯誤")
                return []
            }

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
        // ⚠️ 必須在 MainActor 上修改 @Published 屬性
        Task { @MainActor in
            // 載入上傳狀態
            self.uploadStatus = self.cacheManager.loadUploadStatus() ?? .idle

            // 載入快取的健康數據集合
            for days in self.supportedDaysRanges {
                if let collection = self.cacheManager.loadHealthDataCollection(for: days) {
                    self.healthDataCollections[days] = collection
                }
            }
        }
    }

    private func loadUploadStatus() {
        // ⚠️ 必須在 MainActor 上修改 @Published 屬性
        Task { @MainActor in
            self.uploadStatus = self.cacheManager.loadUploadStatus() ?? .idle
        }
    }
    
    private func saveUploadStatus() {
        // ⚠️ 必須在 MainActor 上讀取 @Published 屬性
        Task { @MainActor in
            let status = self.uploadStatus
            self.cacheManager.saveUploadStatus(status)
        }
    }
    
    // MARK: - Public Interface
    
    /// 獲取健康數據（優先從緩存）
    func getHealthData(days: Int = 7) async -> [HealthRecord] {
        print("📊 [getHealthData] 被調用，天數: \(days)")

        // ✅ 使用 executeTask 防止重複調用
        let result = await executeTask(id: TaskID("get_health_data_\(days)")) {
            return await self.performGetHealthData(days: days)
        }

        // ⚠️ 必須在 MainActor 上訪問 @Published 屬性
        let fallback = await MainActor.run {
            self.healthDataCollections[days]?.records ?? []
        }
        return result ?? fallback
    }

    /// 執行實際的健康數據獲取邏輯
    private func performGetHealthData(days: Int) async -> [HealthRecord] {
        // ⚠️ 必須在 MainActor 上訪問 @Published 屬性
        let cachedCollection = await MainActor.run {
            self.healthDataCollections[days]
        }

        if let collection = cachedCollection {
            print("📊 [getHealthData] ✅ 從內存緩存返回 \(collection.records.count) 筆記錄")
            let hrvCount = collection.records.filter { $0.hrvLastNightAvg != nil }.count
            print("📊 [getHealthData] 內存緩存中 HRV 記錄數: \(hrvCount)")

            // ✅ 優化：檢查緩存時效性（30 分鐘內不重新載入）
            let cacheAge = Date().timeIntervalSince(collection.lastUpdated)
            let cacheValid = cacheAge < 1800 // 30 分鐘

            if cacheValid {
                print("📊 [getHealthData] 緩存有效（更新於 \(Int(cacheAge/60)) 分鐘前），直接返回")
                return collection.records
            }

            // ⚠️ 如果快取中沒有 HRV 數據，且是 Apple Health 用戶，強制刷新
            if hrvCount == 0 && userPreferenceManager.dataSourcePreference == .appleHealth {
                print("📊 [getHealthData] ⚠️ 快取中無 HRV 數據，強制刷新")
                await MainActor.run {
                    self.healthDataCollections.removeValue(forKey: days)
                }
                // ✅ 使用 executeTask 防止重複調用
                await executeTask(id: TaskID("load_health_data_\(days)"), cooldownSeconds: 30) {
                    try? await APICallTracker.$currentSource.withValue("HealthDataUploadManagerV2: getHealthData") {
                        try await self.loadHealthDataForRange(days: days)
                    }
                }
                let refreshedResult = await MainActor.run {
                    self.healthDataCollections[days]?.records ?? []
                }
                let refreshedHrvCount = refreshedResult.filter { $0.hrvLastNightAvg != nil }.count
                print("📊 [getHealthData] 刷新後返回 \(refreshedResult.count) 筆記錄，HRV 記錄數: \(refreshedHrvCount)")
                return refreshedResult
            }

            // 緩存過期但有數據，背景更新但立即返回舊數據
            print("📊 [getHealthData] 緩存過期，背景更新中...")
            Task.detached { [weak self] in
                // ✅ 使用 executeTask 防止重複調用
                await self?.executeTask(id: TaskID("load_health_data_\(days)"), cooldownSeconds: 30) {
                    try? await APICallTracker.$currentSource.withValue("HealthDataUploadManagerV2: getHealthData (background)") {
                        print("📊 [getHealthData] 緩存過期，背景更新loadHealthDataForRange")
                        try await self?.loadHealthDataForRange(days: days)
                    }
                }
            }
            return collection.records
        }

        print("📊 [getHealthData] 內存緩存未命中，觸發載入")

        // 如果沒有快取，觸發載入
        // ✅ 使用 executeTask 防止重複調用
        await executeTask(id: TaskID("load_health_data_\(days)"), cooldownSeconds: 30) {
            try? await APICallTracker.$currentSource.withValue("HealthDataUploadManagerV2: getHealthData") {
                print("📊 [getHealthData] 如果沒有快取，觸發載入loadHealthDataForRange")
                try await self.loadHealthDataForRange(days: days)
            }
        }
        let result = await MainActor.run {
            self.healthDataCollections[days]?.records ?? []
        }
        print("📊 [getHealthData] 載入後返回 \(result.count) 筆記錄")
        return result
    }

    /// 強制刷新健康數據（清除快取）
    func forceRefreshHealthData(days: Int = 7) async {
        print("📊 [getHealthData] 強制刷新，天數: \(days)")
        // ⚠️ 必須在 MainActor 上修改 @Published 屬性
        await MainActor.run {
            self.healthDataCollections.removeValue(forKey: days)
        }
        cacheManager.clearCache()
        print("📊 [getHealthData] 強制刷新：loadHealthDataForRange")
        // ✅ 使用 executeTask 防止重複調用
        await executeTask(id: TaskID("load_health_data_\(days)"), cooldownSeconds: 30) {
            try? await self.loadHealthDataForRange(days: days)
        }
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
