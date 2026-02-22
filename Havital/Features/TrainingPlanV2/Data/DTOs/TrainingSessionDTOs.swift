import Foundation

// MARK: - Training Session DTOs (V2.1+)
/// Data Layer - 與 API JSON 結構一一對應,使用 snake_case 命名

// MARK: - HeartRateRangeDTO

struct HeartRateRangeDTO: Codable, Equatable {
    let min: Int?
    let max: Int?

    enum CodingKeys: String, CodingKey {
        case min
        case max
    }
}

// MARK: - RunSegmentDTO

struct RunSegmentDTO: Codable, Equatable {
    let distanceKm: Double?
    let distanceM: Int?
    let durationMinutes: Int?
    let durationSeconds: Int?
    let pace: String?
    let heartRateRange: HeartRateRangeDTO?
    let intensity: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case durationMinutes = "duration_minutes"
        case durationSeconds = "duration_seconds"
        case pace
        case heartRateRange = "heart_rate_range"
        case intensity
        case description
    }
}

// MARK: - IntervalBlockDTO

struct IntervalBlockDTO: Codable, Equatable {
    let repeats: Int
    let workDistanceKm: Double?
    let workDistanceM: Int?
    let workDurationMinutes: Int?
    let workPace: String?
    let workDescription: String?
    let recoveryDistanceKm: Double?
    let recoveryDistanceM: Int?
    let recoveryDurationMinutes: Int?
    let recoveryPace: String?
    let recoveryDescription: String?
    let recoveryDurationSeconds: Int?
    let variant: String?

    enum CodingKeys: String, CodingKey {
        case repeats
        case workDistanceKm = "work_distance_km"
        case workDistanceM = "work_distance_m"
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
}

// MARK: - RunActivityDTO

struct RunActivityDTO: Codable, Equatable {
    let runType: String
    let distanceKm: Double?
    let durationMinutes: Int?
    let pace: String?
    let heartRateRange: HeartRateRangeDTO?
    let interval: IntervalBlockDTO?
    let segments: [RunSegmentDTO]?
    let description: String?
    let targetIntensity: String?

    enum CodingKeys: String, CodingKey {
        case runType = "run_type"
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case pace
        case heartRateRange = "heart_rate_range"
        case interval
        case segments
        case description
        case targetIntensity = "target_intensity"
    }
}

// MARK: - ExerciseDTO

struct ExerciseDTO: Codable, Equatable {
    let name: String
    let sets: Int?
    let reps: Int?
    let repsRange: String?
    let durationSeconds: Int?
    let weightKg: Double?
    let restSeconds: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case sets
        case reps
        case repsRange = "reps_range"
        case durationSeconds = "duration_seconds"
        case weightKg = "weight_kg"
        case restSeconds = "rest_seconds"
        case description
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
    let intensity: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case crossType = "cross_type"
        case durationMinutes = "duration_minutes"
        case distanceKm = "distance_km"
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
/// API 回傳的 session 包裝物件，內含 primary activity

struct SessionWrapperDTO: Codable, Equatable {
    let primary: PrimaryActivityDTO?
}

// MARK: - DayDetailDTO
/// V2 API 支援兩種結構：
/// 1. 扁平結構：primary/warmup/cooldown 直接在 day 層級
/// 2. 包裝結構：session.primary + warmup/cooldown 在 day 層級

struct DayDetailDTO: Codable, Equatable {
    let dayIndex: Int
    let dayTarget: String
    let reason: String
    let tips: String?
    let category: String?
    let primary: PrimaryActivityDTO?
    let warmup: RunSegmentDTO?
    let cooldown: RunSegmentDTO?
    let supplementary: [SupplementaryActivityDTO]?

    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case dayTarget = "day_target"
        case reason
        case tips
        case category
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
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        warmup = try container.decodeIfPresent(RunSegmentDTO.self, forKey: .warmup)
        cooldown = try container.decodeIfPresent(RunSegmentDTO.self, forKey: .cooldown)
        supplementary = try container.decodeIfPresent([SupplementaryActivityDTO].self, forKey: .supplementary)

        // 優先嘗試扁平結構的 primary，再嘗試 session.primary
        if let directPrimary = try container.decodeIfPresent(PrimaryActivityDTO.self, forKey: .primary) {
            primary = directPrimary
        } else if let sessionWrapper = try container.decodeIfPresent(SessionWrapperDTO.self, forKey: .session) {
            primary = sessionWrapper.primary
        } else {
            primary = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayIndex, forKey: .dayIndex)
        try container.encode(dayTarget, forKey: .dayTarget)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(tips, forKey: .tips)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(primary, forKey: .primary)
        try container.encodeIfPresent(warmup, forKey: .warmup)
        try container.encodeIfPresent(cooldown, forKey: .cooldown)
        try container.encodeIfPresent(supplementary, forKey: .supplementary)
    }

    init(dayIndex: Int, dayTarget: String, reason: String, tips: String?, category: String?, primary: PrimaryActivityDTO?, warmup: RunSegmentDTO?, cooldown: RunSegmentDTO?, supplementary: [SupplementaryActivityDTO]?) {
        self.dayIndex = dayIndex
        self.dayTarget = dayTarget
        self.reason = reason
        self.tips = tips
        self.category = category
        self.primary = primary
        self.warmup = warmup
        self.cooldown = cooldown
        self.supplementary = supplementary
    }
}
