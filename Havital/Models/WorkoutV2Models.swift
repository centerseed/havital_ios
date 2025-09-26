import Foundation

// MARK: - Workout List API Models

struct WorkoutListResponse: Codable {
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
    let deviceName: String?
    let basicMetrics: BasicMetrics?
    let advancedMetrics: AdvancedMetrics?
    let createdAt: String?
    let schemaVersion: String?
    let storagePath: String?
    let dailyPlanSummary: DailyPlanSummary?
    let aiSummary: AISummary?
    
    enum CodingKeys: String, CodingKey {
        case id, provider
        case activityType = "activity_type"
        case startTimeUtc = "start_time_utc"
        case endTimeUtc = "end_time_utc"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case deviceName = "device_name"
        case basicMetrics = "basic_metrics"
        case advancedMetrics = "advanced_metrics"
        case createdAt = "created_at"
        case schemaVersion = "schema_version"
        case storagePath = "storage_path"
        case dailyPlanSummary = "daily_plan_summary"
        case aiSummary = "ai_summary"
    }
    
    // MARK: - Convenience Properties
    
    var startDate: Date {
        guard let startTimeUtc = startTimeUtc else {
            print("⚠️ [WorkoutV2] start_time_utc 為空，使用當前時間")
            return Date()
        }
        
        // 先嘗試標準 ISO8601DateFormatter（支持微秒）
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: startTimeUtc) {
            return date
        }
        
        // 如果失敗，嘗試不包含微秒的格式
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: startTimeUtc) {
            return date
        }
        
        // 嘗試 RFC 2822 格式 (例如: Fri, 01 Aug 2025 07:30:01 GMT)
        let rfc2822Formatter = DateFormatter()
        rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")
        rfc2822Formatter.timeZone = TimeZone(secondsFromGMT: 0)
        rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        
        if let date = rfc2822Formatter.date(from: startTimeUtc) {
            return date
        }
        
        // 最後嘗試自定義格式
        let customFormatter = DateFormatter()
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        
        if let date = customFormatter.date(from: startTimeUtc) {
            return date
        }
        
        print("⚠️ [WorkoutV2] 無法解析開始時間: '\(startTimeUtc)'，使用當前時間")
        return Date()
    }
    
    var endDate: Date {
        guard let endTimeUtc = endTimeUtc else {
            return startDate.addingTimeInterval(TimeInterval(durationSeconds))
        }
        
        // 使用與 startDate 相同的解析邏輯
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: endTimeUtc) {
            return date
        }
        
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: endTimeUtc) {
            return date
        }
        
        // 嘗試 RFC 2822 格式 (例如: Fri, 01 Aug 2025 07:30:01 GMT)
        let rfc2822Formatter = DateFormatter()
        rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")
        rfc2822Formatter.timeZone = TimeZone(secondsFromGMT: 0)
        rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        
        if let date = rfc2822Formatter.date(from: endTimeUtc) {
            return date
        }
        
        let customFormatter = DateFormatter()
        customFormatter.locale = Locale(identifier: "en_US_POSIX")
        customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        
        if let date = customFormatter.date(from: endTimeUtc) {
            return date
        }
        
        print("⚠️ [WorkoutV2] 無法解析結束時間: '\(endTimeUtc)'，使用計算時間")
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

// MARK: - Safe Number Wrapper Structs
// These wrapper structs provide compatibility with the existing codebase that expects a .value property
// They internally use the same parsing logic as SafeNumber

struct SafeDouble: Codable {
    private var _internal: Double?
    
    var value: Double? {
        return _internal
    }
    
    init(value: Double?) {
        self._internal = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            _internal = nil
            return
        }
        
        // Try to decode as Double first
        if let doubleValue = try? container.decode(Double.self) {
            _internal = doubleValue
            return
        }
        
        // Try to decode as String and convert
        if let stringValue = try? container.decode(String.self),
           let doubleValue = Double(stringValue) {
            _internal = doubleValue
            return
        }
        
        // Try to decode as Int and convert
        if let intValue = try? container.decode(Int.self) {
            _internal = Double(intValue)
            return
        }
        
        // Try to decode as Decimal and convert
        if let decimalValue = try? container.decode(Decimal.self) {
            _internal = NSDecimalNumber(decimal: decimalValue).doubleValue
            return
        }
        
        _internal = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_internal)
    }
}

struct SafeInt: Codable {
    private var _internal: Int?
    
    var value: Int? {
        return _internal
    }
    
    init(value: Int?) {
        self._internal = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            _internal = nil
            return
        }
        
