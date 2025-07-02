import Foundation

// MARK: - Workout List API Models

struct WorkoutListResponse: Codable {
    let data: WorkoutListData
}

struct WorkoutListData: Codable {
    let workouts: [WorkoutV2]
    let pagination: PaginationInfo
}

struct WorkoutV2: Codable, Identifiable {
    let id: String
    let provider: String
    let activityType: String
    let startTimeUtc: String?
    let endTimeUtc: String?
    let durationSeconds: Int
    let distanceMeters: Double?
    let basicMetrics: BasicMetrics?
    let advancedMetrics: AdvancedMetrics?
    let createdAt: String?
    let schemaVersion: String?
    let storagePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, provider
        case activityType = "activity_type"
        case startTimeUtc = "start_time_utc"
        case endTimeUtc = "end_time_utc"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case basicMetrics = "basic_metrics"
        case advancedMetrics = "advanced_metrics"
        case createdAt = "created_at"
        case schemaVersion = "schema_version"
        case storagePath = "storage_path"
    }
    
    // MARK: - Convenience Properties
    
    var startDate: Date {
        if let startTimeUtc = startTimeUtc {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: startTimeUtc) ?? Date()
        }
        return Date()
    }
    
    var endDate: Date {
        if let endTimeUtc = endTimeUtc {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: endTimeUtc) ?? Date()
        }
        return startDate.addingTimeInterval(TimeInterval(durationSeconds))
    }
    
    var duration: TimeInterval {
        return TimeInterval(durationSeconds)
    }
    
    var distance: Double? {
        return distanceMeters
    }
    
    var calories: Double? {
        return basicMetrics?.caloriesKcal.map { Double($0) }
    }
    
    // MARK: - Advanced Properties
    
    var dynamicVdot: Double? {
        return advancedMetrics?.dynamicVdot
    }
    
    var trainingType: String? {
        return advancedMetrics?.trainingType
    }
}

struct BasicMetrics: Codable {
    let avgHeartRateBpm: Int?
    let maxHeartRateBpm: Int?
    let minHeartRateBpm: Int?
    let avgPaceSPerKm: Double?
    let avgSpeedMPerS: Double?
    let maxSpeedMPerS: Double?
    let avgCadenceSpm: Int?
    let avgStrideLengthM: Double?
    let caloriesKcal: Int?
    let totalDistanceM: Double?
    let totalDurationS: Int?
    let movingDurationS: Int?
    let totalAscentM: Double?
    let totalDescentM: Double?
    let avgAltitudeM: Double?
    let avgPowerW: Double?
    let maxPowerW: Double?
    let normalizedPowerW: Double?
    let trainingLoad: Double?
    
    enum CodingKeys: String, CodingKey {
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case maxHeartRateBpm = "max_heart_rate_bpm"
        case minHeartRateBpm = "min_heart_rate_bpm"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case avgSpeedMPerS = "avg_speed_m_per_s"
        case maxSpeedMPerS = "max_speed_m_per_s"
        case avgCadenceSpm = "avg_cadence_spm"
        case avgStrideLengthM = "avg_stride_length_m"
        case caloriesKcal = "calories_kcal"
        case totalDistanceM = "total_distance_m"
        case totalDurationS = "total_duration_s"
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

struct PaginationInfo: Codable {
    let nextCursor: String?
    let hasMore: Bool
    let totalEstimated: Int
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case totalEstimated = "total_estimated"
        case pageSize = "page_size"
    }
}

// MARK: - Workout Detail API Models

struct WorkoutDetailResponse: Codable {
    let data: WorkoutV2Detail
}

struct WorkoutV2Detail: Codable {
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
    let basicMetrics: V2BasicMetrics?
    let advancedMetrics: V2AdvancedMetrics?
    let timeSeries: V2TimeSeries?
    let routeData: V2RouteData?
    let deviceInfo: V2DeviceInfo?
    let environment: V2Environment?
    let metadata: V2Metadata?
    
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
        case routeData = "route_data"
        case deviceInfo = "device_info"
        case environment = "environment"
        case metadata = "metadata"
    }
}

