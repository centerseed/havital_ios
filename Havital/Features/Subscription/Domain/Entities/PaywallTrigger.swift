import Foundation

// MARK: - PaywallSource
/// Source parameter for paywall_opened analytics event (AC-PAYWALL-28).
/// Identifies which entry point triggered the paywall sheet.
enum PaywallSource: String {
    /// User triggered Week 2 weekly plan generation for the first time (no existing Week 2 plan).
    case weeklyPlanWeek2 = "weekly_plan_week2"
    /// User triggered re-generation or adjustment of an existing weekly plan (Week 2+).
    case weeklyPlanRegenerate = "weekly_plan_regenerate"
    /// User triggered AI weekly review.
    case weeklyReview = "weekly_review"
    /// User triggered target race creation.
    case targetRaceCreate = "target_race_create"
    /// User tapped upgrade/subscription in Settings.
    case settingsUpgrade = "settings_upgrade"
    /// Expired subscriber re-subscribing. Requires sub_source (original feature trigger).
    case resubscribe = "resubscribe"
    /// Active subscriber changing plan.
    case changePlan = "change_plan"
}

// MARK: - PaywallTrigger
/// 付費牆觸發原因（Presentation 層使用）
enum PaywallTrigger: Hashable, Identifiable {
    case apiGated                                   // API 回 403 subscription_required (legacy)
    case trialExpired                               // 試用期到期主動檢查 (legacy)
    case featureLocked                              // 功能被鎖定提示 (legacy)
    case resubscribe                                // cancelled 用戶重新訂閱
    case changePlan                                 // active 用戶變更方案

    // Source-aware triggers (S06/S07/S08)
    case weeklyPlanWeek2                            // Week 2 首次生成被 gate → inline card CTA
    case weeklyPlanRegenerate                       // 重新生成 / 調整 Week 2+ 課表
    case weeklyReview                               // 週回顧 inline card CTA
    case targetRaceCreate                           // 建立目標賽事 inline card CTA
    case settingsUpgrade                            // Settings 升級按鈕

    var id: Self { self }

    /// PaywallSource for analytics. Used by AC-PAYWALL-28.
    var paywallSource: PaywallSource {
        switch self {
        case .weeklyPlanWeek2:      return .weeklyPlanWeek2
        case .weeklyPlanRegenerate: return .weeklyPlanRegenerate
        case .weeklyReview:         return .weeklyReview
        case .targetRaceCreate:     return .targetRaceCreate
        case .settingsUpgrade:      return .settingsUpgrade
        case .resubscribe:          return .resubscribe
        case .changePlan:           return .changePlan
        // Legacy fallbacks
        case .apiGated, .featureLocked: return .weeklyPlanWeek2
        case .trialExpired:         return .resubscribe
        }
    }

    /// GA4 event parameter string for this trigger.
    var analyticsString: String {
        paywallSource.rawValue
    }

    /// Whether this trigger is a resubscribe flow (requires sub_source tracking).
    var isResubscribe: Bool {
        self == .resubscribe
    }
}
