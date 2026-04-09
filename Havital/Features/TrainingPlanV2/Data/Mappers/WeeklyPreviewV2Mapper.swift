import Foundation

// MARK: - WeeklyPreviewV2Mapper
/// Weekly Preview V2 Mapper - Data Layer
/// 負責 DTO → Entity 轉換
enum WeeklyPreviewV2Mapper {

    // MARK: - DTO → Entity

    /// 將 WeeklyPreviewResponseDTO 轉換為 WeeklyPreviewV2 Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: WeeklyPreviewResponseDTO) -> WeeklyPreviewV2 {
        return WeeklyPreviewV2(
            id: dto.planId,
            methodologyId: dto.methodologyId,
            weeks: dto.weeks.map { toWeekPreview(from: $0) },
            createdAt: dto.createdAt.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) },
            updatedAt: dto.updatedAt.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
        )
    }

    // MARK: - Private

    private static func toWeekPreview(from dto: WeekPreviewDTO) -> WeekPreview {
        return WeekPreview(
            week: dto.week,
            stageId: dto.stageId,
            targetKm: dto.targetKm,
            targetKmDisplay: dto.targetKmDisplay,
            distanceUnit: dto.distanceUnit,
            isRecovery: dto.isRecovery ?? false,
            milestoneRef: dto.milestoneRef,
            intensityRatio: dto.intensityRatio.map { toIntensityDistribution(from: $0) },
            qualityOptions: dto.qualityOptions?.map { displayType(for: $0) } ?? [],
            longRun: dto.longRun?.trainingType
        )
    }

    /// 特殊 variant（編輯課表可選的獨立類型）保留原始 trainingType，其餘用 category
    private static let specialVariants: Set<String> = [
        "yasso_800", "norwegian_4x4",
        "cruise_intervals", "short_interval", "long_interval",
        "hill_repeats", "fast_finish", "race_pace", "mp_long_run", "progressive_long_run"
    ]

    /// Backend phase-level category key → localization 基礎訓練類型
    /// Backend 的 category 是 YAML phase 中的 slot 名稱（如 threshold_long），
    /// 而非 workout template 的基礎類型（如 threshold），需要正規化才能 localize。
    private static let categoryBaseTypeMap: [String: String] = [
        // Norwegian
        "lt1_calibration": "threshold",
        "threshold_long": "threshold",
        "threshold_short": "threshold",
        "threshold_maintenance": "threshold",
        // Polarized
        "neuromuscular": "strides",
        "vo2max_long": "interval",
        "vo2max_short": "interval",
        "vo2max_maintenance": "interval",
        // Paceriz
        "speed_development": "interval",
        "threshold_work": "threshold",
        "interval_work": "interval",
        "speed_maintenance": "interval",
        // Speed Endurance
        "aerobic_quality": "fartlek",
        "threshold_quality_1": "tempo",
        "threshold_quality_2": "threshold",
        // Hansons
        "optional_quality": "strides",
        "race_specific": "race_pace",
    ]

    private static func displayType(for option: QualityOptionDTO) -> String {
        if specialVariants.contains(option.trainingType) {
            return option.trainingType
        }
        return categoryBaseTypeMap[option.category] ?? option.category
    }

    private static func toIntensityDistribution(from dto: IntensityDistributionDTO) -> IntensityDistributionV2 {
        return IntensityDistributionV2(low: dto.low, medium: dto.medium, high: dto.high)
    }
}
