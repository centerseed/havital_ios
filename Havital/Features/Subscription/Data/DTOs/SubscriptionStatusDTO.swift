import Foundation

// MARK: - SubscriptionStatusDTO
/// 訂閱狀態 API 響應 - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
struct SubscriptionStatusDTO: Codable {

    // MARK: - Properties

    let status: String
    let expiresAt: String?
    let planType: String?
    let rizoUsage: RizoUsageDTO?
    let billingIssue: Bool?
    let enforcementEnabled: Bool?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case status
        case expiresAt = "expires_at"
        case planType = "plan_type"
        case rizoUsage = "rizo_usage"
        case billingIssue = "billing_issue"
        case enforcementEnabled = "enforcement_enabled"
    }
}

// MARK: - RizoUsageDTO
struct RizoUsageDTO: Codable {
    let used: Int
    let limit: Int
}
