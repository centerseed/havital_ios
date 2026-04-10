import Foundation
import SwiftUI

// MARK: - PurchaseState

enum PurchaseState {
    case idle
    case purchasing
    case success
    case failed(String)
}

// MARK: - PaywallViewModel

@MainActor
final class PaywallViewModel: ObservableObject, TaskManageable {

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Properties

    /// 觸發付費牆的原因
    let trigger: PaywallTrigger

    // MARK: - Published State

    @Published var offerings: ViewState<[SubscriptionOfferingEntity]> = .loading
    @Published var purchaseState: PurchaseState = .idle

    // MARK: - Dependencies

    private let subscriptionRepository: SubscriptionRepository

    // MARK: - Initialization

    init(trigger: PaywallTrigger, subscriptionRepository: SubscriptionRepository? = nil) {
        self.trigger = trigger
        self.subscriptionRepository = subscriptionRepository ?? DependencyContainer.shared.resolve()
    }

    deinit { cancelAllTasks() }

    // MARK: - Actions

    func loadOfferings() async {
        // ADR-002 BLOCKED — stub for now, show empty state
        offerings = .empty
    }

    // MARK: - Computed Properties

    /// 試用期剩餘天數（僅 .trial 狀態時非 nil）
    /// 直接從 SubscriptionStateManager 讀取以確保即時性
    var trialDaysRemaining: Int? {
        guard let status = SubscriptionStateManager.shared.currentStatus,
              status.status == .trial,
              let expiresAt = status.expiresAt else { return nil }
        let remaining = expiresAt - Date().timeIntervalSince1970
        return max(0, Int(remaining / 86400))
    }
}
