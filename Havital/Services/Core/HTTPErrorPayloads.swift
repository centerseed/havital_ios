import Foundation

// MARK: - HTTPError Payloads
// Data Layer 輕量 struct，只需 Decodable

struct SubscriptionErrorPayload: Decodable {
    let error: String           // "subscription_required"
    let subscription: SubscriptionErrorStatusRaw
}

struct SubscriptionErrorStatusRaw: Decodable {
    let status: String
    let expiresAt: TimeInterval?
    let planType: String?
    let billingIssue: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case expiresAt = "expires_at"
        case planType = "plan_type"
        case billingIssue = "billing_issue"
    }
}

struct RizoUsagePayload: Decodable {
    let error: String           // "rizo_quota_exceeded"
    let rizoUsage: RizoUsageRaw

    enum CodingKeys: String, CodingKey {
        case error
        case rizoUsage = "rizo_usage"
    }
}

struct RizoUsageRaw: Decodable {
    let used: Int
    let limit: Int
}
