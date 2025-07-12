import Foundation
import HealthKit

class WorkoutBackgroundUploader {
    static let shared = WorkoutBackgroundUploader()
    
    private let workoutService: WorkoutV2Service
    private let workoutUploadTracker: WorkoutUploadTracker
    private let notificationManager = SyncNotificationManager.shared
    private var isUploading = false // 防止多個上傳過程同時運行
    
    private init() {
        self.workoutService = WorkoutV2Service.shared
        self.workoutUploadTracker = WorkoutUploadTracker.shared
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
        
        // 使用統一的 WorkoutService 方法進行批量上傳
        let result = await workoutService.uploadWorkouts(
            workoutsToUpload,
            force: force,
            retryHeartRate: true
        )
        
        // 使用通知管理器處理完成通知
        if sendNotifications {
            if isBulkSync {
                // 批量同步結束通知
                notificationManager.recordSuccess(count: result.success)
                await notificationManager.endBulkSync()
            } else if result.success > 0 {
                // 普通同步完成通知
                await notificationManager.notifySyncCompletion(count: result.success)
            }
        }
        
        print("運動記錄上傳完成，成功: \(result.success), 失敗: \(result.failed), 總計: \(result.total)")
        return result.success
    }
    
    // 獲取運動記錄的來源和裝置資訊
    private func getWorkoutSourceAndDevice(_ workout: HKWorkout) async -> (source: String, device: String?) {
        // 預設值
        var source = "apple_health"
        var deviceBrand: String? = nil
        
        // 檢查 metadata 中的裝置資訊
        if let metadata = workout.metadata {
            // 1. 先檢查是否有製造商資訊
            if let manufacturer = metadata[HKMetadataKeyDeviceManufacturerName] as? String {
                let lowercased = manufacturer.lowercased()
                if lowercased.contains("apple") {
                    source = "apple_watch"
                    deviceBrand = "Apple"
                } else if lowercased.contains("garmin") {
                    source = "garmin"
                    deviceBrand = "Garmin"
                } else if lowercased.contains("polar") {
                    source = "polar"
                    deviceBrand = "Polar"
                } else if lowercased.contains("suunto") {
                    source = "suunto"
                    deviceBrand = "Suunto"
                } else if lowercased.contains("coros") {
                    source = "coros"
                    deviceBrand = "Coros"
                } else if lowercased.contains("huawei") || lowercased.contains("honor") {
                    source = "huawei"
                    deviceBrand = "Huawei"
                } else if lowercased.contains("samsung") || lowercased.contains("galaxy") {
                    source = "samsung"
                    deviceBrand = "Samsung"
                } else if lowercased.contains("fitbit") {
                    source = "fitbit"
                    deviceBrand = "Fitbit"
                } else {
                    // 其他未列出的製造商
                    deviceBrand = manufacturer
                }
            }
            
            // 2. 如果有裝置名稱，且尚未識別出品牌，則從裝置名稱中嘗試識別
            if deviceBrand == nil, let deviceName = metadata[HKMetadataKeyDeviceName] as? String {
                let lowercased = deviceName.lowercased()
                
                if deviceBrand == nil {
                    // 檢查常見品牌
                    let brandMappings: [(String, String)] = [
                        ("apple", "Apple"),
                        ("garmin", "Garmin"),
                        ("polar", "Polar"),
                        ("suunto", "Suunto"),
                        ("coros", "Coros"),
                        ("huawei", "Huawei"),
                        ("honor", "Huawei"),
                        ("samsung", "Samsung"),
                        ("galaxy", "Samsung"),
                        ("fitbit", "Fitbit")
                    ]
                    
                    for (keyword, brand) in brandMappings {
                        if lowercased.contains(keyword) {
                            deviceBrand = brand
                            break
                        }
                    }
                }
                
                // 如果還是無法識別品牌，但有名稱，則使用名稱
                if deviceBrand == nil {
                    deviceBrand = deviceName
                }
            }
        }
        
        // 如果無法識別品牌，但已經有來源，則使用來源作為品牌
        if deviceBrand == nil && source != "apple_health" {
            deviceBrand = source.capitalized
        }
        
        return (source, deviceBrand)
    }
}
