import Foundation

// MARK: - WeeklySummaryV2 Entity
/// 週訓練摘要 V2 - Domain Layer 業務實體
/// 整合訓練分析、能力進展、調整建議等
/// ✅ 符合 Codable 以支援本地緩存
struct WeeklySummaryV2: Codable, Equatable {

    // MARK: - 基本資訊

    /// 週摘要 ID
    let id: String

    /// 用戶 ID
    let uid: String

    /// 關聯的週課表 ID
    let weeklyPlanId: String

    /// 關聯的訓練概覽 ID
    let trainingOverviewId: String

    /// 訓練週次
    let weekOfTraining: Int

    /// 創建時間
    let createdAt: Date?

    // MARK: - 摘要內容

    /// 計畫上下文摘要
    let planContext: PlanContextSummary?

    /// 訓練完成度
    let trainingCompletion: TrainingCompletionV2

    /// 訓練分析
    let trainingAnalysis: TrainingAnalysisV2

    /// Readiness 指標摘要（根據 target_type 選擇性填充）
    let readinessSummary: ReadinessSummary?

    /// 能力進展追蹤
    let capabilityProgression: CapabilityProgression?

    /// 里程碑進度
    let milestoneProgress: MilestoneProgress?

    /// 歷史對比摘要
    let historicalComparison: HistoricalComparisonSummary?

    /// 當週亮點
    let weeklyHighlights: WeeklyHighlightsV2

    /// 即將到來的賽事評估（race_run only）
    let upcomingRaceEvaluation: UpcomingRaceEvaluationV2?

    /// 下週調整建議
    let nextWeekAdjustments: NextWeekAdjustmentsV2

    /// 休息週建議
    let restWeekRecommendation: RestWeekAssessment?

    /// 最終訓練歷程回顧（最終週填充）
    let finalTrainingReview: FinalTrainingReview?

    /// Prompt audit ID
    let promptAuditId: String?

    /// 系統確定性觀察項（如跑量漸進敘事）
    let observations: [String]?

    /// 週故事化敘事（LLM 生成，三欄：本週主線、連貫主軸、行動鉤）
    let weeklyStory: WeeklyStory?

    /// decision-chain 週回顧首屏資料；舊週沒有這欄時保持 nil，走既有畫面。
    var decisionChain: DecisionChainWeeklySummary? = nil
    /// 週回顧現讀序列的日期上下文；舊 payload 沒有時保持 nil。
    var localWeekEndExclusive: String? = nil
    var inputAsOf: String? = nil

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
        case observations
        case weeklyStory = "weekly_story"
        case decisionChain = "decision_chain"
        case localWeekEndExclusive = "local_week_end_exclusive"
        case inputAsOf = "input_as_of"
    }
}

// MARK: - Nested Entities

// MARK: - PlanContextSummary
/// 計畫上下文摘要
struct PlanContextSummary: Codable, Equatable {
    let targetType: String
    let methodologyId: String
    let methodologyName: String
    let currentPhase: String
    let phaseWeek: Int
    let phaseTotalWeeks: Int
    let totalWeeks: Int
    let weeksRemaining: Int
    let currentStageDescription: String
    let upcomingMilestone: MilestoneRef?

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

// MARK: - MilestoneRef
/// 里程碑參照
struct MilestoneRef: Codable, Equatable {
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

// MARK: - TrainingCompletionV2
/// 訓練完成度
struct TrainingCompletionV2: Codable, Equatable {
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

// MARK: - TrainingAnalysisV2
/// 訓練分析
struct TrainingAnalysisV2: Codable, Equatable {
    let heartRate: HeartRateAnalysisV2?
    let pace: PaceAnalysisV2?
    let distance: DistanceAnalysisV2?
    let intensityDistribution: IntensityDistributionAnalysisV2?

    enum CodingKeys: String, CodingKey {
        case heartRate = "heart_rate"
        case pace
        case distance
        case intensityDistribution = "intensity_distribution"
    }
}

// MARK: - Analysis Sub-entities
struct HeartRateAnalysisV2: Codable, Equatable {
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

struct PaceAnalysisV2: Codable, Equatable {
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

struct DistanceAnalysisV2: Codable, Equatable {
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

struct IntensityDistributionAnalysisV2: Codable, Equatable {
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

// MARK: - ReadinessSummary
/// Readiness 指標摘要（根據 target_type 選擇性填充）
struct ReadinessSummary: Codable, Equatable {
    let speed: SpeedSummary?
    let endurance: EnduranceSummary?
    let trainingLoad: TrainingLoadSummary?
    let raceFitness: RaceFitnessSummary?
    let mileage: MileageSummary?
    let overallReadinessScore: Double?
    let overallStatus: String?
    let flags: [ReadinessFlag]

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

struct SpeedSummary: Codable, Equatable {
    let score: Double
    let achievementRate: Double?
    let trend: String
    let trendData: [TrendDataPoint]
    let evaluation: String