        // Try to decode as Int first
        if let intValue = try? container.decode(Int.self) {
            _internal = intValue
            return
        }
        
        // Try to decode as Double and convert
        if let doubleValue = try? container.decode(Double.self) {
            _internal = Int(doubleValue)
            return
        }
        
        // Try to decode as String and convert
        if let stringValue = try? container.decode(String.self),
           let intValue = Int(stringValue) {
            _internal = intValue
            return
        }
        
        _internal = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_internal)
    }
}

struct BasicMetrics: Codable {
    private let _avgHeartRateBpm: SafeInt?
    private let _maxHeartRateBpm: SafeInt?
    private let _minHeartRateBpm: SafeDouble?
    private let _avgPaceSPerKm: SafeDouble?
    private let _avgSpeedMPerS: SafeDouble?
    private let _maxSpeedMPerS: SafeDouble?
    private let _avgCadenceSpm: SafeInt?
    private let _avgStrideLengthM: SafeDouble?
    private let _caloriesKcal: SafeDouble?
    private let _totalDistanceM: SafeDouble?
    private let _totalDurationS: SafeInt?
    private let _movingDurationS: SafeInt?
    private let _totalAscentM: SafeDouble?
    private let _totalDescentM: SafeDouble?
    private let _avgAltitudeM: SafeDouble?
    private let _avgPowerW: SafeDouble?
    private let _maxPowerW: SafeDouble?
    private let _normalizedPowerW: SafeDouble?
    private let _trainingLoad: SafeDouble?
    
    // 公開的計算屬性
    var avgHeartRateBpm: Int? { _avgHeartRateBpm?.value }
    var maxHeartRateBpm: Int? { _maxHeartRateBpm?.value }
    var minHeartRateBpm: Int? { Int(_minHeartRateBpm?.value ?? 0) }
    var avgPaceSPerKm: Double? { _avgPaceSPerKm?.value }
    var avgSpeedMPerS: Double? { _avgSpeedMPerS?.value }
    var maxSpeedMPerS: Double? { _maxSpeedMPerS?.value }
    var avgCadenceSpm: Int? { _avgCadenceSpm?.value }
    var avgStrideLengthM: Double? { _avgStrideLengthM?.value }
    var caloriesKcal: Int? { Int(_caloriesKcal?.value ?? 0) }
    var totalDistanceM: Double? { _totalDistanceM?.value }
    var totalDurationS: Int? { _totalDurationS?.value }
    var movingDurationS: Int? { _movingDurationS?.value }
    var totalAscentM: Double? { _totalAscentM?.value }
    var totalDescentM: Double? { _totalDescentM?.value }
    var avgAltitudeM: Double? { _avgAltitudeM?.value }
    var avgPowerW: Double? { _avgPowerW?.value }
    var maxPowerW: Double? { _maxPowerW?.value }
    var normalizedPowerW: Double? { _normalizedPowerW?.value }
    var trainingLoad: Double? { _trainingLoad?.value }
    
    enum CodingKeys: String, CodingKey {
        case _avgHeartRateBpm = "avg_heart_rate_bpm"
        case _maxHeartRateBpm = "max_heart_rate_bpm"
        case _minHeartRateBpm = "min_heart_rate_bpm"
        case _avgPaceSPerKm = "avg_pace_s_per_km"
        case _avgSpeedMPerS = "avg_speed_m_per_s"
        case _maxSpeedMPerS = "max_speed_m_per_s"
        case _avgCadenceSpm = "avg_cadence_spm"
        case _avgStrideLengthM = "avg_stride_length_m"
        case _caloriesKcal = "calories_kcal"
        case _totalDistanceM = "total_distance_m"
        case _totalDurationS = "total_duration_s"
        case _movingDurationS = "moving_duration_s"
        case _totalAscentM = "total_ascent_m"
        case _totalDescentM = "total_descent_m"
        case _avgAltitudeM = "avg_altitude_m"
        case _avgPowerW = "avg_power_w"
        case _maxPowerW = "max_power_w"
        case _normalizedPowerW = "normalized_power_w"
        case _trainingLoad = "training_load"
    }
    
