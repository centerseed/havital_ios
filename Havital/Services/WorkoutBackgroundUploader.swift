import Foundation
import HealthKit

class WorkoutBackgroundUploader {
    static let shared = WorkoutBackgroundUploader()
    
    private let healthKitManager: HealthKitManager
    private let workoutUploadTracker: WorkoutUploadTracker
    private let workoutService: WorkoutService
    
    private init() {
        self.healthKitManager = HealthKitManager()
        self.workoutUploadTracker = WorkoutUploadTracker.shared
        self.workoutService = WorkoutService.shared
    }
    
    /// 上傳所有未上傳的運動記錄，考慮心率資料的可用性
    func uploadPendingWorkouts(workouts: [HKWorkout]) async {
        print("開始上傳未同步的運動記錄...")
        
        for workout in workouts {
            let workoutId = workout.uuid.uuidString
            
            // 如果已經上傳且有心率資料，則跳過
            if workoutUploadTracker.isWorkoutUploaded(workout) &&
               workoutUploadTracker.workoutHasHeartRate(workout) {
                continue
            }
            
            // 如果已上傳但沒有心率資料，且時間未超過1小時，則跳過
            if workoutUploadTracker.isWorkoutUploaded(workout) &&
               !workoutUploadTracker.workoutHasHeartRate(workout) {
                if let uploadTime = workoutUploadTracker.getWorkoutUploadTime(workout) {
                    let timeElapsed = Date().timeIntervalSince(uploadTime)
                    if timeElapsed < 3600 { // 1小時 = 3600秒
                        // 還在等待期內，跳過
                        continue
                    }
                    // 超過1小時，嘗試再次獲取心率資料並上傳
                    print("運動記錄 \(workoutId) 已上傳但缺少心率資料，且超過1小時，嘗試再次獲取")
                }
            }
            
            do {
                // 獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                // 檢查心率數據是否有效（至少有一定數量的數據點）
                if heartRateData.isEmpty || heartRateData.count < 5 {
                    print("運動記錄 \(workoutId) 的心率數據不足，暫不上傳")
                    
                    // 如果之前沒有上傳過，標記為已嘗試但無心率資料
                    if !workoutUploadTracker.isWorkoutUploaded(workout) {
                        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                    }
                    continue
                }
                
                // 獲取配速數據
                let paceData = try await healthKitManager.fetchPaceData(for: workout)
                
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let paces = paceData.map { DataPoint(time: $0.0, value: $0.1) }
                
                // 上傳運動數據
                try await workoutService.postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    paces: paces
                )
                
                // 標記為已上傳且包含心率資料
                workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate), 包含心率數據")
                
            } catch {
                print("上傳運動記錄失敗: \(workoutId), 錯誤: \(error)")
                
                // 如果之前沒有上傳過，標記為已嘗試但無心率資料
                if !workoutUploadTracker.isWorkoutUploaded(workout) {
                    workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                }
            }
            
            // 添加小延遲避免請求過於頻繁
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        print("運動記錄上傳完成")
    }
}
