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
    
    private let workoutService = WorkoutService.shared
    private var workoutObserver: HKObserverQuery?
    private var observerStarted = false
    
    // 初始設置
    func setup(healthKitManager: HealthKitManager) {
        // 啟動 HealthKit 觀察者
        startWorkoutObserver(healthKitManager: healthKitManager)
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
}
