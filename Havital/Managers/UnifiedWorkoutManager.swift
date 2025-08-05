import Foundation
import HealthKit
import BackgroundTasks

/// 統一運動數據管理器
/// 負責協調 Apple Health 和 Garmin 的資料流程，實現統一的 V2 API 資料架構
class UnifiedWorkoutManager: ObservableObject, TaskManageable {
    static let shared = UnifiedWorkoutManager()
    
    // 依賴服務
    private let workoutV2Service = WorkoutV2Service.shared
    private let cacheManager = WorkoutV2CacheManager.shared
    private let workoutBackgroundManager = WorkoutBackgroundManager.shared
    private let healthKitManager = HealthKitManager()
    
    // 狀態
    @Published var isLoading = false
    @Published var workouts: [WorkoutV2] = []
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private var healthKitObserver: HKObserverQuery?
    private var isObserving = false
    
    // 任務管理 - 使用 Actor-based TaskRegistry
    let taskRegistry = TaskRegistry()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public Interface
    
    /// 初始化統一工作流程
    func initialize() async {
        let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
        
        Logger.firebase(
            "UnifiedWorkoutManager 初始化",
            level: .info,
            labels: [
                "module": "UnifiedWorkoutManager",
                "action": "initialize"
            ],
            jsonPayload: [
                "data_source": dataSourcePreference.rawValue
            ]
        )
        
        switch dataSourcePreference {
        case .appleHealth:
            await setupAppleHealthWorkflow()
        case .garmin:
            await setupGarminWorkflow()
        case .unbound:
            print("UnifiedWorkoutManager: 尚未綁定數據源")
        }

    }
    
    /// 載入運動記錄（統一介面）
    func loadWorkouts() async {
        await executeTask(id: TaskID("load_workouts")) {
            await self.performLoadWorkouts()
        }
    }
    
    /// 執行實際的載入邏輯
    private func performLoadWorkouts() async {
        // 防止重複調用
        if await MainActor.run(body: { self.isLoading }) {
            print("UnifiedWorkoutManager: 正在載入中，跳過重複調用")
            return
        }
        
        await MainActor.run {
            isLoading = true
            syncError = nil
        }
        
        do {
            // 檢查是否被取消
            try Task.checkCancellation()
            
            // 優先從緩存載入（永久緩存）
            if let cachedWorkouts = cacheManager.getCachedWorkoutList(), !cachedWorkouts.isEmpty {
                await MainActor.run {
                    self.workouts = cachedWorkouts
                    self.isLoading = false
                }
                print("從永久緩存載入了 \(cachedWorkouts.count) 筆運動記錄")
                
                // 發送運動數據更新通知（首次載入緩存數據）
                NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
                
                // 檢查是否需要背景更新（但不阻塞 UI）
                if cacheManager.shouldRefreshCache(intervalSinceLastSync: 300) { // 5 分鐘
                    print("背景更新運動記錄...")
                    Task.detached { [weak self] in
                        await self?.backgroundUpdateWorkouts()
                    }
                }
                return
            }
            
            // 如果沒有緩存，從 API 獲取數據
            print("沒有緩存數據，從 API 載入運動記錄...")
            let fetchedWorkouts = try await workoutV2Service.fetchRecentWorkouts(limit: 100)
            
            // 檢查是否被取消
            try Task.checkCancellation()
            
            // 快取數據
            cacheManager.cacheWorkoutList(fetchedWorkouts)
            
            await MainActor.run {
                self.workouts = fetchedWorkouts
                self.isLoading = false
                self.lastSyncTime = Date()
            }
            
            // 發送運動數據更新通知
            NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
            
            Logger.firebase(
                "運動記錄首次載入成功",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "initial_load_workouts"
                ],
                jsonPayload: [
                    "workouts_count": fetchedWorkouts.count,
                    "data_source": UserPreferenceManager.shared.dataSourcePreference.rawValue
                ]
            )
            
        } catch is CancellationError {
            print("UnifiedWorkoutManager: 載入任務被取消")
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isLoading = false
            }
            
