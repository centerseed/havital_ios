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

    /// 試用期結束時間（Unix timestamp）。來自後端 trial_end_at 欄位。
    let trialEndAt: TimeInterval?

    /// 用戶首次訂閱時間（Unix timestamp）。nil 表示從未訂閱過（真新用戶）。
    /// AC-PAYWALL-37: 用於區分「真新用戶」（從沒付費過）與「流失用戶」（曾付費已到期）。
    let subscribedAt: TimeInterval?

    /// IAP grace period 結束時間（Unix timestamp）。nil 表示不在 grace period 中。
    /// AC-PAYWALL-38/39: IAP 上線後後端給予免費體驗期。
    let iapGraceUntil: TimeInterval?

    /// 是否正處於 launch grace period（後端權威值）。預設 false 確保舊 backend 不回此欄位時安全。
    /// AC-PAYWALL-38/39: true 時享有 premium-equivalent access，但非真正訂閱。
    let inGracePeriod: Bool

    /// Grace period 剩餘天數（後端計算值）。inGracePeriod=true 時後端提供。
    let graceRemainingDays: Int?

    /// 有 active Starter 買斷 → 有資格買 Paceriz 早鳥 eb1。預設 false（舊後端不回此欄位時安全）。
    let canOfferPacerizEb1: Bool

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
        inIntroTrial: Bool? = nil,
        trialEndAt: TimeInterval? = nil,
        subscribedAt: TimeInterval? = nil,
        iapGraceUntil: TimeInterval? = nil,
        inGracePeriod: Bool = false,
        graceRemainingDays: Int? = nil,
        canOfferPacerizEb1: Bool = false
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
        self.canOfferPacerizEb1 = canOfferPacerizEb1
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
            && lhs.trialEndAt == rhs.trialEndAt
            && lhs.subscribedAt == rhs.subscribedAt
            && lhs.iapGraceUntil == rhs.iapGraceUntil
            && lhs.inGracePeriod == rhs.inGracePeriod
            && lhs.graceRemainingDays == rhs.graceRemainingDays
            && lhs.canOfferPacerizEb1 == rhs.canOfferPacerizEb1
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

    /// Trial remaining days for UI.
    ///
    /// Backend returns `trial_remaining_days=9999` for non-enforced soft-launch
    /// bypass users. That value is not a real trial countdown and must not leak
    /// into paywall/profile UI.
    var trialDaysRemaining: Int? {
        guard !inGracePeriod else { return nil }
        if let trialEndAt {
            let remaining = max(0, trialEndAt - Date().timeIntervalSince1970)
            return Int(ceil(remaining / 86400.0))
        }
        if let trialRemainingDays {
            guard enforcementEnabled || trialRemainingDays < 9999 else { return nil }
            return trialRemainingDays
        }
        guard expiresAt != nil else { return nil }
        return daysRemaining
    }
}

// MARK: - Display labels
/// 訂閱狀態的**顯示文案**。原本只長在 `UserProfileView` 裡（1.x 設定頁的
/// `subscriptionTierLabel`／`subscriptionPlanName`），2.0 設定頁也要同一組字，
/// 所以收斂到實體本身：兩個畫面共用一份，不各自拼一次。
///
/// 三語走 `Localizable.strings` 的既有 `profile.subscription.*`／
/// `settings.subscription.tier.*`。**後端識別字（`planType`、`status.rawValue`）
/// 一律不上畫面**——`default` 分支給的是產品名或既有在地化字串。
extension SubscriptionStatusEntity {

    /// 方案名（`年訂閱`／`月訂閱（早鳥）`／`Paceriz Premium`）。
    var planDisplayName: String {
        let earlyBird = isEarlyBird == true
        switch planType {
        case "yearly":
            return earlyBird
                ? NSLocalizedString("profile.subscription.plan.yearly_early_bird", comment: "Annual Early Bird")
                : NSLocalizedString("profile.subscription.plan.yearly", comment: "Annual")
        case "monthly":
            return earlyBird
                ? NSLocalizedString("profile.subscription.plan.monthly_early_bird", comment: "Monthly Early Bird")
                : NSLocalizedString("profile.subscription.plan.monthly", comment: "Monthly")
        default:
            return earlyBird
                ? NSLocalizedString("profile.subscription.plan.premium_early_bird", comment: "Premium Early Bird")
                : "Paceriz Premium"
        }
    }

    /// 設定頁的「方案：…」整行（AC-PAYWALL-36/40）。
    /// 狀態：免費 / Apple intro trial / 7 天 grace period / 已訂閱。
    static func tierLabel(for status: SubscriptionStatusEntity?) -> String {
        let freeLabel = NSLocalizedString(
            "settings.subscription.tier.free_label",
            comment: "Current plan: Free Preview"
        )
        guard let status else { return freeLabel }

        if status.inGracePeriod, let days = status.graceRemainingDays {
            return String(
                format: NSLocalizedString(
                    "settings.subscription.tier.grace_label_format",
                    comment: "Current plan: Free trial (%d days left)"
                ),
                days
            )
        }
        if status.inIntroTrial == true, let days = status.trialDaysRemaining {
            return String(
                format: NSLocalizedString(
                    "settings.subscription.tier.trial_label_format",
                    comment: "Current plan: Trial (%d days left)"
                ),
                days
            )
        }
        switch status.status {
        case .active, .gracePeriod:
            return String(
                format: NSLocalizedString(
                    "settings.subscription.tier.premium_label_format",
                    comment: "Current plan: Premium (%@)"
                ),
                status.planDisplayName
            )
        case .trial:
            guard let days = status.trialDaysRemaining else { return freeLabel }
            return String(
                format: NSLocalizedString(
                    "settings.subscription.tier.trial_label_format",
                    comment: "Current plan: Trial (%d days left)"
                ),
                days
            )
        case .cancelled, .expired, .none:
            return freeLabel
        }
    }

    /// 2.0 設定頁訂閱卡右上的狀態膠囊（設計 frame-21／「訂閱狀態變體」）。
    /// 比 `tierLabel` 短，因為卡片標題已經寫了產品名。
    static func compactStateLabel(for status: SubscriptionStatusEntity?) -> String {
        guard let status else {
            return NSLocalizedString("profile.subscription.free", comment: "Free")
        }
        if status.billingIssue {
            return NSLocalizedString("profile.subscription.billing_issue", comment: "Billing issue")
        }
        let remaining: (Int) -> String = { days in
            String(
                format: NSLocalizedString(
                    "profile.subscription.trial_remaining_days",
                    comment: "%d days left"
                ),
                days
            )
        }
        if status.inGracePeriod, let days = status.graceRemainingDays {
            return remaining(days)
        }
        switch status.status {
        case .active, .gracePeriod:
            return "\(status.planDisplayName) · "
                + NSLocalizedString("app2.settings.subscription_active", comment: "Renewing")
        case .trial:
            let trial = NSLocalizedString("profile.subscription.trial", comment: "Trial")
            guard let days = status.trialDaysRemaining else { return trial }
            return "\(trial) · \(remaining(days))"
        case .cancelled:
            return NSLocalizedString("profile.subscription.cancelled", comment: "Cancelled")
        case .expired:
            return NSLocalizedString("profile.subscription.expired", comment: "Expired")
        case .none:
            return NSLocalizedString("profile.subscription.free", comment: "Free")
        }
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