    // 便利初始化方法，用於測試和手動創建
    init(avgHeartRateBpm: Int? = nil,
         maxHeartRateBpm: Int? = nil,
         minHeartRateBpm: Double? = nil,
         avgPaceSPerKm: Double? = nil,
         avgSpeedMPerS: Double? = nil,
         maxSpeedMPerS: Double? = nil,
         avgCadenceSpm: Int? = nil,
         avgStrideLengthM: Double? = nil,
         caloriesKcal: Double? = nil,
         totalDistanceM: Double? = nil,
         totalDurationS: Int? = nil,
         movingDurationS: Int? = nil,
         totalAscentM: Double? = nil,
         totalDescentM: Double? = nil,
         avgAltitudeM: Double? = nil,
         avgPowerW: Double? = nil,
         maxPowerW: Double? = nil,
         normalizedPowerW: Double? = nil,
         trainingLoad: Double? = nil) {
        
        self._avgHeartRateBpm = avgHeartRateBpm.map { SafeInt(value: $0) }
        self._maxHeartRateBpm = maxHeartRateBpm.map { SafeInt(value: $0) }
        self._minHeartRateBpm = minHeartRateBpm.map { SafeDouble(value: $0) }
        self._avgPaceSPerKm = avgPaceSPerKm.map { SafeDouble(value: $0) }
        self._avgSpeedMPerS = avgSpeedMPerS.map { SafeDouble(value: $0) }
        self._maxSpeedMPerS = maxSpeedMPerS.map { SafeDouble(value: $0) }
        self._avgCadenceSpm = avgCadenceSpm.map { SafeInt(value: $0) }
        self._avgStrideLengthM = avgStrideLengthM.map { SafeDouble(value: $0) }
        self._caloriesKcal = caloriesKcal.map { SafeDouble(value: $0) }
        self._totalDistanceM = totalDistanceM.map { SafeDouble(value: $0) }
        self._totalDurationS = totalDurationS.map { SafeInt(value: $0) }
        self._movingDurationS = movingDurationS.map { SafeInt(value: $0) }
        self._totalAscentM = totalAscentM.map { SafeDouble(value: $0) }
        self._totalDescentM = totalDescentM.map { SafeDouble(value: $0) }
        self._avgAltitudeM = avgAltitudeM.map { SafeDouble(value: $0) }
        self._avgPowerW = avgPowerW.map { SafeDouble(value: $0) }
        self._maxPowerW = maxPowerW.map { SafeDouble(value: $0) }
        self._normalizedPowerW = normalizedPowerW.map { SafeDouble(value: $0) }
        self._trainingLoad = trainingLoad.map { SafeDouble(value: $0) }
    }
}

struct PaginationInfo: Codable {
    let nextCursor: String?
    let prevCursor: String?
    let hasMore: Bool
    let hasNewer: Bool
    let oldestId: String?
    let newestId: String?
    let totalItems: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case prevCursor = "prev_cursor"
        case hasMore = "has_more"
        case hasNewer = "has_newer"
        case oldestId = "oldest_id"
        case newestId = "newest_id"
        case totalItems = "total_items"
        case pageSize = "page_size"
    }
    
    // 向後相容性：如果 API 仍返回舊欄位名稱
    var totalEstimated: Int {
        return totalItems ?? 0
    }
}

// MARK: - Workout Detail API Models

typealias WorkoutDetailResponse = WorkoutV2Detail

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
    let laps: [LapData]?
    let dailyPlanSummary: DailyPlanSummary?
    let aiSummary: AISummary?
    
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
        case laps = "laps"
        case dailyPlanSummary = "daily_plan_summary"
        case aiSummary = "ai_summary"
    }
}

// MARK: - V2 API Detail Models

struct V2BasicMetrics: Codable {
    private let _maxSpeedMPerS: SafeDouble?
    private let _avgCadenceSpm: SafeInt?
    private let _minHeartRateBpm: SafeInt?
    private let _normalizedPowerW: SafeDouble?
    private let _totalDescentM: SafeDouble?
    private let _trainingLoad: SafeDouble?
    private let _caloriesKcal: SafeInt?
    private let _totalAscentM: SafeDouble?
    private let _maxPowerW: SafeDouble?
    private let _avgHeartRateBpm: SafeInt?
    private let _avgAltitudeM: SafeDouble?
    private let _avgPaceSPerKm: SafeDouble?
    private let _movingDurationS: SafeInt?
    private let _avgPowerW: SafeDouble?
    private let _avgSpeedMPerS: SafeDouble?
    private let _maxHeartRateBpm: SafeInt?
    private let _totalDistanceM: SafeDouble?
    private let _totalDurationS: SafeInt?
    private let _avgStrideLengthM: SafeDouble?
    
