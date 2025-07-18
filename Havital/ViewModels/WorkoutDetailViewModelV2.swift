import SwiftUI
import Combine

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
    @Published var workoutDetail: WorkoutDetailV2?
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
    
    // TaskManageable 協議實作
    var activeTasks: [String: Task<Void, Never>] = [:]
    
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
        
        // 直接使用 API 提供的配速數據
        if let speedsData = timeSeries.speedsMPerS,
           let timestamps = timeSeries.timestampsS {
            
            var pacePoints: [DataPoint] = []
            
            for (index, speed) in speedsData.enumerated() {
                if index < timestamps.count,
                   let speedValue = speed,
                   let timestamp = timestamps[index],
                   speedValue > 0.1 && speedValue < 15 { // 過濾異常值和 null 值
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    pacePoints.append(DataPoint(time: time, value: speedValue))
                }
            }
            
            // 數據降採樣以提升效能
            self.paces = downsampleData(pacePoints, maxPoints: 500)
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
    
    /// 取消載入任務
    func cancelLoadingTasks() {
        cancelAllTasks()
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
            cacheManager.cacheWorkoutDetail(workoutId: workout.id, detail: response.data)
            
            // 處理時間序列數據，轉換成圖表格式
            self.processTimeSeriesData(from: response.data)
            
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
                    "activity_type": response.data.activityType
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
