import SwiftUI
import Combine
import HealthKit

/// 實際的 V2 API 運動詳情數據模型 (基於實際 API 回應)
struct WorkoutDetailV2: Codable {
    let id: String
    let provider: String
    let activityType: String
    let sportType: String
    let startTime: String
    let endTime: String
    let userId: String
    let schemaVersion: String
    let source: String
    let storagePath: String
    let createdAt: String?
    let updatedAt: String?
    let originalId: String
    let providerUserId: String
    let garminUserId: String?
    let webhookStoragePath: String?
    
    // 基本指標
    let basicMetrics: RealBasicMetrics?
    
    // 高級指標
    let advancedMetrics: RealAdvancedMetrics?
    
    // 時間序列數據
    let timeSeries: TimeSeries?
    
    // 設備信息
    let deviceInfo: DeviceInfo?
    
    // 路線數據
    let routeData: WorkoutRouteData?
    
    // 環境數據
    let environment: EnvironmentData?
    
    // 元數據
    let metadata: Metadata?
    
    enum CodingKeys: String, CodingKey {
        case id, provider, source
        case activityType = "activity_type"
        case sportType = "sport_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case userId = "user_id"
        case schemaVersion = "schema_version"
        case storagePath = "storage_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case originalId = "original_id"
        case providerUserId = "provider_user_id"
        case garminUserId = "garmin_user_id"
        case webhookStoragePath = "webhook_storage_path"
        case basicMetrics = "basic_metrics"
        case advancedMetrics = "advanced_metrics"
        case timeSeries = "time_series"
        case deviceInfo = "device_info"
        case routeData = "route_data"
        case environment = "environment"
        case metadata = "metadata"
    }
}

struct RealBasicMetrics: Codable {
    let totalDurationS: Int?
    let totalDistanceM: Double?
    let avgHeartRateBpm: Int?
    let maxHeartRateBpm: Int?
    let minHeartRateBpm: Int?
    let avgPaceSPerKm: Double?
    let avgSpeedMPerS: Double?
    let maxSpeedMPerS: Double?
    let avgCadenceSpm: Int?
    let avgStrideLengthM: Double?
    let caloriesKcal: Int?
    let movingDurationS: Int?
    let totalAscentM: Double?
    let totalDescentM: Double?
    let avgAltitudeM: Double?
    let avgPowerW: Double?
    let maxPowerW: Double?
    let normalizedPowerW: Double?
    let trainingLoad: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalDurationS = "total_duration_s"
        case totalDistanceM = "total_distance_m"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case maxHeartRateBpm = "max_heart_rate_bpm"
        case minHeartRateBpm = "min_heart_rate_bpm"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case avgSpeedMPerS = "avg_speed_m_per_s"
        case maxSpeedMPerS = "max_speed_m_per_s"
        case avgCadenceSpm = "avg_cadence_spm"
        case avgStrideLengthM = "avg_stride_length_m"
        case caloriesKcal = "calories_kcal"
        case movingDurationS = "moving_duration_s"
        case totalAscentM = "total_ascent_m"
        case totalDescentM = "total_descent_m"
        case avgAltitudeM = "avg_altitude_m"
        case avgPowerW = "avg_power_w"
        case maxPowerW = "max_power_w"
        case normalizedPowerW = "normalized_power_w"
        case trainingLoad = "training_load"
    }
}

struct RealAdvancedMetrics: Codable {
    let dynamicVdot: Double?
    let tss: Double?
    let trainingType: String?
    let intensityMinutes: RealIntensityMinutes?
    let intervalCount: Int?
    let avgHrTop20Percent: Double?
    let hrZoneDistribution: RealZoneDistribution?
    let paceZoneDistribution: RealZoneDistribution?
    let rpe: Double?
    
    enum CodingKeys: String, CodingKey {
        case dynamicVdot = "dynamic_vdot"
        case tss
        case trainingType = "training_type"
        case intensityMinutes = "intensity_minutes"
        case intervalCount = "interval_count"
        case avgHrTop20Percent = "avg_hr_top20_percent"
        case hrZoneDistribution = "hr_zone_distribution"
        case paceZoneDistribution = "pace_zone_distribution"
        case rpe
    }
}

struct RealIntensityMinutes: Codable {
    let low: Double?
    let medium: Double?
    let high: Double?
}