    // 公開的計算屬性
    var maxSpeedMPerS: Double? { _maxSpeedMPerS?.value }
    var avgCadenceSpm: Int? { _avgCadenceSpm?.value }
    var minHeartRateBpm: Int? { _minHeartRateBpm?.value }
    var normalizedPowerW: Double? { _normalizedPowerW?.value }
    var totalDescentM: Double? { _totalDescentM?.value }
    var trainingLoad: Double? { _trainingLoad?.value }
    var caloriesKcal: Int? { _caloriesKcal?.value }
    var totalAscentM: Double? { _totalAscentM?.value }
    var maxPowerW: Double? { _maxPowerW?.value }
    var avgHeartRateBpm: Int? { _avgHeartRateBpm?.value }
    var avgAltitudeM: Double? { _avgAltitudeM?.value }
    var avgPaceSPerKm: Double? { _avgPaceSPerKm?.value }
    var movingDurationS: Int? { _movingDurationS?.value }
    var avgPowerW: Double? { _avgPowerW?.value }
    var avgSpeedMPerS: Double? { _avgSpeedMPerS?.value }
    var maxHeartRateBpm: Int? { _maxHeartRateBpm?.value }
    var totalDistanceM: Double? { _totalDistanceM?.value }
    var totalDurationS: Int? { _totalDurationS?.value }
    var avgStrideLengthM: Double? { _avgStrideLengthM?.value }
    
    enum CodingKeys: String, CodingKey {
        case _maxSpeedMPerS = "max_speed_m_per_s"
        case _avgCadenceSpm = "avg_cadence_spm"
        case _minHeartRateBpm = "min_heart_rate_bpm"
        case _normalizedPowerW = "normalized_power_w"
        case _totalDescentM = "total_descent_m"
        case _trainingLoad = "training_load"
        case _caloriesKcal = "calories_kcal"
        case _totalAscentM = "total_ascent_m"
        case _maxPowerW = "max_power_w"
        case _avgHeartRateBpm = "avg_heart_rate_bpm"
        case _avgAltitudeM = "avg_altitude_m"
        case _avgPaceSPerKm = "avg_pace_s_per_km"
        case _movingDurationS = "moving_duration_s"
        case _avgPowerW = "avg_power_w"
        case _avgSpeedMPerS = "avg_speed_m_per_s"
        case _maxHeartRateBpm = "max_heart_rate_bpm"
        case _totalDistanceM = "total_distance_m"
        case _totalDurationS = "total_duration_s"
        case _avgStrideLengthM = "avg_stride_length_m"
    }
}

struct V2AdvancedMetrics: Codable {
    private let _rpe: SafeDouble?
    let intensityMinutes: V2IntensityMinutes?
    private let _avgHrTop20Percent: SafeDouble?
    private let _tss: SafeDouble?
    let hrZoneDistribution: V2ZoneDistribution?
    let trainingType: String?
    private let _intervalCount: SafeInt?
    let paceZoneDistribution: V2ZoneDistribution?
    private let _dynamicVdot: SafeDouble?
    private let _avgStanceTimeMs: SafeDouble?
    private let _avgVerticalRatioPercent: SafeDouble?
    
    // 公開的計算屬性
    var rpe: Double? { _rpe?.value }
    var avgHrTop20Percent: Double? { _avgHrTop20Percent?.value }
    var tss: Double? { _tss?.value }
    var intervalCount: Int? { _intervalCount?.value }
    var dynamicVdot: Double? { _dynamicVdot?.value }
    var avgStanceTimeMs: Double? { _avgStanceTimeMs?.value }
    var avgVerticalRatioPercent: Double? { _avgVerticalRatioPercent?.value }
    
    enum CodingKeys: String, CodingKey {
        case _rpe = "rpe"
        case intensityMinutes = "intensity_minutes"
        case _avgHrTop20Percent = "avg_hr_top20_percent"
        case _tss = "tss"
        case hrZoneDistribution = "hr_zone_distribution"
        case trainingType = "training_type"
        case _intervalCount = "interval_count"
        case paceZoneDistribution = "pace_zone_distribution"
        case _dynamicVdot = "dynamic_vdot"
        case _avgStanceTimeMs = "avg_stance_time_ms"
        case _avgVerticalRatioPercent = "avg_vertical_ratio_percent"
    }
}

struct V2IntensityMinutes: Codable {
    private let _high: SafeDouble?
    private let _low: SafeDouble?
    private let _medium: SafeDouble?
    
    // 公開的計算屬性
    var high: Double? { _high?.value }
    var low: Double? { _low?.value }
    var medium: Double? { _medium?.value }
    
    enum CodingKeys: String, CodingKey {
        case _high = "high"
        case _low = "low"
        case _medium = "medium"
    }
    
