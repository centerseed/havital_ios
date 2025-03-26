import Foundation
import HealthKit

class WorkoutUploadTracker {
    static let shared = WorkoutUploadTracker()
    
    private let defaults = UserDefaults.standard
    private let uploadedWorkoutsKey = "uploaded_workouts"
    
    private init() {}
    
    /// 生成穩定的工作識別碼
    func generateStableWorkoutId(_ workout: HKWorkout) -> String {
        // 使用開始時間、結束時間和運動類型作為組合識別符
        let startTimeStamp = Int(workout.startDate.timeIntervalSince1970)
        let endTimeStamp = Int(workout.endDate.timeIntervalSince1970)
        let activityType = workout.workoutActivityType.rawValue
        
        return "\(startTimeStamp)_\(endTimeStamp)_\(activityType)"
    }
    
    /// 標記運動為已上傳，並指定是否包含心率數據
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedWorkouts()
        
        // 儲存上傳時間和心率數據狀態
        let uploadInfo: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "hasHeartRate": hasHeartRate
        ]
        
        uploadedWorkouts[stableId] = uploadInfo
        
        do {
            let data = try JSONSerialization.data(withJSONObject: uploadedWorkouts)
            defaults.set(data, forKey: uploadedWorkoutsKey)
        } catch {
            print("保存已上傳運動記錄時出錯: \(error)")
        }
    }
    
    /// 檢查運動是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts()
        return uploadedWorkouts[stableId] != nil
    }
    
    /// 檢查運動是否包含心率數據
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts()
        
        if let uploadInfo = uploadedWorkouts[stableId] as? [String: Any],
           let hasHeartRate = uploadInfo["hasHeartRate"] as? Bool {
            return hasHeartRate
        }
        
        return false
    }
    
    /// 獲取運動上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts()
        
        if let uploadInfo = uploadedWorkouts[stableId] as? [String: Any],
           let timestamp = uploadInfo["timestamp"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        
        return nil
    }
    
    /// 返回上傳的運動記錄資訊
    private func getUploadedWorkouts() -> [String: Any] {
        guard let data = defaults.data(forKey: uploadedWorkoutsKey) else {
            return [:]
        }
        
        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        } catch {
            print("讀取已上傳運動記錄時出錯: \(error)")
        }
        
        return [:]
    }
    
    /// 獲取已上傳運動記錄的數量
    func getUploadedWorkoutsCount() -> Int {
        return getUploadedWorkouts().count
    }
    
    /// 清除已上傳運動記錄歷史
    func clearUploadedWorkouts() {
        defaults.removeObject(forKey: uploadedWorkoutsKey)
    }
    
    /// 獲取需要重試獲取心率數據的運動記錄
    func getWorkoutsNeedingHeartRateRetry(timeThreshold: TimeInterval = 3600) -> [String] {
        let uploadedWorkouts = getUploadedWorkouts()
        var workoutsNeedingRetry: [String] = []
        
        let now = Date().timeIntervalSince1970
        
        for (stableId, info) in uploadedWorkouts {
            // 確保可以解析上傳信息
            guard let uploadInfo = info as? [String: Any],
                  let timestamp = uploadInfo["timestamp"] as? TimeInterval,
                  let hasHeartRate = uploadInfo["hasHeartRate"] as? Bool else {
                continue
            }
            
            // 如果沒有心率數據且上傳時間超過指定閾值，添加到需要重試的列表
            if !hasHeartRate {
                let timeElapsed = now - timestamp
                if timeElapsed >= timeThreshold { // 默認1小時 = 3600秒
                    workoutsNeedingRetry.append(stableId)
                }
            }
        }
        
        return workoutsNeedingRetry
    }
}
