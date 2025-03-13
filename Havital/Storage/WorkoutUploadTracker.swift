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
    
    /// 標記運動為已上傳
    func markWorkoutAsUploaded(_ workout: HKWorkout) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedWorkouts()
        uploadedWorkouts[stableId] = Date().timeIntervalSince1970
        
        do {
            let data = try JSONEncoder().encode(uploadedWorkouts)
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
    
    /// 獲取運動上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts()
        if let timestamp = uploadedWorkouts[stableId] {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    /// 返回上傳的運動記錄字典
    private func getUploadedWorkouts() -> [String: TimeInterval] {
        guard let data = defaults.data(forKey: uploadedWorkoutsKey) else {
            return [:]
        }
        
        do {
            return try JSONDecoder().decode([String: TimeInterval].self, from: data)
        } catch {
            print("讀取已上傳運動記錄時出錯: \(error)")
            return [:]
        }
    }
    
    /// 清除已上傳運動記錄歷史
    func clearUploadedWorkouts() {
        defaults.removeObject(forKey: uploadedWorkoutsKey)
    }
}