    // 便利初始化方法，用於從 APIIntensityMinutes 轉換
    init(from intensity: APIIntensityMinutes) {
        self._high = SafeDouble(value: intensity.high)
        self._low = SafeDouble(value: intensity.low)
        self._medium = SafeDouble(value: intensity.medium)
    }
}

struct V2ZoneDistribution: Codable {
    private let _marathon: SafeDouble?
    private let _interval: SafeDouble?
    private let _recovery: SafeDouble?
    private let _threshold: SafeDouble?
    private let _anaerobic: SafeDouble?
    private let _easy: SafeDouble?
    
    // 公開的計算屬性
    var marathon: Double? { _marathon?.value }
    var interval: Double? { _interval?.value }
    var recovery: Double? { _recovery?.value }
    var threshold: Double? { _threshold?.value }
    var anaerobic: Double? { _anaerobic?.value }
    var easy: Double? { _easy?.value }
    
    enum CodingKeys: String, CodingKey {
        case _marathon = "marathon"
        case _interval = "interval"
        case _recovery = "recovery"
        case _threshold = "threshold"
        case _anaerobic = "anaerobic"
        case _easy = "easy"
    }
    
    // 便利初始化方法，用於從 ZoneDistribution 轉換
    init(from zones: ZoneDistribution) {
        self._marathon = SafeDouble(value: zones.marathon)
        self._interval = SafeDouble(value: zones.interval)
        self._recovery = SafeDouble(value: zones.recovery)
        self._threshold = SafeDouble(value: zones.threshold)
        self._anaerobic = SafeDouble(value: zones.anaerobic)
        self._easy = SafeDouble(value: zones.easy)
    }
}

struct V2TimeSeries: Codable {
    private let _cadencesSpm: [SafeInt?]?
    private let _speedsMPerS: [SafeDouble?]?
    private let _altitudesM: [SafeDouble?]?
    private let _heartRatesBpm: [SafeInt?]?
    private let _sampleRateHz: SafeDouble?
    private let _totalSamples: SafeInt?
    private let _temperaturesC: [SafeDouble?]?
    private let _timestampsS: [SafeInt?]?
    private let _distancesM: [SafeDouble?]?
    private let _powersW: [SafeDouble?]?
    private let _pacesSPerKm: [SafeDouble?]?
    
    // 進階步態指標
    private let _stanceTimesMs: [SafeDouble?]?
    private let _stanceTimesPercent: [SafeDouble?]?
    private let _groundContactTimesMs: [SafeDouble?]?
    private let _groundContactBalances: [SafeDouble?]?
    private let _verticalOscillationsMm: [SafeDouble?]?
    private let _verticalRatios: [SafeDouble?]?
    private let _stepLengthsM: [SafeDouble?]?
    private let _runningSmoothnessValues: [SafeDouble?]?
    private let _runningPowersW: [SafeDouble?]?
    
    // 公開的計算屬性
    var cadencesSpm: [Int?]? { _cadencesSpm?.map { $0?.value } }
    var speedsMPerS: [Double?]? { _speedsMPerS?.map { $0?.value } }
    var altitudesM: [Double?]? { _altitudesM?.map { $0?.value } }
    var heartRatesBpm: [Int?]? { _heartRatesBpm?.map { $0?.value } }
    var sampleRateHz: Double? { _sampleRateHz?.value }
    var totalSamples: Int? { _totalSamples?.value }
    var temperaturesC: [Double?]? { _temperaturesC?.map { $0?.value } }
    var timestampsS: [Int?]? { _timestampsS?.map { $0?.value } }
    var distancesM: [Double?]? { _distancesM?.map { $0?.value } }
    var powersW: [Double?]? { _powersW?.map { $0?.value } }
    var pacesSPerKm: [Double?]? { _pacesSPerKm?.map { $0?.value } }
    
    // 進階步態指標的公開計算屬性
    var stanceTimesMs: [Double?]? { _stanceTimesMs?.map { $0?.value } }
    var stanceTimesPercent: [Double?]? { _stanceTimesPercent?.map { $0?.value } }
    var groundContactTimesMs: [Double?]? { _groundContactTimesMs?.map { $0?.value } }
    var groundContactBalances: [Double?]? { _groundContactBalances?.map { $0?.value } }
    var verticalOscillationsMm: [Double?]? { _verticalOscillationsMm?.map { $0?.value } }
    var verticalRatios: [Double?]? { _verticalRatios?.map { $0?.value } }
    var stepLengthsM: [Double?]? { _stepLengthsM?.map { $0?.value } }
    var runningSmoothnessValues: [Double?]? { _runningSmoothnessValues?.map { $0?.value } }
    var runningPowersW: [Double?]? { _runningPowersW?.map { $0?.value } }
    
