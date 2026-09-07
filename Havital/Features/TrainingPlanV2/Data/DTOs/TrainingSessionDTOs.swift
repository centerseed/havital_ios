import Foundation

// MARK: - Training Session DTOs (V2.1+)
/// Data Layer - 與 API JSON 結構一一對應,使用 snake_case 命名

// MARK: - ClimateMetaDTO

struct ClimateMetaDTO: Codable, Equatable {
    let feelsLikeTempC: Double?
    let heatPressureLevel: String
    let paceAdjustmentPct: Double?
    let reasonText: String
    let longRunReductionPct: Double?

    enum CodingKeys: String, CodingKey {
        case feelsLikeTempC = "feels_like_temp_c"
        case heatPressureLevel = "heat_pressure_level"
        case paceAdjustmentPct = "pace_adjustment_pct"
        case reasonText = "reason_text"
        case longRunReductionPct = "long_run_reduction_pct"
    }
}

// MARK: - HeartRateRangeDTO

struct HeartRateRangeDTO: Codable, Equatable {
    let min: Int?
    let max: Int?

    enum CodingKeys: String, CodingKey {
        case min
        case max
    }
}

// MARK: - SegmentEffortDTO

/// 段落序列中，一組間歇的工作段或恢復段規格（contract: steady-intervals-v1）。
///
/// 刻意不含 kind / repeats / work / recovery —— 結構上不可能巢套第二層。
/// `recoveryType` 存 String 而非 enum：後端未來新增恢復型態時，
/// enum 解碼會 throw 並讓整份週課表變空白。
struct SegmentEffortDTO: Codable, Equatable {
    let distanceKm: Double?
    let distanceM: Int?
    let durationMinutes: Int?
    let durationSeconds: Int?
    let pace: String?
    let basePace: String?
    let paceZone: String?
    let targetHrr: [Double]?
    let recoveryType: String?

    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case durationMinutes = "duration_minutes"
        case durationSeconds = "duration_seconds"
        case pace
        case basePace = "base_pace"
        case paceZone = "pace_zone"
        case targetHrr = "target_hrr"
        case recoveryType = "recovery_type"
    }
}

// MARK: - RunSegmentDTO

struct RunSegmentDTO: Codable, Equatable {
    var distanceKm: Double?
    var distanceM: Int?
    var distanceDisplay: Double?
    var distanceUnit: String?
    var durationMinutes: Int?
    var durationSeconds: Int?
    var pace: String?
    var basePace: String?
    var climateAdjustedPace: String?
    var climateMeta: ClimateMetaDTO?
    var heartRateRange: HeartRateRangeDTO?
    var intensity: String?
    var description: String?
    /// 段落型態。缺席 = "steady"（既有文件）。存 String，未知值由 Domain 層降級。
    var kind: String?
    var repeats: Int?
    var work: SegmentEffortDTO?
    var recovery: SegmentEffortDTO?

    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case distanceDisplay = "distance_display"
        case distanceUnit = "distance_unit"
        case durationMinutes = "duration_minutes"
        case durationSeconds = "duration_seconds"
        case pace
        case basePace = "base_pace"
        case climateAdjustedPace = "climate_adjusted_pace"
        case climateMeta = "climate_meta"
        case heartRateRange = "heart_rate_range"
        case intensity
        case description
        case kind
        case repeats
        case work
        case recovery
    }
}

// MARK: - IntervalBlockDTO

struct IntervalBlockDTO: Codable, Equatable {
    var repeats: Int
    var workDistanceKm: Double?
    var workDistanceM: Int?
    var workDistanceDisplay: Double?
    var workDistanceUnit: String?
    var workPaceUnit: String?
    var workDurationMinutes: Int?
    var workPace: String?
    var workDescription: String?
    var recoveryDistanceKm: Double?
    var recoveryDistanceM: Int?
    var recoveryDurationMinutes: Int?
    var recoveryPace: String?
    var recoveryDescription: String?
    var recoveryDurationSeconds: Int?
    var variant: String?

    enum CodingKeys: String, CodingKey {
        case repeats
        case workDistanceKm = "work_distance_km"
        case workDistanceM = "work_distance_m"
        case workDistanceDisplay = "work_distance_display"
        case workDistanceUnit = "work_distance_unit"
        case workPaceUnit = "work_pace_unit"
        case workDurationMinutes = "work_duration_minutes"
        case workPace = "work_pace"
        case workDescription = "work_description"
        case recoveryDistanceKm = "recovery_distance_km"
        case recoveryDistanceM = "recovery_distance_m"
        case recoveryDurationMinutes = "recovery_duration_minutes"
        case recoveryPace = "recovery_pace"
        case recoveryDescription = "recovery_description"
        case recoveryDurationSeconds = "recovery_duration_seconds"
        case variant
    }

