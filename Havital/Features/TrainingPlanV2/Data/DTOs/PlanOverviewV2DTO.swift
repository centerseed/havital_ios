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
    let methodologyId: String
    let totalWeeks: Int
    let startFromStage: String

    // Target 核心字段
    let raceDate: Int?
    let distanceKm: Double?
    let targetPace: String?
    let targetTime: Int?
    let isMainRace: Bool?
    let targetName: String?

    // 方法論概覽
    let methodologyOverview: MethodologyOverviewDTO?

    // 評估與概要
    let targetEvaluate: String
    let approachSummary: String

    // 訓練結構
    let trainingStages: [TrainingStageDTO]
    let milestones: [MilestoneDTO]
    let weeklyPreview: [WeeklyPreviewDTO]

    // Metadata
    let createdAt: String?
    let methodologyVersion: String

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
        case targetPace = "target_pace"
        case targetTime = "target_time"
        case isMainRace = "is_main_race"
        case targetName = "target_name"
        case methodologyOverview = "methodology_overview"
        case targetEvaluate = "target_evaluate"
        case approachSummary = "approach_summary"
        case trainingStages = "training_stages"
        case milestones
        case weeklyPreview = "weekly_preview"
        case createdAt = "created_at"
        case methodologyVersion = "methodology_version"
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
        case intensityRatio = "intensity_ratio"
        case keyWorkouts = "key_workouts"
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

// MARK: - WeeklyPreviewDTO
struct WeeklyPreviewDTO: Codable {
    let week: Int
    let stageId: String
    let targetKm: Double
    let dailySchedule: [DailyScheduleItemDTO]
    let intensityDistribution: IntensityDistributionDTO
    let milestoneRef: String?

    enum CodingKeys: String, CodingKey {
        case week
        case stageId = "stage_id"
        case targetKm = "target_km"
        case dailySchedule = "daily_schedule"
        case intensityDistribution = "intensity_distribution"
        case milestoneRef = "milestone_ref"
    }
}

// MARK: - DailyScheduleItemDTO
struct DailyScheduleItemDTO: Codable {
    let dayOfWeek: Int
    let trainingType: String
    let isKeyWorkout: Bool

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case trainingType = "training_type"
        case isKeyWorkout = "is_key_workout"
    }
}

// MARK: - API Response Wrapper
/// API 響應包裝器
struct PlanOverviewV2Response: Codable {
    let success: Bool
    let message: String?
    let data: PlanOverviewV2DTO
}