struct RealZoneDistribution: Codable {
    let recovery: Double?
    let easy: Double?
    let marathon: Double?
    let threshold: Double?
    let interval: Double?
    let anaerobic: Double?
}

struct TimeSeries: Codable {
    let heartRatesBpm: [Int]?
    let cadencesSpm: [Int]?
    let speedsMPerS: [Double]?
    let altitudesM: [Double]?
    let timestampsS: [Int]?
    let distancesM: [Double]?
    let pacesSPerKm: [Double]?
    let temperaturesC: [Double]?
    let powersW: [Double]?
    let sampleRateHz: Double?
    let totalSamples: Int?
    
    enum CodingKeys: String, CodingKey {
        case heartRatesBpm = "heart_rates_bpm"
        case cadencesSpm = "cadences_spm"
        case speedsMPerS = "speeds_m_per_s"
        case altitudesM = "altitudes_m"
        case timestampsS = "timestamps_s"
        case distancesM = "distances_m"
        case pacesSPerKm = "paces_s_per_km"
        case temperaturesC = "temperatures_c"
        case powersW = "powers_w"
        case sampleRateHz = "sample_rate_hz"
        case totalSamples = "total_samples"
    }
}

struct DeviceInfo: Codable {
    let deviceName: String?
    let deviceModel: String?
    let deviceManufacturer: String?
    let firmwareVersion: String?
    let hasGps: Bool?
    let hasHeartRate: Bool?
    let hasAccelerometer: Bool?
    let hasBarometer: Bool?
    
    enum CodingKeys: String, CodingKey {
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case deviceManufacturer = "device_manufacturer"
        case firmwareVersion = "firmware_version"
        case hasGps = "has_gps"
        case hasHeartRate = "has_heart_rate"
        case hasAccelerometer = "has_accelerometer"
        case hasBarometer = "has_barometer"
    }
}

struct WorkoutRouteData: Codable {
    let totalPoints: Int?
    let latitudes: [Double]?
    let longitudes: [Double]?
    let altitudes: [Double]?
    let timestamps: [String]?
    let horizontalAccuracyM: Double?
    let verticalAccuracyM: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalPoints = "total_points"
        case latitudes, longitudes, altitudes, timestamps
        case horizontalAccuracyM = "horizontal_accuracy_m"
        case verticalAccuracyM = "vertical_accuracy_m"
    }
}

struct EnvironmentData: Codable {
    let temperatureC: Double?
    let windSpeedMPerS: Double?
    let windDirectionDeg: Double?
    let humidityPercent: Double?
    let timezone: String?
    let locationName: String?
    let weatherCondition: String?
    
    enum CodingKeys: String, CodingKey {
        case temperatureC = "temperature_c"
        case windSpeedMPerS = "wind_speed_m_per_s"
        case windDirectionDeg = "wind_direction_deg"
        case humidityPercent = "humidity_percent"
        case timezone
        case locationName = "location_name"
        case weatherCondition = "weather_condition"
    }
}

struct Metadata: Codable {
    let processedSampleCount: Int?
    let originalSampleCount: Int?
    let hasGpsData: Bool?
    let hasHeartRateData: Bool?
    let hasPowerData: Bool?
    let samplingMethod: String?
    let adapterVersion: String?
    let rawDataPath: String?
    let rawDataSizeBytes: Int?
    let processedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case processedSampleCount = "processed_sample_count"
        case originalSampleCount = "original_sample_count"
        case hasGpsData = "has_gps_data"
        case hasHeartRateData = "has_heart_rate_data"
        case hasPowerData = "has_power_data"
        case samplingMethod = "sampling_method"
        case adapterVersion = "adapter_version"
        case rawDataPath = "raw_data_path"
        case rawDataSizeBytes = "raw_data_size_bytes"
        case processedAt = "processed_at"
    }
}

class WorkoutDetailViewModelV2: ObservableObject, TaskManageable {
    @Published var workoutDetail: WorkoutV2Detail?
    @Published var isLoading = false
    @Published var error: String?
    
    // 圖表數據
    @Published var heartRates: [DataPoint] = []
    @Published var paces: [DataPoint] = []
    @Published var speeds: [DataPoint] = []
    @Published var altitudes: [DataPoint] = []
    @Published var cadences: [DataPoint] = []
    
