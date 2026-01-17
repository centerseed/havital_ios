import Foundation

// MARK: - MonthlyStatsMapper
/// 月度統計數據 Mapper - Data Layer
/// 負責 DTO ↔ Entity 雙向轉換
enum MonthlyStatsMapper {

    // MARK: - DTO → Entity

    /// 將 DailyStatsDTO 轉換為 DailyStat Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toDailyStat(from dto: DailyStatsDTO) -> DailyStat {
        return DailyStat(
            date: dto.date,
            totalDistanceKm: dto.totalDistanceKm,
            avgPacePerKm: dto.avgPacePerKm,
            workoutCount: dto.workoutCount
        )
    }

    /// 批量轉換 DailyStatsDTO 列表
    /// - Parameter dtos: DTO 列表
    /// - Returns: Entity 列表
    static func toDailyStats(from dtos: [DailyStatsDTO]) -> [DailyStat] {
        return dtos.map { toDailyStat(from: $0) }
    }

    /// 從完整的 API 響應中提取 Entity 列表
    /// - Parameter response: 完整的 API 響應
    /// - Returns: Entity 列表
    static func toDailyStats(from response: MonthlyStatsDTO) -> [DailyStat] {
        return toDailyStats(from: response.data.dailyStats)
    }

    // MARK: - Entity → DTO (如需上傳功能時使用)

    /// 將 DailyStat Entity 轉換為 DailyStatsDTO
    /// - Parameter entity: Domain Layer 業務實體
    /// - Returns: API 請求的 DTO
    /// - Note: 目前 Monthly Stats 只需要讀取，暫不需要此方法
    static func toDailyStatsDTO(from entity: DailyStat) -> DailyStatsDTO {
        return DailyStatsDTO(
            date: entity.date,
            totalDistanceKm: entity.totalDistanceKm,
            avgPacePerKm: entity.avgPacePerKm,
            workoutCount: entity.workoutCount
        )
    }
}
