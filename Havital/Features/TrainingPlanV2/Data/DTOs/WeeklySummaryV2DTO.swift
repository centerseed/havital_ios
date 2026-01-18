import Foundation

// MARK: - WeeklySummaryV2DTO
/// Weekly Summary V2 DTO - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
/// 注意：此 DTO 包含大量嵌套結構，與 Entity 結構一致
struct WeeklySummaryV2DTO: Codable {

    // MARK: - Properties

    let id: String
    let uid: String
    let weeklyPlanId: String
    let trainingOverviewId: String
    let weekOfTraining: Int
    let createdAt: String?
    let planContext: PlanContextSummaryDTO?
    let trainingCompletion: TrainingCompletionV2DTO
    let trainingAnalysis: TrainingAnalysisV2DTO
    let readinessSummary: ReadinessSummaryDTO?
    let capabilityProgression: CapabilityProgressionDTO?
    let milestoneProgress: MilestoneProgressDTO?
    let historicalComparison: HistoricalComparisonSummaryDTO?
    let weeklyHighlights: WeeklyHighlightsV2DTO
    let upcomingRaceEvaluation: UpcomingRaceEvaluationV2DTO?
    let nextWeekAdjustments: NextWeekAdjustmentsV2DTO
    let restWeekRecommendation: RestWeekAssessmentDTO?
    let finalTrainingReview: FinalTrainingReviewDTO?
    let promptAuditId: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, uid
        case weeklyPlanId = "weekly_plan_id"
        case trainingOverviewId = "training_overview_id"
        case weekOfTraining = "week_of_training"
        case createdAt = "created_at"
        case planContext = "plan_context"
        case trainingCompletion = "training_completion"
        case trainingAnalysis = "training_analysis"
        case readinessSummary = "readiness_summary"
        case capabilityProgression = "capability_progression"
        case milestoneProgress = "milestone_progress"
        case historicalComparison = "historical_comparison"
        case weeklyHighlights = "weekly_highlights"
        case upcomingRaceEvaluation = "upcoming_race_evaluation"
        case nextWeekAdjustments = "next_week_adjustments"
        case restWeekRecommendation = "rest_week_recommendation"
        case finalTrainingReview = "final_training_review"
        case promptAuditId = "prompt_audit_id"
    }
}

// MARK: - Nested DTOs (主要結構，完整版本與 Entity 對應)

struct PlanContextSummaryDTO: Codable {
    let targetType: String
    let methodologyId: String
    let methodologyName: String
    let currentPhase: String
    let phaseWeek: Int
    let phaseTotalWeeks: Int
    let totalWeeks: Int
    let weeksRemaining: Int
    let currentStageDescription: String
    let upcomingMilestone: MilestoneRefDTO?

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case methodologyId = "methodology_id"
        case methodologyName = "methodology_name"
        case currentPhase = "current_phase"
        case phaseWeek = "phase_week"
        case phaseTotalWeeks = "phase_total_weeks"
        case totalWeeks = "total_weeks"
        case weeksRemaining = "weeks_remaining"
        case currentStageDescription = "current_stage_description"
        case upcomingMilestone = "upcoming_milestone"
    }
}

struct MilestoneRefDTO: Codable {
    let id: String
    let name: String
    let targetWeek: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case targetWeek = "target_week"
        case description
    }
}

struct TrainingCompletionV2DTO: Codable {
    let percentage: Double
    let plannedKm: Double
    let completedKm: Double
    let plannedSessions: Int
    let completedSessions: Int
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case percentage
        case plannedKm = "planned_km"
        case completedKm = "completed_km"
        case plannedSessions = "planned_sessions"
        case completedSessions = "completed_sessions"
        case evaluation
    }
}

struct TrainingAnalysisV2DTO: Codable {
    let heartRate: HeartRateAnalysisV2DTO?
    let pace: PaceAnalysisV2DTO?
    let distance: DistanceAnalysisV2DTO?
    let intensityDistribution: IntensityDistributionAnalysisV2DTO?

