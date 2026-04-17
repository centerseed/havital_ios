import Foundation
import HealthKit

enum APIVersion {
    case v1
    case v2
}

class WorkoutUploadTracker {
    static let shared = WorkoutUploadTracker()
    
    private let defaults = UserDefaults.standard
    private let uploadedWorkoutsKey = "uploaded_workouts"
    private let uploadedWorkoutsV2Key = "uploaded_workouts_v2"
    private let failedWorkoutsKey = "failed_workouts_v2"

    // 最大重试次数：一个 workout 最多尝试上传 3 次
    private let maxRetryAttempts = 3
    // 重试冷却时间：失败后 30 分钟内不再重试
    private let retryCooldownSeconds: TimeInterval = 30 * 60

    private init() {
        CacheEventBus.shared.subscribe(forIdentifier: "WorkoutUploadTracker") { [weak self] reason in
            if case .userLogout = reason {
                self?.clearUploadedWorkouts()
            }
        }
    }
    
    /// 生成穩定的工作識別碼
    func generateStableWorkoutId(_ workout: HKWorkout) -> String {
        // 使用開始時間、結束時間和運動類型作為組合識別符
        let startTimeStamp = Int(workout.startDate.timeIntervalSince1970)
        let endTimeStamp = Int(workout.endDate.timeIntervalSince1970)
        let activityType = workout.workoutActivityType.rawValue
        
        return "\(startTimeStamp)_\(endTimeStamp)_\(activityType)"
    }
    
