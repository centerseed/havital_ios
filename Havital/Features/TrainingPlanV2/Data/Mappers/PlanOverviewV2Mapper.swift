import Foundation

// MARK: - PlanOverviewV2Mapper
/// Plan Overview V2 Mapper - Data Layer
/// 負責 DTO ↔ Entity 雙向轉換
enum PlanOverviewV2Mapper {

    // MARK: - DTO → Entity

    /// 將 PlanOverviewV2DTO 轉換為 PlanOverviewV2 Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: PlanOverviewV2DTO) -> PlanOverviewV2 {
        return PlanOverviewV2(
            id: dto.id,
            targetId: dto.targetId,
            targetType: dto.targetType,
            targetDescription: dto.targetDescription,
            methodologyId: dto.methodologyId,
            totalWeeks: dto.totalWeeks,
            startFromStage: dto.startFromStage,
            raceDate: dto.raceDate,
            distanceKm: dto.distanceKm,
            distanceKmDisplay: dto.distanceKmDisplay,
            distanceUnit: dto.distanceUnit,
            targetPace: dto.targetPace,
            targetTime: dto.targetTime,
            isMainRace: dto.isMainRace,
            targetName: dto.targetName,
            methodologyOverview: dto.methodologyOverview.map { toMethodologyOverview(from: $0) },
            targetEvaluate: dto.targetEvaluate,
            approachSummary: dto.approachSummary,
            trainingStages: (dto.trainingStages ?? []).map { toTrainingStage(from: $0) },
            milestones: (dto.milestones ?? []).map { toMilestone(from: $0) },
            createdAt: parseDate(from: dto.createdAt),
            methodologyVersion: dto.methodologyVersion,
            milestoneBasis: dto.milestoneBasis
        )
    }

    // MARK: - Entity → DTO

    /// 將 PlanOverviewV2 Entity 轉換為 PlanOverviewV2DTO
    /// - Parameter entity: Domain Layer 業務實體
    /// - Returns: API 請求的 DTO
    static func toDTO(from entity: PlanOverviewV2) -> PlanOverviewV2DTO {
        return PlanOverviewV2DTO(
            id: entity.id,
            targetId: entity.targetId,
            targetType: entity.targetType,
            targetDescription: entity.targetDescription,
            methodologyId: entity.methodologyId,
            totalWeeks: entity.totalWeeks,
            startFromStage: entity.startFromStage,
            raceDate: entity.raceDate,
            distanceKm: entity.distanceKm,
            distanceKmDisplay: entity.distanceKmDisplay,
            distanceUnit: entity.distanceUnit,
            targetPace: entity.targetPace,
            targetTime: entity.targetTime,
            isMainRace: entity.isMainRace,
            targetName: entity.targetName,
            methodologyOverview: entity.methodologyOverview.map { toMethodologyOverviewDTO(from: $0) },
            targetEvaluate: entity.targetEvaluate,
            approachSummary: entity.approachSummary,
            trainingStages: entity.trainingStages.map { toTrainingStageDTO(from: $0) },
            milestones: entity.milestones.map { toMilestoneDTO(from: $0) },
            createdAt: formatDate(entity.createdAt),
            methodologyVersion: entity.methodologyVersion,
            milestoneBasis: entity.milestoneBasis
        )
    }

    // MARK: - Nested Conversions (DTO → Entity)

    private static func toMethodologyOverview(from dto: MethodologyOverviewDTO) -> MethodologyOverviewV2 {
        return MethodologyOverviewV2(
            name: dto.name,
            philosophy: dto.philosophy,
            intensityStyle: dto.intensityStyle,
            intensityDescription: dto.intensityDescription
        )
    }

    private static func toTrainingStage(from dto: TrainingStageDTO) -> TrainingStageV2 {
        return TrainingStageV2(
            stageId: dto.stageId,
            stageName: dto.stageName,
            stageDescription: dto.stageDescription,
            weekStart: dto.weekStart,
            weekEnd: dto.weekEnd,
            trainingFocus: dto.trainingFocus,
            targetWeeklyKmRange: toTargetWeeklyKmRange(from: dto.targetWeeklyKmRange),
            targetWeeklyKmRangeDisplay: dto.targetWeeklyKmRangeDisplay.map { toTargetWeeklyKmRangeDisplay(from: $0) },
            intensityRatio: dto.intensityRatio.map { toIntensityDistribution(from: $0) },
            keyWorkouts: dto.keyWorkouts
        )
    }

    private static func toTargetWeeklyKmRangeDisplay(from dto: TargetWeeklyKmRangeDisplayDTO) -> TargetWeeklyKmRangeDisplayV2 {
        return TargetWeeklyKmRangeDisplayV2(
            lowDisplay: dto.lowDisplay,
            highDisplay: dto.highDisplay,
            distanceUnit: dto.distanceUnit
        )
    }

    private static func toTargetWeeklyKmRange(from dto: TargetWeeklyKmRangeDTO) -> TargetWeeklyKmRangeV2 {
        return TargetWeeklyKmRangeV2(low: dto.low, high: dto.high)
    }

    private static func toIntensityDistribution(from dto: IntensityDistributionDTO) -> IntensityDistributionV2 {
        return IntensityDistributionV2(low: dto.low, medium: dto.medium, high: dto.high)
    }

    private static func toMilestone(from dto: MilestoneDTO) -> MilestoneV2 {
        return MilestoneV2(
            week: dto.week,
            milestoneType: dto.milestoneType,
            title: dto.title,
            description: dto.description,
            isKeyMilestone: dto.isKeyMilestone
        )
    }

    // MARK: - Nested Conversions (Entity → DTO)

    private static func toMethodologyOverviewDTO(from entity: MethodologyOverviewV2) -> MethodologyOverviewDTO {
        return MethodologyOverviewDTO(
            name: entity.name,
            philosophy: entity.philosophy,
            intensityStyle: entity.intensityStyle,
            intensityDescription: entity.intensityDescription
        )
    }

    private static func toTrainingStageDTO(from entity: TrainingStageV2) -> TrainingStageDTO {
        return TrainingStageDTO(
            stageId: entity.stageId,
            stageName: entity.stageName,
            stageDescription: entity.stageDescription,
            weekStart: entity.weekStart,
            weekEnd: entity.weekEnd,
            trainingFocus: entity.trainingFocus,
            targetWeeklyKmRange: toTargetWeeklyKmRangeDTO(from: entity.targetWeeklyKmRange),
            targetWeeklyKmRangeDisplay: entity.targetWeeklyKmRangeDisplay.map {
                TargetWeeklyKmRangeDisplayDTO(lowDisplay: $0.lowDisplay, highDisplay: $0.highDisplay, distanceUnit: $0.distanceUnit)
            },
            intensityRatio: entity.intensityRatio.map { toIntensityDistributionDTO(from: $0) },
            keyWorkouts: entity.keyWorkouts
        )
    }

    private static func toTargetWeeklyKmRangeDTO(from entity: TargetWeeklyKmRangeV2) -> TargetWeeklyKmRangeDTO {
        return TargetWeeklyKmRangeDTO(low: entity.low, high: entity.high)
    }

    private static func toIntensityDistributionDTO(from entity: IntensityDistributionV2) -> IntensityDistributionDTO {
        return IntensityDistributionDTO(low: entity.low, medium: entity.medium, high: entity.high)
    }

    private static func toMilestoneDTO(from entity: MilestoneV2) -> MilestoneDTO {
        return MilestoneDTO(
            week: entity.week,
            milestoneType: entity.milestoneType,
            title: entity.title,
            description: entity.description,
            isKeyMilestone: entity.isKeyMilestone
        )
    }

    // MARK: - Date Helpers

    /// 解析 ISO 8601 日期字串為 Date
    /// 支援格式：2026-01-21T15:24:26.194000+00:00（含微秒）
    private static func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // 嘗試標準 ISO8601 格式（無微秒）
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date
        }

        // 嘗試含微秒的 ISO8601 格式
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractional.date(from: dateString) {
            return date
        }

        // 嘗試備用格式（Unix timestamp）
        if let timestamp = Int(dateString) {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        Logger.error("[PlanOverviewV2Mapper] ❌ 無法解析日期: \(dateString)")
        return nil
    }

    /// 格式化 Date 為 ISO 8601 字串
    private static func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
