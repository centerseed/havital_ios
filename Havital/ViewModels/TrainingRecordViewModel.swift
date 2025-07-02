import SwiftUI
import HealthKit
import UserNotifications

extension Notification.Name {
    static let workoutsDidUpdate = Notification.Name("workoutsDidUpdate")
}

class TrainingRecordViewModel: ObservableObject {
    @Published var workouts: [HKWorkout] = []
    @Published var isLoading = false
    @Published var uploadStatus: String? = nil
    
    // V2 API 相關屬性
    @Published var workoutsV2: [WorkoutV2] = []
    @Published var isUsingV2API = false
    
    private let workoutService = WorkoutService.shared
    private let workoutV2Service = WorkoutV2Service.shared
    private let cacheManager = WorkoutV2CacheManager.shared
    private var workoutObserver: HKObserverQuery?
    private var observerStarted = false
    
    // 初始設置
    func setup(healthKitManager: HealthKitManager) {
        // 檢查數據來源設定，決定是否啟動 HealthKit 觀察者
        let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
        
        if dataSourcePreference == .appleHealth {
            // 啟動 HealthKit 觀察者
            startWorkoutObserver(healthKitManager: healthKitManager)
        } else {
            print("數據來源為 \(dataSourcePreference.displayName)，跳過 HealthKit 觀察者啟動")
            // 確保停止任何現有的觀察者
            stopWorkoutObserver(healthKitManager: healthKitManager)
            
            // 為 Garmin 用戶載入 V2 API 數據
            Task {
                await loadWorkoutsFromV2API()
            }
        }
    }
    
