import Foundation

// MARK: - SubscriptionMapper
/// 訂閱狀態 Mapper - Data Layer
/// 負責 DTO → Entity 轉換
enum SubscriptionMapper {

    // MARK: - DTO → Entity

    /// 將 SubscriptionStatusDTO 轉換為 SubscriptionStatusEntity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體
    static func toEntity(from dto: SubscriptionStatusDTO) -> SubscriptionStatusEntity {
        let status = SubscriptionStatus(rawValue: dto.status) ?? .none
        let rizoUsage = dto.rizoUsage.map { RizoUsage(used: $0.used, limit: $0.limit) }

        return SubscriptionStatusEntity(
            status: status,
            expiresAt: dto.expiresAt,
            planType: dto.planType,
            rizoUsage: rizoUsage,
            billingIssue: dto.billingIssue ?? false
        )
    }

}