    /// 標記運動為已上傳到 V1 API，並指定是否包含心率數據
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRate, apiVersion: .v1)
    }
    
    /// 標記運動為已上傳到指定 API 版本，並指定是否包含心率數據
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true, apiVersion: APIVersion) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedWorkouts(for: apiVersion)
        
        // 儲存上傳時間、心率數據狀態和重試計數
        let uploadInfo: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "hasHeartRate": hasHeartRate,
            "heartRateRetryCount": 0
        ]
        
        uploadedWorkouts[stableId] = uploadInfo
        
        do {
            let data = try JSONSerialization.data(withJSONObject: uploadedWorkouts)
            let key = apiVersion == .v1 ? uploadedWorkoutsKey : uploadedWorkoutsV2Key
            defaults.set(data, forKey: key)
            defaults.synchronize() // 確保立即保存
        } catch {
            print("保存已上傳運動記錄時出錯: \(error)")
        }
    }
    
    /// 檢查運動是否已上傳到 V1 API
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return isWorkoutUploaded(workout, apiVersion: .v1)
    }
    
    /// 檢查運動是否已上傳到指定 API 版本
    func isWorkoutUploaded(_ workout: HKWorkout, apiVersion: APIVersion) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts(for: apiVersion)
        return uploadedWorkouts[stableId] != nil
    }
    
    /// 檢查運動是否包含心率數據（V1 API）
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        return workoutHasHeartRate(workout, apiVersion: .v1)
    }
    
    /// 檢查運動是否包含心率數據（指定 API 版本）
    func workoutHasHeartRate(_ workout: HKWorkout, apiVersion: APIVersion) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts(for: apiVersion)
        
        if let uploadInfo = uploadedWorkouts[stableId] as? [String: Any],
           let hasHeartRate = uploadInfo["hasHeartRate"] as? Bool {
            return hasHeartRate
        }
        
        return false
    }
    
    /// 獲取運動上傳時間（V1 API）
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return getWorkoutUploadTime(workout, apiVersion: .v1)
    }
    
    /// 獲取運動上傳時間（指定 API 版本）
    func getWorkoutUploadTime(_ workout: HKWorkout, apiVersion: APIVersion) -> Date? {
        let stableId = generateStableWorkoutId(workout)
        let uploadedWorkouts = getUploadedWorkouts(for: apiVersion)
        
        if let uploadInfo = uploadedWorkouts[stableId] as? [String: Any],
           let timestamp = uploadInfo["timestamp"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        
        return nil
    }
    
    /// 返回上傳的運動記錄資訊（V1 API）
    private func getUploadedWorkouts() -> [String: Any] {
        return getUploadedWorkouts(for: .v1)
    }
    
    /// 返回指定 API 版本的上傳運動記錄資訊
    private func getUploadedWorkouts(for apiVersion: APIVersion) -> [String: Any] {
        let key = apiVersion == .v1 ? uploadedWorkoutsKey : uploadedWorkoutsV2Key
        guard let data = defaults.data(forKey: key) else {
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
        defaults.synchronize() // 確保立即保存
    }
    
    /// 移除特定運動的上傳紀錄
    func removeWorkoutRecord(_ workout: HKWorkout) {
        let stableId = generateStableWorkoutId(workout)
        var uploadedWorkouts = getUploadedWorkouts()
        uploadedWorkouts.removeValue(forKey: stableId)
        do {
            let data = try JSONSerialization.data(withJSONObject: uploadedWorkouts)
            defaults.set(data, forKey: uploadedWorkoutsKey)
            defaults.synchronize()
        } catch {
            print("移除運動上傳紀錄時出錯: \(error)")
        }
    }
    
    /// 獲取需要重試獲取心率數據的運動記錄ID列表
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
    
    /// 更新運動記錄的心率狀態
    func updateWorkoutHeartRateStatus(_ workout: HKWorkout, hasHeartRate: Bool) {
        if isWorkoutUploaded(workout) {
            // 保持上傳時間不變，只更新心率狀態
            let stableId = generateStableWorkoutId(workout)
            var uploadedWorkouts = getUploadedWorkouts()
            
            if var uploadInfo = uploadedWorkouts[stableId] as? [String: Any] {
                uploadInfo["hasHeartRate"] = hasHeartRate
                uploadedWorkouts[stableId] = uploadInfo
                
                do {
                    let data = try JSONSerialization.data(withJSONObject: uploadedWorkouts)
                    defaults.set(data, forKey: uploadedWorkoutsKey)
                    defaults.synchronize()
                } catch {
                    print("更新運動記錄心率狀態時出錯: \(error)")
                }
            }
        }
    }
    
    /// 取得所有沒有心率資料的運動記錄ID
    func getAllWorkoutsWithoutHeartRate() -> [String] {
        let uploadedWorkouts = getUploadedWorkouts()
        var workoutsWithoutHR: [String] = []
        
        for (stableId, info) in uploadedWorkouts {
            guard let uploadInfo = info as? [String: Any],
                  let hasHeartRate = uploadInfo["hasHeartRate"] as? Bool else {
                continue
            }
            
            if !hasHeartRate {
                workoutsWithoutHR.append(stableId)
            }
        }
        
        return workoutsWithoutHR
    }
    
    /// 批量清除舊的記錄，只保留最近的N條
    func cleanupOldRecords(keepLatest: Int = 200) {
        // 清理 V1 和 V2 兩個 key
        cleanupRecordsForKey(uploadedWorkoutsKey, keepLatest: keepLatest)
        cleanupRecordsForKey(uploadedWorkoutsV2Key, keepLatest: keepLatest)
    }

    private func cleanupRecordsForKey(_ key: String, keepLatest: Int) {
        guard let data = defaults.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let uploadedWorkouts = json

        // 如果記錄數少於保留閾值，則不執行清理
        if uploadedWorkouts.count <= keepLatest {
            return
        }

        // 將記錄轉換為可排序的數組
        var records: [(String, TimeInterval)] = []
        for (stableId, info) in uploadedWorkouts {
            if let uploadInfo = info as? [String: Any],
               let timestamp = uploadInfo["timestamp"] as? TimeInterval {
                records.append((stableId, timestamp))
            }
        }

        // 按時間戳排序（降序）
        records.sort { $0.1 > $1.1 }

        // 只保留最新的N條記錄
        let recordsToKeep = records.prefix(keepLatest)

        // 建立新的字典
        var newUploadedWorkouts: [String: Any] = [:]
        for (stableId, _) in recordsToKeep {
            if let info = uploadedWorkouts[stableId] {
                newUploadedWorkouts[stableId] = info
            }
        }

        // 保存新的字典
        do {
            let data = try JSONSerialization.data(withJSONObject: newUploadedWorkouts)
            defaults.set(data, forKey: key)
            defaults.synchronize()

            print("清理完成 [\(key)]，從 \(uploadedWorkouts.count) 條記錄減少到 \(newUploadedWorkouts.count) 條")
        } catch {
            print("清理舊記錄時出錯 [\(key)]: \(error)")
        }
    }

    // MARK: - Upload Failure Tracking

    /// 記錄 workout 上傳失敗
    /// - Parameters:
    ///   - workout: 失敗的 workout
    ///   - reason: 失敗原因
    ///   - apiVersion: API 版本
    func markWorkoutAsFailed(_ workout: HKWorkout, reason: String, apiVersion: APIVersion = .v2) {
        let stableId = generateStableWorkoutId(workout)
        var failedWorkouts = getFailedWorkouts()

        // 獲取現有的失敗記錄或創建新記錄
        var failureInfo = failedWorkouts[stableId] as? [String: Any] ?? [:]

        // 增加重試計數
        let retryCount = (failureInfo["retryCount"] as? Int ?? 0) + 1

        // 更新失敗信息
        failureInfo = [
            "retryCount": retryCount,
            "lastFailureTime": Date().timeIntervalSince1970,
            "lastFailureReason": reason,
            "firstFailureTime": failureInfo["firstFailureTime"] as? TimeInterval ?? Date().timeIntervalSince1970
        ]

        failedWorkouts[stableId] = failureInfo

        do {
            let data = try JSONSerialization.data(withJSONObject: failedWorkouts)
            defaults.set(data, forKey: failedWorkoutsKey)
            defaults.synchronize()

            print("🚨 [WorkoutUploadTracker] 記錄上傳失敗: \(stableId)")
            print("   - 重試次數: \(retryCount)/\(maxRetryAttempts)")
            print("   - 失敗原因: \(reason)")
        } catch {
            print("保存失敗記錄時出錯: \(error)")
        }
    }

    /// 檢查 workout 是否應該重試上傳
    /// - Parameter workout: 要檢查的 workout
    /// - Returns: true 表示應該重試，false 表示不應該重試
    func shouldRetryUpload(_ workout: HKWorkout) -> Bool {
        let stableId = generateStableWorkoutId(workout)
        let failedWorkouts = getFailedWorkouts()

        guard let failureInfo = failedWorkouts[stableId] as? [String: Any] else {
            // 沒有失敗記錄，可以重試
            return true
        }

        // 檢查重試次數
        let retryCount = failureInfo["retryCount"] as? Int ?? 0
        if retryCount >= maxRetryAttempts {
            print("⚠️ [WorkoutUploadTracker] Workout \(stableId) 已達最大重試次數 (\(retryCount)/\(maxRetryAttempts))，跳過上傳")
            return false
        }

        // 檢查冷卻時間
        if let lastFailureTime = failureInfo["lastFailureTime"] as? TimeInterval {
            let timeSinceFailure = Date().timeIntervalSince1970 - lastFailureTime
            if timeSinceFailure < retryCooldownSeconds {
                let remainingMinutes = Int((retryCooldownSeconds - timeSinceFailure) / 60)
                print("⚠️ [WorkoutUploadTracker] Workout \(stableId) 在冷卻期內，還需等待 \(remainingMinutes) 分鐘")
                return false
            }
        }

        // 可以重試
        print("✅ [WorkoutUploadTracker] Workout \(stableId) 可以重試上傳 (嘗試 \(retryCount + 1)/\(maxRetryAttempts))")
        return true
    }

    /// 清除 workout 的失敗記錄（上傳成功後調用）
    /// - Parameter workout: 成功上傳的 workout
    func clearFailureRecord(_ workout: HKWorkout) {
        let stableId = generateStableWorkoutId(workout)
        var failedWorkouts = getFailedWorkouts()

        if failedWorkouts.removeValue(forKey: stableId) != nil {
            do {
                let data = try JSONSerialization.data(withJSONObject: failedWorkouts)
                defaults.set(data, forKey: failedWorkoutsKey)
                defaults.synchronize()
                print("✅ [WorkoutUploadTracker] 清除失敗記錄: \(stableId)")
            } catch {
                print("清除失敗記錄時出錯: \(error)")
            }
        }
    }

    /// 獲取所有失敗的 workout 記錄
    private func getFailedWorkouts() -> [String: Any] {
        guard let data = defaults.data(forKey: failedWorkoutsKey) else {
            return [:]
        }

        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return dict
            }
        } catch {
            print("讀取失敗記錄時出錯: \(error)")
        }

        return [:]
    }

    /// 獲取失敗統計信息
    func getFailureStats() -> (totalFailed: Int, permanentlyFailed: Int) {
        let failedWorkouts = getFailedWorkouts()
        let totalFailed = failedWorkouts.count

        let permanentlyFailed = failedWorkouts.values.compactMap { $0 as? [String: Any] }
            .filter { ($0["retryCount"] as? Int ?? 0) >= maxRetryAttempts }
            .count

        return (totalFailed, permanentlyFailed)
    }

    /// 清除所有失敗記錄
    func clearAllFailureRecords() {
        defaults.removeObject(forKey: failedWorkoutsKey)
        defaults.synchronize()
        print("🗑️ [WorkoutUploadTracker] 已清除所有失敗記錄")
    }

    /// 調試：打印所有失敗的 workout 記錄
    func debugPrintAllFailedWorkouts() {
        let failedWorkouts = getFailedWorkouts()

        if failedWorkouts.isEmpty {
            print("📋 [DEBUG] 沒有失敗的運動記錄")
            return
        }

        print("📋 [DEBUG] 所有失敗的運動記錄 (\(failedWorkouts.count) 個):")
        print(String(repeating: "=", count: 50))

        for (stableId, info) in failedWorkouts.sorted(by: {
            let time1 = ($0.value as? [String: Any])?["lastFailureTime"] as? TimeInterval ?? 0
            let time2 = ($1.value as? [String: Any])?["lastFailureTime"] as? TimeInterval ?? 0
            return time1 > time2  // 降序排列，最新的在前
        }) {
            guard let failureInfo = info as? [String: Any] else { continue }

            let retryCount = failureInfo["retryCount"] as? Int ?? 0
            let reason = failureInfo["lastFailureReason"] as? String ?? "未知"
            let lastFailureTime = failureInfo["lastFailureTime"] as? TimeInterval ?? 0
            let firstFailureTime = failureInfo["firstFailureTime"] as? TimeInterval ?? 0

            let lastFailureDate = Date(timeIntervalSince1970: lastFailureTime)
            let firstFailureDate = Date(timeIntervalSince1970: firstFailureTime)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            print("\n📌 Workout ID: \(stableId)")
            print("   首次失敗: \(dateFormatter.string(from: firstFailureDate))")
            print("   最後失敗: \(dateFormatter.string(from: lastFailureDate))")
            print("   重試次數: \(retryCount)/\(maxRetryAttempts)")
            print("   失敗原因: \(reason)")
        }

        print(String(repeating: "=", count: 50))
    }

    /// 調試：搜尋特定日期的失敗 workout
    func debugFindFailedWorkoutsOnDate(_ date: Date) {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let failedWorkouts = getFailedWorkouts()

        var matchedWorkouts: [(String, [String: Any])] = []

        for (stableId, info) in failedWorkouts {
            guard let failureInfo = info as? [String: Any],
                  let lastFailureTime = failureInfo["lastFailureTime"] as? TimeInterval else {
                continue
            }

            let failureDate = Date(timeIntervalSince1970: lastFailureTime)
            let failureDateComponents = calendar.dateComponents([.year, .month, .day], from: failureDate)

            if failureDateComponents == targetComponents {
                matchedWorkouts.append((stableId, failureInfo))
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        if matchedWorkouts.isEmpty {
            print("🔍 [DEBUG] \(dateString) 沒有失敗的運動記錄")
            return
        }

        print("🔍 [DEBUG] \(dateString) 失敗的運動記錄 (\(matchedWorkouts.count) 個):")
        print(String(repeating: "=", count: 50))

        for (stableId, failureInfo) in matchedWorkouts {
            let retryCount = failureInfo["retryCount"] as? Int ?? 0
            let reason = failureInfo["lastFailureReason"] as? String ?? "未知"
            let lastFailureTime = failureInfo["lastFailureTime"] as? TimeInterval ?? 0

            let lastFailureDate = Date(timeIntervalSince1970: lastFailureTime)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"

            print("\n📌 Workout ID: \(stableId)")
            print("   失敗時間: \(timeFormatter.string(from: lastFailureDate))")
            print("   重試次數: \(retryCount)/\(maxRetryAttempts)")
            print("   失敗原因: \(reason)")
        }

        print(String(repeating: "=", count: 50))
    }
}