// MARK: - V2 API Detail Models

struct V2BasicMetrics: Codable {
    let maxSpeedMPerS: Double?
    let avgCadenceSpm: Int?
    let minHeartRateBpm: Int?
    let normalizedPowerW: Double?
    let totalDescentM: Double?
    let trainingLoad: Double?
    let caloriesKcal: Int?
    let totalAscentM: Double?
    let maxPowerW: Double?
    let avgHeartRateBpm: Int?
    let avgAltitudeM: Double?
    let avgPaceSPerKm: Double?
    let movingDurationS: Int?
    let avgPowerW: Double?
    let avgSpeedMPerS: Double?
    let maxHeartRateBpm: Int?
    let totalDistanceM: Double?
    let totalDurationS: Int?
    let avgStrideLengthM: Double?
    
    enum CodingKeys: String, CodingKey {
        case maxSpeedMPerS = "max_speed_m_per_s"
        case avgCadenceSpm = "avg_cadence_spm"
        case minHeartRateBpm = "min_heart_rate_bpm"
        case normalizedPowerW = "normalized_power_w"
        case totalDescentM = "total_descent_m"
        case trainingLoad = "training_load"
        case caloriesKcal = "calories_kcal"
        case totalAscentM = "total_ascent_m"
        case maxPowerW = "max_power_w"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case avgAltitudeM = "avg_altitude_m"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case movingDurationS = "moving_duration_s"
        case avgPowerW = "avg_power_w"
        case avgSpeedMPerS = "avg_speed_m_per_s"
        case maxHeartRateBpm = "max_heart_rate_bpm"
        case totalDistanceM = "total_distance_m"
        case totalDurationS = "total_duration_s"
        case avgStrideLengthM = "avg_stride_length_m"
    }
}

struct V2AdvancedMetrics: Codable {
    let rpe: Double?
    let intensityMinutes: V2IntensityMinutes?
    let avgHrTop20Percent: Double?
    let tss: Double?
    let hrZoneDistribution: V2ZoneDistribution?
    let trainingType: String?
    let intervalCount: Int?
    let paceZoneDistribution: V2ZoneDistribution?
    let dynamicVdot: Double?
    
    enum CodingKeys: String, CodingKey {
        case rpe
        case intensityMinutes = "intensity_minutes"
        case avgHrTop20Percent = "avg_hr_top20_percent"
        case tss
        case hrZoneDistribution = "hr_zone_distribution"
        case trainingType = "training_type"
        case intervalCount = "interval_count"
        case paceZoneDistribution = "pace_zone_distribution"
        case dynamicVdot = "dynamic_vdot"
    }
}

struct V2IntensityMinutes: Codable {
    let high: Double?
    let low: Double?
    let medium: Double?
}

struct V2ZoneDistribution: Codable {
    let marathon: Double?
    let interval: Double?
    let recovery: Double?
    let threshold: Double?
    let anaerobic: Double?
    let easy: Double?
}

struct V2TimeSeries: Codable {
    let cadencesSpm: [Int?]?
    let speedsMPerS: [Double?]?
    let altitudesM: [Double?]?
    let heartRatesBpm: [Int?]?
    let sampleRateHz: Double?
    let totalSamples: Int?
    let temperaturesC: [Double?]?
    let timestampsS: [Int?]?
    let distancesM: [Double?]?
    let powersW: [Double?]?
    let pacesSPerKm: [Double?]?
    
    enum CodingKeys: String, CodingKey {
        case cadencesSpm = "cadences_spm"
        case speedsMPerS = "speeds_m_per_s"
        case altitudesM = "altitudes_m"
        case heartRatesBpm = "heart_rates_bpm"
        case sampleRateHz = "sample_rate_hz"
        case totalSamples = "total_samples"
        case temperaturesC = "temperatures_c"
        case timestampsS = "timestamps_s"
        case distancesM = "distances_m"
        case powersW = "powers_w"
        case pacesSPerKm = "paces_s_per_km"
    }
}