    enum CodingKeys: String, CodingKey {
        case _cadencesSpm = "cadences_spm"
        case _speedsMPerS = "speeds_m_per_s"
        case _altitudesM = "altitudes_m" 
        case _heartRatesBpm = "heart_rates_bpm"
        case _sampleRateHz = "sample_rate_hz"
        case _totalSamples = "total_samples"
        case _temperaturesC = "temperatures_c"
        case _timestampsS = "timestamps_s"
        case _distancesM = "distances_m"
        case _powersW = "powers_w"
        case _pacesSPerKm = "paces_s_per_km"
        
        // 進階步態指標
        case _stanceTimesMs = "stance_times_ms"
        case _stanceTimesPercent = "stance_times_percent"
        case _groundContactTimesMs = "ground_contact_times_ms"
        case _groundContactBalances = "ground_contact_balances"
        case _verticalOscillationsMm = "vertical_oscillations_mm"
        case _verticalRatios = "vertical_ratios"
        case _stepLengthsM = "step_lengths_m"
        case _runningSmoothnessValues = "running_smoothness_values"
        case _runningPowersW = "running_powers_w"
    }
}

struct V2RouteData: Codable {
    private let _horizontalAccuracyM: SafeDouble?
    private let _totalPoints: SafeInt?
    let timestamps: [String?]?
    private let _verticalAccuracyM: SafeDouble?
    private let _longitudes: [SafeDouble?]?
    private let _altitudes: [SafeDouble?]?
    private let _latitudes: [SafeDouble?]?
    
    // 公開的計算屬性
    var horizontalAccuracyM: Double? { _horizontalAccuracyM?.value }
    var totalPoints: Int? { _totalPoints?.value }
    var verticalAccuracyM: Double? { _verticalAccuracyM?.value }
    var longitudes: [Double?]? { _longitudes?.map { $0?.value } }
    var altitudes: [Double?]? { _altitudes?.map { $0?.value } }
    var latitudes: [Double?]? { _latitudes?.map { $0?.value } }
    
    enum CodingKeys: String, CodingKey {
        case _horizontalAccuracyM = "horizontal_accuracy_m"
        case _totalPoints = "total_points"
        case timestamps
        case _verticalAccuracyM = "vertical_accuracy_m"
        case _longitudes = "longitudes"
        case _altitudes = "altitudes"
        case _latitudes = "latitudes"
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
    private let _temperatureC: SafeDouble?
    private let _windSpeedMPerS: SafeDouble?
    private let _windDirectionDeg: SafeDouble?
    private let _humidityPercent: SafeDouble?
    let timezone: String?
    let locationName: String?
    let weatherCondition: String?
    
    // 公開的計算屬性
    var temperatureC: Double? { _temperatureC?.value }
    var windSpeedMPerS: Double? { _windSpeedMPerS?.value }
    var windDirectionDeg: Double? { _windDirectionDeg?.value }
    var humidityPercent: Double? { _humidityPercent?.value }
    
    enum CodingKeys: String, CodingKey {
        case _temperatureC = "temperature_c"
        case _windSpeedMPerS = "wind_speed_m_per_s"
        case _windDirectionDeg = "wind_direction_deg"
        case _humidityPercent = "humidity_percent"
        case timezone
        case locationName = "location_name"
        case weatherCondition = "weather_condition"
    }
}

struct V2Metadata: Codable {
    private let _processedSampleCount: SafeInt?
    let hasPowerData: Bool?
    let hasGpsData: Bool?
    let samplingMethod: String?
    let adapterVersion: String?
    private let _originalSampleCount: SafeInt?
    let rawDataPath: String?
    let hasHeartRateData: Bool?
    private let _rawDataSizeBytes: SafeInt?
    let processedAt: String?
    
    // 公開的計算屬性
    var processedSampleCount: Int? { _processedSampleCount?.value }
    var originalSampleCount: Int? { _originalSampleCount?.value }
    var rawDataSizeBytes: Int? { _rawDataSizeBytes?.value }
    
    enum CodingKeys: String, CodingKey {
        case _processedSampleCount = "processed_sample_count"
        case hasPowerData = "has_power_data"
        case hasGpsData = "has_gps_data"
        case samplingMethod = "sampling_method"
        case adapterVersion = "adapter_version"
        case _originalSampleCount = "original_sample_count"
        case rawDataPath = "raw_data_path"
        case hasHeartRateData = "has_heart_rate_data"
        case _rawDataSizeBytes = "raw_data_size_bytes"
        case processedAt = "processed_at"
    }
}

// MARK: - Lap Data Models

struct LapData: Codable, Identifiable {
    let id: String = UUID().uuidString
    