    /// 自定義編碼器 — recovery 欄位用 encode（nil → null），work 欄位用 encodeIfPresent（nil → 省略）
    /// 確保後端收到 null 時清除舊的 recovery 距離/配速
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repeats, forKey: .repeats)
        // Work 欄位：省略 nil（不影響後端已有值）
        try container.encodeIfPresent(workDistanceKm, forKey: .workDistanceKm)
        try container.encodeIfPresent(workDistanceM, forKey: .workDistanceM)
        try container.encodeIfPresent(workDistanceDisplay, forKey: .workDistanceDisplay)
        try container.encodeIfPresent(workDistanceUnit, forKey: .workDistanceUnit)
        try container.encodeIfPresent(workPaceUnit, forKey: .workPaceUnit)
        try container.encodeIfPresent(workDurationMinutes, forKey: .workDurationMinutes)
        try container.encodeIfPresent(workPace, forKey: .workPace)
        try container.encodeIfPresent(workDescription, forKey: .workDescription)
        // Recovery 欄位：明確編碼 nil 為 null，確保後端清除舊值
        try container.encode(recoveryDistanceKm, forKey: .recoveryDistanceKm)
        try container.encode(recoveryDistanceM, forKey: .recoveryDistanceM)
        try container.encode(recoveryDurationMinutes, forKey: .recoveryDurationMinutes)
        try container.encode(recoveryPace, forKey: .recoveryPace)
        try container.encodeIfPresent(recoveryDescription, forKey: .recoveryDescription)
        try container.encode(recoveryDurationSeconds, forKey: .recoveryDurationSeconds)
        try container.encodeIfPresent(variant, forKey: .variant)
    }
}

// MARK: - RunActivityDTO

struct RunActivityDTO: Codable, Equatable {
    var runType: String
    var distanceKm: Double?
    var distanceDisplay: Double?
    var distanceUnit: String?
    var paceUnit: String?
    var durationMinutes: Int?
    var durationSeconds: Int?
    var pace: String?
    var basePace: String?
    var climateAdjustedPace: String?
    var heartRateRange: HeartRateRangeDTO?
    var interval: IntervalBlockDTO?
    var segments: [RunSegmentDTO]?
    var description: String?
    var targetIntensity: String?
    var climateMeta: ClimateMetaDTO?
    var isTrail: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case runType = "run_type"
        case distanceKm = "distance_km"
        case distanceDisplay = "distance_display"
        case distanceUnit = "distance_unit"
        case paceUnit = "pace_unit"
        case durationMinutes = "duration_minutes"
        case durationSeconds = "duration_seconds"
        case pace
        case basePace = "base_pace"
        case climateAdjustedPace = "climate_adjusted_pace"
        case heartRateRange = "heart_rate_range"
        case interval
        case segments
        case description
        case targetIntensity = "target_intensity"
        case climateMeta = "climate_meta"
        case isTrail = "is_trail"
    }
}

// MARK: - ExerciseDTO

struct ExerciseDTO: Codable, Equatable {
    let exerciseId: String?
    let name: String
    let sets: Int?
    let reps: Int?
    let repsRange: String?
    let durationSeconds: Int?
    let weightKg: Double?
    let restSeconds: Int?
    let description: String?
    let seriesId: String?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case name
        case sets
        case reps
        case repsRange = "reps_range"
        case durationSeconds = "duration_seconds"
        case weightKg = "weight_kg"
        case restSeconds = "rest_seconds"
        case description
        case seriesId = "series_id"
    }
}

// MARK: - StrengthActivityDTO

struct StrengthActivityDTO: Codable, Equatable {
    let strengthType: String
    let exercises: [ExerciseDTO]
    let durationMinutes: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case strengthType = "strength_type"
        case exercises
        case durationMinutes = "duration_minutes"
        case description
    }
}

// MARK: - CrossActivityDTO

struct CrossActivityDTO: Codable, Equatable {
    let crossType: String
    let durationMinutes: Int
    let distanceKm: Double?
    let distanceDisplay: Double?
    let distanceUnit: String?
    let intensity: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case crossType = "cross_type"
        case durationMinutes = "duration_minutes"
        case distanceKm = "distance_km"
        case distanceDisplay = "distance_display"
        case distanceUnit = "distance_unit"
        case intensity
        case description
    }
}

// MARK: - PrimaryActivityDTO

enum PrimaryActivityDTO: Codable, Equatable {
    case run(RunActivityDTO)
    case strength(StrengthActivityDTO)
    case cross(CrossActivityDTO)

    init(from decoder: Decoder) throws {
        // 嘗試根據存在的欄位判斷類型
        let container = try decoder.singleValueContainer()

        // 先嘗試解碼為 RunActivity (檢查是否有 run_type)
        if let runActivity = try? container.decode(RunActivityDTO.self) {
            self = .run(runActivity)
            return
        }

        // 再嘗試 StrengthActivity (檢查是否有 strength_type)
        if let strengthActivity = try? container.decode(StrengthActivityDTO.self) {
            self = .strength(strengthActivity)
            return
        }

        // 最後嘗試 CrossActivity (檢查是否有 cross_type)
        if let crossActivity = try? container.decode(CrossActivityDTO.self) {
            self = .cross(crossActivity)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "無法解析 PrimaryActivityDTO: 不符合任何已知類型"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .run(let activity):
            try container.encode(activity)
        case .strength(let activity):
            try container.encode(activity)
        case .cross(let activity):
            try container.encode(activity)
        }
    }
}

