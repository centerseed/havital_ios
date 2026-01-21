import Foundation

// MARK: - WeeklyPlanV2Mapper
/// Weekly Plan V2 Mapper - Data Layer
/// 負責 DTO ↔ Entity 雙向轉換
/// ✅ 完整兼容 V1 WeeklyPlan 結構
enum WeeklyPlanV2Mapper {

    // MARK: - DTO → Entity

    /// 將 WeeklyPlanV2DTO 轉換為 WeeklyPlanV2 Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: WeeklyPlanV2DTO) -> WeeklyPlanV2 {
        return WeeklyPlanV2(
            planId: dto.planId,
            weekOfTraining: dto.weekOfTraining,
            id: dto.id,
            purpose: dto.purpose,
            weekOfPlan: dto.weekOfPlan,
            totalWeeks: dto.totalWeeks,
            totalDistance: dto.totalDistance,
            totalDistanceReason: dto.totalDistanceReason,
            designReason: dto.designReason,
            days: dto.days,  // 直接使用 V1 的 TrainingDay，無需轉換
            intensityTotalMinutes: dto.intensityTotalMinutes,  // 直接使用 V1 的 IntensityTotalMinutes
            createdAt: parseDate(from: dto.createdAt),
            updatedAt: parseDate(from: dto.updatedAt),
            trainingLoadAnalysis: dto.trainingLoadAnalysis,
            personalizedRecommendations: dto.personalizedRecommendations,
            realTimeAdjustments: dto.realTimeAdjustments,
            apiVersion: dto.apiVersion
        )
    }

    // MARK: - Entity → DTO

    /// 將 WeeklyPlanV2 Entity 轉換為 WeeklyPlanV2DTO
    /// - Parameter entity: Domain Layer 業務實體
    /// - Returns: API 請求的 DTO
    static func toDTO(from entity: WeeklyPlanV2) -> WeeklyPlanV2DTO {
        return WeeklyPlanV2DTO(
            planId: entity.planId,
            weekOfTraining: entity.weekOfTraining,
            id: entity.id,
            purpose: entity.purpose,
            weekOfPlan: entity.weekOfPlan,
            totalWeeks: entity.totalWeeks,
            totalDistance: entity.totalDistance,
            totalDistanceReason: entity.totalDistanceReason,
            designReason: entity.designReason,
            days: entity.days,  // 直接使用，無需轉換
            intensityTotalMinutes: entity.intensityTotalMinutes,
            createdAt: formatDate(entity.createdAt),
            updatedAt: formatDate(entity.updatedAt),
            trainingLoadAnalysis: entity.trainingLoadAnalysis,
            personalizedRecommendations: entity.personalizedRecommendations,
            realTimeAdjustments: entity.realTimeAdjustments,
            apiVersion: entity.apiVersion
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

        Logger.error("[WeeklyPlanV2Mapper] ❌ 無法解析日期: \(dateString)")
        return nil
    }

    /// 格式化 Date 為 ISO 8601 字串
    private static func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
