import Foundation

// MARK: - PaywallTrigger
/// 付費牆觸發原因（Presentation 層使用）
enum PaywallTrigger: Hashable, Identifiable {
    case apiGated       // API 回 403 subscription_required
    case trialExpired   // 試用期到期主動檢查
    case featureLocked  // 功能被鎖定提示
    case resubscribe    // cancelled 用戶重新訂閱
    case changePlan     // active 用戶變更方案

    var id: Self { self }

    /// GA4 event parameter string for this trigger.
    var analyticsString: String {
        switch self {
        case .apiGated:      return "api_gated"
        case .trialExpired:  return "trial_expired"
        case .featureLocked: return "feature_locked"
        case .resubscribe:   return "resubscribe"
        case .changePlan:    return "change_plan"
        }
    }
}
