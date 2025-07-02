import Foundation
import HealthKit

/// 統一運動數據管理器
/// 負責協調 Apple Health 和 Garmin 的資料流程，實現統一的 V2 API 資料架構
class UnifiedWorkoutManager: ObservableObject {
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
        }
    }
    
    /// 載入運動記錄（統一介面）
    func loadWorkouts() async {
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
            // 先嘗試從快取載入
            if let cachedWorkouts = cacheManager.getCachedWorkoutList(), !cachedWorkouts.isEmpty {
                await MainActor.run {
                    self.workouts = cachedWorkouts
                    self.isLoading = false
                }
                print("從快取載入了 \(cachedWorkouts.count) 筆運動記錄")
            }
            
            // 從 V2 API 獲取最新數據
            let fetchedWorkouts = try await workoutV2Service.fetchRecentWorkouts(limit: 50)
            
            // 快取數據
            cacheManager.cacheWorkoutList(fetchedWorkouts)
            
            await MainActor.run {
                self.workouts = fetchedWorkouts
                self.isLoading = false
                self.lastSyncTime = Date()
            }
            
            Logger.firebase(
                "運動記錄載入成功",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "load_workouts"
                ],
                jsonPayload: [
                    "workouts_count": fetchedWorkouts.count,
                    "data_source": UserPreferenceManager.shared.dataSourcePreference.rawValue
                ]
            )
            
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isLoading = false
            }
            
            // 如果 API 失敗，使用快取數據
            if let cachedWorkouts = cacheManager.getCachedWorkoutList() {
                await MainActor.run {
                    self.workouts = cachedWorkouts
                }
                print("API 失敗，使用快取數據")
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
    
    /// 刷新運動記錄
    func refreshWorkouts() async {
        await loadWorkouts()
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
        
        // 清除快取
        cacheManager.clearAllCache()
        
        // 清空當前數據
        await MainActor.run {
            workouts = []
            syncError = nil
        }
        
        // 更新偏好設定
        UserPreferenceManager.shared.dataSourcePreference = newDataSource
        
        // 初始化新的工作流程
        await initialize()
        
        // 載入新數據
        await loadWorkouts()
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
        
        do {
            // 請求 HealthKit 授權
            try await healthKitManager.requestAuthorization()
            
            // 啟動 HealthKit 觀察者
            await startHealthKitObserver()
            
            // 設置背景管理器
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
            
        } catch {
            print("處理新的 Apple Health 運動記錄失敗: \(error.localizedDescription)")
        }
    }
    
    private func checkAndUploadPendingAppleHealthWorkouts() async {
        print("檢查待上傳的 Apple Health 運動記錄")
        
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
        do {
            let response = try await workoutV2Service.uploadAppleHealthWorkout(workout)
            
            Logger.firebase(
                "Apple Health 運動記錄上傳到 V2 API 成功",
                level: .info,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "upload_apple_health_to_v2"
                ],
                jsonPayload: [
                    "workout_id": response.id,
                    "workout_type": workout.workoutActivityType.name,
                    "duration_seconds": Int(workout.duration)
                ]
            )
            
        } catch {
            Logger.firebase(
                "Apple Health 運動記錄上傳到 V2 API 失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "UnifiedWorkoutManager",
                    "action": "upload_apple_health_to_v2"
                ],
                jsonPayload: [
                    "workout_type": workout.workoutActivityType.name,
                    "duration_seconds": Int(workout.duration)
                ]
            )
        }
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
        // 停止 HealthKit 觀察者
        if let observer = healthKitObserver {
            healthKitManager.healthStore.stop(observer)
            healthKitManager.healthStore.disableBackgroundDelivery(for: HKObjectType.workoutType()) { success, error in
                if !success, let error = error {
                    print("無法禁用 Apple Health 背景傳遞: \(error.localizedDescription)")
                }
            }
            healthKitObserver = nil
            isObserving = false
            print("Apple Health 觀察者已停止")
        }
        
        // 停止背景管理器
        workoutBackgroundManager.stopAndCleanupObserving()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .workoutsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshWorkouts()
            }
        }
    }
    
    deinit {
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
            guard let workoutStartDate = workout.startDate else { return false }
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
} 