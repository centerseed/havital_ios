import Foundation

// MARK: - SubscriptionStatusEntity
/// 訂閱狀態業務實體 - Domain Layer
/// 純粹的業務模型，不包含 Codable（不耦合序列化格式）
struct SubscriptionStatusEntity {

    // MARK: - Properties

    /// 訂閱是否有效
    let status: SubscriptionStatus

    /// 訂閱到期時間（Unix timestamp），nil 表示無期限或未知
    let expiresAt: TimeInterval?

    /// 訂閱方案類型
    let planType: String?

    /// Rizo AI 功能使用量
    let rizoUsage: RizoUsage?

    /// 是否有帳單問題（如付款失敗）
    let billingIssue: Bool

    // MARK: - Initialization

    init(
        status: SubscriptionStatus,
        expiresAt: TimeInterval? = nil,
        planType: String? = nil,
        rizoUsage: RizoUsage? = nil,
        billingIssue: Bool = false
    ) {
        self.status = status
        self.expiresAt = expiresAt
        self.planType = planType
        self.rizoUsage = rizoUsage
        self.billingIssue = billingIssue
    }
}

// MARK: - SubscriptionStatus
enum SubscriptionStatus: String {
    case active
    case expired
    case trial
    case none
}

// MARK: - RizoUsage
struct RizoUsage {
    let used: Int
    let limit: Int

    var remaining: Int {
        return max(0, limit - used)
    }

    var isExhausted: Bool {
        return used >= limit
    }
}
