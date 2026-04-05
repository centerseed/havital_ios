import Foundation

// MARK: - PlanOverviewV2DTO
/// Plan Overview V2 DTO - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
struct PlanOverviewV2DTO: Codable {

    // MARK: - Properties

    let id: String
    let targetId: String?
    let targetType: String
    let targetDescription: String?
    let methodologyId: String?
    let totalWeeks: Int
    let startFromStage: String?

    // Target 核心字段
    let raceDate: Int?
    let distanceKm: Double?
    let distanceKmDisplay: Double?
    let distanceUnit: String?
    let targetPace: String?
    let targetTime: Int?
    let isMainRace: Bool?
    let targetName: String?

    // 方法論概覽
    let methodologyOverview: MethodologyOverviewDTO?

    // 評估與概要（AI 生成，POST 回傳時可能為 null）
    let targetEvaluate: String?
    let approachSummary: String?

    // 訓練結構（POST 回傳時可能為 null 或空陣列）
    let trainingStages: [TrainingStageDTO]?
    let milestones: [MilestoneDTO]?

    // Metadata
    let createdAt: String?
    let methodologyVersion: String?

    // 里程碑計算依據
    let milestoneBasis: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case targetId = "target_id"
        case targetType = "target_type"
        case targetDescription = "target_description"
        case methodologyId = "methodology_id"
        case totalWeeks = "total_weeks"
        case startFromStage = "start_from_stage"
        case raceDate = "race_date"
        case distanceKm = "distance_km"
        case distanceKmDisplay = "distance_km_display"
        case distanceUnit = "distance_unit"
        case targetPace = "target_pace"
        case targetTime = "target_time"
        case isMainRace = "is_main_race"
        case targetName = "target_name"
        case methodologyOverview = "methodology_overview"
        case targetEvaluate = "target_evaluate"
        case approachSummary = "approach_summary"
        case trainingStages = "training_stages"
        case milestones
        case createdAt = "created_at"
        case methodologyVersion = "methodology_version"
        case milestoneBasis = "milestone_basis"
    }

    init(
        id: String,
        targetId: String?,
        targetType: String,
        targetDescription: String?,
        methodologyId: String?,
        totalWeeks: Int,
        startFromStage: String?,
        raceDate: Int?,
        distanceKm: Double?,
        distanceKmDisplay: Double?,
        distanceUnit: String?,
        targetPace: String?,
        targetTime: Int?,
        isMainRace: Bool?,
        targetName: String?,
        methodologyOverview: MethodologyOverviewDTO?,
        targetEvaluate: String?,
        approachSummary: String?,
        trainingStages: [TrainingStageDTO]?,
        milestones: [MilestoneDTO]?,
        createdAt: String?,
        methodologyVersion: String?,
        milestoneBasis: String?
    ) {
        self.id = id
        self.targetId = targetId
        self.targetType = targetType
        self.targetDescription = targetDescription
        self.methodologyId = methodologyId
        self.totalWeeks = totalWeeks
        self.startFromStage = startFromStage
        self.raceDate = raceDate
        self.distanceKm = distanceKm
        self.distanceKmDisplay = distanceKmDisplay
        self.distanceUnit = distanceUnit
        self.targetPace = targetPace
        self.targetTime = targetTime
        self.isMainRace = isMainRace
        self.targetName = targetName
        self.methodologyOverview = methodologyOverview
        self.targetEvaluate = targetEvaluate
        self.approachSummary = approachSummary
        self.trainingStages = trainingStages
        self.milestones = milestones
        self.createdAt = createdAt
        self.methodologyVersion = methodologyVersion
        self.milestoneBasis = milestoneBasis
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        targetId = try container.decodeIfPresent(String.self, forKey: .targetId)
        targetType = try container.decode(String.self, forKey: .targetType)
        targetDescription = try container.decodeIfPresent(String.self, forKey: .targetDescription)
        methodologyId = try container.decodeIfPresent(String.self, forKey: .methodologyId)
        totalWeeks = try container.decode(Int.self, forKey: .totalWeeks)
        startFromStage = try container.decodeIfPresent(String.self, forKey: .startFromStage)
        raceDate = try container.decodeIfPresent(Int.self, forKey: .raceDate)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        distanceKmDisplay = try container.decodeIfPresent(Double.self, forKey: .distanceKmDisplay)
        distanceUnit = try container.decodeIfPresent(String.self, forKey: .distanceUnit)
        targetPace = try container.decodeIfPresent(String.self, forKey: .targetPace)
        targetTime = try container.decodeIfPresent(Int.self, forKey: .targetTime)
        isMainRace = try container.decodeIfPresent(Bool.self, forKey: .isMainRace)
        targetName = try container.decodeIfPresent(String.self, forKey: .targetName)
        methodologyOverview = try container.decodeIfPresent(MethodologyOverviewDTO.self, forKey: .methodologyOverview)
        targetEvaluate = try container.decodeIfPresent(String.self, forKey: .targetEvaluate)
        approachSummary = try container.decodeIfPresent(String.self, forKey: .approachSummary)
        trainingStages = try container.decodeIfPresent([TrainingStageDTO].self, forKey: .trainingStages)
        milestones = try container.decodeIfPresent([MilestoneDTO].self, forKey: .milestones)
        methodologyVersion = try container.decodeIfPresent(String.self, forKey: .methodologyVersion)
        milestoneBasis = try container.decodeIfPresent(String.self, forKey: .milestoneBasis)

        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = createdAtString
        } else if let createdAtInt = try container.decodeIfPresent(Int.self, forKey: .createdAt) {
            createdAt = String(createdAtInt)
        } else if let createdAtDouble = try container.decodeIfPresent(Double.self, forKey: .createdAt) {
            createdAt = String(Int(createdAtDouble))
        } else {
            createdAt = nil
        }
    }
}

