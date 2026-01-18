import Foundation

// MARK: - WeeklySummaryV2Mapper
/// Weekly Summary V2 Mapper - Data Layer
/// 負責 DTO ↔ Entity 雙向轉換
/// 注意：此 Mapper 包含大量嵌套轉換，與 Entity/DTO 結構對應
enum WeeklySummaryV2Mapper {

    // MARK: - DTO → Entity (主要轉換)

    /// 將 WeeklySummaryV2DTO 轉換為 WeeklySummaryV2 Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: WeeklySummaryV2DTO) -> WeeklySummaryV2 {
        return WeeklySummaryV2(
            id: dto.id,
            uid: dto.uid,
            weeklyPlanId: dto.weeklyPlanId,
            trainingOverviewId: dto.trainingOverviewId,
            weekOfTraining: dto.weekOfTraining,
            createdAt: parseDate(from: dto.createdAt),
            planContext: dto.planContext.map { toPlanContext(from: $0) },
            trainingCompletion: toTrainingCompletion(from: dto.trainingCompletion),
            trainingAnalysis: toTrainingAnalysis(from: dto.trainingAnalysis),
            readinessSummary: dto.readinessSummary.map { toReadinessSummary(from: $0) },
            capabilityProgression: dto.capabilityProgression.map { toCapabilityProgression(from: $0) },
            milestoneProgress: dto.milestoneProgress.map { toMilestoneProgress(from: $0) },
            historicalComparison: dto.historicalComparison.map { toHistoricalComparison(from: $0) },
            weeklyHighlights: toWeeklyHighlights(from: dto.weeklyHighlights),
            upcomingRaceEvaluation: dto.upcomingRaceEvaluation.map { toUpcomingRaceEvaluation(from: $0) },
            nextWeekAdjustments: toNextWeekAdjustments(from: dto.nextWeekAdjustments),
            restWeekRecommendation: dto.restWeekRecommendation.map { toRestWeekAssessment(from: $0) },
            finalTrainingReview: dto.finalTrainingReview.map { toFinalTrainingReview(from: $0) },
            promptAuditId: dto.promptAuditId
        )
    }

    // MARK: - Nested Conversions (DTO → Entity)

    private static func toPlanContext(from dto: PlanContextSummaryDTO) -> PlanContextSummary {
        return PlanContextSummary(
            targetType: dto.targetType,
            methodologyId: dto.methodologyId,
            methodologyName: dto.methodologyName,
            currentPhase: dto.currentPhase,
            phaseWeek: dto.phaseWeek,
            phaseTotalWeeks: dto.phaseTotalWeeks,
            totalWeeks: dto.totalWeeks,
            weeksRemaining: dto.weeksRemaining,
            currentStageDescription: dto.currentStageDescription,
            upcomingMilestone: dto.upcomingMilestone.map { toMilestoneRef(from: $0) }
        )
    }

    private static func toMilestoneRef(from dto: MilestoneRefDTO) -> MilestoneRef {
        return MilestoneRef(
            id: dto.id,
            name: dto.name,
            targetWeek: dto.targetWeek,
            description: dto.description
        )
    }

    private static func toTrainingCompletion(from dto: TrainingCompletionV2DTO) -> TrainingCompletionV2 {
        return TrainingCompletionV2(
            percentage: dto.percentage,
            plannedKm: dto.plannedKm,
            completedKm: dto.completedKm,
            plannedSessions: dto.plannedSessions,
            completedSessions: dto.completedSessions,
            evaluation: dto.evaluation
        )
    }

    private static func toTrainingAnalysis(from dto: TrainingAnalysisV2DTO) -> TrainingAnalysisV2 {
        return TrainingAnalysisV2(
            heartRate: dto.heartRate.map { toHeartRateAnalysis(from: $0) },
            pace: dto.pace.map { toPaceAnalysis(from: $0) },
            distance: dto.distance.map { toDistanceAnalysis(from: $0) },
            intensityDistribution: dto.intensityDistribution.map { toIntensityDistributionAnalysis(from: $0) }
        )
    }

    private static func toHeartRateAnalysis(from dto: HeartRateAnalysisV2DTO) -> HeartRateAnalysisV2 {
        return HeartRateAnalysisV2(
            average: dto.average,
            max: dto.max,
            zonesDistribution: dto.zonesDistribution,
            evaluation: dto.evaluation
        )
    }

    private static func toPaceAnalysis(from dto: PaceAnalysisV2DTO) -> PaceAnalysisV2 {
        return PaceAnalysisV2(
            average: dto.average,
            trend: dto.trend,
            targetPaceAchievement: dto.targetPaceAchievement,
            evaluation: dto.evaluation
        )
    }

    private static func toDistanceAnalysis(from dto: DistanceAnalysisV2DTO) -> DistanceAnalysisV2 {
        return DistanceAnalysisV2(
            total: dto.total,
            comparisonToPlan: dto.comparisonToPlan,
            longRunCompleted: dto.longRunCompleted,
            evaluation: dto.evaluation
        )
    }

    private static func toIntensityDistributionAnalysis(from dto: IntensityDistributionAnalysisV2DTO) -> IntensityDistributionAnalysisV2 {
        return IntensityDistributionAnalysisV2(
            easyPercentage: dto.easyPercentage,
            moderatePercentage: dto.moderatePercentage,
            hardPercentage: dto.hardPercentage,
            targetDistribution: dto.targetDistribution,
            evaluation: dto.evaluation
        )
    }

    private static func toReadinessSummary(from dto: ReadinessSummaryDTO) -> ReadinessSummary {
        return ReadinessSummary(
            speed: dto.speed.map { toSpeedSummary(from: $0) },
            endurance: dto.endurance.map { toEnduranceSummary(from: $0) },
            trainingLoad: dto.trainingLoad.map { toTrainingLoadSummary(from: $0) },
            raceFitness: dto.raceFitness.map { toRaceFitnessSummary(from: $0) },
            mileage: dto.mileage.map { toMileageSummary(from: $0) },
            overallReadinessScore: dto.overallReadinessScore,
            overallStatus: dto.overallStatus,
            flags: dto.flags.map { toReadinessFlag(from: $0) }
        )
    }

    private static func toSpeedSummary(from dto: SpeedSummaryDTO) -> SpeedSummary {
        return SpeedSummary(
            score: dto.score,
            achievementRate: dto.achievementRate,
            trend: dto.trend,
            trendData: dto.trendData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toEnduranceSummary(from dto: EnduranceSummaryDTO) -> EnduranceSummary {
        return EnduranceSummary(
            score: dto.score,
            avgEsc: dto.avgEsc,
            longRunCompletion: dto.longRunCompletion,
            volumeConsistency: dto.volumeConsistency,
            trend: dto.trend,
            trendData: dto.trendData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toTrainingLoadSummary(from dto: TrainingLoadSummaryDTO) -> TrainingLoadSummary {
        return TrainingLoadSummary(
            score: dto.score,
            currentTsb: dto.currentTsb,
            ctl: dto.ctl,
            atl: dto.atl,
            balanceStatus: dto.balanceStatus,
            isInOptimalRange: dto.isInOptimalRange,
            deviation: dto.deviation,
            trendData: dto.trendData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toRaceFitnessSummary(from dto: RaceFitnessSummaryDTO) -> RaceFitnessSummary {
        return RaceFitnessSummary(
            score: dto.score,
            currentVdot: dto.currentVdot,
            targetVdot: dto.targetVdot,
            baselineVdot: dto.baselineVdot,
            progressPercentage: dto.progressPercentage,
            trainingProgress: dto.trainingProgress,
            estimatedRaceTime: dto.estimatedRaceTime,
            targetRaceTime: dto.targetRaceTime,
            timeGapSeconds: dto.timeGapSeconds,
            trend: dto.trend,
            trendData: dto.trendData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toMileageSummary(from dto: MileageSummaryDTO) -> MileageSummary {
        return MileageSummary(
            plannedKm: dto.plannedKm,
            completedKm: dto.completedKm,
            completionRate: dto.completionRate,
            weeklyTrend: dto.weeklyTrend,
            streakWeeks: dto.streakWeeks,
            evaluation: dto.evaluation
        )
    }

    private static func toReadinessFlag(from dto: ReadinessFlagDTO) -> ReadinessFlag {
        return ReadinessFlag(
            level: dto.level,
            metric: dto.metric,
            message: dto.message,
            recommendedAction: dto.recommendedAction
        )
    }

    private static func toTrendDataPoint(from dto: TrendDataPointDTO) -> TrendDataPoint {
        return TrendDataPoint(
            date: dto.date,
            value: dto.value,
            label: dto.label
        )
    }

    private static func toCapabilityProgression(from dto: CapabilityProgressionDTO) -> CapabilityProgression {
        return CapabilityProgression(
            vdotProgression: dto.vdotProgression.map { toVdotProgression(from: $0) },
            speedProgression: dto.speedProgression.map { toMetricProgression(from: $0) },
            enduranceProgression: dto.enduranceProgression.map { toMetricProgression(from: $0) },
            overallTrend: dto.overallTrend,
            evaluation: dto.evaluation
        )
    }

    private static func toVdotProgression(from dto: VdotProgressionDTO) -> VdotProgression {
        return VdotProgression(
            baselineVdot: dto.baselineVdot,
            currentVdot: dto.currentVdot,
            targetVdot: dto.targetVdot,
            progressPercentage: dto.progressPercentage,
            trend: dto.trend,
            chartData: dto.chartData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toMetricProgression(from dto: MetricProgressionDTO) -> MetricProgression {
        return MetricProgression(
            startValue: dto.startValue,
            currentValue: dto.currentValue,
            changePercentage: dto.changePercentage,
            trend: dto.trend,
            chartData: dto.chartData.map { toTrendDataPoint(from: $0) },
            evaluation: dto.evaluation
        )
    }

    private static func toMilestoneProgress(from dto: MilestoneProgressDTO) -> MilestoneProgress {
        return MilestoneProgress(
            achievedMilestones: dto.achievedMilestones.map { toMilestoneRef(from: $0) },
            upcomingMilestones: dto.upcomingMilestones.map { toMilestoneRef(from: $0) },
            currentPhaseCompletion: dto.currentPhaseCompletion
        )
    }

    private static func toHistoricalComparison(from dto: HistoricalComparisonSummaryDTO) -> HistoricalComparisonSummary {
        return HistoricalComparisonSummary(
            hasComparisonData: dto.hasComparisonData,
            comparisonWeek: dto.comparisonWeek,
            comparisonDate: dto.comparisonDate,
            speedChange: dto.speedChange,
            enduranceChange: dto.enduranceChange,
            vdotChange: dto.vdotChange,
            mileageChange: dto.mileageChange,
            completionRateChange: dto.completionRateChange
        )
    }

    private static func toWeeklyHighlights(from dto: WeeklyHighlightsV2DTO) -> WeeklyHighlightsV2 {
        return WeeklyHighlightsV2(
            highlights: dto.highlights,
            achievements: dto.achievements,
            areasForImprovement: dto.areasForImprovement
        )
    }

    private static func toUpcomingRaceEvaluation(from dto: UpcomingRaceEvaluationV2DTO) -> UpcomingRaceEvaluationV2 {
        return UpcomingRaceEvaluationV2(
            raceName: dto.raceName,
            raceDate: dto.raceDate,
            daysRemaining: dto.daysRemaining,
            readinessScore: dto.readinessScore,
            readinessAssessment: dto.readinessAssessment,
            predictedTime: dto.predictedTime,
            targetTime: dto.targetTime,
            keyConcerns: dto.keyConcerns
        )
    }

    private static func toNextWeekAdjustments(from dto: NextWeekAdjustmentsV2DTO) -> NextWeekAdjustmentsV2 {
        return NextWeekAdjustmentsV2(
            items: dto.items.map { toAdjustmentItem(from: $0) },
            summary: dto.summary,
            methodologyConstraintsConsidered: dto.methodologyConstraintsConsidered,
            basedOnFlags: dto.basedOnFlags,
            customizationRecommendations: dto.customizationRecommendations.map { toCustomizationRecommendation(from: $0) }
        )
    }

    private static func toAdjustmentItem(from dto: AdjustmentItemV2DTO) -> AdjustmentItemV2 {
        return AdjustmentItemV2(
            content: dto.content,
            category: dto.category,
            apply: dto.apply,
            slotType: dto.slotType,
            trainingType: dto.trainingType,
            reason: dto.reason,
            impact: dto.impact,
            sourceFlag: dto.sourceFlag,
            priority: dto.priority
        )
    }

    private static func toCustomizationRecommendation(from dto: CustomizationRecommendationDTO) -> CustomizationRecommendation {
        return CustomizationRecommendation(
            recommendationType: dto.recommendationType,
            slotType: dto.slotType,
            originalType: dto.originalType,
            recommendedType: dto.recommendedType,
            currentValue: dto.currentValue,
            recommendedValue: dto.recommendedValue,
            adjustmentPercentage: dto.adjustmentPercentage,
            targetDays: dto.targetDays,
            durationWeeks: dto.durationWeeks,
            reason: dto.reason,
            confidence: dto.confidence,
            basedOn: dto.basedOn
        )
    }

    private static func toRestWeekAssessment(from dto: RestWeekAssessmentDTO) -> RestWeekAssessment {
        return RestWeekAssessment(
            recommended: dto.recommended,
            reason: dto.reason,
            fatigueIndicators: dto.fatigueIndicators
        )
    }

    private static func toFinalTrainingReview(from dto: FinalTrainingReviewDTO) -> FinalTrainingReview {
        return FinalTrainingReview(
            journeySummary: dto.journeySummary,
            capabilityGrowth: dto.capabilityGrowth,
            keyMilestones: dto.keyMilestones,
            racePerformanceEvaluation: dto.racePerformanceEvaluation,
            encouragement: dto.encouragement,
            nextStepsGuidance: dto.nextStepsGuidance,
            postRaceRecoveryPlan: dto.postRaceRecoveryPlan
        )
    }

    // MARK: - Date Helpers

    /// 解析 ISO 8601 日期字串為 Date
    private static func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }

        // 嘗試備用格式（Unix timestamp）
        if let timestamp = Int(dateString) {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        return nil
    }
}