            // 如果 API 失敗，嘗試使用緩存數據
            if let cachedWorkouts = cacheManager.getCachedWorkoutList() {
                await MainActor.run {
                    self.workouts = cachedWorkouts
                }
                print("API 失敗，使用緩存數據，共 \(cachedWorkouts.count) 筆記錄")
            }
            
            Logger.firebase(
                "運動記錄載入失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "load_workouts"
                ]
            )
        }
    }
    
    /// 刷新運動記錄（強制從 API 更新）
    func refreshWorkouts() async {
        await executeTask(id: TaskID("refresh_workouts")) {
            await self.forceRefreshFromAPI()
        }
    }
    
    /// 強制從 API 刷新運動記錄
    func forceRefreshFromAPI() async {
        await MainActor.run {
            isLoading = true
            syncError = nil
        }
        
        do {
            print("強制刷新：從 API 獲取最新運動記錄...")
            let fetchedWorkouts = try await workoutV2Service.fetchRecentWorkouts(limit: 100)
            
            // 直接覆寫緩存，確保與後端保持一致
            cacheManager.cacheWorkoutList(fetchedWorkouts)
            await MainActor.run {
                self.workouts = fetchedWorkouts
                self.lastSyncTime = Date()
                self.isLoading = false
            }
            
            // 發送運動數據更新通知
            NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
            Logger.firebase(
                "強制刷新運動記錄完成 (覆寫方式)",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "force_refresh"
                ],
                jsonPayload: [
                    "total_workouts": fetchedWorkouts.count
                ]
            )
            
        } catch is CancellationError {
            print("UnifiedWorkoutManager: 強制刷新任務被取消")
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isLoading = false
            }
            
            print("強制刷新失敗: \(error.localizedDescription)")
            Logger.firebase(
                "強制刷新運動記錄失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "force_refresh"
                ]
            )
        }
    }
    
    /// 背景更新運動記錄（不阻塞 UI）
    private func backgroundUpdateWorkouts() async {
        do {
            print("背景更新：從 API 獲取最新運動記錄...")
            let fetchedWorkouts = try await workoutV2Service.fetchRecentWorkouts(limit: 100)
            
            // 合併到緩存
            let mergedCount = cacheManager.mergeWorkoutsToCache(fetchedWorkouts)
            
            if mergedCount > 0 {
                // 有新數據，更新 UI
                if let updatedWorkouts = cacheManager.getCachedWorkoutList() {
                    await MainActor.run {
                        self.workouts = updatedWorkouts
                        self.lastSyncTime = Date()
                    }
                    print("背景更新完成：新增 \(mergedCount) 筆記錄")
                    
                    // 發送運動數據更新通知
                    NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
                }
            } else {
                // 沒有新數據，只更新同步時間
                cacheManager.cacheWorkoutList(self.workouts) // 更新同步時間戳
                await MainActor.run {
                    self.lastSyncTime = Date()
                }
                print("背景更新完成：沒有新數據")
            }
            
            Logger.firebase(
                "背景更新運動記錄完成",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "background_update"
                ],
                jsonPayload: [
                    "new_workouts": mergedCount,
                    "total_workouts": self.workouts.count
                ]
            )
            
        } catch {
            print("背景更新失敗: \(error.localizedDescription)")
            Logger.firebase(
                "背景更新運動記錄失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "background_update"
                ]
            )
        }
    }
    
    /// 切換數據來源
    func switchDataSource(to newDataSource: DataSourceType) async {
        Logger.firebase(
            "切換數據來源",
            level: .info,
            labels: [
                "module": "UnifiedWorkoutManager",
                "action": "switch_data_source"
            ],
            jsonPayload: [
                "from": UserPreferenceManager.shared.dataSourcePreference.rawValue,
                "to": newDataSource.rawValue
            ]
        )
        
        // 停止當前工作流程
        await stopCurrentWorkflow()
        
        // 清除所有本地資料
        await clearAllLocalData()
        
        // 更新偏好設定
        UserPreferenceManager.shared.dataSourcePreference = newDataSource
        
        // 初始化新的工作流程
        await initialize()
        
        // 載入新數據
        await loadWorkouts()
    }
    
    /// 清除所有本地資料
    @MainActor
    func clearAllLocalData() {
        // 清除 Workout V2 快取
        cacheManager.clearAllCache()
        
        // 清空當前數據
        workouts = []
        lastSyncTime = nil
        syncError = nil
        
        // 清除 WorkoutV2Service 快取
        WorkoutV2Service.shared.clearWorkoutSummaryCache()
        
        // 清除 TrainingPlan 相關快取
        TrainingPlanStorage.shared.clearAll()
        
        // 清除 WeeklySummary 快取
        WeeklySummaryStorage.shared.clearSavedWeeklySummary()
        
        // 清除 Workout 上傳追蹤
        WorkoutUploadTracker.shared.clearUploadedWorkouts()
        
        // 清除 VDOTStorage 快取
        VDOTStorage.shared.clearVDOTData()
        
        // 清除 TargetStorage 快取
        TargetStorage.shared.clearAllTargets()
        
        Logger.firebase(
            "所有本地資料已清除",
            level: .info,
            labels: [
                "module": "UnifiedWorkoutManager",
                "action": "clear_all_local_data"
            ]
        )
    }
    
    /// 獲取運動統計數據
    func getWorkoutStats(days: Int = 30) async throws -> WorkoutStatsResponse {
        // 先嘗試從快取獲取
        if let cachedStats = cacheManager.getCachedWorkoutStats(maxAge: 1800) { // 30 分鐘快取
            return cachedStats
        }
        
        // 從 API 獲取
        let response = try await workoutV2Service.fetchWorkoutStats(days: days)
        
        // 快取統計數據
        cacheManager.cacheWorkoutStats(response)
        
        return response
    }
    
    // MARK: - Apple Health Workflow
    
    private func setupAppleHealthWorkflow() async {
        print("設置 Apple Health 工作流程")
        
        // 再次確認當前數據來源（防止競態條件）
        guard UserPreferenceManager.shared.dataSourcePreference == .appleHealth else {
            print("數據來源已切換，取消 Apple Health 工作流程設置")
            return
        }
        
        do {
            // 請求 HealthKit 授權
            try await healthKitManager.requestAuthorization()
            
            // 啟動 HealthKit 觀察者
            await startHealthKitObserver()
            
            // 設置背景管理器 (WorkoutBackgroundManager 內部會再次檢查數據來源)
            await workoutBackgroundManager.setupWorkoutObserver()
            
            // 檢查並上傳待處理的運動記錄
            Task {
                await checkAndUploadPendingAppleHealthWorkouts()
            }
            
        } catch {
            print("設置 Apple Health 工作流程失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.syncError = "設置 Apple Health 失敗: \(error.localizedDescription)"
            }
        }
    }
    
    private func startHealthKitObserver() async {
        guard !isObserving else { return }
        
        let workoutType = HKObjectType.workoutType()
        
        healthKitObserver = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("HealthKit 觀察者錯誤: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            print("檢測到新的 Apple Health 運動記錄")
            
            Task {
                await self.handleNewAppleHealthWorkout()
                completionHandler()
            }
        }
        
        if let observer = healthKitObserver {
            healthKitManager.healthStore.execute(observer)
            
            // 啟用背景傳遞
            healthKitManager.healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
                if success {
                    print("Apple Health 背景傳遞已啟用")
                } else if let error = error {
                    print("無法啟用 Apple Health 背景傳遞: \(error.localizedDescription)")
                }
            }
            
            isObserving = true
            print("Apple Health 觀察者已啟動")
        }
    }
    
    private func handleNewAppleHealthWorkout() async {
        // 確認當前數據來源是 Apple Health
        let currentDataSource = UserPreferenceManager.shared.dataSourcePreference
        print("🚨 [觀察者調試] Apple Health 觀察者被觸發")
        print("🚨 [觀察者調試] 當前數據源設置: \(currentDataSource.rawValue)")
        
        guard currentDataSource == .appleHealth else {
            print("🚨 [觀察者調試] 數據來源已切換為 \(currentDataSource.rawValue)，忽略 Apple Health 運動記錄更新")
            return
        }
        
        // 獲取最新的運動記錄
        do {
            let now = Date()
            let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now)!
            let recentWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: oneDayAgo, end: now)
            
            // 上傳新的運動記錄到 V2 API
            for workout in recentWorkouts {
                await uploadAppleHealthWorkoutToV2API(workout)
            }
            
            // 重新載入統一的運動記錄
            await loadWorkouts()
            
            // 發送運動數據更新通知
            NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
            
        } catch {
            print("處理新的 Apple Health 運動記錄失敗: \(error.localizedDescription)")
        }
    }
    
    private func checkAndUploadPendingAppleHealthWorkouts() async {
        print("檢查待上傳的 Apple Health 運動記錄")
        
        // 確認當前數據來源是 Apple Health
        guard UserPreferenceManager.shared.dataSourcePreference == .appleHealth else {
            print("數據來源不是 Apple Health，跳過運動記錄上傳")
            return
        }
        
        do {
            let now = Date()
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: oneWeekAgo, end: now)
            
            print("發現 \(workouts.count) 筆 Apple Health 運動記錄")
            
            // 批量上傳到 V2 API
            for workout in workouts {
                await uploadAppleHealthWorkoutToV2API(workout)
            }
            
        } catch {
            print("檢查待上傳的 Apple Health 運動記錄失敗: \(error.localizedDescription)")
        }
    }
    
    private func uploadAppleHealthWorkoutToV2API(_ workout: HKWorkout) async {
        // 添加調試：檢查當前數據源設置
        let currentDataSource = UserPreferenceManager.shared.dataSourcePreference
        print("🚨 [上傳調試] 嘗試上傳 Apple Health workout")
        print("🚨 [上傳調試] 當前數據源設置: \(currentDataSource.rawValue)")
        print("🚨 [上傳調試] Workout ID: \(workout.uuid.uuidString)")
        
        // 如果當前數據源不是 Apple Health，應該停止上傳
        guard currentDataSource == .appleHealth else {
            print("🚨 [上傳調試] 數據源不是 Apple Health，停止上傳")
            return
        }
        
        // 檢查運動是否已經上傳到 V2 API
        if WorkoutUploadTracker.shared.isWorkoutUploaded(workout, apiVersion: .v2) {
            print("🚨 [上傳調試] 運動已上傳到 V2 API，跳過重複上傳")
            return
        }
        
        do {
            let result = try await workoutV2Service.uploadWorkout(workout)
            
            // 標記運動為已上傳到 V2 API
            WorkoutUploadTracker.shared.markWorkoutAsUploaded(workout, hasHeartRate: true, apiVersion: .v2)
            print("🚨 [上傳調試] 已標記運動為已上傳到 V2 API")
            
            Logger.firebase(
                "Apple Health 運動記錄上傳到 V2 API 成功",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "upload_apple_health_to_v2"
                ],
                jsonPayload: [
                    "workout_type": workout.workoutActivityType.name,
                    "duration_seconds": Int(workout.duration)
                ]
            )
            
        } catch {
            // 詳細錯誤回報機制
            await reportWorkoutUploadError(workout: workout, error: error)
        }
    }
    
    /// 詳細的運動上傳錯誤回報
    private func reportWorkoutUploadError(workout: HKWorkout, error: Error) async {
        // 收集詳細的運動數據資訊用於錯誤分析
        var workoutDetails: [String: Any] = [
            "workout_uuid": workout.uuid.uuidString,
            "workout_type": workout.workoutActivityType.rawValue,
            "workout_type_name": workout.workoutActivityType.name,
            "duration_seconds": Int(workout.duration),
            "start_date": workout.startDate.timeIntervalSince1970,
            "end_date": workout.endDate.timeIntervalSince1970,
            "total_distance_meters": workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            "total_energy_burned": workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
            "source_name": workout.sourceRevision.source.name,
            "source_bundle_id": workout.sourceRevision.source.bundleIdentifier
        ]
        
        // 收集設備資訊
        if let device = workout.device {
            workoutDetails["device_name"] = device.name
            workoutDetails["device_manufacturer"] = device.manufacturer
            workoutDetails["device_model"] = device.model
            workoutDetails["device_hardware_version"] = device.hardwareVersion
            workoutDetails["device_software_version"] = device.softwareVersion
        }
        
        // 收集 metadata 資訊
        if let metadata = workout.metadata {
            var metadataInfo: [String: Any] = [:]
            for (key, value) in metadata {
                metadataInfo[String(describing: key)] = String(describing: value)
            }
            workoutDetails["metadata"] = metadataInfo
        }
        
        // 嘗試收集部分健康數據以診斷問題
        do {
            let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            workoutDetails["heart_rate_sample_count"] = heartRateData.count
            if !heartRateData.isEmpty {
                workoutDetails["heart_rate_min"] = heartRateData.map { $0.1 }.min()
                workoutDetails["heart_rate_max"] = heartRateData.map { $0.1 }.max()
                workoutDetails["heart_rate_avg"] = heartRateData.map { $0.1 }.reduce(0, +) / Double(heartRateData.count)
            }
        } catch let hrError {
            workoutDetails["heart_rate_fetch_error"] = hrError.localizedDescription
        }
        
        // 錯誤類型分析
        var errorType = "unknown"
        var errorDetails: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        
        if let workoutError = error as? WorkoutV2ServiceError {
            switch workoutError {
            case .invalidWorkoutData:
                errorType = "invalid_workout_data"
            case .noHeartRateData:
                errorType = "no_heart_rate_data"
            case .uploadFailed(let message):
                errorType = "upload_failed"
                errorDetails["upload_error_message"] = message
            case .networkError(let netError):
                errorType = "network_error"
                errorDetails["network_error_description"] = netError.localizedDescription
            }
        } else if let apiErrorResponse = error as? APIErrorResponse {
            errorType = "api_error"
            errorDetails["api_error_code"] = apiErrorResponse.error.code
            errorDetails["api_error_message"] = apiErrorResponse.error.message
        } else if let urlError = error as? URLError {
            errorType = "network_error"
            errorDetails["url_error_code"] = urlError.code.rawValue
            errorDetails["url_error_description"] = urlError.localizedDescription
        }
        
        Logger.firebase(
            "Apple Health 運動記錄上傳到 V2 API 失敗 - 詳細錯誤報告",
            level: .error,
            labels: [
                "module": "UnifiedWorkoutManager",
                "action": "upload_apple_health_to_v2_error",
                "error_type": errorType,
                "device_manufacturer": workoutDetails["device_manufacturer"] as? String ?? "unknown",
                "source_bundle_id": workoutDetails["source_bundle_id"] as? String ?? "unknown"
            ],
            jsonPayload: [
                "workout_details": workoutDetails,
                "error_details": errorDetails,
                "timestamp": Date().timeIntervalSince1970,
                "user_data_source": UserPreferenceManager.shared.dataSourcePreference.rawValue
            ]
        )
        
        // 本地錯誤日誌
        print("❌ [詳細錯誤] 運動上傳失敗")
        print("   - 運動類型: \(workout.workoutActivityType.name)")
        print("   - 持續時間: \(workout.duration)秒")
        print("   - 來源: \(workout.sourceRevision.source.name)")
        print("   - 錯誤: \(error.localizedDescription)")
    }
    
    // MARK: - Garmin Workflow
    
    private func setupGarminWorkflow() async {
        print("設置 Garmin 工作流程")
        
        // Garmin 數據由後台自動同步，無需特別設置
        // 只需要定期從 V2 API 拉取數據即可
        
        Logger.firebase(
            "Garmin 工作流程設置完成",
            level: .info,
            labels: [
                "module": "UnifiedWorkoutManager",
                "action": "setup_garmin_workflow"
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func stopCurrentWorkflow() async {
        print("🛑 UnifiedWorkoutManager: 開始停止當前工作流程")
        
        // 取消所有任務
        cancelAllTasks()
        
        // 停止 HealthKit 觀察者
        if let observer = healthKitObserver {
            print("🛑 停止 UnifiedWorkoutManager 的 HealthKit 觀察者")
            healthKitManager.healthStore.stop(observer)
            healthKitManager.healthStore.disableBackgroundDelivery(for: HKObjectType.workoutType()) { success, error in
                if !success, let error = error {
                    print("無法禁用 Apple Health 背景傳遞: \(error.localizedDescription)")
                } else {
                    print("✅ Apple Health 背景傳遞已禁用")
                }
            }
            healthKitObserver = nil
            isObserving = false
            print("✅ UnifiedWorkoutManager 的 Apple Health 觀察者已停止")
        } else {
            print("ℹ️ UnifiedWorkoutManager 沒有活躍的 HealthKit 觀察者")
        }
        
        // 強制停止背景管理器 - 確保清理所有觀察者
        print("🛑 強制停止 WorkoutBackgroundManager")
        workoutBackgroundManager.stopAndCleanupObserving()
        
        // 取消所有背景任務
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("🛑 已取消所有背景同步任務")
        
        print("✅ UnifiedWorkoutManager: 工作流程停止完成")
    }
    
    private func setupNotificationObservers() {
        // 🚫 移除循環監聽：UnifiedWorkoutManager 不應該監聽自己發送的 workoutsDidUpdate 通知
        // 這會造成無限循環：refreshWorkouts() -> 發送通知 -> 監聽到通知 -> 再次 refreshWorkouts()
        // 其他 ViewModels 仍會正常接收 workoutsDidUpdate 通知並更新 UI
        
        // 監聽數據源變更 - 修復觀察者未及時停止的問題
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                print("🔄 UnifiedWorkoutManager: 收到數據源變更通知")
                if let newDataSource = notification.object as? DataSourceType {
                    print("🔄 數據源切換到: \(newDataSource.rawValue)")
                    await self?.handleDataSourceChange(to: newDataSource)
                }
            }
        }
    }
    
    /// 處理數據源變更
    private func handleDataSourceChange(to newDataSource: DataSourceType) async {
        print("🔄 UnifiedWorkoutManager: 處理數據源變更到 \(newDataSource.rawValue)")
        
        // 強制停止當前所有工作流程
        await stopCurrentWorkflow()
        
        // 清除本地數據
        await MainActor.run {
            clearAllLocalData()
        }
        
        // 根據新數據源重新初始化
        await initialize()
        
        // 重新載入數據
        await loadWorkouts()
        
        print("✅ UnifiedWorkoutManager: 數據源切換完成")
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extensions

extension UnifiedWorkoutManager {
    
    /// 獲取特定類型的運動記錄
    func getWorkoutsByType(_ activityType: String) -> [WorkoutV2] {
        return workouts.filter { $0.activityType == activityType }
    }
    
    /// 獲取指定日期範圍的運動記錄
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        return workouts.filter { workout in
            let workoutStartDate = workout.startDate
            return workoutStartDate >= startDate && workoutStartDate <= endDate
        }
    }
    
    /// 計算總距離
    func getTotalDistance(for activityType: String? = nil) -> Double {
        let filteredWorkouts = activityType != nil ? getWorkoutsByType(activityType!) : workouts
        return filteredWorkouts.compactMap { $0.distance }.reduce(0, +)
    }
    
    /// 計算總時長
    func getTotalDuration(for activityType: String? = nil) -> TimeInterval {
        let filteredWorkouts = activityType != nil ? getWorkoutsByType(activityType!) : workouts
        return filteredWorkouts.map { $0.duration }.reduce(0, +)
    }
    
    /// 檢查是否有運動記錄
    var hasWorkouts: Bool {
        return !workouts.isEmpty
    }
    
    /// 獲取最新的運動記錄
    var latestWorkout: WorkoutV2? {
        return workouts.first
    }
    
    /// 獲取緩存統計資訊
    func getCacheStats() -> CacheStats {
        return cacheManager.getCacheStats()
    }
    
    /// 檢查是否有緩存數據
    var hasCachedData: Bool {
        return cacheManager.hasCachedWorkouts()
    }
    
    /// 獲取最後同步時間
    var lastCacheSync: Date? {
        return cacheManager.getLastSyncTime()
    }
    
    /// 檢查緩存是否需要刷新
    func shouldRefreshCache() -> Bool {
        return cacheManager.shouldRefreshCache()
    }
} 