    // 心率區間分佈
    @Published var hrZoneDistribution: [String: Double] = [:]
    @Published var paceZoneDistribution: [String: Double] = [:]
    
    // 圖表相關屬性
    @Published var yAxisRange: (min: Double, max: Double) = (60, 180)
    
    let workout: WorkoutV2
    private let workoutV2Service = WorkoutV2Service.shared
    private let cacheManager = WorkoutV2CacheManager.shared
    
    // TaskManageable 協議實作 (Actor-based)
    let taskRegistry = TaskRegistry()
    
    init(workout: WorkoutV2) {
        self.workout = workout
    }
    
    deinit {
        cancelAllTasks()
        // 確保所有異步任務都被取消
        heartRates.removeAll()
        paces.removeAll()
        speeds.removeAll()
        altitudes.removeAll()
        cadences.removeAll()
    }
    
    // MARK: - 重新上傳功能 (Apple Health Only)
    
    /// 重新上傳結果枚舉
    enum ReuploadResult {
        case success(hasHeartRate: Bool)
        case insufficientHeartRate(count: Int)
        case failure(message: String)
    }
    
    /// 重新上傳 Apple Health 的運動記錄（包含心率檢查）
    func reuploadWorkoutWithHeartRateCheck() async -> ReuploadResult {
        // 檢查是否為 Apple Health 資料來源
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return .failure(message: "只有 Apple Health 資料才能重新上傳")
        }
        
        print("🔄 開始重新上傳運動記錄（含心率檢查）- ID: \(workout.id)")
        
        // 首先檢查心率數據
        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()
        