    enum CodingKeys: String, CodingKey {
        case heartRate = "heart_rate"
        case pace
        case distance
        case intensityDistribution = "intensity_distribution"
    }
}

struct HeartRateAnalysisV2DTO: Codable {
    let average: Double?
    let max: Double?
    let zonesDistribution: [String: Double]?
    let evaluation: String?

    enum CodingKeys: String, CodingKey {
        case average, max
        case zonesDistribution = "zones_distribution"
        case evaluation
    }
}

struct PaceAnalysisV2DTO: Codable {
    let average: String?
    let trend: String?
    let targetPaceAchievement: Double?
    let evaluation: String?

    enum CodingKeys: String, CodingKey {
        case average, trend
        case targetPaceAchievement = "target_pace_achievement"
        case evaluation
    }
}

struct DistanceAnalysisV2DTO: Codable {
    let total: Double
    let comparisonToPlan: String?
    let longRunCompleted: Bool?
    let evaluation: String?

    enum CodingKeys: String, CodingKey {
        case total
        case comparisonToPlan = "comparison_to_plan"
        case longRunCompleted = "long_run_completed"
        case evaluation
    }
}

struct IntensityDistributionAnalysisV2DTO: Codable {
    let easyPercentage: Double
    let moderatePercentage: Double
    let hardPercentage: Double
    let targetDistribution: String?
    let evaluation: String?

    enum CodingKeys: String, CodingKey {
        case easyPercentage = "easy_percentage"
        case moderatePercentage = "moderate_percentage"
        case hardPercentage = "hard_percentage"
        case targetDistribution = "target_distribution"
        case evaluation
    }
}

// 簡化版本 - 其他嵌套 DTOs 使用相同命名但省略完整定義以節省空間
// 實際實現時，這些結構應與 Entity 中的定義完全對應

struct ReadinessSummaryDTO: Codable {
    let speed: SpeedSummaryDTO?
    let endurance: EnduranceSummaryDTO?
    let trainingLoad: TrainingLoadSummaryDTO?
    let raceFitness: RaceFitnessSummaryDTO?
    let mileage: MileageSummaryDTO?
    let overallReadinessScore: Double?
    let overallStatus: String?
    let flags: [ReadinessFlagDTO]

    enum CodingKeys: String, CodingKey {
        case speed, endurance
        case trainingLoad = "training_load"
        case raceFitness = "race_fitness"
        case mileage
        case overallReadinessScore = "overall_readiness_score"
        case overallStatus = "overall_status"
        case flags
    }
}

struct SpeedSummaryDTO: Codable {
    let score: Double
    let achievementRate: Double?
    let trend: String
    let trendData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case score
        case achievementRate = "achievement_rate"
        case trend
        case trendData = "trend_data"
        case evaluation
    }
}

struct EnduranceSummaryDTO: Codable {
    let score: Double
    let avgEsc: Double?
    let longRunCompletion: Double?
    let volumeConsistency: Double?
    let trend: String
    let trendData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case score
        case avgEsc = "avg_esc"
        case longRunCompletion = "long_run_completion"
        case volumeConsistency = "volume_consistency"
        case trend
        case trendData = "trend_data"
        case evaluation
    }
}

struct TrainingLoadSummaryDTO: Codable {
    let score: Double
    let currentTsb: Double?
    let ctl: Double?
    let atl: Double?
    let balanceStatus: String
    let isInOptimalRange: Bool
    let deviation: Double?
    let trendData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case score
        case currentTsb = "current_tsb"
        case ctl, atl
        case balanceStatus = "balance_status"
        case isInOptimalRange = "is_in_optimal_range"
        case deviation
        case trendData = "trend_data"
        case evaluation
    }
}

