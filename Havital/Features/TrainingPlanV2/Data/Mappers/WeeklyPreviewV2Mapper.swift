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
            qualityOptions: dto.qualityOptions?.map { $0.trainingType } ?? [],
            longRun: dto.longRun?.trainingType
        )
    }

    private static func toIntensityDistribution(from dto: IntensityDistributionDTO) -> IntensityDistributionV2 {
        return IntensityDistributionV2(low: dto.low, medium: dto.medium, high: dto.high)
    }
}