// MARK: - SupplementaryActivityDTO

enum SupplementaryActivityDTO: Codable, Equatable {
    case strength(StrengthActivityDTO)
    case cross(CrossActivityDTO)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let strengthActivity = try? container.decode(StrengthActivityDTO.self) {
            self = .strength(strengthActivity)
            return
        }

        if let crossActivity = try? container.decode(CrossActivityDTO.self) {
            self = .cross(crossActivity)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "無法解析 SupplementaryActivityDTO"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .strength(let activity):
            try container.encode(activity)
        case .cross(let activity):
            try container.encode(activity)
        }
    }
}

// MARK: - TrainingSessionDTO

struct TrainingSessionDTO: Codable, Equatable {
    let warmup: RunSegmentDTO?
    let primary: PrimaryActivityDTO
    let cooldown: RunSegmentDTO?
    let supplementary: [SupplementaryActivityDTO]?

    enum CodingKeys: String, CodingKey {
        case warmup
        case primary
        case cooldown
        case supplementary
    }
}

// MARK: - SessionWrapperDTO
/// API 回傳的 session 包裝物件，內含 primary activity 和補充訓練

struct SessionWrapperDTO: Codable, Equatable {
    let primary: PrimaryActivityDTO?
    let supplementary: [SupplementaryActivityDTO]?
}

// MARK: - DayDetailDTO
/// V2 API 支援兩種結構：
/// 1. 扁平結構：primary/warmup/cooldown 直接在 day 層級
/// 2. 包裝結構：session.primary + warmup/cooldown 在 day 層級

struct DayDetailDTO: Codable, Equatable {
    var dayIndex: Int
    var dayTarget: String
    var reason: String
    /// 這一天的**總量**（熱身＋主課＋緩和）。`primary.distance_km` 在間歇課只算主課段，
    /// 兩者不同（dev 實測：日層 5.2、`primary` 2.2）。
    var distanceKm: Double?
    var tips: String?
    var category: String?
    var climateMeta: ClimateMetaDTO?
    var primary: PrimaryActivityDTO?
    var warmup: RunSegmentDTO?
    var cooldown: RunSegmentDTO?
    var supplementary: [SupplementaryActivityDTO]?

    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case dayTarget = "day_target"
        case reason
        case distanceKm = "distance_km"
        case tips
        case category
        case climateMeta = "climate_meta"
        case primary
        case session
        case warmup
        case cooldown
        case supplementary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayIndex = try container.decode(Int.self, forKey: .dayIndex)
        dayTarget = try container.decode(String.self, forKey: .dayTarget)
        reason = try container.decode(String.self, forKey: .reason)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        climateMeta = try container.decodeIfPresent(ClimateMetaDTO.self, forKey: .climateMeta)
        warmup = try container.decodeIfPresent(RunSegmentDTO.self, forKey: .warmup)
        cooldown = try container.decodeIfPresent(RunSegmentDTO.self, forKey: .cooldown)
        let flatSupplementary = try container.decodeIfPresent([SupplementaryActivityDTO].self, forKey: .supplementary)

        // 優先嘗試扁平結構的 primary，再嘗試 session.primary
        if let directPrimary = try container.decodeIfPresent(PrimaryActivityDTO.self, forKey: .primary) {
            primary = directPrimary
            supplementary = flatSupplementary
        } else if let sessionWrapper = try container.decodeIfPresent(SessionWrapperDTO.self, forKey: .session) {
            primary = sessionWrapper.primary
            // 扁平 supplementary 優先；若無，嘗試從 session.supplementary 補充
            supplementary = flatSupplementary ?? sessionWrapper.supplementary
        } else {
            primary = nil
            supplementary = flatSupplementary
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayIndex, forKey: .dayIndex)
        try container.encode(dayTarget, forKey: .dayTarget)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(distanceKm, forKey: .distanceKm)
        try container.encodeIfPresent(tips, forKey: .tips)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(climateMeta, forKey: .climateMeta)
        try container.encodeIfPresent(primary, forKey: .primary)
        // Day-level warmup/cooldown are editable fields. An explicit null is the
        // delete command for the backend merge; omitting the key is a no-op.
        try container.encode(warmup, forKey: .warmup)
        try container.encode(cooldown, forKey: .cooldown)
        try container.encodeIfPresent(supplementary, forKey: .supplementary)
    }

    init(dayIndex: Int, dayTarget: String, reason: String, distanceKm: Double? = nil, tips: String?, category: String?, climateMeta: ClimateMetaDTO?, primary: PrimaryActivityDTO?, warmup: RunSegmentDTO?, cooldown: RunSegmentDTO?, supplementary: [SupplementaryActivityDTO]?) {
        self.dayIndex = dayIndex
        self.dayTarget = dayTarget
        self.reason = reason
        self.distanceKm = distanceKm
        self.tips = tips
        self.category = category
        self.climateMeta = climateMeta
        self.primary = primary
        self.warmup = warmup
        self.cooldown = cooldown
        self.supplementary = supplementary
    }
}
