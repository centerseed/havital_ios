import Foundation
import HealthKit

// MARK: - 錯誤類型定義
enum AppleHealthWorkoutUploadError: Error {
    case serverError
}

// MARK: - Apple Health Workout Upload Service
class AppleHealthWorkoutUploadService {
    static let shared = AppleHealthWorkoutUploadService()
    private init() {}
    
    private let healthKitManager = HealthKitManager()
    private let workoutUploadTracker = WorkoutUploadTracker.shared
    
    // MARK: - Helper - workout type -> string
    private func getWorkoutTypeString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .trackAndField:                           return "run"
        case .walking:                                           return "walk"
        case .cycling, .handCycling:                             return "cycling"
        case .swimming, .swimBikeRun:                            return "swim"
        case .highIntensityIntervalTraining:                     return "hiit"
        case .crossTraining:                                     return "cross"
        case .mixedCardio:                                       return "mixedCardio"
        case .pilates:                                           return "pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
        case .yoga, .mindAndBody:                                return "yoga"
        case .hiking:                                            return "hiking"
        default:                                                 return "other"
        }
    }
    
    // MARK: - Public Helper
    func makeWorkoutId(for workout: HKWorkout) -> String {
        let type  = getWorkoutTypeString(workout.workoutActivityType)
        let start = Int(workout.startDate.timeIntervalSince1970)
        let distM = Int(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        return "\(type)_\(start)_\(distM)"
    }
    
    // MARK: - Core Upload API
    func uploadWorkout(_ workout: HKWorkout,
                       force: Bool = false,
                       retryHeartRate: Bool = false,
                       source: String = "apple_health",
                       device: String? = nil) async throws -> UploadResult {
        // 選擇檢查：確保當前資料來源是 Apple Health
        guard UserPreferenceManager.shared.dataSourcePreference == .appleHealth else {
            throw WorkoutV2ServiceError.invalidWorkoutData
        }
        
        // 檢查基本數據（時間和距離）
        let duration = workout.duration
        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        
        // 基本數據驗證：必須有有效的持續時間
        guard duration > 0 else {
            throw WorkoutV2ServiceError.invalidWorkoutData
        }
        
        // 取得心率數據（可選，不再強制要求）
        var heartRateData: [(Date, Double)] = []
        do {
            heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            if retryHeartRate && heartRateData.count < 5 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            }
        } catch {
            print("無法獲取心率數據，但將繼續上傳: \(error.localizedDescription)")
        }
        
        // 獲取設備信息
        let deviceInfo = getWorkoutDeviceInfo(workout)
        let actualSource = deviceInfo.source
        let actualDevice = deviceInfo.device
        
        // 擴充數據（全部為可選）
        let speedData = (try? await healthKitManager.fetchSpeedData(for: workout)) ?? []
        let strideLengthData = try? await healthKitManager.fetchStrideLengthData(for: workout)
        let cadenceData = try? await healthKitManager.fetchCadenceData(for: workout)
        let groundContactTimeData = try? await healthKitManager.fetchGroundContactTimeData(for: workout)
        let verticalOscillationData = try? await healthKitManager.fetchVerticalOscillationData(for: workout)
        let totalCalories = try? await healthKitManager.fetchCaloriesData(for: workout)
        
        // 轉成 DataPoint
        let heartRates  = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
        let speeds      = speedData.map { DataPoint(time: $0.0, value: $0.1) }
        let strides     = strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
        let cadences    = cadenceData?.map { DataPoint(time: $0.0, value: $0.1) }
        let contacts    = groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
        let oscillations = verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }
        
        try await postWorkoutDetails(workout: workout,
                                     heartRates: heartRates,
                                     speeds: speeds,
                                     strideLengths: strides,
                                     cadences: cadences,
                                     groundContactTimes: contacts,
                                     verticalOscillations: oscillations,
                                     totalCalories: totalCalories,
                                     source: actualSource,
                                     device: actualDevice)
        
        let hasHeartRateData = heartRateData.count >= 5
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRateData)
        return .success(hasHeartRate: hasHeartRateData)
    }
    
    // MARK: - Batch Upload
    func uploadWorkouts(_ workouts: [HKWorkout],
                        force: Bool = false,
                        retryHeartRate: Bool = false) async -> UploadBatchResult {
        var success = 0
        var failed  = 0
        var failedList: [FailedWorkout] = []
        
        for w in workouts {
            do {
                _ = try await uploadWorkout(w, force: force, retryHeartRate: retryHeartRate)
                success += 1
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                failed += 1
                failedList.append(FailedWorkout(workout: w, error: error))
            }
        }
        return UploadBatchResult(total: workouts.count, success: success, failed: failed, failedWorkouts: failedList)
    }
    
    // MARK: - Internal request helper
    private func postWorkoutDetails(workout: HKWorkout,
                                    heartRates: [DataPoint],
                                    speeds: [DataPoint],
                                    strideLengths: [DataPoint]? = nil,
                                    cadences: [DataPoint]? = nil,
                                    groundContactTimes: [DataPoint]? = nil,
                                    verticalOscillations: [DataPoint]? = nil,
                                    totalCalories: Double? = nil,
                                    source: String,
                                    device: String?) async throws {
        // 建立 WorkoutData 結構
        let workoutData = WorkoutData(
            id: makeWorkoutId(for: workout),
            name: workout.workoutActivityType.name,
            type: getWorkoutTypeString(workout.workoutActivityType),
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
            totalCalories: totalCalories,
            source: source,
            device: device)
        
        let http = try await APIClient.shared.requestWithStatus(path: "/v2/workouts", method: "POST", body: try JSONEncoder().encode(workoutData))
        guard (200...299).contains(http.statusCode) else {
            throw AppleHealthWorkoutUploadError.serverError
        }
    }
    
    // MARK: - Summary Helpers (cache)
    func getWorkoutSummary(workoutId: String) async throws -> WorkoutSummary {
        let path = "/workout/summary/\(workoutId)" // v2 未提供 summary 端點，暫沿用舊端點
        let response: WorkoutSummaryResponse = try await APIClient.shared.request(WorkoutSummaryResponse.self, path: path, method: "GET")
        return response.data.workout
    }
    
    func saveCachedWorkoutSummary(_ summary: WorkoutSummary, for id: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data] ?? [:]
        if let data = try? JSONEncoder().encode(summary) {
            dict[id] = data
            UserDefaults.standard.set(dict, forKey: "WorkoutSummaryCache")
        }
    }
    func getCachedWorkoutSummary(for id: String) -> WorkoutSummary? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data], let data = dict[id], let summary = try? JSONDecoder().decode(WorkoutSummary.self, from: data) else { return nil }
        return summary
    }
    func clearWorkoutSummaryCache() {
        UserDefaults.standard.removeObject(forKey: "WorkoutSummaryCache")
    }
    
    // MARK: - Device Info Helper
    private func getWorkoutDeviceInfo(_ workout: HKWorkout) -> (source: String, device: String?) {
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
                
                // 如果還是無法識別品牌，但有名稱，則使用名稱
                if deviceBrand == nil {
                    deviceBrand = deviceName
                }
            }
            
            // 3. 嘗試從 device 物件獲取更詳細的信息
            if let device = workout.device {
                if deviceBrand == nil, let manufacturer = device.manufacturer {
                    deviceBrand = manufacturer
                }
                
                // 如果有型號信息，將其附加到品牌名稱中
                if let model = device.model, let brand = deviceBrand {
                    deviceBrand = "\(brand) \(model)"
                } else if let model = device.model, deviceBrand == nil {
                    deviceBrand = model
                }
            }
        }
        
        // 如果無法識別品牌，但已經有來源，則使用來源作為品牌
        if deviceBrand == nil && source != "apple_health" {
            deviceBrand = source.capitalized
        }
        
        return (source, deviceBrand)
    }
    
    // MARK: - Upload Tracker Helpers
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRate)
    }
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool { workoutUploadTracker.isWorkoutUploaded(workout) }
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool { workoutUploadTracker.workoutHasHeartRate(workout) }
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? { workoutUploadTracker.getWorkoutUploadTime(workout) }
    
    // MARK: - Result types
    enum UploadResult {
        case success(hasHeartRate: Bool)
        case failure(error: Error)
    }
    struct UploadBatchResult { let total: Int; let success: Int; let failed: Int; let failedWorkouts: [FailedWorkout] }
    struct FailedWorkout { let workout: HKWorkout; let error: Error }
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
    let totalCalories: Double?               // 總卡路里
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
