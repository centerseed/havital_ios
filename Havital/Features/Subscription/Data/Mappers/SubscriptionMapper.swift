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
        var status = resolveStatus(from: dto.status)
        let rizoUsage = dto.rizoUsage.map { RizoUsage(used: $0.used, limit: $0.limit) }
        let expiresAt = dto.expiresAt.flatMap { parseISO8601ToTimeInterval($0) }
        let billingIssue = dto.billingIssue ?? false

        // active + billingIssue → gracePeriod（Apple billing retry 期間，服務不中斷但帳務異常）
        if status == .active && billingIssue {
            status = .gracePeriod
        }

        // cancelled 到期後應視為 expired（避免取消後逾期仍顯示可用）
        if status == .cancelled,
           let expiresAt,
           expiresAt <= Date().timeIntervalSince1970 {
            status = .expired
        }

        return SubscriptionStatusEntity(
            status: status,
            expiresAt: expiresAt,
            planType: dto.planType,
            rizoUsage: rizoUsage,
            billingIssue: billingIssue
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
        case "subscribed":
            // Backend canonical paid state.
            return .active
        case SubscriptionStatus.expired.rawValue:
            return .expired
        case SubscriptionStatus.trial.rawValue:
            return .trial
        case "trial_active":
            return .trial
        case "cancelled":
            return .cancelled
        case "revoked", "revoke":
            // Apple 退款 / revoke 事件視為到期（曾訂閱者）
            return .expired
        case "grace_period":
            return .gracePeriod
        default:
            return .none
        }
    }
}
