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
    private let analyticsService: AnalyticsService
    private let offerRedemptionCoordinator: OfferRedemptionCoordinator

    // MARK: - Initialization

    init(
        trigger: PaywallTrigger,
        subscriptionRepository: SubscriptionRepository? = nil,
        analyticsService: AnalyticsService? = nil,
        offerRedemptionCoordinator: OfferRedemptionCoordinator? = nil
    ) {
        self.trigger = trigger
        let resolvedRepository = subscriptionRepository ?? DependencyContainer.shared.resolve()
        self.subscriptionRepository = resolvedRepository
        self.analyticsService = analyticsService ?? DependencyContainer.shared.resolve()
        self.offerRedemptionCoordinator = offerRedemptionCoordinator
            ?? OfferRedemptionCoordinator(subscriptionRepository: resolvedRepository)
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

    func purchase(request: SubscriptionPurchaseRequest) async {
        let purchaseContext = "\(request.offeringId.lowercased()) \(request.packageId.lowercased())"
        let planType = purchaseContext.contains("yearly") || purchaseContext.contains("annual")
            ? "yearly"
            : "monthly"
        let analyticsOfferType = analyticsOfferType(for: request.offerType)
        analyticsService.track(.paywallTapSubscribe(planType: planType, offerType: analyticsOfferType))

        purchaseState = .purchasing
        do {
            let result = try await subscriptionRepository.purchase(request: request)
            switch result {
            case .success:
                let unlocked = await refreshStatusWithRetry()
                purchaseState = unlocked
                    ? .success
                    : .failed(NSLocalizedString("paywall.purchase_pending_processing", comment: "Purchase is being processed"))
            case .cancelled:
                // User-cancelled is intentional — not a failure.
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
                analyticsService.track(
                    .purchaseFail(
                        errorType: classifyPurchaseError(error),
                        offerType: analyticsOfferType
                    )
                )
                purchaseState = .failed(error.localizedDescription)
            }
        } catch {
            analyticsService.track(
                .purchaseFail(
                    errorType: classifyPurchaseError(error),
                    offerType: analyticsOfferType
                )
            )
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func purchase(offeringId: String, packageId: String) async {
        await purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: offeringId,
                packageId: packageId,
                offerType: nil,
                offerIdentifier: nil
            )
        )
    }

    func redeemOfferCode() async {
        purchaseState = .purchasing

        let result = await offerRedemptionCoordinator.redeem(entryPoint: .paywall)
        switch result {
        case .success:
            purchaseState = .success
        case .cancelled:
            purchaseState = .idle
        case .pendingProcessing:
            purchaseState = .failed(
                NSLocalizedString(
                    "paywall.offer_code_pending_processing",
                    comment: "Offer code redemption is being processed"
                )
            )
        case .failed(let error):
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
    /// 優先採用後端計算的 `trialRemainingDays`（SSOT），
    /// 若後端未提供則 fallback 到本地以 `expiresAt` 計算的 `daysRemaining`。
    var trialDaysRemaining: Int? {
        guard let status = SubscriptionStateManager.shared.currentStatus,
              status.status == .trial else { return nil }
        if let backendValue = status.trialRemainingDays {
            return backendValue
        }
        guard status.expiresAt != nil else { return nil }
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

    // MARK: - Analytics

    func trackPaywallView() {
        analyticsService.track(.paywallView(
            trigger: trigger.analyticsString,
            trialRemainingDays: trialDaysRemaining
        ))
    }

    // MARK: - Private

    private func classifyPurchaseError(_ error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("network") || desc.contains("timeout") || desc.contains("connection") {
            return "network_error"
        }
        if desc.contains("payment") || desc.contains("declined") || desc.contains("billing") {
            return "payment_declined"
        }
        if desc.contains("store") || desc.contains("storekit") {
            return "store_error"
        }
        return "unknown"
    }

    private func analyticsOfferType(for offerType: SubscriptionOfferType?) -> String {
        offerType?.rawValue ?? "standard"
    }

    private func refreshStatusWithRetry() async -> Bool {
        if let status = SubscriptionStateManager.shared.currentStatus,
           isUnlockedStatus(status.status) {
            return true
        }

        // P1-4: 與 SubscriptionRepositoryImpl.refreshStatus 的 15×2s=30s retry 策略對齊
        // （原本 [0,1,2,4,6]=13s 不夠 webhook 抵達）
        let retryDelaysSeconds: [UInt64] = [0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
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