    let lapNumber: Int
    private let _startTimeOffsetS: SafeInt
    private let _totalTimeS: SafeInt?
    private let _totalDistanceM: SafeDouble?
    private let _avgSpeedMPerS: SafeDouble?
    private let _avgPaceSPerKm: SafeDouble?
    private let _avgHeartRateBpm: SafeInt?
    
    // 公開的計算屬性
    var startTimeOffsetS: Int { _startTimeOffsetS.value ?? 0 }
    var totalTimeS: Int? { _totalTimeS?.value }
    var totalDistanceM: Double? { _totalDistanceM?.value }
    var avgSpeedMPerS: Double? { _avgSpeedMPerS?.value }
    var avgPaceSPerKm: Double? { _avgPaceSPerKm?.value }
    var avgHeartRateBpm: Int? { _avgHeartRateBpm?.value }
    
    enum CodingKeys: String, CodingKey {
        case lapNumber = "lap_number"
        case _startTimeOffsetS = "start_time_offset_s"
        case _totalTimeS = "total_time_s"
        case _totalDistanceM = "total_distance_m"
        case _avgSpeedMPerS = "avg_speed_m_per_s"
        case _avgPaceSPerKm = "avg_pace_s_per_km"
        case _avgHeartRateBpm = "avg_heart_rate_bpm"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        lapNumber = try container.decode(Int.self, forKey: .lapNumber)
        _startTimeOffsetS = try container.decode(SafeInt.self, forKey: ._startTimeOffsetS)
        _totalTimeS = try container.decodeIfPresent(SafeInt.self, forKey: ._totalTimeS)
        _totalDistanceM = try container.decodeIfPresent(SafeDouble.self, forKey: ._totalDistanceM)
        _avgSpeedMPerS = try container.decodeIfPresent(SafeDouble.self, forKey: ._avgSpeedMPerS)
        _avgPaceSPerKm = try container.decodeIfPresent(SafeDouble.self, forKey: ._avgPaceSPerKm)
        _avgHeartRateBpm = try container.decodeIfPresent(SafeInt.self, forKey: ._avgHeartRateBpm)
    }
    
