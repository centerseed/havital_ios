import Foundation
import SwiftUI

// MARK: - PurchaseState

enum PurchaseState: Equatable {
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

    func restorePurchases() async throws {
        purchaseState = .purchasing
        do {
            try await subscriptionRepository.restorePurchases()
            let unlocked = await refreshStatusWithRetry()
            purchaseState = unlocked
                ? .success
                : .failed(NSLocalizedString("paywall.restore_no_active_subscription", comment: "No active subscription found"))
        } catch {
            if error.isCancellationError {
                purchaseState = .idle
                return
            }
            purchaseState = .failed(error.localizedDescription)
            throw error
        }
    }

    func purchase(offeringId: String, packageId: String) async {
        purchaseState = .purchasing
        do {
            let result = try await subscriptionRepository.purchase(offeringId: offeringId, packageId: packageId)
            switch result {
            case .success:
                let unlocked = await refreshStatusWithRetry()
                purchaseState = unlocked
                    ? .success
                    : .failed(NSLocalizedString("paywall.purchase_pending_processing", comment: "Purchase is being processed"))
            case .cancelled:
                purchaseState = .failed(
                    NSLocalizedString(
                        "paywall.purchase_cancelled_retry",
                        comment: "Apple sign-in completed but purchase was cancelled; ask user to tap again"
                    )
                )
            case .pendingProcessing:
                let unlocked = await refreshStatusWithRetry()
                purchaseState = unlocked
                    ? .success
                    : .failed(NSLocalizedString("paywall.purchase_pending_processing", comment: "Purchase is being processed"))
            case .failed(let error):
                purchaseState = .failed(error.localizedDescription)
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func loadOfferings() async {
        offerings = .loading
        do {
            let result = try await subscriptionRepository.fetchOfferings()
            offerings = result.isEmpty ? .empty : .loaded(result)
        } catch {
            offerings = .error(error.toDomainError())
        }
    }

    // MARK: - Computed Properties

    /// 試用期剩餘天數（僅 .trial 狀態時非 nil）
    /// 直接從 SubscriptionStateManager 讀取以確保即時性
    var trialDaysRemaining: Int? {
        guard let status = SubscriptionStateManager.shared.currentStatus,
              status.status == .trial,
              status.expiresAt != nil else { return nil }
        return status.daysRemaining
    }

    /// Restore Purchases 顯示規則（Spec 矩陣）
    /// 顯示：expired / none / cancelled
    /// 隱藏：trial / active / gracePeriod
    var shouldShowRestoreButton: Bool {
        guard let status = SubscriptionStateManager.shared.currentStatus?.status else {
            return true
        }
        switch status {
        case .expired, .none, .cancelled:
            return true
        case .trial, .active, .gracePeriod:
            return false
        }
    }

    // MARK: - Private

    private func refreshStatusWithRetry() async -> Bool {
        if let status = SubscriptionStateManager.shared.currentStatus,
           isUnlockedStatus(status.status) {
            return true
        }

        let retryDelaysSeconds: [UInt64] = [0, 1, 2, 4, 6]
        for delay in retryDelaysSeconds {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
            do {
                let status = try await subscriptionRepository.refreshStatus()
                Logger.debug("[PaywallViewModel] refreshStatusWithRetry: status=\(status.status.rawValue)")
                if isUnlockedStatus(status.status) {
                    return true
                }
            } catch {
                Logger.debug("[PaywallViewModel] refreshStatusWithRetry attempt failed: \(error.localizedDescription)")
            }
        }
        return false
    }

    private func isUnlockedStatus(_ status: SubscriptionStatus) -> Bool {
        status == .active || status == .trial || status == .cancelled || status == .gracePeriod
    }
}