    // 啟動 HealthKit 觀察者
    private func startWorkoutObserver(healthKitManager: HealthKitManager) {
        guard !observerStarted else { return }
        
        let workoutType = HKObjectType.workoutType()
        let center = healthKitManager.healthStore
        
        // 創建觀察者查詢
        workoutObserver = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("HealthKit 觀察者錯誤: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // 當檢測到新的訓練資料時，刷新 UI 上的訓練記錄
            print("檢測到新的訓練資料，刷新訓練記錄")
            Task {
                await self.refreshWorkouts(healthKitManager: healthKitManager)
                completionHandler()
            }
        }
        
        // 啟動觀察者查詢
        if let observer = workoutObserver {
            center.execute(observer)
            
            // 啟用後台傳遞
            center.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
                if success {
                    print("後台傳遞已啟用")
                } else if let error = error {
                    print("無法啟用後台傳遞: \(error.localizedDescription)")
                }
            }
            
            observerStarted = true
            print("HealthKit 訓練觀察者已啟動")
        }
    }
    
    // 停止 HealthKit 觀察者
    func stopWorkoutObserver(healthKitManager: HealthKitManager) {
        if let observer = workoutObserver {
            healthKitManager.healthStore.stop(observer)
            
            // 禁用後台傳遞
            healthKitManager.healthStore.disableBackgroundDelivery(for: HKObjectType.workoutType()) { success, error in
                if !success, let error = error {
                    print("無法禁用後台傳遞: \(error.localizedDescription)")
                }
            }
            
            observerStarted = false
            print("HealthKit 訓練觀察者已停止")
        }
    }
    
    // 加載訓練記錄
    func loadWorkouts(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            let now = Date()
            // 改為獲取一個月的數據
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            
            let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: oneMonthAgo, end: now)
            
            // 在主線程更新 UI
            await MainActor.run {
                self.workouts = fetchedWorkouts.sorted(by: { $0.startDate > $1.startDate }) // 按日期降序排序
                self.isLoading = false
            }
            
            // 啟動 HealthKit 觀察者
            setup(healthKitManager: healthKitManager)
            
            // 不再主動觸發上傳，僅由 WorkoutBackgroundManager 負責
            
        } catch {
            print("加載訓練記錄時出錯: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.workouts = []
            }
        }
    }
    
    // 刷新訓練記錄（不觸發上傳）
    private func refreshWorkouts(healthKitManager: HealthKitManager) async {
        do {
            let now = Date()
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: oneMonthAgo, end: now)
            
            // 更新 UI
            await MainActor.run {
                self.workouts = fetchedWorkouts.sorted(by: { $0.startDate > $1.startDate })
                // 發送通知
                NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
                print("已發送 workoutsDidUpdate 通知")
            }
        } catch {
            print("刷新訓練記錄時出錯: \(error)")
        }
    }
    
    /// 檢查特定訓練記錄是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return workoutService.isWorkoutUploaded(workout)
    }
    
    /// 獲取訓練記錄的上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return workoutService.getWorkoutUploadTime(workout)
    }
    
    // 清理資源
    deinit {
        print("TrainingRecordViewModel 被釋放，應該停止 HealthKit 觀察者")
    }
    
    // MARK: - V2 API Methods
    
    /// 使用 V2 API 載入運動記錄（用於 Garmin 用戶）
    func loadWorkoutsFromV2API() async {
        await MainActor.run {
            isLoading = true
            isUsingV2API = true
        }
        
        do {
            // 先嘗試從快取載入
            if let cachedWorkouts = cacheManager.getCachedWorkoutList(), !cachedWorkouts.isEmpty {
                await MainActor.run {
                    self.workoutsV2 = cachedWorkouts
                    self.isLoading = false
                }
                print("從快取載入了 \(cachedWorkouts.count) 筆運動記錄")
            }
            
            // 從 API 獲取最新數據
            let workouts = try await workoutV2Service.fetchRecentWorkouts(limit: 50)
            
            // 快取數據
            cacheManager.cacheWorkoutList(workouts)
            
            await MainActor.run {
                self.workoutsV2 = workouts
                self.isLoading = false
            }
            
            Logger.firebase(
                "V2 API 運動記錄載入成功",
                level: .info,
                labels: [
                    "module": "TrainingRecordViewModel",
                    "action": "load_workouts_v2"
                ],
                jsonPayload: [
                    "workouts_count": workouts.count,
                    "data_source": "api"
                ]
            )
            
        } catch {
            print("載入 V2 API 運動記錄失敗: \(error.localizedDescription)")
            
            // 如果 API 失敗，嘗試使用快取數據
            if let cachedWorkouts = cacheManager.getCachedWorkoutList() {
                await MainActor.run {
                    self.workoutsV2 = cachedWorkouts
                    self.isLoading = false
                }
                print("API 失敗，使用快取數據")
            } else {
                await MainActor.run {
                    self.workoutsV2 = []
                    self.isLoading = false
                }
            }
            
            Logger.firebase(
                "V2 API 運動記錄載入失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "TrainingRecordViewModel",
                    "action": "load_workouts_v2"
                ]
            )
        }
    }
    
    /// 刷新 V2 API 數據
    func refreshWorkoutsFromV2API() async {
        guard isUsingV2API else { return }
        
        do {
            let workouts = try await workoutV2Service.fetchRecentWorkouts(limit: 50)
            cacheManager.cacheWorkoutList(workouts)
            
            await MainActor.run {
                self.workoutsV2 = workouts
            }
            
            // 發送更新通知
            await MainActor.run {
                NotificationCenter.default.post(name: .workoutsDidUpdate, object: nil)
            }
            
        } catch {
            print("刷新 V2 API 運動記錄失敗: \(error.localizedDescription)")
        }
    }
    
    /// 切換數據來源
    func switchDataSource(to newDataSource: DataSourceType, healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        switch newDataSource {
        case .appleHealth:
            // 切換到 Apple Health
            await MainActor.run {
                isUsingV2API = false
                workoutsV2 = []
            }
            await loadWorkouts(healthKitManager: healthKitManager)
            
        case .garmin:
            // 切換到 Garmin V2 API
            stopWorkoutObserver(healthKitManager: healthKitManager)
            await MainActor.run {
                workouts = []
            }
            await loadWorkoutsFromV2API()
        }
    }
    
    /// 上傳新的 Apple Health 運動記錄到 V2 API
    func uploadNewAppleHealthWorkout(_ workout: HKWorkout) async {
        // 只有在 Apple Health 模式下才上傳
        guard !isUsingV2API else { return }
        
        do {
            let response = try await workoutV2Service.uploadAppleHealthWorkout(workout)
            
            Logger.firebase(
                "Apple Health 運動記錄上傳到 V2 API 成功",
                level: .info,
                labels: [
                    "module": "TrainingRecordViewModel",
                    "action": "upload_apple_health_to_v2"
                ],
                jsonPayload: [
                    "workout_id": response.id,
                    "workout_type": workout.workoutActivityType.name
                ]
            )
            
        } catch {
            Logger.firebase(
                "Apple Health 運動記錄上傳到 V2 API 失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "TrainingRecordViewModel",
                    "action": "upload_apple_health_to_v2"
                ]
            )
        }
    }
    
    /// 獲取統一的運動記錄數量
    var totalWorkoutsCount: Int {
        return isUsingV2API ? workoutsV2.count : workouts.count
    }
    
    /// 檢查是否有運動記錄
    var hasWorkouts: Bool {
        return totalWorkoutsCount > 0
    }
}