        // 建立時間範圍查詢
        let startTime = workout.startDate.addingTimeInterval(-60)
        let endTime = workout.endDate.addingTimeInterval(60)
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume(returning: .failure(message: "ViewModel 已被釋放"))
                    return
                }
                
                if let error = error {
                    print("❌ 查詢 HealthKit 運動記錄失敗: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(message: "查詢 HealthKit 運動記錄失敗"))
                    return
                }
                
                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    print("❌ 找不到對應的 HealthKit 運動記錄")
                    continuation.resume(returning: .failure(message: "找不到對應的 HealthKit 運動記錄"))
                    return
                }
                
                // 找到最匹配的運動
                let targetDuration = TimeInterval(self.workout.durationSeconds)
                let targetDistance = self.workout.distanceMeters ?? 0
                
                let matchingWorkout = workouts.first { hkWorkout in
                    let durationDiff = abs(hkWorkout.duration - targetDuration)
                    let distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    let distanceDiff = abs(distance - targetDistance)
                    
                    return durationDiff <= 5 && distanceDiff <= 50
                } ?? workouts.first
                
                guard let hkWorkout = matchingWorkout else {
                    print("❌ 找不到匹配的 HealthKit 運動記錄")
                    continuation.resume(returning: .failure(message: "找不到匹配的運動記錄"))
                    return
                }
                
                // 檢查心率數據
                Task {
                    do {
                        let healthKitManager = HealthKitManager()
                        let heartRateData = try await healthKitManager.fetchHeartRateData(for: hkWorkout, forceRefresh: true, retryAttempt: 0)
                        
                        print("🔍 心率數據檢查: \(heartRateData.count) 筆")
                        
                        // 如果心率數據少於2點，詢問用戶是否繼續
                        if heartRateData.count < 2 {
                            print("⚠️ 心率數據不足: \(heartRateData.count) < 2 筆")
                            continuation.resume(returning: .insufficientHeartRate(count: heartRateData.count))
                            return
                        }
                        
                        // 心率數據足夠，繼續上傳
                        let uploadService = AppleHealthWorkoutUploadService.shared
                        let result = try await uploadService.uploadWorkout(
                            hkWorkout,
                            force: true,
                            retryHeartRate: true,
                            source: "apple_health"
                        )
                        
                        switch result {
                        case .success(let hasHeartRate):
                            print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                            
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .workoutsDidUpdate,
                                    object: nil,
                                    userInfo: ["reuploadedWorkoutId": self.workout.id]
                                )
                            }
                            
                            continuation.resume(returning: .success(hasHeartRate: hasHeartRate))
                            
                        case .failure(let error):
                            print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                            continuation.resume(returning: .failure(message: "重新上傳失敗: \(error.localizedDescription)"))
                        }
                        
                    } catch {
                        print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
                        continuation.resume(returning: .failure(message: "重新上傳過程發生錯誤: \(error.localizedDescription)"))
                    }
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 強制重新上傳（忽略心率檢查）
    func forceReuploadWorkout() async -> Bool {
        return await reuploadWorkout()
    }
    
    /// 重新上傳 Apple Health 的運動記錄
    func reuploadWorkout() async -> Bool {
        // 檢查是否為 Apple Health 資料來源
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return false
        }
        
        print("🔄 開始重新上傳運動記錄 - ID: \(workout.id)")
        
        // 使用運動的開始時間和持續時間來查找對應的 HealthKit 運動
        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()
        
        // 建立時間範圍查詢（前後各 1 分鐘的容錯）
        let startTime = workout.startDate.addingTimeInterval(-60)
        let endTime = workout.endDate.addingTimeInterval(60)
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                if let error = error {
                    print("❌ 查詢 HealthKit 運動記錄失敗: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    print("❌ 找不到對應的 HealthKit 運動記錄")
                    continuation.resume(returning: false)
                    return
                }
                
                // 找到最匹配的運動（根據持續時間和距離）
                let targetDuration = TimeInterval(self.workout.durationSeconds)
                let targetDistance = self.workout.distanceMeters ?? 0
                
                let matchingWorkout = workouts.first { hkWorkout in
                    let durationDiff = abs(hkWorkout.duration - targetDuration)
                    let distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    let distanceDiff = abs(distance - targetDistance)
                    
                    // 允許 5 秒的時間差和 50 米的距離差
                    return durationDiff <= 5 && distanceDiff <= 50
                } ?? workouts.first // 如果沒有完全匹配的，使用第一個
                
                guard let hkWorkout = matchingWorkout else {
                    print("❌ 找不到匹配的 HealthKit 運動記錄")
                    continuation.resume(returning: false)
                    return
                }
                
                print("✅ 找到匹配的 HealthKit 運動記錄: \(hkWorkout.uuid)")
                
                // 使用 AppleHealthWorkoutUploadService 重新上傳
                Task {
                    do {
                        let uploadService = AppleHealthWorkoutUploadService.shared
                        let result = try await uploadService.uploadWorkout(
                            hkWorkout,
                            force: true,           // 強制重新上傳
                            retryHeartRate: true,  // 重試獲取心率資料
                            source: "apple_health"
                        )
                        
                        // 檢查上傳結果
                        switch result {
                        case .success(let hasHeartRate):
                            print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                            
                            // 發送通知以更新 UI
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .workoutsDidUpdate,
                                    object: nil,
                                    userInfo: ["reuploadedWorkoutId": self.workout.id]
                                )
                            }
                            
                            continuation.resume(returning: true)
                            
                        case .failure(let error):
                            print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                            continuation.resume(returning: false)
                        }
                    } catch {
                        print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    }
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 時間序列數據處理
    
    /// 處理時間序列數據，轉換成圖表格式
    private func processTimeSeriesData(from detail: WorkoutV2Detail) {
        // 基於實際 API 回應格式處理時間序列數據
        if let timeSeriesData = detail.timeSeries {
            processTimeSeriesFromAPI(timeSeriesData)
        }
    }
    
    /// 處理來自 API 的時間序列數據
    private func processTimeSeriesFromAPI(_ timeSeries: V2TimeSeries) {
        let baseTime = workout.startDate
        
        // 處理心率數據
        if let heartRateData = timeSeries.heartRatesBpm,
           let timestamps = timeSeries.timestampsS {
            
            var heartRatePoints: [DataPoint] = []
            
            for (index, hr) in heartRateData.enumerated() {
                if index < timestamps.count,
                   let heartRate = hr,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    heartRatePoints.append(DataPoint(time: time, value: Double(heartRate)))
                }
            }
            
            // 數據降採樣以提升效能
            self.heartRates = downsampleData(heartRatePoints, maxPoints: 500)
        }
        
        // 處理配速數據，使用 paces_s_per_km 直接顯示配速
        if let pacesData = timeSeries.pacesSPerKm,
           let timestamps = timeSeries.timestampsS {
            
            var pacePoints: [DataPoint] = []
            
            for (index, pace) in pacesData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的配速值
                    if let paceValue = pace,
                       paceValue > 0 && paceValue < 3600, // 合理的配速範圍：0-60分鐘/公里
                       paceValue.isFinite { // 確保不是無窮大或NaN
                        pacePoints.append(DataPoint(time: time, value: paceValue))
                    }
                    // 如果配速是null或異常值，就直接跳過該數據點
                    // 這樣圖表會在該時間段出現斷點，正確顯示間歇訓練的休息段
                }
            }
            
            // 直接使用所有有效數據點，不進行降採樣
            self.paces = pacePoints
        }
    }
    
    /// 數據降採樣以提升圖表效能
    private func downsampleData(_ dataPoints: [DataPoint], maxPoints: Int) -> [DataPoint] {
        guard dataPoints.count > maxPoints else { return dataPoints }
        
        let step = dataPoints.count / maxPoints
        var sampledPoints: [DataPoint] = []
        
        for i in stride(from: 0, to: dataPoints.count, by: step) {
            sampledPoints.append(dataPoints[i])
        }
        
        // 確保包含最後一個點
        if let lastPoint = dataPoints.last, sampledPoints.last != lastPoint {
            sampledPoints.append(lastPoint)
        }
        
        return sampledPoints
    }
    
    // MARK: - 數據載入
    
    /// 載入運動詳細資料（只載入一次，不支援刷新）
    func loadWorkoutDetail() async {
        // 如果已經載入過，直接返回
        if workoutDetail != nil {
            return
        }
        
        await executeTask(id: "load_workout_detail") {
            await self.performLoadWorkoutDetail()
        }
    }
    
    /// 重新載入運動詳細資料（用於下拉刷新）
    func refreshWorkoutDetail() async {
        await executeTask(id: "refresh_workout_detail") {
            await self.performRefreshWorkoutDetail()
        }
    }
    
    /// 取消載入任務
    func cancelLoadingTasks() {
        cancelAllTasks()
    }
    
    @MainActor
    private func performRefreshWorkoutDetail() async {
        isLoading = true
        error = nil
        
        do {
            // 清除快取，強制重新從 API 獲取
            cacheManager.clearWorkoutDetailCache(workoutId: workout.id)
            
            // 檢查任務是否被取消
            try Task.checkCancellation()
            
            // 從 API 獲取詳細數據
            let response = try await workoutV2Service.fetchWorkoutDetail(workoutId: workout.id)
            
            // 檢查任務是否被取消
            try Task.checkCancellation()
            
            // 快取詳細數據
            cacheManager.cacheWorkoutDetail(workoutId: workout.id, detail: response)
            
            // 設置 workoutDetail
            self.workoutDetail = response
            
            // 清除舊的圖表數據
            self.heartRates.removeAll()
            self.paces.removeAll()
            self.speeds.removeAll()
            self.altitudes.removeAll()
            self.cadences.removeAll()
            
            // 處理時間序列數據，轉換成圖表格式
            self.processTimeSeriesData(from: response)
            
            // 設置心率 Y 軸範圍
            if !heartRates.isEmpty {
                let hrValues = heartRates.map { $0.value }
                let minHR = hrValues.min() ?? 60
                let maxHR = hrValues.max() ?? 180
                let margin = (maxHR - minHR) * 0.1
                self.yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
            }
            
            Logger.firebase(
                "運動詳情刷新成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "refresh_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )
            
            self.isLoading = false
            
        } catch is CancellationError {
            print("WorkoutDetailViewModelV2: 刷新任務被取消")
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
            
            Logger.firebase(
                "運動詳情刷新失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "refresh_detail"]
            )
        }
    }

    @MainActor
    private func performLoadWorkoutDetail() async {
        isLoading = true
        error = nil
        
        do {
            // 首先檢查快取（30 分鐘 TTL）
            if let cachedDetail = cacheManager.getCachedWorkoutDetail(workoutId: workout.id, maxAge: 30 * 60) {
                Logger.firebase(
                    "從快取載入運動詳情",
                    level: .info,
                    labels: ["module": "WorkoutDetailViewModelV2", "action": "load_cached"]
                )
                
                // 設置 workoutDetail 以便 UI 可以訪問設備信息等
                self.workoutDetail = cachedDetail
                
                // 處理快取的時間序列數據
                self.processTimeSeriesData(from: cachedDetail)
                
                // 設置心率 Y 軸範圍
                if !heartRates.isEmpty {
                    let hrValues = heartRates.map { $0.value }
                    let minHR = hrValues.min() ?? 60
                    let maxHR = hrValues.max() ?? 180
                    let margin = (maxHR - minHR) * 0.1
                    self.yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
                }
                
                self.isLoading = false
                return // 使用快取數據，不需要 API 呼叫
            }
            
            // 檢查任務是否被取消
            try Task.checkCancellation()
            
            // 從 API 獲取詳細數據
            let response = try await workoutV2Service.fetchWorkoutDetail(workoutId: workout.id)
            
            // 檢查任務是否被取消
            try Task.checkCancellation()
            
            // 快取詳細數據
            cacheManager.cacheWorkoutDetail(workoutId: workout.id, detail: response)
            
            // 設置 workoutDetail 以便 UI 可以訪問設備信息等
            self.workoutDetail = response
            
            // 處理時間序列數據，轉換成圖表格式
            self.processTimeSeriesData(from: response)
            
            // 設置心率 Y 軸範圍
            if !heartRates.isEmpty {
                let hrValues = heartRates.map { $0.value }
                let minHR = hrValues.min() ?? 60
                let maxHR = hrValues.max() ?? 180
                let margin = (maxHR - minHR) * 0.1
                self.yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
            }
            
            Logger.firebase(
                "運動詳情載入成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "load_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )
            
            self.isLoading = false
            
        } catch is CancellationError {
            print("WorkoutDetailViewModelV2: 載入任務被取消")
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
            
            Logger.firebase(
                "運動詳情載入失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "load_detail"]
            )
        }
    }
    
    // MARK: - 格式化方法
    
    var workoutType: String {
        workout.activityType
    }
    
    var duration: String {
        let duration = workout.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var distance: String? {
        guard let distance = workout.distance else { return nil }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    var calories: String? {
        guard let calories = workout.calories else { return nil }
        return String(format: "%.0f kcal", calories)
    }
    
    var pace: String? {
        guard let distance = workout.distance, distance > 0 else { return nil }
        
        let paceSecondsPerMeter = workout.duration / distance
        let paceInSecondsPerKm = paceSecondsPerMeter * 1000
        let paceMinutes = Int(paceInSecondsPerKm) / 60
        let paceRemainingSeconds = Int(paceInSecondsPerKm) % 60
        return String(format: "%d:%02d/km", paceMinutes, paceRemainingSeconds)
    }
    
    var averageHeartRate: String? {
        return workout.basicMetrics?.avgHeartRateBpm.map { "\($0) bpm" }
    }
    
    var maxHeartRate: String? {
        return workout.basicMetrics?.maxHeartRateBpm.map { "\($0) bpm" }
    }
    
    var dynamicVdot: String? {
        return workout.dynamicVdot.map { String(format: "%.1f", $0) }
    }
    
    var trainingType: String? {
        guard let type = workout.trainingType else { return nil }
        
        switch type.lowercased() {
        case "easy_run":
            return "輕鬆跑"
        case "recovery_run":
            return "恢復跑"
        case "long_run":
            return "長跑"
        case "tempo":
            return "節奏跑"
        case "threshold":
            return "閾值跑"
        case "interval":
            return "間歇跑"
        case "fartlek":
            return "法特萊克"
        case "hill_training":
            return "坡道訓練"
        case "race":
            return "比賽"
        case "rest":
            return "休息"
        default:
            return type
        }
    }
    
    // MARK: - 圖表相關屬性
    
    var maxHeartRateString: String {
        guard let max = heartRates.map({ $0.value }).max(), !heartRates.isEmpty else { return "--" }
        return "\(Int(max)) bpm"
    }
    
    var minHeartRateString: String {
        guard let min = heartRates.map({ $0.value }).min(), !heartRates.isEmpty else { return "--" }
        return "\(Int(min)) bpm"
    }
    
    var chartAverageHeartRate: Double? {
        guard !heartRates.isEmpty else { return nil }
        let sum = heartRates.reduce(0.0) { $0 + $1.value }
        return sum / Double(heartRates.count)
    }
} 
