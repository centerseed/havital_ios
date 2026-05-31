import Foundation

// MARK: - SubscriptionReminderManager
/// 訂閱到期提醒管理器 - Domain 層
/// 控制 trial 即將到期和 expired 提醒的顯示頻率
/// - trial: 剩餘 <= 7 天，每日最多一次
/// - expired: 每次 App 啟動一次，同 session 不重複
@MainActor
final class SubscriptionReminderManager: ObservableObject {
    static let shared = SubscriptionReminderManager()

    // MARK: - Published

    @Published private(set) var pendingReminder: SubscriptionReminder?

    // MARK: - Private State

    private var hasShownExpiredThisSession = false

    private enum Keys {
        static let lastTrialReminderDate = "subscription_last_trial_reminder_date"
    }

    private init() {}

    // MARK: - Public

    /// 檢查並產生提醒（App 啟動或前景恢復時呼叫）
    /// - Parameters:
    ///   - status: 目前訂閱狀態。
    ///   - hasGeneratedTrainingPlan: 用戶是否已生成 Week 1 課表（planOverview != nil）。
    ///     若為 true 且狀態為 expired，FreeTierBanner 已在主頁持續顯示，不再重複觸發 dialog。
    ///     預設 false，保持向後相容（不傳此參數時行為不變）。
    func checkAndShowReminder(
        status: SubscriptionStatusEntity?,
        hasGeneratedTrainingPlan: Bool = false
    ) {
        guard let status else {
            pendingReminder = nil
            return
        }

        guard SubscriptionStateManager.shared.isEnforcementEnabled else {
            pendingReminder = nil
            return
        }

        switch status.status {
        case .trial:
            checkTrialReminder(status: status)
        case .expired:
            // FreeTierBanner 顯示條件：!hasPremiumAccess && planOverview != nil。
            // 若 banner 已常駐顯示，dialog 是重複提醒；以 hasGeneratedTrainingPlan 代理此判斷。
            if hasGeneratedTrainingPlan {
                pendingReminder = nil
                return
            }
            checkExpiredReminder(status: status)
        default:
            // active, cancelled, gracePeriod, none — 不需要提醒
            pendingReminder = nil
        }
    }

    /// 使用者關閉提醒後呼叫
    func dismissReminder() {
        if case .expired = pendingReminder {
            hasShownExpiredThisSession = true
        }
        pendingReminder = nil
    }

    /// 重置 session 狀態（新 session 開始時呼叫，通常不需要手動呼叫）
    func resetSession() {
        hasShownExpiredThisSession = false
    }

    // MARK: - Private

    private func checkTrialReminder(status: SubscriptionStatusEntity) {
        // 使用後端計算的 trialRemainingDays（SSOT），不依賴 expiresAt
        guard let remainingDays = status.trialRemainingDays,
              remainingDays > 0,
              remainingDays <= 7 else {
            pendingReminder = nil
            return
        }

        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let lastShown = UserDefaults.standard.double(forKey: Keys.lastTrialReminderDate)
        guard lastShown < today else {
            pendingReminder = nil
            return
        }

        UserDefaults.standard.set(today, forKey: Keys.lastTrialReminderDate)
        pendingReminder = .trialExpiring(daysRemaining: remainingDays, trialEndsAt: status.trialEndAt)
    }

    private func checkExpiredReminder(status: SubscriptionStatusEntity) {
        // AC-PAYWALL-37 belt-and-suspenders: a nil subscribedAt means the user
        // has never had a paid subscription (true new user). Showing an "expired"
        // dialog is incorrect messaging — they never subscribed. Skip it.
        guard status.subscribedAt != nil else {
            pendingReminder = nil
            return
        }

        guard !hasShownExpiredThisSession else {
            pendingReminder = nil
            return
        }
        hasShownExpiredThisSession = true
        pendingReminder = .expired
    }
}

// MARK: - SubscriptionReminder
enum SubscriptionReminder: Identifiable, Equatable {
    case trialExpiring(daysRemaining: Int, trialEndsAt: TimeInterval?)
    case expired

    var id: String {
        switch self {
        case .trialExpiring(let days, _): return "trial_\(days)"
        case .expired: return "expired"
        }
    }
}
