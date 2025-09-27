import Foundation
import HealthKit
import BackgroundTasks

/// Apple Health 數據上傳管理器
/// 提供可靠的數據上傳機制，包含離線緩存、重試、背景上傳等功能
class HealthDataUploadManager: ObservableObject, TaskManageable, Cacheable {
    static let shared = HealthDataUploadManager()
    
    private let healthKitManager = HealthKitManager()
    private let apiClient = APIClient.shared
    private let userDefaults = UserDefaults.standard
    
    // 緩存和重試配置
    private let maxRetries = 3
    private let retryInterval: TimeInterval = 300 // 5分鐘
    private let batchSize = 7 // 每次最多上傳7天數據
    
    // 緩存相關
    private let cachedDataKey = "cached_health_data"
    private let lastUploadDateKey = "last_health_upload_date"
    private let pendingUploadsKey = "pending_health_uploads"
    private let cachedHealthDataKey = "cached_health_daily_data"
    private let healthDataCacheTimeKey = "health_data_cache_time"
    
    // 上傳狀態
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var lastUploadDate: Date?
    @Published var pendingUploadCount = 0
    
    // TaskManageable 協議實現 (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // Cacheable 協議實現
    var cacheIdentifier: String { "HealthDataUploadManager" }
    
    private init() {
        loadCachedState()
        // setupBackgroundTaskHandler() // 背景任務現在在 HavitalApp.swift 中統一註冊

        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
    }
    
    // MARK: - Cacheable Protocol Implementation
    
    func clearCache() {
        clearHealthDataCache()
    }
    
    func getCacheSize() -> Int {
        let keys = ["7", "14", "30"].map { "\(cachedHealthDataKey)_\($0)" }
        return keys.compactMap { userDefaults.data(forKey: $0)?.count }.reduce(0, +)
    }
    
    func isExpired() -> Bool {
        // 檢查所有緩存是否都過期
        let keys = ["7", "14", "30"].map { "\(healthDataCacheTimeKey)_\($0)" }
        return keys.allSatisfy { key in
            guard let cacheTime = userDefaults.object(forKey: key) as? Date else { return true }
            return Date().timeIntervalSince(cacheTime) >= 1800 // 30分鐘
        }
    }
    
    deinit {
        cancelAllTasks()
        Task {
            await stopHealthKitObservers()
        }
    }
    
    // MARK: - Public Interface
    
    /// 開始定期健康數據同步
    func startHealthDataSync() async {
        let dataSource = UserPreferenceManager.shared.dataSourcePreference
        print("開始健康數據同步 - 數據源: \(dataSource.displayName)")
        
        switch dataSource {
        case .appleHealth:
            // Apple Health: 上傳本地數據 + 設置觀察者
            await uploadPendingHealthData()
            setupHealthKitObserver()
            // scheduleBackgroundSync() // 背景任務現在在 HavitalApp.swift 中統一處理

        case .garmin:
            // Garmin: 只設置定期 API 刷新
            setupGarminDataRefresh()
            // scheduleBackgroundSync() // 背景任務現在在 HavitalApp.swift 中統一處理
            
        case .unbound:
            print("數據源未綁定，跳過健康數據同步")
            return
        }
    }
    
    /// 設置 HealthKit 觀察者，監聽新數據
    private func setupHealthKitObserver() {
        // 監聽 HRV 數據更新
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let hrvQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task {
                // HRV 數據更新，等待一段時間後上傳（讓數據穩定）
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 等待30分鐘
                await self?.uploadRecentHealthData()
                
                // 通知 UI 刷新數據
                await self?.notifyAppleHealthDataRefresh()
                completionHandler()
            }
        }
        
        // 監聽靜息心率數據更新
        let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        let rhrQuery = HKObserverQuery(sampleType: rhrType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task {
                // 靜息心率更新，立即嘗試上傳
                await self?.uploadRecentHealthData()
                
                // 通知 UI 刷新數據
                await self?.notifyAppleHealthDataRefresh()
                completionHandler()
            }
        }
        
