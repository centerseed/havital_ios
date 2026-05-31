import Foundation

// MARK: - SubscriptionStateManager
/// 全域訂閱狀態 Singleton - Domain 層
/// 供需要顯示試用剩餘天數、billing_issue banner 的 View 訂閱
@MainActor
final class SubscriptionStateManager: ObservableObject {
    static let shared = SubscriptionStateManager()

    @Published private(set) var currentStatus: SubscriptionStatusEntity?

    /// 狀態是否剛發生降級（如 active → expired）
    /// View 層可觀察此屬性來顯示非阻斷通知
    @Published private(set) var recentDowngrade: StatusDowngrade?

    private init() {
        // CacheEventBus subscription moved to CacheRegistrationCoordinator (App layer)
    }

    /// Reset subscription state on logout.
    /// Called by CacheRegistrationCoordinator when CacheEventBus fires .userLogout.
    func applyLogoutReset() {
        update(SubscriptionStatusEntity(status: .none))
        clearDowngrade()
    }

    /// 後端是否開啟訂閱執行（false = 軟上線期間，不顯示 paywall）
    var isEnforcementEnabled: Bool {
        currentStatus?.enforcementEnabled ?? false
    }

    /// Whether the user has access to premium features (subscribed, in Apple intro trial, or in launch grace period).
    /// Used by S07 gating: if true, do NOT show inline upsell card.
    /// AC-PAYWALL-27: subscribers and trial users proceed without gating.
    /// AC-PAYWALL-39: grace period users also have premium access (AI features unlocked).
    var hasPremiumAccess: Bool {
        guard let status = currentStatus else { return false }
        // Apple intro trial also counts as premium access
        if status.inIntroTrial == true { return true }
        // IAP launch grace period: backend-confirmed, unlocks all AI features
        if status.inGracePeriod { return true }
        switch status.status {
        case .active, .trial, .gracePeriod, .cancelled:
            return true
        case .expired, .none:
            return false
        }
    }

    /// Whether the user has a real (paid) subscription — excludes launch grace period.
    /// Used by banner / tier label logic: grace period users see the upgrade prompt,
    /// not the "subscribed" UI.
    /// AC-PAYWALL-38/39: grace period → hasRealSubscription = false (banner still visible).
    var hasRealSubscription: Bool {
        guard let status = currentStatus else { return false }
        if status.inGracePeriod { return false }
        switch status.status {
        case .active, .trial, .gracePeriod, .cancelled:
            return true
        case .expired, .none:
            return false
        }
    }

    func update(_ status: SubscriptionStatusEntity) {
        let previousStatusName = currentStatus?.status.rawValue ?? "nil"
        if let previous = currentStatus {
            guard status != previous else {
                print("[Subscription] State.update skipped (no change): status=\(status.status.rawValue) inGrace=\(status.inGracePeriod)")
                return
            }
            let downgrade = detectDowngrade(from: previous.status, to: status.status)
            if downgrade != nil {
                recentDowngrade = downgrade
            }
        }
        print("[Subscription] State.update applied: \(previousStatusName) → \(status.status.rawValue) inGrace=\(status.inGracePeriod) hasOverride=\(status.hasOverride)")
        currentStatus = status
    }

    /// 清除降級通知（View 顯示後呼叫）
    func clearDowngrade() {
        recentDowngrade = nil
    }

    // MARK: - Private

    /// 偵測狀態是否降級
    private func detectDowngrade(from old: SubscriptionStatus, to new: SubscriptionStatus) -> StatusDowngrade? {
        let activeStatuses: Set<SubscriptionStatus> = [.active, .trial, .gracePeriod, .cancelled]
        let inactiveStatuses: Set<SubscriptionStatus> = [.expired, .none]

        // 從有權限 → 無權限 = 降級
        if activeStatuses.contains(old) && inactiveStatuses.contains(new) {
            return StatusDowngrade(from: old, to: new)
        }
        return nil
    }
}

// MARK: - StatusDowngrade
struct StatusDowngrade: Equatable {
    let from: SubscriptionStatus
    let to: SubscriptionStatus
}
