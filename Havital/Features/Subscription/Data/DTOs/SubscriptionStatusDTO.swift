import Foundation

// MARK: - SubscriptionStatusDTO
/// 訂閱狀態 API 響應 - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
///
/// 所有新欄位都是 Optional，以確保舊版後端（不回傳這些欄位）仍然可以成功解碼。
struct SubscriptionStatusDTO: Codable {

    // MARK: - Properties

    let status: String
    let expiresAt: String?
    let planType: String?
    let rizoUsage: RizoUsageDTO?
    let billingIssue: Bool?
    let enforcementEnabled: Bool?

    /// 試用期剩餘天數（後端計算的權威值，App 直接採用，不要自己再算）
    let trialRemainingDays: Int?

    /// 是否為 Early Bird 早鳥方案（後端依 cohort 判斷）
    let isEarlyBird: Bool?

    /// 是否有 admin override（後端管理後台手動介入過）
    let hasOverride: Bool?

    /// 是否處於 App Store introductory offer / trial 期間（StoreKit 判斷）
    let inIntroTrial: Bool?

    /// 試用期結束時間（ISO8601）。status=trial_active 時後端提供此欄位。
    let trialEndAt: String?

    /// 用戶首次訂閱時間（ISO8601）。nil 表示從未訂閱過（真新用戶）。
    /// AC-PAYWALL-37: 用於區分「真新用戶」（從沒付費過）與「流失用戶」（曾付費已到期）。
    let subscribedAt: String?

    /// 7-day grace period 結束時間（ISO8601）。nil 表示目前不在 grace period 中。
    /// AC-PAYWALL-38/39: IAP 購買後後端給予 7 天免費體驗期，期間享有 premium-equivalent access。
    let iapGraceUntil: String?

    /// 是否正處於 7-day grace period 中（後端權威值）。
    /// AC-PAYWALL-38/39: true 時 hasPremiumAccess = true，但 hasRealSubscription = false。
    let inGracePeriod: Bool?

    /// Grace period 剩餘天數（後端計算值）。inGracePeriod=true 時後端提供此欄位。
    let graceRemainingDays: Int?

    // MARK: - Initialization

    /// 顯式 init（所有新欄位預設 nil，讓既有 call site 不需修改）
    init(
        status: String,
        expiresAt: String? = nil,
        planType: String? = nil,
        rizoUsage: RizoUsageDTO? = nil,
        billingIssue: Bool? = nil,
        enforcementEnabled: Bool? = nil,
        trialRemainingDays: Int? = nil,
        isEarlyBird: Bool? = nil,
        hasOverride: Bool? = nil,
        inIntroTrial: Bool? = nil,
        trialEndAt: String? = nil,
        subscribedAt: String? = nil,
        iapGraceUntil: String? = nil,
        inGracePeriod: Bool? = nil,
        graceRemainingDays: Int? = nil
    ) {
        self.status = status
        self.expiresAt = expiresAt
        self.planType = planType
        self.rizoUsage = rizoUsage
        self.billingIssue = billingIssue
        self.enforcementEnabled = enforcementEnabled
        self.trialRemainingDays = trialRemainingDays
        self.isEarlyBird = isEarlyBird
        self.hasOverride = hasOverride
        self.inIntroTrial = inIntroTrial
        self.trialEndAt = trialEndAt
        self.subscribedAt = subscribedAt
        self.iapGraceUntil = iapGraceUntil
        self.inGracePeriod = inGracePeriod
        self.graceRemainingDays = graceRemainingDays
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case status
        case expiresAt = "expires_at"
        case planType = "plan_type"
        case rizoUsage = "rizo_usage"
        case billingIssue = "billing_issue"
        case enforcementEnabled = "enforcement_enabled"
        case trialRemainingDays = "trial_remaining_days"
        case isEarlyBird = "is_early_bird"
        case hasOverride = "has_override"
        case inIntroTrial = "in_intro_trial"
        case trialEndAt = "trial_end_at"
        case subscribedAt = "subscribed_at"
        case iapGraceUntil = "iap_grace_until"
        case inGracePeriod = "in_grace_period"
        case graceRemainingDays = "grace_remaining_days"
    }
}

// MARK: - RizoUsageDTO
struct RizoUsageDTO: Codable {
    let used: Int
    let limit: Int

    /// 剩餘可用次數（後端計算值，通常等於 max(0, limit - used)，但以後端為準）
    let remaining: Int?

    /// 下次重置時間（ISO8601 字串，例如每週的重置點）
    let resetsAt: String?

    init(used: Int, limit: Int, remaining: Int? = nil, resetsAt: String? = nil) {
        self.used = used
        self.limit = limit
        self.remaining = remaining
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case used
        case limit
        case remaining
        case resetsAt = "resets_at"
    }
}