    // 便利屬性 - 格式化的配速顯示
    var formattedPace: String {
        guard let pace = avgPaceSPerKm else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 便利屬性 - 格式化的時間顯示
    var formattedTime: String {
        guard let time = totalTimeS else { return "--:--" }
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 便利屬性 - 格式化的距離顯示
    var formattedDistance: String {
        guard let distance = totalDistanceM else { return "--" }
        return String(format: "%.2f km", distance / 1000)
    }
}

// MARK: - Legacy V1 API Models (Keep for backwards compatibility)

struct AdvancedMetrics: Codable {
    private let _dynamicVdot: SafeDouble?
    private let _tss: SafeDouble?
    let trainingType: String?
    let intensityMinutes: APIIntensityMinutes?
    private let _intervalCount: SafeInt?
    private let _avgHrTop20Percent: SafeDouble?
    let hrZoneDistribution: ZoneDistribution?
    let paceZoneDistribution: ZoneDistribution?
    private let _rpe: SafeDouble?
    private let _avgStanceTimeMs: SafeDouble?
    private let _avgVerticalRatioPercent: SafeDouble?
    
    // 公開的計算屬性
    var dynamicVdot: Double? { _dynamicVdot?.value }
    var tss: Double? { _tss?.value }
    var intervalCount: Int? { _intervalCount?.value }
    var avgHrTop20Percent: Double? { _avgHrTop20Percent?.value }
    var rpe: Double? { _rpe?.value }
    var avgStanceTimeMs: Double? { _avgStanceTimeMs?.value }
    var avgVerticalRatioPercent: Double? { _avgVerticalRatioPercent?.value }
    
    enum CodingKeys: String, CodingKey {
        case _dynamicVdot = "dynamic_vdot"
        case _tss = "tss"
        case trainingType = "training_type"
        case intensityMinutes = "intensity_minutes"
        case _intervalCount = "interval_count"
        case _avgHrTop20Percent = "avg_hr_top20_percent"
        case hrZoneDistribution = "hr_zone_distribution"
        case paceZoneDistribution = "pace_zone_distribution"
        case _rpe = "rpe"
        case _avgStanceTimeMs = "avg_stance_time_ms"
        case _avgVerticalRatioPercent = "avg_vertical_ratio_percent"
    }
    
    // 便利初始化方法，用於測試和手動創建
    init(dynamicVdot: Double? = nil,
         tss: Double? = nil,
         trainingType: String? = nil,
         intensityMinutes: APIIntensityMinutes? = nil,
         intervalCount: Int? = nil,
         avgHrTop20Percent: Double? = nil,
         hrZoneDistribution: ZoneDistribution? = nil,
         paceZoneDistribution: ZoneDistribution? = nil,
         rpe: Double? = nil,
         avgStanceTimeMs: Double? = nil,
         avgVerticalRatioPercent: Double? = nil) {
        
        self._dynamicVdot = dynamicVdot.map { SafeDouble(value: $0) }
        self._tss = tss.map { SafeDouble(value: $0) }
        self.trainingType = trainingType
        self.intensityMinutes = intensityMinutes
        self._intervalCount = intervalCount.map { SafeInt(value: $0) }
        self._avgHrTop20Percent = avgHrTop20Percent.map { SafeDouble(value: $0) }
        self.hrZoneDistribution = hrZoneDistribution
        self.paceZoneDistribution = paceZoneDistribution
        self._rpe = rpe.map { SafeDouble(value: $0) }
        self._avgStanceTimeMs = avgStanceTimeMs.map { SafeDouble(value: $0) }
        self._avgVerticalRatioPercent = avgVerticalRatioPercent.map { SafeDouble(value: $0) }
    }
}

struct ZoneDistribution: Codable {
    private let _marathon: SafeDouble?
    private let _threshold: SafeDouble?
    private let _recovery: SafeDouble?
    private let _interval: SafeDouble?
    private let _anaerobic: SafeDouble?
    private let _easy: SafeDouble?
    
    // 公開的計算屬性
    var marathon: Double? { _marathon?.value }
    var threshold: Double? { _threshold?.value }
    var recovery: Double? { _recovery?.value }
    var interval: Double? { _interval?.value }
    var anaerobic: Double? { _anaerobic?.value }
    var easy: Double? { _easy?.value }
    
    enum CodingKeys: String, CodingKey {
        case _marathon = "marathon"
        case _threshold = "threshold"
        case _recovery = "recovery"
        case _interval = "interval"
        case _anaerobic = "anaerobic"
        case _easy = "easy"
    }
}

struct APIIntensityMinutes: Codable {
    private let _low: SafeDouble?
    private let _medium: SafeDouble?
    private let _high: SafeDouble?
    
    // 公開的計算屬性
    var low: Double? { _low?.value }
    var medium: Double? { _medium?.value }
    var high: Double? { _high?.value }
    
    enum CodingKeys: String, CodingKey {
        case _low = "low"
        case _medium = "medium"
        case _high = "high"
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

// MARK: - Daily Plan Summary and AI Summary Models

struct DailyPlanSummary: Codable {
    let dayTarget: String?
    let distanceKm: Double?
    let pace: String?
    let trainingType: String?
    let heartRateRange: DailySummaryHeartRateRange?
    let trainingDetails: DailyTrainingDetails?
    
    enum CodingKeys: String, CodingKey {
        case dayTarget = "day_target"
        case distanceKm = "distance_km"
        case pace
        case trainingType = "training_type"
        case heartRateRange = "heart_rate_range"
        case trainingDetails = "training_details"
    }
}

struct DailyTrainingDetails: Codable {
    let description: String?
    let segments: [DailyPlanSegment]?
    let totalDistanceKm: Double?
    
    enum CodingKeys: String, CodingKey {
        case description
        case segments
        case totalDistanceKm = "total_distance_km"
    }
}

struct DailySummaryHeartRateRange: Codable {
    let min: Int
    let max: Int
}

struct DailyPlanSegment: Codable {
    let distanceKm: Double?
    let pace: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case pace
        case description
    }
}

struct AISummary: Codable {
    let analysis: String

    enum CodingKeys: String, CodingKey {
        case analysis
    }
}

// MARK: - Lap Data Models

struct LapData: Codable {
    let lapNumber: Int                   // 分圈序號（從 1 開始）
    let startTime: TimeInterval          // 分圈開始時間
    let endTime: TimeInterval            // 分圈結束時間
    let duration: TimeInterval           // 分圈持續時間（秒）
    let distance: Double?                // 分圈距離（米）
    let averagePace: Double?             // 平均配速（秒/公里）
    let averageHeartRate: Double?        // 平均心率（BPM）
    let type: String                     // 分圈類型："manual", "auto", "segment"
    let metadata: [String: String]?      // 額外的元數據
}