    enum CodingKeys: String, CodingKey {
        case score
        case achievementRate = "achievement_rate"
        case trend
        case trendData = "trend_data"
        case evaluation
    }
}

struct EnduranceSummary: Codable, Equatable {
    let score: Double
    let avgEsc: Double?
    let longRunCompletion: Double?
    let volumeConsistency: Double?
    let trend: String
    let trendData: [TrendDataPoint]
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

struct TrainingLoadSummary: Codable, Equatable {
    let score: Double
    let currentTsb: Double?
    let ctl: Double?
    let atl: Double?
    let balanceStatus: String
    let isInOptimalRange: Bool
    let deviation: Double?
    let trendData: [TrendDataPoint]
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

struct RaceFitnessSummary: Codable, Equatable {
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
    let trendData: [TrendDataPoint]
    let evaluation: String
    /// VDOT 來源："benchmark" 表示由指標跑校準，"training" 表示由訓練資料估算
    let vdotSource: String?
    /// 最近指標跑日期，格式 YYYY-MM-DD（僅 vdotSource == "benchmark" 時有值）
    let benchmarkDate: String?

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
        case vdotSource = "vdot_source"
        case benchmarkDate = "benchmark_date"
    }
}

struct MileageSummary: Codable, Equatable {
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

struct ReadinessFlag: Codable, Equatable {
    let level: String
    let metric: String
    let message: String
    let recommendedAction: String

    enum CodingKeys: String, CodingKey {
        case level, metric, message
        case recommendedAction = "recommended_action"
    }
}

struct TrendDataPoint: Codable, Equatable {
    let date: String
    let value: Double
    let label: String?
}

// MARK: - CapabilityProgression
/// 能力進展追蹤
struct CapabilityProgression: Codable, Equatable {
    let vdotProgression: VdotProgression?
    let speedProgression: MetricProgression?
    let enduranceProgression: MetricProgression?
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

struct VdotProgression: Codable, Equatable {
    let baselineVdot: Double
    let currentVdot: Double
    let targetVdot: Double?
    let progressPercentage: Double
    let trend: String
    let chartData: [TrendDataPoint]
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

struct MetricProgression: Codable, Equatable {
    let startValue: Double
    let currentValue: Double
    let changePercentage: Double
    let trend: String
    let chartData: [TrendDataPoint]
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

// MARK: - MilestoneProgress
/// 里程碑進度
struct MilestoneProgress: Codable, Equatable {
    let achievedMilestones: [MilestoneRef]
    let upcomingMilestones: [MilestoneRef]
    let currentPhaseCompletion: Double

    enum CodingKeys: String, CodingKey {
        case achievedMilestones = "achieved_milestones"
        case upcomingMilestones = "upcoming_milestones"
        case currentPhaseCompletion = "current_phase_completion"
    }
}

// MARK: - HistoricalComparisonSummary
/// 4週進展對比摘要
struct HistoricalComparisonSummary: Codable, Equatable {
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

// MARK: - WeeklyHighlightsV2
/// 當週亮點
struct WeeklyHighlightsV2: Codable, Equatable {
    let highlights: [String]
    let achievements: [String]
    let areasForImprovement: [String]

    enum CodingKeys: String, CodingKey {
        case highlights, achievements
        case areasForImprovement = "areas_for_improvement"
    }
}

// MARK: - UpcomingRaceEvaluationV2
/// 即將到來的賽事評估（race_run only）
struct UpcomingRaceEvaluationV2: Codable, Equatable {
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

// MARK: - NextWeekAdjustmentsV2

/// 使用者自然語言編輯週回顧的狀態
enum UserNlEditStatus: String, Codable, Equatable {
    case none, pending, applied, failed
}

/// 下週調整建議
struct NextWeekAdjustmentsV2: Codable, Equatable {
    let items: [AdjustmentItemV2]
    let summary: String
    let methodologyConstraintsConsidered: Bool
    let basedOnFlags: [String]
    let userNlEdit: String?
    let userNlEditStatus: UserNlEditStatus
    let userNlEditFailReason: String?

    enum CodingKeys: String, CodingKey {
        case items, summary
        case methodologyConstraintsConsidered = "methodology_constraints_considered"
        case basedOnFlags = "based_on_flags"
        case userNlEdit = "user_nl_edit"
        case userNlEditStatus = "user_nl_edit_status"
        case userNlEditFailReason = "user_nl_edit_fail_reason"
    }

    init(
        items: [AdjustmentItemV2],
        summary: String,
        methodologyConstraintsConsidered: Bool,
        basedOnFlags: [String],
        userNlEdit: String?,
        userNlEditStatus: UserNlEditStatus,
        userNlEditFailReason: String?
    ) {
        self.items = items
        self.summary = summary
        self.methodologyConstraintsConsidered = methodologyConstraintsConsidered
        self.basedOnFlags = basedOnFlags
        self.userNlEdit = userNlEdit
        self.userNlEditStatus = userNlEditStatus
        self.userNlEditFailReason = userNlEditFailReason
    }

