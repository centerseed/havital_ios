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

    private init() {}

    func update(_ status: SubscriptionStatusEntity) {
        if let previous = currentStatus {
            guard status != previous else { return }
            let downgrade = detectDowngrade(from: previous.status, to: status.status)
            if downgrade != nil {
                recentDowngrade = downgrade
            }
        }
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