// MARK: - MethodologyOverviewDTO
struct MethodologyOverviewDTO: Codable {
    let name: String
    let philosophy: String
    let intensityStyle: String
    let intensityDescription: String

    enum CodingKeys: String, CodingKey {
        case name
        case philosophy
        case intensityStyle = "intensity_style"
        case intensityDescription = "intensity_description"
    }
}

// MARK: - TrainingStageDTO
struct TrainingStageDTO: Codable {
    let stageId: String
    let stageName: String
    let stageDescription: String
    let weekStart: Int
    let weekEnd: Int
    let trainingFocus: String
    let targetWeeklyKmRange: TargetWeeklyKmRangeDTO
    let targetWeeklyKmRangeDisplay: TargetWeeklyKmRangeDisplayDTO?
    let intensityRatio: IntensityDistributionDTO?
    let keyWorkouts: [String]?

    enum CodingKeys: String, CodingKey {
        case stageId = "stage_id"
        case stageName = "stage_name"
        case stageDescription = "stage_description"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case trainingFocus = "training_focus"
        case targetWeeklyKmRange = "target_weekly_km_range"
        case targetWeeklyKmRangeDisplay = "target_weekly_km_range_display"
        case intensityRatio = "intensity_ratio"
        case keyWorkouts = "key_workouts"
    }
}

// MARK: - TargetWeeklyKmRangeDisplayDTO
/// 英制用戶的週跑量顯示值（公制用戶不回傳此欄位）
struct TargetWeeklyKmRangeDisplayDTO: Codable {
    let lowDisplay: Double
    let highDisplay: Double
    let distanceUnit: String

    enum CodingKeys: String, CodingKey {
        case lowDisplay = "low_display"
        case highDisplay = "high_display"
        case distanceUnit = "distance_unit"
    }
}

// MARK: - TargetWeeklyKmRangeDTO
struct TargetWeeklyKmRangeDTO: Codable {
    let low: Double
    let high: Double
}

// MARK: - IntensityDistributionDTO
struct IntensityDistributionDTO: Codable {
    let low: Double
    let medium: Double
    let high: Double
}

// MARK: - MilestoneDTO
struct MilestoneDTO: Codable {
    let week: Int
    let milestoneType: String
    let title: String
    let description: String
    let isKeyMilestone: Bool

    enum CodingKeys: String, CodingKey {
        case week
        case milestoneType = "milestone_type"
        case title
        case description
        case isKeyMilestone = "is_key_milestone"
    }
}