    /// Custom decode so old UserDefaults cache JSON (without the user_nl_edit_* keys)
    /// decodes safely: the non-optional `userNlEditStatus` falls back to `.none`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decode([AdjustmentItemV2].self, forKey: .items)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.methodologyConstraintsConsidered = try container.decode(Bool.self, forKey: .methodologyConstraintsConsidered)
        self.basedOnFlags = try container.decode([String].self, forKey: .basedOnFlags)
        self.userNlEdit = try container.decodeIfPresent(String.self, forKey: .userNlEdit)
        self.userNlEditStatus = try container.decodeIfPresent(UserNlEditStatus.self, forKey: .userNlEditStatus) ?? .none
        self.userNlEditFailReason = try container.decodeIfPresent(String.self, forKey: .userNlEditFailReason)
    }
}

struct AdjustmentItemV2: Codable, Equatable {
    let content: String
    let category: String
    let apply: Bool
    let slotType: String?
    let trainingType: String?
    let reason: String
    let impact: String
    let sourceFlag: String?
    let priority: String
    // Typed benchmark payloads — set by Mapper, not decoded from wire
    var benchmarkExecute: BenchmarkExecutePayload? = nil
    var benchmarkCalibration: BenchmarkCalibrationPayload? = nil

    enum CodingKeys: String, CodingKey {
        case content, category, apply
        case slotType = "slot_type"
        case trainingType = "training_type"
        case reason, impact
        case sourceFlag = "source_flag"
        case priority
        // benchmarkExecute/benchmarkCalibration are NOT decoded from wire JSON
        // (the API path uses AdjustmentItemV2DTO + Mapper). They ARE included here so
        // the local UserDefaults cache (Codable round-trip) preserves them — otherwise a
        // cache hit returns nil payloads and the dedicated benchmark cards degrade to the
        // plain card. Optional with `= nil` default → old cache entries decode safely.
        case benchmarkExecute
        case benchmarkCalibration
    }
}

// MARK: - Benchmark Payload Types

/// Payload for "execute_benchmark" adjustment items.
struct BenchmarkExecutePayload: Codable, Equatable {
    let distanceKm: Double
    let scheduledWeekday: Int?
}

/// Payload for "adjust_vdot" adjustment items.
struct BenchmarkCalibrationPayload: Codable, Equatable {
    let workoutDate: String?
    let distanceKm: Double
    let durationS: Double
    let shouldHedge: Bool
    let paceBeforeSPerKm: Int?
    let paceAfterSPerKm: Int?
    let raceDistanceLabel: String?
    let raceTimeBeforeS: Int?
    let raceTimeAfterS: Int?
    let vdotBefore: Double?
    let vdotAfter: Double?
}

// MARK: - WeeklyStory
/// 週故事化敘事 entity（對應 WeeklyStoryDTO，三欄全 optional）
struct WeeklyStory: Codable, Equatable {
    let text: String?
    let thread: String?
    let callback: String?
}

// MARK: - Decision-chain weekly review

/// §4.2a 的 focus 只帶判斷材料，不帶任何數值；數值由 App 讀 metrics/series 現算。
struct DecisionChainFocus: Codable, Equatable {
    let kind: String
    let metric: String
    let direction: String
    let startDay: String
    let endDay: String
    let hypothesisId: String?
    let intervention: String?
    let verdict: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case kind, metric, direction
        case startDay = "start_day"
        case endDay = "end_day"
        case hypothesisId = "hypothesis_id"
        case intervention, verdict, reason
    }
}

struct DecisionChainNarrative: Codable, Equatable {
    let headline: String
    let retrospect: String
    let nextWeek: String

    enum CodingKeys: String, CodingKey {
        case headline, retrospect
        case nextWeek = "next_week"
    }
}

struct DecisionChainExecution: Codable, Equatable {
    let completedKm: Double?
    let plannedKm: Double?
    let runCount: Int?
    let qualityCount: Int?

    enum CodingKeys: String, CodingKey {
        case completedKm = "completed_km"
        case plannedKm = "planned_km"
        case runCount = "run_count"
        case qualityCount = "quality_count"
    }
}

struct DecisionChainWeeklySummary: Codable, Equatable {
    let asOf: String?
    let focus: DecisionChainFocus?
    let narrative: DecisionChainNarrative?
    let execution: DecisionChainExecution?

    init(
        asOf: String? = nil,
        focus: DecisionChainFocus?,
        narrative: DecisionChainNarrative?,
        execution: DecisionChainExecution?
    ) {
        self.asOf = asOf
        self.focus = focus
        self.narrative = narrative
        self.execution = execution
    }
}

// CustomizationRecommendation 已移除（2026-04-05）
// 後端 customization_recommendations 欄位廢棄，不再由 LLM 填充。
// 統一使用 AdjustmentItemV2 作為建議結構。

// MARK: - RestWeekAssessment
/// 休息週建議
struct RestWeekAssessment: Codable, Equatable {
    let recommended: Bool
    let reason: String?
    let fatigueIndicators: [String]

    enum CodingKeys: String, CodingKey {
        case recommended, reason
        case fatigueIndicators = "fatigue_indicators"
    }
}

// MARK: - FinalTrainingReview
/// 最終訓練歷程回顧（最終週填充）
struct FinalTrainingReview: Codable, Equatable {
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
