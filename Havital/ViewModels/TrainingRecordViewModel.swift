import SwiftUI
import HealthKit
import UserNotifications

extension Notification.Name {
    static let workoutsDidUpdate = Notification.Name("workoutsDidUpdate")
}

class TrainingRecordViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var uploadStatus: String? = nil
    
    // 統一使用 UnifiedWorkoutManager
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared
    private let workoutService = WorkoutService.shared
    
    // 初始設置 - 統一使用 UnifiedWorkoutManager
    func setup() {
        // UnifiedWorkoutManager 已經在 App 啟動時初始化
        // 這裡不需要額外設置，只需要確保數據已載入
        print("TrainingRecordViewModel 設置完成，使用 UnifiedWorkoutManager")
    }
    
    // 不再需要 HealthKit 觀察者，由 UnifiedWorkoutManager 統一管理
    // 這些方法保留以保持向後兼容性，但實際不執行任何操作
    private func startWorkoutObserver(healthKitManager: HealthKitManager) {
        print("TrainingRecordViewModel: HealthKit 觀察者由 UnifiedWorkoutManager 統一管理")
    }
    
    func stopWorkoutObserver(healthKitManager: HealthKitManager) {
        print("TrainingRecordViewModel: HealthKit 觀察者由 UnifiedWorkoutManager 統一管理")
    }
    
    // 加載訓練記錄 - 統一使用 UnifiedWorkoutManager
    func loadWorkouts(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoading = true
        }
        
        // 使用 UnifiedWorkoutManager 載入數據
        await unifiedWorkoutManager.loadWorkouts()
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 刷新訓練記錄 - 統一使用 UnifiedWorkoutManager
    private func refreshWorkouts(healthKitManager: HealthKitManager) async {
        await unifiedWorkoutManager.refreshWorkouts()
    }
    
    /// 檢查特定訓練記錄是否已上傳 - 統一使用 UnifiedWorkoutManager
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        // 對於 V2 API 數據，所有記錄都已經在後端
        return true
    }
    
    /// 獲取訓練記錄的上傳時間 - 統一使用 UnifiedWorkoutManager
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        // 對於 V2 API 數據，使用記錄的開始時間
        return workout.startDate
    }
    
    // 清理資源
    deinit {
        print("TrainingRecordViewModel 被釋放")
    }
    
    // MARK: - Unified Data Access Methods
    
    /// 獲取統一的運動記錄列表
    var workouts: [WorkoutV2] {
        return unifiedWorkoutManager.workouts
    }
    
    /// 獲取統一的運動記錄數量
    var totalWorkoutsCount: Int {
        return unifiedWorkoutManager.workouts.count
    }
    
    /// 檢查是否有運動記錄
    var hasWorkouts: Bool {
        return unifiedWorkoutManager.hasWorkouts
    }
    
    /// 獲取指定日期範圍的運動記錄
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        return unifiedWorkoutManager.getWorkoutsInDateRange(startDate: startDate, endDate: endDate)
    }
    
    /// 獲取特定類型的運動記錄
    func getWorkoutsByType(_ activityType: String) -> [WorkoutV2] {
        return unifiedWorkoutManager.getWorkoutsByType(activityType)
    }
    
    /// 計算總距離
    func getTotalDistance(for activityType: String? = nil) -> Double {
        return unifiedWorkoutManager.getTotalDistance(for: activityType)
    }
    
    /// 計算總時長
    func getTotalDuration(for activityType: String? = nil) -> TimeInterval {
        return unifiedWorkoutManager.getTotalDuration(for: activityType)
    }
    
    /// 獲取最新的運動記錄
    var latestWorkout: WorkoutV2? {
        return unifiedWorkoutManager.latestWorkout
    }
}
