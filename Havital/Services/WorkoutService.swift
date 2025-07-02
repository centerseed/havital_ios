import Foundation
import HealthKit

// MARK: - 錯誤類型定義
enum WorkoutUploadError: Error {
    case missingHeartRateData
    case serverError
}

class WorkoutService {
    static let shared = WorkoutService()
    
    private let healthKitManager = HealthKitManager()
    private let workoutUploadTracker = WorkoutUploadTracker.shared
    
    private init() {}
    
    // Helper method to determine workout type string
    private func getWorkoutTypeString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .trackAndField:
            return "run"
        case .walking:
            return "walk"
        case .cycling, .handCycling:
            return "cycling"
        case .swimming, .swimBikeRun:
            return "swim"
        case .highIntensityIntervalTraining:
            return "hiit"
        case .crossTraining:
            return "cross"
        case .mixedCardio:
            return "mixedCardio"
        case .pilates:
            return "pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "strength"
        case .yoga, .mindAndBody:
            return "yoga"
        case .hiking:
            return "hiking"
        default:
            return "other"
        }
    }
    
    // 統一組 workoutId 的方法
    func makeWorkoutId(for workout: HKWorkout) -> String {
        let type = getWorkoutTypeString(workout.workoutActivityType)
        let startTs = Int(workout.startDate.timeIntervalSince1970)
        let distM = Int(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        return "\(type)_\(startTs)_\(distM)"
    }
    
    // MARK: - 統一的 Workout 上傳方法
    
    /// 統一的 workout 上傳方法，包含數據獲取和上傳邏輯
    /// - Parameters:
    ///   - workout: 要上傳的運動記錄
    ///   - force: 是否強制上傳（跳過心率數據檢查）
    ///   - retryHeartRate: 是否重試獲取心率數據
    ///   - source: 數據來源
    ///   - device: 設備型號
    /// - Returns: 上傳結果
    func uploadWorkout(
        _ workout: HKWorkout,
        force: Bool = false,
        retryHeartRate: Bool = false,
        source: String = "apple_health",
        device: String? = nil
    ) async throws -> UploadResult {
        
        // 獲取心率數據
        var heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
        
        // 如果需要重試且心率數據不足，等待後重試
        if retryHeartRate && (heartRateData.isEmpty || heartRateData.count < 5) {
            Logger.info("心率資料尚未準備好，等待5秒後重試")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            Logger.info("重試後心率數據數量: \(heartRateData.count)")
        }
        
        // 檢查心率數據是否足夠（除非強制模式）
        if !force {
            if heartRateData.isEmpty || heartRateData.count < 5 {
                let elapsed = Date().timeIntervalSince(workout.endDate)
                if elapsed < 10 * 60 {
                    // 運動結束不到10分鐘，可能是數據還沒準備好
                    Logger.warn("運動記錄 \(workout.uuid) 心率資料尚未齊全，稍後重試")
                    throw WorkoutUploadError.missingHeartRateData
                } else {
                    // 超過10分鐘仍無心率數據，標記為已上傳但無心率
                    Logger.warn("運動記錄 \(workout.uuid) 心率資料仍不完整，超過10分鐘，標記為已上傳無心率")
                    workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                    return UploadResult.success(hasHeartRate: false)
                }
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
        try await postWorkoutDetails(
            workout: workout,
            heartRates: heartRates,
            speeds: speeds,
            strideLengths: strides,
            cadences: cadences,
            groundContactTimes: contactTimes,
            verticalOscillations: oscillations,
            source: source,
            device: device
        )
        
        // 標記為已上傳且包含心率資料
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
        Logger.info("成功上傳運動記錄: \(workout.workoutActivityType.name), 心率數據: \(heartRates.count)筆")
        
        return UploadResult.success(hasHeartRate: true)
    }
    
    /// 批量上傳 workout
    /// - Parameters:
    ///   - workouts: 要上傳的運動記錄列表
    ///   - force: 是否強制上傳
    ///   - retryHeartRate: 是否重試獲取心率數據
    /// - Returns: 上傳結果統計
    func uploadWorkouts(
        _ workouts: [HKWorkout],
        force: Bool = false,
        retryHeartRate: Bool = false
    ) async -> UploadBatchResult {
        
        var successCount = 0
        var failedCount = 0
        var failedWorkouts: [FailedWorkout] = []
        
        for workout in workouts {
            do {
                _ = try await uploadWorkout(workout, force: force, retryHeartRate: retryHeartRate)
                successCount += 1
                
                // 添加小延遲避免請求過於頻繁
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
            } catch {
                failedCount += 1
                failedWorkouts.append(FailedWorkout(workout: workout, error: error))
                
                // 記錄失敗到 Firebase Cloud Logging
                Logger.firebase(
                    "批量上傳運動記錄失敗",
                    level: .error,
                    labels: [
                        "module": "WorkoutService",
                        "action": "batch_upload",
                        "failure_reason": "upload_error"
                    ],
                    jsonPayload: [
                        "workout_id": workout.uuid.uuidString,
                        "user_id": AuthenticationService.shared.user?.uid ?? "unknown",
                        "error_type": String(describing: type(of: error)),
                        "error_message": error.localizedDescription,
                        "workout_type": workout.workoutActivityType.name,
                        "workout_start_date": workout.startDate.timeIntervalSince1970,
                        "workout_end_date": workout.endDate.timeIntervalSince1970,
                        "is_force_upload": force,
                        "retry_heart_rate": retryHeartRate
                    ]
                )
            }
        }
        
        return UploadBatchResult(
            total: workouts.count,
            success: successCount,
            failed: failedCount,
            failedWorkouts: failedWorkouts
        )
    }
    
    // MARK: - 原有的 postWorkoutDetails 方法（現在是內部方法）
    
    func postWorkoutDetails(
        workout: HKWorkout,
        heartRates: [DataPoint],
        speeds: [DataPoint],
        strideLengths: [DataPoint]? = nil,
        cadences: [DataPoint]? = nil,
        groundContactTimes: [DataPoint]? = nil,
        verticalOscillations: [DataPoint]? = nil,
        source: String = "apple_health",
        device: String? = nil
    ) async throws {
        // 確保有心率數據
        if heartRates.isEmpty || heartRates.count < 1 {
            Logger.warn("警告: 運動記錄心率數據不足 (\(heartRates.count) 筆)，不上傳")
            
            // 記錄到 Firebase Cloud Logging
            Logger.firebase(
                "運動記錄上傳失敗：心率數據不足",
                level: .warn,
                labels: [
                    "module": "WorkoutService",
                    "action": "upload",
                    "failure_reason": "insufficient_heart_rate_data"
                ],
                jsonPayload: [
                    "workout_id": workout.uuid.uuidString,
                    "user_id": AuthenticationService.shared.user?.uid ?? "unknown",
                    "heart_rate_count": heartRates.count,
                    "workout_type": workout.workoutActivityType.name,
                    "workout_start_date": workout.startDate.timeIntervalSince1970,
                    "workout_end_date": workout.endDate.timeIntervalSince1970,
                    "source": source,
                    "device": device ?? "unknown"
                ]
            )
            
            throw WorkoutUploadError.missingHeartRateData
        }
        
        Logger.debug("上傳運動記錄 - Workout End Date: \(workout.endDate)")
        Logger.debug("上傳運動記錄 - Heart Rate Data Points: \(heartRates.count)")
        
        // Debug: log original activityType and mapped type
        let workoutType = getWorkoutTypeString(workout.workoutActivityType)
        Logger.debug("原始 activityType：\(workout.workoutActivityType) rawValue: \(workout.workoutActivityType.rawValue) -> mapped to type: \(workoutType)")
        
        // 創建運動數據模型
        let workoutData = WorkoutData(
            id: makeWorkoutId(for: workout),
            name: workout.workoutActivityType.name,
            type: workoutType,
            startDate: workout.startDate.timeIntervalSince1970,
            endDate: workout.endDate.timeIntervalSince1970,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            heartRates: heartRates.map { HeartRateData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            speeds: speeds.map { SpeedData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            strideLengths: strideLengths?.map { StrideData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            cadences: cadences?.map { CadenceData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            groundContactTimes: groundContactTimes?.map { GroundContactTimeData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            verticalOscillations: verticalOscillations?.map { VerticalOscillationData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            source: source,
            device: device
        )
        
        do {
            // 使用 APIClient 上傳運動數據並檢查 HTTP 狀態碼
            let http = try await APIClient.shared.requestWithStatus(
                path: "/workout", method: "POST",
                body: try JSONEncoder().encode(workoutData))
            Logger.info("上傳運動數據 HTTP 狀態: \(http.statusCode)")
            guard (200...299).contains(http.statusCode) else {
                let errorMessage = "上傳失敗，HTTP 狀態碼: \(http.statusCode)"
                
                // 記錄到 Firebase Cloud Logging
                Logger.firebase(
                    "運動記錄上傳失敗：HTTP錯誤",
                    level: .error,
                    labels: [
                        "module": "WorkoutService",
                        "action": "upload",
                        "failure_reason": "http_error"
                    ],
                    jsonPayload: [
                        "workout_id": workout.uuid.uuidString,
                        "user_id": AuthenticationService.shared.user?.uid ?? "unknown",
                        "http_status_code": http.statusCode,
                        "workout_type": workout.workoutActivityType.name,
                        "workout_start_date": workout.startDate.timeIntervalSince1970,
                        "workout_end_date": workout.endDate.timeIntervalSince1970,
                        "source": source,
                        "device": device ?? "unknown",
                        "heart_rate_count": heartRates.count,
                        "speed_count": speeds.count
                    ]
                )
                
                throw NSError(domain: "WorkoutService", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            Logger.info("成功上傳運動數據")
            
            // 上傳成功後，嘗試同步拉取並快取動態跑力，若失敗則拋出
            let summaryId = makeWorkoutId(for: workout)
            let summary = try await getWorkoutSummary(workoutId: summaryId)
            saveCachedWorkoutSummary(summary, for: summaryId)
            Logger.info("已快取 WorkoutSummary for \(summaryId)")
            
            // 只有真正同步到後台再標記
            markWorkoutAsUploaded(workout)
            
        } catch {
            // 記錄到 Firebase Cloud Logging
            Logger.firebase(
                "運動記錄上傳失敗：\(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutService",
                    "action": "upload",
                    "failure_reason": "api_error"
                ],
                jsonPayload: [
                    "workout_id": workout.uuid.uuidString,
                    "user_id": AuthenticationService.shared.user?.uid ?? "unknown",
                    "error_type": String(describing: type(of: error)),
                    "error_message": error.localizedDescription,
                    "workout_type": workout.workoutActivityType.name,
                    "workout_start_date": workout.startDate.timeIntervalSince1970,
                    "workout_end_date": workout.endDate.timeIntervalSince1970,
                    "source": source,
                    "device": device ?? "unknown",
                    "heart_rate_count": heartRates.count,
                    "speed_count": speeds.count
                ]
            )
            
            throw error
        }
    }
    
    // MARK: - 結果類型定義
    
    /// 單個 workout 上傳結果
    enum UploadResult {
        case success(hasHeartRate: Bool)
        case failure(error: Error)
    }
    
    /// 批量上傳結果
    struct UploadBatchResult {
        let total: Int
        let success: Int
        let failed: Int
        let failedWorkouts: [FailedWorkout]
    }
    
    /// 失敗的 workout 資訊
    struct FailedWorkout {
        let workout: HKWorkout
        let error: Error
    }
    
    // MARK: - 其他方法保持不變
    
    // 新增 Workout Summary API 方法
    func getWorkoutSummary(workoutId: String) async throws -> WorkoutSummary {
        let path = "/workout/summary/\(workoutId)"
        let response: WorkoutSummaryResponse = try await APIClient.shared.request(WorkoutSummaryResponse.self,
            path: path, method: "GET")
        return response.data.workout
    }
    
    // MARK: - 快取 WorkoutSummary 方法
    func saveCachedWorkoutSummary(_ summary: WorkoutSummary, for id: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data] ?? [:]
        if let data = try? JSONEncoder().encode(summary) {
            dict[id] = data
            UserDefaults.standard.set(dict, forKey: "WorkoutSummaryCache")
        }
    }
    
    func getCachedWorkoutSummary(for id: String) -> WorkoutSummary? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data],
              let data = dict[id],
              let summary = try? JSONDecoder().decode(WorkoutSummary.self, from: data)
        else { return nil }
        return summary
    }

    // MARK: - Clear WorkoutSummaryCache
    /// 清除儲存在 UserDefaults 的 WorkoutSummaryCache
    func clearWorkoutSummaryCache() {
        UserDefaults.standard.removeObject(forKey: "WorkoutSummaryCache")
    }

    // WorkoutService.swift 中添加的方法

    // 添加到 WorkoutService 類中
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        WorkoutUploadTracker.shared.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRate)
    }

    // 檢查特定運動記錄是否已上傳
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return WorkoutUploadTracker.shared.isWorkoutUploaded(workout)
    }

    // 檢查特定運動記錄是否包含心率數據
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool {
        return WorkoutUploadTracker.shared.workoutHasHeartRate(workout)
    }

    // 獲取運動記錄的上傳時間
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return WorkoutUploadTracker.shared.getWorkoutUploadTime(workout)
    }
}

// Data models for API
struct WorkoutData: Codable {
    let id: String
    let name: String
    let type: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let duration: TimeInterval
    let distance: Double
    let heartRates: [HeartRateData]
    let speeds: [SpeedData]                  // 改為速度
    let strideLengths: [StrideData]?         // 步幅
    let cadences: [CadenceData]?             // 步頻
    let groundContactTimes: [GroundContactTimeData]? // 觸地時間
    let verticalOscillations: [VerticalOscillationData]? // 垂直振幅
    let source: String?                       // 資料來源 (如: apple_health, garmin, polar 等)
    let device: String?                       // 裝置型號 (如: Apple Watch Series 7, Garmin Forerunner 945 等)
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct SpeedData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m/s
}

struct StrideData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}

struct CadenceData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：steps/min
}

struct GroundContactTimeData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：ms
}

struct VerticalOscillationData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}

struct EmptyResponse: Codable {}

// Extension to get a name for the workout type
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running, .trackAndField:
            return "跑步"
        case .cycling, .handCycling:
            return "騎車"
        case .walking:
            return "步行"
        case .swimming, .swimBikeRun:
            return "游泳"
        case .highIntensityIntervalTraining:
            return "高強度間歇訓練"
        case .crossTraining:
            return "交叉訓練"
        case .mixedCardio:
            return "混合有氧"
        case .traditionalStrengthTraining:
            return "重量訓練"
        case .functionalStrengthTraining:
            return "功能性訓練"
        case .yoga, .mindAndBody:
            return "瑜伽"
        case .pilates:
            return "普拉提"
        case .hiking:
            return "健行"
        default:
            return "其他運動"
        }
    }
}
