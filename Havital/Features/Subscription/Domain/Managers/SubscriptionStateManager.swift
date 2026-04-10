import Foundation

// MARK: - SubscriptionStateManager
/// 全域訂閱狀態 Singleton - Domain 層
/// 供需要顯示試用剩餘天數、billing_issue banner 的 View 訂閱
@MainActor
final class SubscriptionStateManager: ObservableObject {
    static let shared = SubscriptionStateManager()

    @Published private(set) var currentStatus: SubscriptionStatusEntity?

    private init() {}

    func update(_ status: SubscriptionStatusEntity) {
        currentStatus = status
    }
}
