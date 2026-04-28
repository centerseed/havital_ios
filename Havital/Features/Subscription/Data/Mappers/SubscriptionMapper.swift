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
        let rizoUsage = dto.rizoUsage.map {
            RizoUsage(
                used: $0.used,
                limit: $0.limit,
                remaining: $0.remaining,
                resetsAt: $0.resetsAt
            )
        }
        let expiresAt = dto.expiresAt.flatMap { parseISO8601ToTimeInterval($0) }
        let trialEndAt = dto.trialEndAt.flatMap { parseISO8601ToTimeInterval($0) }
        let subscribedAt = dto.subscribedAt.flatMap { parseISO8601ToTimeInterval($0) }
        let iapGraceUntil = dto.iapGraceUntil.flatMap { parseISO8601ToTimeInterval($0) }
        let inGracePeriod = dto.inGracePeriod ?? false
        let billingIssue = dto.billingIssue ?? false

        // active + billingIssue → gracePeriod（Apple billing retry 期間，服務不中斷但帳務異常）
        if status == .active && billingIssue {
            status = .gracePeriod
        }

        // 任何帶 expiresAt 的付費狀態，只要已過期就應視為 expired
        if [.active, .trial, .gracePeriod, .cancelled].contains(status),
           let expiresAt,
           expiresAt <= Date().timeIntervalSince1970 {
            status = .expired
        }

        return SubscriptionStatusEntity(
            status: status,
            expiresAt: expiresAt,
            planType: dto.planType,
            rizoUsage: rizoUsage,
            billingIssue: billingIssue,
            enforcementEnabled: dto.enforcementEnabled ?? false,
            trialRemainingDays: dto.trialRemainingDays,
            isEarlyBird: dto.isEarlyBird,
            hasOverride: dto.hasOverride,
            inIntroTrial: dto.inIntroTrial,
            trialEndAt: trialEndAt,
            subscribedAt: subscribedAt,
            iapGraceUntil: iapGraceUntil,
            inGracePeriod: inGracePeriod,
            graceRemainingDays: dto.graceRemainingDays
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
            // AC-PAYWALL-29: backend 16-day trial retired. Mapping retained for backward
            // compatibility in case old backend instances still send this value.
            // New users no longer receive trial_active from backend.
            // The authoritative trial source is now Apple Introductory Offer (inIntroTrial=true).
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
