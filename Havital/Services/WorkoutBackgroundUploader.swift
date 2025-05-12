import Foundation
import HealthKit

class WorkoutBackgroundUploader {
    static let shared = WorkoutBackgroundUploader()
    
    private let healthKitManager: HealthKitManager
    private let workoutUploadTracker: WorkoutUploadTracker
    private let workoutService: WorkoutService
    private let notificationManager = SyncNotificationManager.shared
    private var isUploading = false // 防止多個上傳過程同時運行
    
    private init() {
        self.healthKitManager = HealthKitManager()
        self.workoutUploadTracker = WorkoutUploadTracker.shared
        self.workoutService = WorkoutService.shared
    }
    
    /// 上傳所有未上傳的運動記錄，考慮心率資料的可用性
    @discardableResult
    func uploadPendingWorkouts(workouts: [HKWorkout], sendNotifications: Bool = false, force: Bool = false) async -> Int {
        // 如果已經在上傳中，則直接返回
        guard !isUploading else {
            print("已有上傳任務在進行中，跳過本次請求")
            return 0
        }
        
        isUploading = true
        defer { isUploading = false }
        
        print("開始上傳未同步的運動記錄...")
        print("force: \(force), 原始 workouts 數量: \(workouts.count)")
        
        // 篩選出需要上傳的運動記錄
        var workoutsToUpload: [HKWorkout] = []
        
        for workout in workouts {
            // 只有在非強制模式下才跳過已上傳的 workout
            if !force {
                // 已上傳且有心率資料，則跳過
                if workoutUploadTracker.isWorkoutUploaded(workout) &&
                   workoutUploadTracker.workoutHasHeartRate(workout) {
                    continue
                }
                // 已上傳但缺少心率且在等待期內，跳過
                if workoutUploadTracker.isWorkoutUploaded(workout) &&
                   !workoutUploadTracker.workoutHasHeartRate(workout) {
                    if let uploadTime = workoutUploadTracker.getWorkoutUploadTime(workout) {
                        let timeElapsed = Date().timeIntervalSince(uploadTime)
                        if timeElapsed < 3600 {
                            continue
                        }
                        print("運動記錄 \(workout.uuid.uuidString) 已上傳但缺少心率資料，且超過1小時，嘗試再次獲取")
                    }
                }
            }
            
            workoutsToUpload.append(workout)
        }
        
        // 篩選結果
        let stableIds = workoutsToUpload.map { workoutUploadTracker.generateStableWorkoutId($0) }
        print("篩選後 workoutsToUpload 數量: \(workoutsToUpload.count)，stableIds: \(stableIds)")
        
        // 如果沒有需要上傳的記錄，直接返回
        if workoutsToUpload.isEmpty {
            print("沒有需要上傳的運動記錄")
            return 0
        }
        
        // 檢查是否為大批量上傳
        let isBulkSync = workoutsToUpload.count > 5
        
        // 使用通知管理器處理通知
        if sendNotifications && isBulkSync {
            await notificationManager.startBulkSync(count: workoutsToUpload.count)
        }
        
        // 開始上傳流程
        var successCount = 0
        
        for workout in workoutsToUpload {
            do {
                // 獲取心率數據
                var heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                if heartRateData.isEmpty || heartRateData.count < 5 {
                    print("心率資料尚未準備好，等待30秒後重試")
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                }
                
                // 強制模式可跳過心率數據檢查
                if !force {
                    // 檢查心率數據是否有效（至少有一定數量的數據點）
                    if heartRateData.isEmpty || heartRateData.count < 5 {
                        print("運動記錄 \(workout.uuid.uuidString) 的心率數據不足，暫不上傳")
                        continue
                    }
                }
                
                // 獲取所有擴展數據
                let speedData = try await healthKitManager.fetchSpeedData(for: workout)
                let strideLengthData = try? await healthKitManager.fetchStrideLengthData(for: workout)
                let cadenceData = try? await healthKitManager.fetchCadenceData(for: workout)
                let groundContactTimeData = try? await healthKitManager.fetchGroundContactTimeData(for: workout)
                let verticalOscillationData = try? await healthKitManager.fetchVerticalOscillationData(for: workout)
                            
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let speeds = speedData.map { DataPoint(time: $0.0, value: $0.1) }
                let strides = strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
                let cadences = cadenceData?.map { DataPoint(time: $0.0, value: $0.1) }
                let contactTimes = groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
                let oscillations = verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }
                            
                
                // 上傳運動數據
                try await workoutService.postWorkoutDetails(
                                workout: workout,
                                heartRates: heartRates,
                                speeds: speeds,
                                strideLengths: strides,
                                cadences: cadences,
                                groundContactTimes: contactTimes,
                                verticalOscillations: oscillations
                            )
                
                // 標記為已上傳且包含心率資料
                workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate), 包含心率數據")
                
                successCount += 1
                
            } catch {
                print("上傳運動記錄失敗: \(workout.uuid.uuidString), 錯誤: \(error)")
            }
            
            // 添加小延遲避免請求過於頻繁
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        // 使用通知管理器處理完成通知
        if sendNotifications {
            if isBulkSync {
                // 批量同步結束通知
                notificationManager.recordSuccess(count: successCount)
                await notificationManager.endBulkSync()
            } else if successCount > 0 {
                // 普通同步完成通知
                await notificationManager.notifySyncCompletion(count: successCount)
            }
        }
        
        print("運動記錄上傳完成，成功: \(successCount), 總計: \(workoutsToUpload.count)")
        return successCount
    }
}
