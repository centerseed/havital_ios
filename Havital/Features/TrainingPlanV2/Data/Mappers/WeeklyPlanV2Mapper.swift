import Foundation

// MARK: - WeeklyPlanV2Mapper
/// Weekly Plan V2 Mapper - Data Layer
/// 負責 DTO ↔ Entity 雙向轉換
enum WeeklyPlanV2Mapper {

    // MARK: - DTO → Entity

    /// 將 WeeklyPlanV2DTO 轉換為 WeeklyPlanV2 Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: WeeklyPlanV2DTO) -> WeeklyPlanV2 {
        return WeeklyPlanV2(
            id: dto.id,
            uid: dto.uid,
            activeTrainingId: dto.activeTrainingId,
            weekOfTraining: dto.weekOfTraining,
            targetType: dto.targetType,
            methodologyId: dto.methodologyId,
            plan: PlanData(rawData: dto.plan),
            createdAt: parseDate(from: dto.createdAt),
            updatedAt: parseDate(from: dto.updatedAt)
        )
    }

    // MARK: - Entity → DTO

    /// 將 WeeklyPlanV2 Entity 轉換為 WeeklyPlanV2DTO
    /// - Parameter entity: Domain Layer 業務實體
    /// - Returns: API 請求的 DTO
    static func toDTO(from entity: WeeklyPlanV2) -> WeeklyPlanV2DTO {
        return WeeklyPlanV2DTO(
            id: entity.id,
            uid: entity.uid,
            activeTrainingId: entity.activeTrainingId,
            weekOfTraining: entity.weekOfTraining,
            targetType: entity.targetType,
            methodologyId: entity.methodologyId,
            plan: entity.plan.rawData,
            createdAt: formatDate(entity.createdAt),
            updatedAt: formatDate(entity.updatedAt)
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

    /// 格式化 Date 為 ISO 8601 字串
    private static func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
