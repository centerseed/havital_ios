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
        let status = resolveStatus(from: dto.status)
        let rizoUsage = dto.rizoUsage.map { RizoUsage(used: $0.used, limit: $0.limit) }
        let expiresAt = dto.expiresAt.flatMap { parseISO8601ToTimeInterval($0) }

        return SubscriptionStatusEntity(
            status: status,
            expiresAt: expiresAt,
            planType: dto.planType,
            rizoUsage: rizoUsage,
            billingIssue: dto.billingIssue ?? false
        )
    }

    private static func parseISO8601ToTimeInterval(_ dateString: String) -> TimeInterval? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.timeIntervalSince1970
        }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)?.timeIntervalSince1970
    }

    private static func resolveStatus(from rawValue: String) -> SubscriptionStatus {
        switch rawValue.lowercased() {
        case SubscriptionStatus.active.rawValue:
            return .active
        case SubscriptionStatus.expired.rawValue:
            return .expired
        case SubscriptionStatus.trial.rawValue:
            return .trial
        case "trial_active":
            return .trial
        case "cancelled":
            // 後端可能回傳 cancelled，表示尚未到期但已 cancel 申請中；此時仍視為 active 狀態以維持 UI 可用性
            return .active
        default:
            return .none
        }
    }
}
