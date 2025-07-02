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
    let schemaVersion: String
    let sourceInfo: SourceInfo
    let activityProfile: ActivityProfile
    let summaryMetrics: SummaryMetrics
    let advancedMetrics: AdvancedMetrics?
    let timeSeriesStreams: TimeSeriesStreams?
    let routeData: RouteData?
    
    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion = "schema_version"
        case sourceInfo = "source_info"
        case activityProfile = "activity_profile"
        case summaryMetrics = "summary_metrics"
        case advancedMetrics = "advanced_metrics"
        case timeSeriesStreams = "time_series_streams"
        case routeData = "route_data"
    }
}

struct SourceInfo: Codable {
    let name: String
    let originalId: String?
    let importMethod: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case originalId = "original_id"
        case importMethod = "import_method"
    }
}

struct ActivityProfile: Codable {
    let type: String
    let startTimeUtc: String?
    let endTimeUtc: String?
    let durationTotalSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case type
        case startTimeUtc = "start_time_utc"
        case endTimeUtc = "end_time_utc"
        case durationTotalSeconds = "duration_total_seconds"
    }
}

struct SummaryMetrics: Codable {
    let distanceMeters: Double?
    let avgHeartRateBpm: Int?
    let maxHeartRateBpm: Int?
    let activeCaloriesKcal: Double?
    let avgPaceSPerKm: Int?
    
    enum CodingKeys: String, CodingKey {
        case distanceMeters = "distance_meters"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case maxHeartRateBpm = "max_heart_rate_bpm"
        case activeCaloriesKcal = "active_calories_kcal"
        case avgPaceSPerKm = "avg_pace_s_per_km"
    }
}

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

struct TimeSeriesStreams: Codable {
    let timestampsSecondsOffset: [Int]?
    let heartRateBpm: [Int]?
    let latitudeDeg: [Double]?
    let longitudeDeg: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case timestampsSecondsOffset = "timestamps_seconds_offset"
        case heartRateBpm = "heart_rate_bpm"
        case latitudeDeg = "latitude_deg"
        case longitudeDeg = "longitude_deg"
    }
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
        guard let endTimeUtc = activityProfile.startTimeUtc else { return nil }
        return ISO8601DateFormatter().date(from: endTimeUtc)
    }
    
    var endDate: Date? {
        guard let endTimeUtc = activityProfile.endTimeUtc else { return nil }
        return ISO8601DateFormatter().date(from: endTimeUtc)
    }
    
    var duration: TimeInterval {
        TimeInterval(activityProfile.durationTotalSeconds)
    }
    
    var distance: Double? {
        summaryMetrics.distanceMeters
    }
}

extension WorkoutV2 {
    var startDate: Date? {
        guard let startTimeUtc = startTimeUtc else { return nil }
        return ISO8601DateFormatter().date(from: startTimeUtc)
    }
    
    var endDate: Date? {
        guard let endTimeUtc = endTimeUtc else { return nil }
        return ISO8601DateFormatter().date(from: endTimeUtc)
    }
    
    var duration: TimeInterval {
        TimeInterval(durationSeconds)
    }
    
    var distance: Double? {
        return distanceMeters
    }
} 