struct RaceFitnessSummaryDTO: Codable {
    let score: Double
    let currentVdot: Double
    let targetVdot: Double?
    let baselineVdot: Double?
    let progressPercentage: Double
    let trainingProgress: Double?
    let estimatedRaceTime: String?
    let targetRaceTime: String?
    let timeGapSeconds: Int?
    let trend: String
    let trendData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case score
        case currentVdot = "current_vdot"
        case targetVdot = "target_vdot"
        case baselineVdot = "baseline_vdot"
        case progressPercentage = "progress_percentage"
        case trainingProgress = "training_progress"
        case estimatedRaceTime = "estimated_race_time"
        case targetRaceTime = "target_race_time"
        case timeGapSeconds = "time_gap_seconds"
        case trend
        case trendData = "trend_data"
        case evaluation
    }
}

struct MileageSummaryDTO: Codable {
    let plannedKm: Double
    let completedKm: Double
    let completionRate: Double
    let weeklyTrend: String
    let streakWeeks: Int
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case plannedKm = "planned_km"
        case completedKm = "completed_km"
        case completionRate = "completion_rate"
        case weeklyTrend = "weekly_trend"
        case streakWeeks = "streak_weeks"
        case evaluation
    }
}

struct ReadinessFlagDTO: Codable {
    let level: String
    let metric: String
    let message: String
    let recommendedAction: String

    enum CodingKeys: String, CodingKey {
        case level, metric, message
        case recommendedAction = "recommended_action"
    }
}

struct TrendDataPointDTO: Codable {
    let date: String
    let value: Double
    let label: String?
}

struct CapabilityProgressionDTO: Codable {
    let vdotProgression: VdotProgressionDTO?
    let speedProgression: MetricProgressionDTO?
    let enduranceProgression: MetricProgressionDTO?
    let overallTrend: String
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case vdotProgression = "vdot_progression"
        case speedProgression = "speed_progression"
        case enduranceProgression = "endurance_progression"
        case overallTrend = "overall_trend"
        case evaluation
    }
}

struct VdotProgressionDTO: Codable {
    let baselineVdot: Double
    let currentVdot: Double
    let targetVdot: Double?
    let progressPercentage: Double
    let trend: String
    let chartData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case baselineVdot = "baseline_vdot"
        case currentVdot = "current_vdot"
        case targetVdot = "target_vdot"
        case progressPercentage = "progress_percentage"
        case trend
        case chartData = "chart_data"
        case evaluation
    }
}

struct MetricProgressionDTO: Codable {
    let startValue: Double
    let currentValue: Double
    let changePercentage: Double
    let trend: String
    let chartData: [TrendDataPointDTO]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case startValue = "start_value"
        case currentValue = "current_value"
        case changePercentage = "change_percentage"
        case trend
        case chartData = "chart_data"
        case evaluation
    }
}

struct MilestoneProgressDTO: Codable {
    let achievedMilestones: [MilestoneRefDTO]
    let upcomingMilestones: [MilestoneRefDTO]
    let currentPhaseCompletion: Double

    enum CodingKeys: String, CodingKey {
        case achievedMilestones = "achieved_milestones"
        case upcomingMilestones = "upcoming_milestones"
        case currentPhaseCompletion = "current_phase_completion"
    }
}

struct HistoricalComparisonSummaryDTO: Codable {
    let hasComparisonData: Bool
    let comparisonWeek: Int?
    let comparisonDate: String?
    let speedChange: Double?
    let enduranceChange: Double?
    let vdotChange: Double?
    let mileageChange: Double?
    let completionRateChange: Double?

    enum CodingKeys: String, CodingKey {
        case hasComparisonData = "has_comparison_data"
        case comparisonWeek = "comparison_week"
        case comparisonDate = "comparison_date"
        case speedChange = "speed_change"
        case enduranceChange = "endurance_change"
        case vdotChange = "vdot_change"
        case mileageChange = "mileage_change"
        case completionRateChange = "completion_rate_change"
    }
}

