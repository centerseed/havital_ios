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

    /// 後端是否開啟訂閱執行（false = 軟上線期間，paywall 靜默）
    let enforcementEnabled: Bool

    /// 試用期剩餘天數（後端權威值）。nil 時表示後端未提供，UI 應 fallback 到 `daysRemaining`。
    let trialRemainingDays: Int?

    /// 是否為 Early Bird 早鳥方案
    let isEarlyBird: Bool?

    /// 是否有 admin override
    let hasOverride: Bool?

    /// 是否處於 App Store introductory offer / trial 期間
    let inIntroTrial: Bool?

    // MARK: - Initialization

    init(
        status: SubscriptionStatus,
        expiresAt: TimeInterval? = nil,
        planType: String? = nil,
        rizoUsage: RizoUsage? = nil,
        billingIssue: Bool = false,
        enforcementEnabled: Bool = false,
        trialRemainingDays: Int? = nil,
        isEarlyBird: Bool? = nil,
        hasOverride: Bool? = nil,
        inIntroTrial: Bool? = nil
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
    }
}

// MARK: - Equatable
extension SubscriptionStatusEntity: Equatable {
    static func == (lhs: SubscriptionStatusEntity, rhs: SubscriptionStatusEntity) -> Bool {
        lhs.status == rhs.status
            && lhs.expiresAt == rhs.expiresAt
            && lhs.planType == rhs.planType
            && lhs.rizoUsage == rhs.rizoUsage
            && lhs.billingIssue == rhs.billingIssue
            && lhs.enforcementEnabled == rhs.enforcementEnabled
            && lhs.trialRemainingDays == rhs.trialRemainingDays
            && lhs.isEarlyBird == rhs.isEarlyBird
            && lhs.hasOverride == rhs.hasOverride
            && lhs.inIntroTrial == rhs.inIntroTrial
    }
}

// MARK: - Convenience
extension SubscriptionStatusEntity {
    /// 到期日距今剩餘天數（無到期日或已過期回傳 0）
    var daysRemaining: Int {
        guard let expiresAt else { return 0 }
        let remaining = max(0, expiresAt - Date().timeIntervalSince1970)
        return Int(ceil(remaining / 86400.0))
    }
}

// MARK: - SubscriptionStatus
enum SubscriptionStatus: String {
    case active
    case expired
    case trial
    case none
    case cancelled
    case gracePeriod
}

// MARK: - RizoUsage
struct RizoUsage: Equatable {
    let used: Int
    let limit: Int

    /// 後端提供的剩餘次數（若 nil 則 fallback 用 limit - used 計算）
    private let backendRemaining: Int?

    /// 後端提供的下次重置時間（ISO8601 字串）
    let resetsAt: String?

    init(used: Int, limit: Int, remaining: Int? = nil, resetsAt: String? = nil) {
        self.used = used
        self.limit = limit
        self.backendRemaining = remaining
        self.resetsAt = resetsAt
    }

    /// 剩餘可用次數：優先取後端值，fallback 到 max(0, limit - used)
    var remaining: Int {
        if let backendRemaining {
            return max(0, backendRemaining)
        }
        return max(0, limit - used)
    }

    var isExhausted: Bool {
        return used >= limit
    }
}