        // 使用 HealthKitObserverCoordinator 註冊 Observer
        Task {
            let hrvRegistered = await HealthKitObserverCoordinator.shared.registerObserver(
                type: HealthKitObserverCoordinator.ObserverType.heartRateVariability,
                query: hrvQuery,
                enableBackground: true,
                sampleType: hrvType
            )
            
            let rhrRegistered = await HealthKitObserverCoordinator.shared.registerObserver(
                type: HealthKitObserverCoordinator.ObserverType.restingHeartRate,
                query: rhrQuery,
                enableBackground: true,
                sampleType: rhrType
            )
            
            if hrvRegistered {
                print("HealthDataUploadManager: 成功註冊 HRV Observer")
            }
            if rhrRegistered {
                print("HealthDataUploadManager: 成功註冊 RHR Observer")
            }
        }
    }
    
    /// 立即同步健康數據
    func syncHealthDataNow() async {
        await uploadRecentHealthData()
    }
    
    /// 停止所有 HealthKit 觀察者
    private func stopHealthKitObservers() async {
        await HealthKitObserverCoordinator.shared.removeObserver(type: HealthKitObserverCoordinator.ObserverType.heartRateVariability)
        await HealthKitObserverCoordinator.shared.removeObserver(type: HealthKitObserverCoordinator.ObserverType.restingHeartRate)
        print("HealthDataUploadManager: 已停止所有 HealthKit 觀察者")
    }
    
    /// 獲取健康數據（優先從緩存，然後 API，最後本地數據）
    func getHealthData(days: Int = 7) async -> [HealthRecord] {
        return await executeTask(id: TaskID("get_health_data_\(days)")) {
            await self.performGetHealthData(days: days)
        } ?? []
    }
    
    /// 執行實際的健康數據獲取邏輯
    private func performGetHealthData(days: Int) async -> [HealthRecord] {
        print("🔍 [HealthDataUploadManager] performGetHealthData 開始，days: \(days)")

        let dataSource = UserPreferenceManager.shared.dataSourcePreference
        print("🔍 [HealthDataUploadManager] 用戶數據來源: \(dataSource)")

        // Apple Health 用戶直接使用本地 HealthKit 數據
        if dataSource == .appleHealth {
            print("🔍 [HealthDataUploadManager] Apple Health 用戶，直接使用本地 HealthKit 數據")
            let localData = await getLocalHealthData(days: days)

            let hrvCount = localData.filter { $0.hrvLastNightAvg != nil }.count
            print("🔍 [HealthDataUploadManager] 從 HealthKit 載入健康數據:")
            print("   - 總記錄數: \(localData.count)")
            print("   - HRV 有效記錄: \(hrvCount)")

            return localData
        }

        // Garmin 用戶使用 API 數據流程
        print("🔍 [HealthDataUploadManager] Garmin 用戶，使用 API 數據流程")

        // 首先檢查緩存
        if let cachedData = getCachedHealthData(days: days) {
            let hrvCount = cachedData.filter { $0.hrvLastNightAvg != nil }.count
            print("🔍 [HealthDataUploadManager] 從緩存載入健康數據:")
            print("   - 總記錄數: \(cachedData.count)")
            print("   - HRV 有效記錄: \(hrvCount)")
            return cachedData
        }

        print("🔍 [HealthDataUploadManager] 緩存為空，嘗試從 API 獲取")

        // 嘗試從 API 獲取
        do {
            let response = try await apiClient.fetchHealthDaily(limit: days)
            let healthData = response.healthData

            let hrvCount = healthData.filter { $0.hrvLastNightAvg != nil }.count
            print("🔍 [HealthDataUploadManager] 從 API 載入健康數據:")
            print("   - 總記錄數: \(healthData.count)")
            print("   - HRV 有效記錄: \(hrvCount)")

            // 緩存 API 數據
            cacheHealthData(healthData, days: days)
            print("🔍 [HealthDataUploadManager] API 數據已緩存")

            return healthData
        } catch {
            print("🔍 [HealthDataUploadManager] 從 API 獲取健康數據失敗，嘗試本地數據:")
            print("   - 錯誤: \(error)")

            // 回退到本地 HealthKit 數據
            print("🔍 [HealthDataUploadManager] 開始從 HealthKit 獲取本地數據")
            let localData = await getLocalHealthData(days: days)

            let hrvCount = localData.filter { $0.hrvLastNightAvg != nil }.count
            print("🔍 [HealthDataUploadManager] 從 HealthKit 載入健康數據:")
            print("   - 總記錄數: \(localData.count)")
            print("   - HRV 有效記錄: \(hrvCount)")

            return localData
        }
    }
    
    // MARK: - Private Implementation
    
    /// 上傳待處理的健康數據
    private func uploadPendingHealthData() async {
        let pendingUploads = getPendingUploads()
        guard !pendingUploads.isEmpty else {
            await uploadRecentHealthData()
            return
        }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            pendingUploadCount = pendingUploads.count
        }
        
        var successCount = 0
        for (index, upload) in pendingUploads.enumerated() {
            let success = await uploadHealthRecord(upload.record, retryCount: upload.retryCount)
            if success {
                removePendingUpload(upload.id)
                successCount += 1
            } else {
                incrementRetryCount(upload.id)
            }
            
            await MainActor.run {
                uploadProgress = Double(index + 1) / Double(pendingUploads.count)
            }
        }
        
        let finalSuccessCount = successCount
        await MainActor.run {
            isUploading = false
            if finalSuccessCount > 0 {
                lastUploadDate = Date()
                saveLastUploadDate()
            }
            pendingUploadCount = getPendingUploads().count
        }
        
        Logger.firebase(
            "健康數據批量上傳完成",
            level: .info,
            labels: [
                "module": "HealthDataUploadManager",
                "action": "upload_pending_data"
            ],
            jsonPayload: [
                "success_count": finalSuccessCount,
                "total_count": pendingUploads.count
            ]
        )
    }
    
    /// 上傳最近的健康數據
    private func uploadRecentHealthData() async {
        let daysSinceLastUpload = getDaysSinceLastUpload()
        let daysToUpload = min(daysSinceLastUpload, 30) // 最多30天
        
        guard daysToUpload > 0 else {
            print("無需上傳新的健康數據")
            return
        }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }
        
        do {
            let healthRecords = await generateHealthRecords(days: daysToUpload)
            var successCount = 0
            
            for (index, record) in healthRecords.enumerated() {
                let success = await uploadHealthRecord(record)
                if success {
                    successCount += 1
                } else {
                    // 上傳失敗，加入待重試隊列
                    addPendingUpload(record)
                }
                
                await MainActor.run {
                    uploadProgress = Double(index + 1) / Double(healthRecords.count)
                }
            }
            
            let finalSuccessCount2 = successCount
            await MainActor.run {
                isUploading = false
                if finalSuccessCount2 > 0 {
                    lastUploadDate = Date()
                    saveLastUploadDate()
                }
                pendingUploadCount = getPendingUploads().count
            }
            
            Logger.firebase(
                "最近健康數據上傳完成",
                level: .info,
                labels: [
                    "module": "HealthDataUploadManager",
                    "action": "upload_recent_data"
                ],
                jsonPayload: [
                    "success_count": finalSuccessCount2,
                    "total_count": healthRecords.count,
                    "days_uploaded": daysToUpload
                ]
            )
            
        } catch {
            await MainActor.run {
                isUploading = false
            }
            
            Logger.firebase(
                "健康數據上傳失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "HealthDataUploadManager",
                    "action": "upload_recent_data"
                ]
            )
        }
    }
    
    /// 上傳單筆健康記錄
    private func uploadHealthRecord(_ record: HealthRecord, retryCount: Int = 0) async -> Bool {
        // TODO: 實現實際的 API 調用
        // do {
        //     let success = try await apiClient.uploadHealthRecord(record)
        //     return success
        // } catch {
        //     Logger.firebase(...)
        //     return false
        // }
        
        // 模擬上傳（實際實現時替換）
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        } catch {
            // Task.sleep 可能因為取消而拋出錯誤
        }
        
        Logger.firebase(
            "健康記錄上傳成功 (模擬)",
            level: .info,
            labels: [
                "module": "HealthDataUploadManager",
                "action": "upload_health_record"
            ],
            jsonPayload: [
                "date": record.date,
                "retry_count": retryCount
            ]
        )
        
        return true
    }
    
    /// 從 HealthKit 生成健康記錄
    private func generateHealthRecords(days: Int) async -> [HealthRecord] {
        print("🔍 [HealthDataUploadManager] generateHealthRecords 開始，天數: \(days)")

        var records: [HealthRecord] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }

            print("🔍 [HealthDataUploadManager] 處理第 \(i) 天: \(date)")
            let record = await generateHealthRecord(for: date)
            records.append(record)
        }

        print("🔍 [HealthDataUploadManager] generateHealthRecords 完成，生成 \(records.count) 筆記錄")
        return records
    }
    
    /// 為特定日期生成健康記錄
    private func generateHealthRecord(for date: Date) async -> HealthRecord {
        let dateString = formatDateForAPI(date)
        let isToday = Calendar.current.isDateInToday(date)
        
        do {
            // 獲取該日期的健康數據
            var hrvData: Double? = nil
            var restingHR: Double? = nil
            var calories: Double? = nil
            
            // HRV 數據處理：昨晚的 HRV 通常在早上才可用
            print("🔍 [HealthDataUploadManager] 檢查日期 \(dateString) 的 HRV 數據:")
            print("   - isToday: \(isToday)")
            print("   - shouldFetchTodayHRV(): \(shouldFetchTodayHRV())")

            if !isToday || shouldFetchTodayHRV() {
                let startOfDay = Calendar.current.startOfDay(for: date)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date

                print("🔍 [HealthDataUploadManager] 開始獲取 HRV 數據:")
                print("   - 查詢範圍: \(startOfDay) ~ \(endOfDay)")

                let hrvDataPoints = try await healthKitManager.fetchHRVData(start: startOfDay, end: endOfDay)
                print("🔍 [HealthDataUploadManager] HRV 查詢結果:")
                print("   - 原始數據點數量: \(hrvDataPoints.count)")

                if !hrvDataPoints.isEmpty {
                    let values = hrvDataPoints.map { $0.1 }
                    let average = values.reduce(0, +) / Double(values.count)
                    hrvData = average
                    print("   - HRV 平均值: \(average) ms")
                } else {
                    hrvData = nil
                    print("   - HRV 數據為空")
                }

                // 如果是今天且還沒有 HRV 數據，可能需要等待
                if isToday && hrvData == nil {
                    print("今天的 HRV 數據尚未可用，將在後續上傳中重試")
                }
            } else {
                print("🔍 [HealthDataUploadManager] 跳過今天的 HRV 數據獲取 (shouldFetchTodayHRV = false)")
            }
            
            // 靜息心率：通常當天就有
            // 注意：fetchRestingHeartRate() 獲取的是最近的靜息心率，不是特定日期
            restingHR = await healthKitManager.fetchRestingHeartRate()
            
            // 卡路里：需要自己實現按日期獲取的邏輯
            calories = try await fetchActiveCaloriesForDate(date)
            
            let record = HealthRecord(
                date: dateString,
                dailyCalories: calories.flatMap { Int($0) },
                hrvLastNightAvg: hrvData,
                restingHeartRate: restingHR.flatMap { Int($0) },
                atl: nil,
                ctl: nil,
                fitness: nil,
                tsb: nil,
                updatedAt: nil,
                workoutTrigger: nil
            )
            
            // 記錄數據完整性
            logDataCompleteness(for: dateString, record: record)
            
            return record
            
        } catch {
            print("獲取 \(date) 的健康數據失敗: \(error)")
            
            // 即使某天數據獲取失敗，也創建一個空記錄
            let record = HealthRecord(
                date: dateString,
                dailyCalories: nil,
                hrvLastNightAvg: nil,
                restingHeartRate: nil,
                atl: nil,
                ctl: nil,
                fitness: nil,
                tsb: nil,
                updatedAt: nil,
                workoutTrigger: nil
            )
            
            logDataCompleteness(for: dateString, record: record)
            return record
        }
    }
    
    /// 判斷是否應該獲取今天的 HRV 數據
    private func shouldFetchTodayHRV() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        print("🔍 [HealthDataUploadManager] shouldFetchTodayHRV 檢查:")
        print("   - 當前時間: \(now)")
        print("   - 當前小時: \(hour)")
        print("   - 是否 >= 8 點: \(hour >= 8)")

        // 早上 8 點之後才嘗試獲取昨晚的 HRV 數據
        return hour >= 8
    }
    
    /// 記錄數據完整性日誌
    private func logDataCompleteness(for date: String, record: HealthRecord) {
        var availableFields: [String] = []
        var missingFields: [String] = []
        
        if record.dailyCalories != nil {
            availableFields.append("calories")
        } else {
            missingFields.append("calories")
        }
        
        if record.hrvLastNightAvg != nil {
            availableFields.append("hrv")
        } else {
            missingFields.append("hrv")
        }
        
        if record.restingHeartRate != nil {
            availableFields.append("resting_hr")
        } else {
            missingFields.append("resting_hr")
        }
        
        Logger.firebase(
            "健康數據完整性檢查",
            level: missingFields.isEmpty ? .info : .warn,
            labels: [
                "module": "HealthDataUploadManager",
                "action": "data_completeness_check"
            ],
            jsonPayload: [
                "date": date,
                "available_fields": availableFields,
                "missing_fields": missingFields,
                "completeness_score": Double(availableFields.count) / 3.0
            ]
        )
    }
    
    /// 格式化日期為 API 所需格式
    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    /// 獲取特定日期的活動卡路里數據
    private func fetchActiveCaloriesForDate(_ date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        
        let healthStore = HKHealthStore()
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sum = statistics?.sumQuantity() {
                    let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                    continuation.resume(returning: calories > 0 ? calories : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 獲取本地健康數據（回退方案）
    private func getLocalHealthData(days: Int) async -> [HealthRecord] {
        return await generateHealthRecords(days: days)
    }
    
    // MARK: - 緩存和持久化
    
    private func loadCachedState() {
        lastUploadDate = userDefaults.object(forKey: lastUploadDateKey) as? Date
        pendingUploadCount = getPendingUploads().count
    }
    
    private func saveLastUploadDate() {
        userDefaults.set(lastUploadDate, forKey: lastUploadDateKey)
    }
    
    private func getDaysSinceLastUpload() -> Int {
        guard let lastUpload = lastUploadDate else {
            return 14 // 首次使用，上傳最近14天
        }
        
        let daysSince = Calendar.current.dateComponents([.day], from: lastUpload, to: Date()).day ?? 0
        return max(0, daysSince)
    }
    
    // MARK: - 待重試隊列管理
    
    private struct PendingUpload: Codable {
        let id: UUID
        let record: HealthRecord
        let retryCount: Int
        let createdAt: Date
    }
    
    private func addPendingUpload(_ record: HealthRecord) {
        var pendingUploads = getPendingUploads()
        let upload = PendingUpload(
            id: UUID(),
            record: record,
            retryCount: 0,
            createdAt: Date()
        )
        pendingUploads.append(upload)
        savePendingUploads(pendingUploads)
    }
    
    private func removePendingUpload(_ id: UUID) {
        var pendingUploads = getPendingUploads()
        pendingUploads.removeAll { $0.id == id }
        savePendingUploads(pendingUploads)
    }
    
    private func incrementRetryCount(_ id: UUID) {
        var pendingUploads = getPendingUploads()
        if let index = pendingUploads.firstIndex(where: { $0.id == id }) {
            let upload = pendingUploads[index]
            if upload.retryCount < maxRetries {
                pendingUploads[index] = PendingUpload(
                    id: upload.id,
                    record: upload.record,
                    retryCount: upload.retryCount + 1,
                    createdAt: upload.createdAt
                )
            } else {
                // 超過最大重試次數，移除
                pendingUploads.remove(at: index)
            }
        }
        savePendingUploads(pendingUploads)
    }
    
    private func getPendingUploads() -> [PendingUpload] {
        guard let data = userDefaults.data(forKey: pendingUploadsKey),
              let uploads = try? JSONDecoder().decode([PendingUpload].self, from: data) else {
            return []
        }
        
        // 清理過期的待重試項目（超過7天）
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return uploads.filter { $0.createdAt > cutoffDate }
    }
    
    private func savePendingUploads(_ uploads: [PendingUpload]) {
        if let data = try? JSONEncoder().encode(uploads) {
            userDefaults.set(data, forKey: pendingUploadsKey)
        }
    }
    
    // MARK: - 背景任務
    
    private func setupBackgroundTaskHandler() {
        // 標準健康數據同步任務
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.havital.health-data-sync", using: nil) { task in
            self.handleBackgroundHealthSync(task as! BGProcessingTask)
        }
        
        // HRV 重試同步任務
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.havital.hrv-retry-sync", using: nil) { task in
            self.handleHRVRetrySync(task as! BGProcessingTask)
        }
    }
    
    private func scheduleBackgroundSync() {
        // 標準背景同步（每4小時）
        let request = BGProcessingTaskRequest(identifier: "com.havital.health-data-sync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60) // 4小時後
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("已安排健康數據背景同步任務")
        } catch {
            print("無法安排健康數據背景同步任務: \(error)")
        }
        
        // HRV 專用同步（每天早上8:30執行，確保獲取昨晚的HRV）
        // scheduleHRVRetrySync() // 背景任務現在在 HavitalApp.swift 中統一處理
    }
    
    private func scheduleHRVRetrySync() {
        let calendar = Calendar.current
        let now = Date()
        
        // 計算下次早上8:30的時間
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        components.minute = 30
        
        guard var targetDate = calendar.date(from: components) else { return }
        
        // 如果今天的8:30已經過了，就安排明天的8:30
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }
        
        let request = BGProcessingTaskRequest(identifier: "com.havital.hrv-retry-sync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = targetDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("已安排 HRV 重試同步任務：\(targetDate)")
        } catch {
            print("無法安排 HRV 重試同步任務: \(error)")
        }
    }
    
    private func handleBackgroundHealthSync(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await uploadPendingHealthData()
            task.setTaskCompleted(success: true)
            
            // 安排下一次背景同步
            // scheduleBackgroundSync() // 背景任務現在在 HavitalApp.swift 中統一處理
        }
    }
    
    private func handleHRVRetrySync(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let dataSource = UserPreferenceManager.shared.dataSourcePreference
            
            switch dataSource {
            case .appleHealth:
                // Apple Health: 專門重試昨天和今天的 HRV 數據
                await uploadRecentHealthData()
                
            case .garmin:
                // Garmin: 強制刷新 API 數據
                await refreshGarminHealthData()
                
            case .unbound:
                print("數據源未綁定，跳過 HRV 重試同步")
            }
            
            task.setTaskCompleted(success: true)
            
            // 安排下一次 HRV 重試同步
            // scheduleHRVRetrySync() // 背景任務現在在 HavitalApp.swift 中統一處理
        }
    }
    
    /// 設置 Garmin 數據刷新機制
    private func setupGarminDataRefresh() {
        print("設置 Garmin 數據定期刷新機制")
        
        // 立即刷新一次數據
        Task {
            await refreshGarminHealthData()
        }
    }
    
    /// 刷新 Garmin 健康數據
    private func refreshGarminHealthData() async {
        print("刷新 Garmin 健康數據")
        
        // 清除緩存並重新獲取數據
        clearHealthDataCache()
        
        // 通知 SharedHealthDataManager 刷新數據
        await notifyGarminDataRefresh()
        
        Logger.firebase(
            "Garmin 健康數據刷新完成",
            level: .info,
            labels: [
                "module": "HealthDataUploadManager",
                "action": "refresh_garmin_data"
            ]
        )
    }
    
    /// 通知 SharedHealthDataManager 刷新數據
    private func notifyGarminDataRefresh() async {
        // 發送通知給 UI 層刷新數據
        await MainActor.run {
            NotificationCenter.default.post(
                name: .garminHealthDataRefresh,
                object: nil
            )
        }
    }
    
    /// 通知 Apple Health 數據更新
    private func notifyAppleHealthDataRefresh() async {
        // 發送通知給 UI 層刷新數據
        await MainActor.run {
            NotificationCenter.default.post(
                name: .appleHealthDataRefresh,
                object: nil
            )
        }
    }
    
    // MARK: - Health Data Caching
    
    /// 緩存健康數據
    private func cacheHealthData(_ data: [HealthRecord], days: Int) {
        let cacheKey = "\(cachedHealthDataKey)_\(days)"
        let timeKey = "\(healthDataCacheTimeKey)_\(days)"
        
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: cacheKey)
            userDefaults.set(Date(), forKey: timeKey)
        }
    }
    
    /// 獲取緩存的健康數據
    private func getCachedHealthData(days: Int) -> [HealthRecord]? {
        let cacheKey = "\(cachedHealthDataKey)_\(days)"
        let timeKey = "\(healthDataCacheTimeKey)_\(days)"
        
        // 檢查緩存時間（30分鐘有效期）
        guard let cacheTime = userDefaults.object(forKey: timeKey) as? Date,
              Date().timeIntervalSince(cacheTime) < 1800 else {
            print("健康數據緩存已過期或不存在")
            return nil
        }
        
        // 獲取緩存數據
        guard let data = userDefaults.data(forKey: cacheKey),
              let cachedData = try? JSONDecoder().decode([HealthRecord].self, from: data) else {
            print("無法解析健康數據緩存")
            return nil
        }
        
        return cachedData
    }
    
    /// 清除健康數據緩存
    func clearHealthDataCache() {
        let keys = ["7", "14", "30"].flatMap { days in
            ["\(cachedHealthDataKey)_\(days)", "\(healthDataCacheTimeKey)_\(days)"]
        }
        
        keys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        
        print("已清除所有健康數據緩存")
    }
    
    /// 強制刷新健康數據（清除緩存後重新獲取）
    func refreshHealthData(days: Int = 7) async -> [HealthRecord] {
        // 清除特定天數的緩存
        let cacheKey = "\(cachedHealthDataKey)_\(days)"
        let timeKey = "\(healthDataCacheTimeKey)_\(days)"
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: timeKey)
        
        // 重新獲取數據
        return await getHealthData(days: days)
    }
}

// MARK: - Extensions

extension HealthDataUploadManager {
    
    /// 獲取上傳統計資訊
    func getUploadStats() -> (pendingCount: Int, lastUpload: Date?) {
        return (pendingUploadCount, lastUploadDate)
    }
    
    /// 強制重試所有待上傳項目
    func retryAllPendingUploads() async {
        await uploadPendingHealthData()
    }
    
    /// 清除所有待上傳項目（謹慎使用）
    func clearAllPendingUploads() {
        savePendingUploads([])
        pendingUploadCount = 0
    }
}
