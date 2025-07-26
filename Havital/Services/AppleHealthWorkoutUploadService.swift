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
            if retryHeartRate && heartRateData.count == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 等待10秒
                heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            }
        } catch {
            print("無法獲取心率數據，但將繼續上傳: \(error.localizedDescription)")
            // 記錄 HealthKit 數據獲取錯誤
            await reportHealthKitDataError(workout: workout, dataType: "heart_rate", error: error)
        }
        
        // 獲取設備信息
        let deviceInfo = getWorkoutDeviceInfo(workout)
        let actualSource = deviceInfo.source
        let actualDevice = deviceInfo.device
        
        // 擴充數據（全部為可選）
        let speedData: [(Date, Double)]
        do {
            speedData = try await healthKitManager.fetchSpeedData(for: workout)
        } catch {
            speedData = []
            await reportHealthKitDataError(workout: workout, dataType: "speed", error: error)
        }
        
        let strideLengthData: [(Date, Double)]?
        do {
            strideLengthData = try await healthKitManager.fetchStrideLengthData(for: workout)
        } catch {
            strideLengthData = nil
            await reportHealthKitDataError(workout: workout, dataType: "stride_length", error: error)
        }
        
        let cadenceData: [(Date, Double)]?
        do {
            cadenceData = try await healthKitManager.fetchCadenceData(for: workout)
        } catch {
            cadenceData = nil
            await reportHealthKitDataError(workout: workout, dataType: "cadence", error: error)
        }
        
        let groundContactTimeData: [(Date, Double)]?
        do {
            groundContactTimeData = try await healthKitManager.fetchGroundContactTimeData(for: workout)
        } catch {
            groundContactTimeData = nil
            await reportHealthKitDataError(workout: workout, dataType: "ground_contact_time", error: error)
        }
        
        let verticalOscillationData: [(Date, Double)]?
        do {
            verticalOscillationData = try await healthKitManager.fetchVerticalOscillationData(for: workout)
        } catch {
            verticalOscillationData = nil
            await reportHealthKitDataError(workout: workout, dataType: "vertical_oscillation", error: error)
        }
        
        let totalCalories: Double?
        do {
            totalCalories = try await healthKitManager.fetchCaloriesData(for: workout)
        } catch {
            totalCalories = nil
            await reportHealthKitDataError(workout: workout, dataType: "calories", error: error)
        }
        
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
        
        do {
            // 先嘗試上傳，如果成功就結束
            let _: EmptyResponse = try await APIClient.shared.request(
                EmptyResponse.self,
                path: "/v2/workouts",
                method: "POST",
                body: try JSONEncoder().encode(workoutData)
            )
        } catch {
            // 如果失敗，記錄詳細錯誤
            await reportDetailedUploadError(
                workout: workout,
                workoutData: workoutData,
                error: error
            )
            throw error
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
    
    // MARK: - Error Reporting
    
    /// 詳細的運動上傳錯誤回報
    private func reportDetailedUploadError(
        workout: HKWorkout,
        workoutData: WorkoutData,
        error: Error
    ) async {
        // 收集基本運動資訊
        var errorReport: [String: Any] = [
            "workout_id": workoutData.id,
            "workout_type": workoutData.type,
            "workout_name": workoutData.name,
            "duration_seconds": workoutData.duration,
            "distance_meters": workoutData.distance,
            "start_date": workoutData.startDate,
            "end_date": workoutData.endDate,
            "source": workoutData.source ?? "unknown",
            "device": workoutData.device ?? "unknown",
            "heart_rate_samples": workoutData.heartRates.count,
            "speed_samples": workoutData.speeds.count,
            "total_calories": workoutData.totalCalories ?? 0
        ]
        
        // 收集詳細設備資訊
        if let device = workout.device {
            errorReport["device_details"] = [
                "name": device.name ?? "unknown",
                "manufacturer": device.manufacturer ?? "unknown", 
                "model": device.model ?? "unknown",
                "hardware_version": device.hardwareVersion ?? "unknown",
                "software_version": device.softwareVersion ?? "unknown"
            ]
        }
        
        // 收集來源應用資訊
        errorReport["source_details"] = [
            "name": workout.sourceRevision.source.name,
            "bundle_id": workout.sourceRevision.source.bundleIdentifier
        ]
        
        // 收集可選數據狀態
        var optionalDataStatus: [String: Any] = [:]
        if let strides = workoutData.strideLengths {
            optionalDataStatus["stride_samples"] = strides.count
        }
        if let cadences = workoutData.cadences {
            optionalDataStatus["cadence_samples"] = cadences.count
        }
        if let groundTimes = workoutData.groundContactTimes {
            optionalDataStatus["ground_contact_samples"] = groundTimes.count
        }
        if let oscillations = workoutData.verticalOscillations {
            optionalDataStatus["vertical_oscillation_samples"] = oscillations.count
        }
        errorReport["optional_data_status"] = optionalDataStatus
        
        // 錯誤詳情
        var errorDetails: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        var errorType = "unknown"
        
        // 分析錯誤類型並提取 HTTP 狀態碼
        if let nsError = error as? NSError {
            errorDetails["error_domain"] = nsError.domain
            errorDetails["error_code"] = nsError.code
            
            // 檢查是否是 HTTP 錯誤（來自 APIClient）
            if nsError.domain == "APIClient" {
                errorType = "http_error"
                errorDetails["http_status_code"] = nsError.code
                
                // 嘗試從 userInfo 獲取回應內容
                if let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                    errorDetails["response_body"] = errorMessage
                }
                
                // 根據 HTTP 狀態碼分類
                switch nsError.code {
                case 400...499:
                    errorDetails["error_category"] = "client_error"
                case 500...599:
                    errorDetails["error_category"] = "server_error"
                default:
                    errorDetails["error_category"] = "unknown_http_error"
                }
            }
        } else if let urlError = error as? URLError {
            errorType = "network_error"
            errorDetails["url_error_code"] = urlError.code.rawValue
            errorDetails["url_error_localized"] = urlError.localizedDescription
        } else if error is EncodingError {
            errorType = "encoding_error"
        } else if error is DecodingError {
            errorType = "decoding_error"
        }
        
        errorReport["error_details"] = errorDetails
        
        // 數據完整性分析
        var dataQualityAnalysis: [String: Any] = [
            "has_heart_rate": !workoutData.heartRates.isEmpty,
            "has_speed": !workoutData.speeds.isEmpty,
            "has_distance": workoutData.distance > 0,
            "has_calories": (workoutData.totalCalories ?? 0) > 0,
            "duration_reasonable": workoutData.duration > 0 && workoutData.duration < 86400 // 0-24小時
        ]
        
        // 心率數據品質
        if !workoutData.heartRates.isEmpty {
            let hrValues = workoutData.heartRates.map { $0.value }
            dataQualityAnalysis["hr_min"] = hrValues.min()
            dataQualityAnalysis["hr_max"] = hrValues.max()
            dataQualityAnalysis["hr_avg"] = hrValues.reduce(0, +) / Double(hrValues.count)
            dataQualityAnalysis["hr_reasonable_range"] = hrValues.allSatisfy { $0 >= 30 && $0 <= 250 }
        }
        
        errorReport["data_quality"] = dataQualityAnalysis
        
        // 使用 Firebase 記錄錯誤
        Logger.firebase(
            "Apple Health 運動記錄 V2 API 上傳失敗 - 詳細分析",
            level: .error,
            labels: [
                "module": "AppleHealthWorkoutUploadService",
                "action": "workout_upload_error",
                "error_type": errorType,
                "workout_type": workoutData.type,
                "device_manufacturer": (errorReport["device_details"] as? [String: String])?["manufacturer"] ?? "unknown",
                "source_bundle_id": (errorReport["source_details"] as? [String: String])?["bundle_id"] ?? "unknown"
            ],
            jsonPayload: errorReport
        )
        
        // 本地 debug 日誌
        print("❌ [詳細錯誤分析] AppleHealthWorkoutUploadService 上傳失敗")
        print("   - 運動: \(workoutData.name) (\(workoutData.type))")
        print("   - 時長: \(workoutData.duration)秒")
        print("   - 設備: \(workoutData.device ?? "unknown")")
        print("   - 錯誤類型: \(errorType)")
        if let httpStatus = errorDetails["http_status_code"] as? Int {
            print("   - HTTP 狀態: \(httpStatus)")
        }
        print("   - 錯誤訊息: \(error.localizedDescription)")
    }
    
    /// HealthKit 數據獲取錯誤回報
    private func reportHealthKitDataError(workout: HKWorkout, dataType: String, error: Error) async {
        var errorReport: [String: Any] = [
            "workout_uuid": workout.uuid.uuidString,
            "workout_type": workout.workoutActivityType.rawValue,
            "workout_type_name": workout.workoutActivityType.name,
            "duration_seconds": Int(workout.duration),
            "data_type": dataType,
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        
        // 收集設備資訊
        if let device = workout.device {
            errorReport["device_info"] = [
                "name": device.name ?? "unknown",
                "manufacturer": device.manufacturer ?? "unknown",
                "model": device.model ?? "unknown"
            ]
        }
        
        // 收集來源資訊
        errorReport["source_info"] = [
            "name": workout.sourceRevision.source.name,
            "bundle_id": workout.sourceRevision.source.bundleIdentifier
        ]
        
        // 錯誤分類
        var errorCategory = "unknown"
        if let hkError = error as? HKError {
            errorCategory = "healthkit_error"
            errorReport["hk_error_code"] = hkError.code.rawValue
        } else if error is CancellationError {
            errorCategory = "cancellation_error"
        }
        
        Logger.firebase(
            "HealthKit 數據獲取失敗 - \(dataType)",
            level: .error,
            labels: [
                "module": "AppleHealthWorkoutUploadService",
                "action": "healthkit_data_fetch_error",
                "data_type": dataType,
                "error_category": errorCategory,
                "device_manufacturer": (errorReport["device_info"] as? [String: String])?["manufacturer"] ?? "unknown"
            ],
            jsonPayload: errorReport
        )
        
        print("⚠️ [HealthKit 錯誤] 無法獲取 \(dataType) 數據: \(error.localizedDescription)")
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