struct V2RouteData: Codable {
    let horizontalAccuracyM: Double?
    let totalPoints: Int?
    let timestamps: [String?]?
    let verticalAccuracyM: Double?
    let longitudes: [Double?]?
    let altitudes: [Double?]?
    let latitudes: [Double?]?
    
    enum CodingKeys: String, CodingKey {
        case horizontalAccuracyM = "horizontal_accuracy_m"
        case totalPoints = "total_points"
        case timestamps
        case verticalAccuracyM = "vertical_accuracy_m"
        case longitudes
        case altitudes
        case latitudes
    }
}

struct V2DeviceInfo: Codable {
    let firmwareVersion: String?
    let hasBarometer: Bool?
    let deviceName: String?
    let hasGps: Bool?
    let hasAccelerometer: Bool?
    let hasHeartRate: Bool?
    let deviceModel: String?
    let deviceManufacturer: String?
    
    enum CodingKeys: String, CodingKey {
        case firmwareVersion = "firmware_version"
        case hasBarometer = "has_barometer"
        case deviceName = "device_name"
        case hasGps = "has_gps"
        case hasAccelerometer = "has_accelerometer"
        case hasHeartRate = "has_heart_rate"
        case deviceModel = "device_model"
        case deviceManufacturer = "device_manufacturer"
    }
}

struct V2Environment: Codable {
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

struct V2Metadata: Codable {
    let processedSampleCount: Int?
    let hasPowerData: Bool?
    let hasGpsData: Bool?
    let samplingMethod: String?
    let adapterVersion: String?
    let originalSampleCount: Int?
    let rawDataPath: String?
    let hasHeartRateData: Bool?
    let rawDataSizeBytes: Int?
    let processedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case processedSampleCount = "processed_sample_count"
        case hasPowerData = "has_power_data"
        case hasGpsData = "has_gps_data"
        case samplingMethod = "sampling_method"
        case adapterVersion = "adapter_version"
        case originalSampleCount = "original_sample_count"
        case rawDataPath = "raw_data_path"
        case hasHeartRateData = "has_heart_rate_data"
        case rawDataSizeBytes = "raw_data_size_bytes"
        case processedAt = "processed_at"
    }
}

// MARK: - Legacy V1 API Models (Keep for backwards compatibility)

struct AdvancedMetrics: Codable {
    let dynamicVdot: Double?
    let tss: Double?
    let trainingType: String?
    let intensityMinutes: APIIntensityMinutes?
    let intervalCount: Int?
    let avgHrTop20Percent: Double?
    let hrZoneDistribution: ZoneDistribution?
    let paceZoneDistribution: ZoneDistribution?
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

struct ZoneDistribution: Codable {
    let marathon: Double?
    let threshold: Double?
    let recovery: Double?
    let interval: Double?
    let anaerobic: Double?
    let easy: Double?
}

struct APIIntensityMinutes: Codable {
    let low: Double?
    let medium: Double?
    let high: Double?
}

struct RouteData: Codable {
    let totalPoints: Int
    let coordinates: [Coordinate]?
    
    enum CodingKeys: String, CodingKey {
        case totalPoints = "total_points"
        case coordinates
    }
}

struct Coordinate: Codable {
    let lat: Double
    let lng: Double
    let timestamp: String
}

// MARK: - Upload Workout Request Models

struct UploadWorkoutRequest: Codable {
    let sourceInfo: UploadSourceInfo
    let activityProfile: UploadActivityProfile
    let summaryMetrics: UploadSummaryMetrics?
    let timeSeriesStreams: UploadTimeSeriesStreams?
    
    enum CodingKeys: String, CodingKey {
        case sourceInfo = "source_info"
        case activityProfile = "activity_profile"
        case summaryMetrics = "summary_metrics"
        case timeSeriesStreams = "time_series_streams"
    }
}



struct UploadSourceInfo: Codable {
    let name: String
    let importMethod: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case importMethod = "import_method"
    }
}

struct UploadActivityProfile: Codable {
    let type: String
    let startTimeUtc: String?
    let endTimeUtc: String
    let durationTotalSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case startTimeUtc = "start_time_utc"
        case endTimeUtc = "end_time_utc"
        case durationTotalSeconds = "duration_total_seconds"
    }
}

