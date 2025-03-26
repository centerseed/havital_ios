import Foundation
import HealthKit

class WorkoutUploadTracker {
    static let shared = WorkoutUploadTracker()
    
    private let defaults = UserDefaults.standard
    private let uploadedWorkoutsKey = "uploaded_workouts"
    
    private init() {}
    
    // 上傳狀態結構，包含時間戳和心率數據狀態
    struct UploadStatus: Codable {
        let timestamp: TimeInterval
        let hasHeartRate: Bool
    }
    
    /// 生成穩定的工作識別碼
    func generateStableWorkoutId(_ workout: HKWorkout) -> String {
        // 使用開始時間、結束時間和運動類型作為組合識別符
        let startTimeStamp = Int(workout.startDate.timeIntervalSince1970)
        let endTimeStamp = Int(workout.endDate.timeIntervalSince1970)
        let activityType = workout.workoutActivityType.rawValue
        
        return "\(startTimeStamp)_\(endTimeStamp)_\(activityType)"
    }
    
    /// 標記運動為已上傳
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedStatusDict()
        
        let status = UploadStatus(timestamp: Date().timeIntervalSince1970, hasHeartRate: hasHeartRate)
        uploadedWorkouts[stableId] = status
        
        saveUploadStatusDict(uploadedWorkouts)
    }
    
    /// 更新運動的心率狀態
    func updateHeartRateStatus(for workout: HKWorkout, hasHeartRate: Bool) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedStatusDict()
        
        if let existingStatus = uploadedWorkouts[stableId] {
            let updatedStatus = UploadStatus(timestamp: existingStatus.timestamp, hasHeartRate: hasHeartRate)
            uploadedWorkouts[stableId] = updatedStatus
            saveUploadStatusDict(uploadedWorkouts)
        }
    }
    
    /// 檢查運動是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedStatusDict()
        return uploadedWorkouts[stableId] != nil
    }
    
    /// 檢查運動是否包含心率數據
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedStatusDict()
        return uploadedWorkouts[stableId]?.hasHeartRate ?? false
    }
    
    /// 獲取運動上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedStatusDict()
        if let timestamp = uploadedWorkouts[stableId]?.timestamp {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    /// 獲取需要重新上傳的運動記錄 (上傳但缺少心率數據且時間超過閾值)
    func getWorkoutsNeedingHeartRateRetry(timeThreshold: TimeInterval = 3600) -> [String] {
        let now = Date().timeIntervalSince1970
        let uploadedWorkouts = getUploadedStatusDict()
        
        return uploadedWorkouts.filter { key, status in
            // 篩選條件：已上傳但沒有心率數據，且在時間閾值內
            !status.hasHeartRate && (now - status.timestamp) > timeThreshold
        }.keys.map { $0 }
    }
    
    /// 獲取已上傳運動記錄數量
    func getUploadedWorkoutsCount() -> Int {
        return getUploadedStatusDict().count
    }
    
    /// 獲取已上傳但缺少心率資料的記錄數量
    func getMissingHeartRateWorkoutsCount() -> Int {
        return getUploadedStatusDict().filter { !$0.value.hasHeartRate }.count
    }
    
    /// 返回上傳的運動記錄狀態字典
    private func getUploadedStatusDict() -> [String: UploadStatus] {
        guard let data = defaults.data(forKey: uploadedWorkoutsKey) else {
            return [:]
        }
        
        do {
            // 先嘗試解碼為新格式
            return try JSONDecoder().decode([String: UploadStatus].self, from: data)
        } catch {
            // 如果失敗，可能是舊格式，嘗試遷移
            do {
                let oldFormat = try JSONDecoder().decode([String: TimeInterval].self, from: data)
                let newFormat = migrateOldFormat(oldFormat)
                saveUploadStatusDict(newFormat)
                return newFormat
            } catch {
                print("讀取已上傳運動記錄時出錯: \(error)")
                return [:]
            }
        }
    }
    
    /// 遷移舊格式的數據到新格式
    private func migrateOldFormat(_ oldFormat: [String: TimeInterval]) -> [String: UploadStatus] {
        var newFormat: [String: UploadStatus] = [:]
        for (key, timestamp) in oldFormat {
            newFormat[key] = UploadStatus(timestamp: timestamp, hasHeartRate: true)
        }
        return newFormat
    }
    
    /// 保存上傳狀態字典
    private func saveUploadStatusDict(_ statuses: [String: UploadStatus]) {
        do {
            let data = try JSONEncoder().encode(statuses)
            defaults.set(data, forKey: uploadedWorkoutsKey)
        } catch {
            print("保存上傳狀態時出錯: \(error)")
        }
    }
    
    /// 清除已上傳運動記錄歷史
    func clearUploadedWorkouts() {
        defaults.removeObject(forKey: uploadedWorkoutsKey)
    }
}