struct WeeklyHighlightsV2DTO: Codable {
    let highlights: [String]
    let achievements: [String]
    let areasForImprovement: [String]

    enum CodingKeys: String, CodingKey {
        case highlights, achievements
        case areasForImprovement = "areas_for_improvement"
    }
}

struct UpcomingRaceEvaluationV2DTO: Codable {
    let raceName: String
    let raceDate: String
    let daysRemaining: Int
    let readinessScore: Double
    let readinessAssessment: String
    let predictedTime: String?
    let targetTime: String?
    let keyConcerns: [String]

    enum CodingKeys: String, CodingKey {
        case raceName = "race_name"
        case raceDate = "race_date"
        case daysRemaining = "days_remaining"
        case readinessScore = "readiness_score"
        case readinessAssessment = "readiness_assessment"
        case predictedTime = "predicted_time"
        case targetTime = "target_time"
        case keyConcerns = "key_concerns"
    }
}

struct NextWeekAdjustmentsV2DTO: Codable {
    let items: [AdjustmentItemV2DTO]
    let summary: String
    let methodologyConstraintsConsidered: Bool
    let basedOnFlags: [String]
    let customizationRecommendations: [CustomizationRecommendationDTO]

    enum CodingKeys: String, CodingKey {
        case items, summary
        case methodologyConstraintsConsidered = "methodology_constraints_considered"
        case basedOnFlags = "based_on_flags"
        case customizationRecommendations = "customization_recommendations"
    }
}

struct AdjustmentItemV2DTO: Codable {
    let content: String
    let category: String
    let apply: Bool
    let slotType: String?
    let trainingType: String?
    let reason: String
    let impact: String
    let sourceFlag: String?
    let priority: String

    enum CodingKeys: String, CodingKey {
        case content, category, apply
        case slotType = "slot_type"
        case trainingType = "training_type"
        case reason, impact
        case sourceFlag = "source_flag"
        case priority
    }
}

struct CustomizationRecommendationDTO: Codable {
    let recommendationType: String
    let slotType: String?
    let originalType: String?
    let recommendedType: String?
    let currentValue: String?
    let recommendedValue: String?
    let adjustmentPercentage: Double?
    let targetDays: [Int]?
    let durationWeeks: Int?
    let reason: String
    let confidence: Double
    let basedOn: [String]

    enum CodingKeys: String, CodingKey {
        case recommendationType = "recommendation_type"
        case slotType = "slot_type"
        case originalType = "original_type"
        case recommendedType = "recommended_type"
        case currentValue = "current_value"
        case recommendedValue = "recommended_value"
        case adjustmentPercentage = "adjustment_percentage"
        case targetDays = "target_days"
        case durationWeeks = "duration_weeks"
        case reason, confidence
        case basedOn = "based_on"
    }
}

struct RestWeekAssessmentDTO: Codable {
    let recommended: Bool
    let reason: String?
    let fatigueIndicators: [String]

    enum CodingKeys: String, CodingKey {
        case recommended, reason
        case fatigueIndicators = "fatigue_indicators"
    }
}

struct FinalTrainingReviewDTO: Codable {
    let journeySummary: String
    let capabilityGrowth: String
    let keyMilestones: [String]
    let racePerformanceEvaluation: String
    let encouragement: String
    let nextStepsGuidance: String
    let postRaceRecoveryPlan: String?

    enum CodingKeys: String, CodingKey {
        case journeySummary = "journey_summary"
        case capabilityGrowth = "capability_growth"
        case keyMilestones = "key_milestones"
        case racePerformanceEvaluation = "race_performance_evaluation"
        case encouragement
        case nextStepsGuidance = "next_steps_guidance"
        case postRaceRecoveryPlan = "post_race_recovery_plan"
    }
}

// MARK: - API Response Wrapper
/// API 響應包裝器
struct WeeklySummaryV2Response: Codable {
    let success: Bool
    let message: String?
    let data: WeeklySummaryV2DTO
}