struct UploadSummaryMetrics: Codable {
    let distanceMeters: Double?
    let activeCaloriesKcal: Double?
    let avgHeartRateBpm: Int?
    let maxHeartRateBpm: Int?
    
    enum CodingKeys: String, CodingKey {
        case distanceMeters = "distance_meters"
        case activeCaloriesKcal = "active_calories_kcal"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case maxHeartRateBpm = "max_heart_rate_bpm"
    }
}

struct UploadTimeSeriesStreams: Codable {
    let timestampsSecondsOffset: [Int]
    let heartRateBpm: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case timestampsSecondsOffset = "timestamps_seconds_offset"
        case heartRateBpm = "heart_rate_bpm"
    }
}

// MARK: - Upload Response Models

struct UploadWorkoutResponse: Codable {
    let id: String
    let schemaVersion: String
    let provider: String
    let createdAt: String
    let basicMetrics: UploadBasicMetrics?
    let advancedMetrics: UploadAdvancedMetrics?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case provider
        case createdAt = "created_at"
        case basicMetrics = "basic_metrics"
        case advancedMetrics = "advanced_metrics"
        case message
    }
}



struct UploadBasicMetrics: Codable {
    let totalDurationS: Int
    let totalDistanceM: Double?
    let avgHeartRateBpm: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalDurationS = "total_duration_s"
        case totalDistanceM = "total_distance_m"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
    }
}

struct UploadAdvancedMetrics: Codable {
    let dynamicVdot: Double?
    let tss: Double?
    
    enum CodingKeys: String, CodingKey {
        case dynamicVdot = "dynamic_vdot"
        case tss
    }
}

// MARK: - Stats API Models

struct WorkoutStatsResponse: Codable {
    let data: WorkoutStatsData
}

struct WorkoutStatsData: Codable {
    let totalWorkouts: Int
    let totalDistanceKm: Double
    let avgPacePerKm: String?
    let providerDistribution: [String: Int]
    let activityTypeDistribution: [String: Int]
    let periodDays: Int
    
    enum CodingKeys: String, CodingKey {
        case totalWorkouts = "total_workouts"
        case totalDistanceKm = "total_distance_km"
        case avgPacePerKm = "avg_pace_per_km"
        case providerDistribution = "provider_distribution"
        case activityTypeDistribution = "activity_type_distribution"
        case periodDays = "period_days"
    }
}

// MARK: - Connection Status Models

struct ConnectionStatusResponse: Codable {
    let data: ConnectionStatusData
}

struct ConnectionStatusData: Codable {
    let connections: [ConnectionInfo]
}

struct ConnectionInfo: Codable {
    let platform: String
    let status: String
    let lastSync: String?
    let syncStatus: String
    
    enum CodingKeys: String, CodingKey {
        case platform, status
        case lastSync = "last_sync"
        case syncStatus = "sync_status"
    }
}

// MARK: - Helper Extensions

extension WorkoutV2Detail {
    var startDate: Date? {
        return ISO8601DateFormatter().date(from: startTime)
    }
    
    var endDate: Date? {
        return ISO8601DateFormatter().date(from: endTime)
    }
    
    var duration: TimeInterval {
        guard let basicMetrics = basicMetrics,
              let totalDurationS = basicMetrics.totalDurationS else {
            // 計算基於開始和結束時間的持續時間
            if let start = startDate, let end = endDate {
                return end.timeIntervalSince(start)
            }
            return 0
        }
        return TimeInterval(totalDurationS)
    }
    
    var distance: Double? {
        return basicMetrics?.totalDistanceM
    }
    
    var averageHeartRate: Int? {
        return basicMetrics?.avgHeartRateBpm
    }
    
    var maxHeartRate: Int? {
        return basicMetrics?.maxHeartRateBpm
    }
    
    var calories: Int? {
        return basicMetrics?.caloriesKcal
    }
    
    var dynamicVdot: Double? {
        return advancedMetrics?.dynamicVdot
    }
    
    var trainingType: String? {
        return advancedMetrics?.trainingType
    }
}



