import Foundation

// MARK: - HTTPError Payloads
// Data Layer 輕量 struct，只需 Decodable
// 注意：後端用 FastAPI HTTPException(detail={...})，回傳格式為 {"detail": {...}}

// MARK: - Detail Wrappers
// FastAPI 的 HTTPException 把 payload 包在 "detail" key 裡

struct SubscriptionErrorDetailWrapper: Decodable {
    let detail: SubscriptionErrorPayload
}

struct RizoUsageDetailWrapper: Decodable {
    let detail: RizoUsagePayload
}

// MARK: - Subscription Error (403)

struct SubscriptionErrorPayload: Decodable {
    let error: String           // "subscription_required"
    let subscription: SubscriptionErrorStatusRaw
}

struct SubscriptionErrorStatusRaw: Decodable {
    let status: String
    let expiresAt: String?
    let planType: String?
    let billingIssue: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case expiresAt = "expires_at"
        case planType = "plan_type"
        case billingIssue = "billing_issue"
    }
}

// MARK: - Rizo Quota Error (429)

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
