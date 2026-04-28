import Foundation
import SwiftUI
import UIKit

// MARK: - PurchaseState

enum PurchaseState: Equatable {
    case idle
    case purchasing
    case success
    case failed(String)
}

// MARK: - PaywallDisplayPackage

/// View-ready representation of a single subscription package for the Paywall.
/// Computed by PaywallViewModel from the current RC offering and (for early-bird)
/// the default offering's same-period package localized price.
struct PaywallDisplayPackage: Identifiable {
    /// Underlying offering entity package (carries period / product ID / price).
    let package: SubscriptionPackageEntity

    /// Display price string (early-bird price when isEarlyBird; regular price otherwise).
    /// Always sourced from RC SDK localized price — never hardcoded.
    let displayPrice: String

    /// Line-through original price string.
    /// Non-nil only when isEarlyBird == true; sourced from the matching default offering package.
    let originalPriceLineThrough: String?

    /// Whether this package belongs to the early-bird offering.
    let isEarlyBird: Bool

    var id: String { package.id }
}

// MARK: - PaywallViewModel

@MainActor
final class PaywallViewModel: ObservableObject, TaskManageable {

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Properties

    /// 觸發付費牆的原因
    let trigger: PaywallTrigger

    /// Sub-source for resubscribe flows (AC-PAYWALL-28).
    /// When trigger = .resubscribe, this identifies the feature that originally triggered the gate.
    let subSource: PaywallSource?

    // MARK: - Published State

    @Published var offerings: ViewState<[SubscriptionOfferingEntity]> = .loading
    @Published var purchaseState: PurchaseState = .idle

    /// The localized plan name of the most recently purchased package.
    /// Set at the moment purchase succeeds — before the RC webhook lands — so the
    /// success modal always shows the plan the user actually bought (not the stale
    /// backend planType that may still reflect the previous subscription period).
    @Published var lastPurchasedPlanName: String?

    // MARK: - Foreground Observer

    /// Notification observer token — held strongly so deinit cleans up automatically.
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Dependencies

    private let subscriptionRepository: SubscriptionRepository
    private let analyticsService: AnalyticsService
    private let offerRedemptionCoordinator: OfferRedemptionCoordinator

    // MARK: - Initialization

    init(
        trigger: PaywallTrigger,
        subSource: PaywallSource? = nil,
        subscriptionRepository: SubscriptionRepository? = nil,
        analyticsService: AnalyticsService? = nil,
        offerRedemptionCoordinator: OfferRedemptionCoordinator? = nil
    ) {
        self.trigger = trigger
        self.subSource = subSource
        let resolvedRepository = subscriptionRepository ?? DependencyContainer.shared.resolve()
        self.subscriptionRepository = resolvedRepository
        self.analyticsService = analyticsService ?? DependencyContainer.shared.resolve()
        self.offerRedemptionCoordinator = offerRedemptionCoordinator
            ?? OfferRedemptionCoordinator(subscriptionRepository: resolvedRepository)

        // AC-IAP-OFFER-04: re-fetch offerings when app re-enters foreground while paywall is visible.
        // Only the owning view should reload — do not use a singleton observer.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.loadOfferings()
            }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        cancelAllTasks()
    }

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
                if unlocked {
                    lastPurchasedPlanName = localizedPlanName(for: planType)
                    purchaseState = .success
                } else {
                    purchaseState = .failed(NSLocalizedString("paywall.purchase_pending_processing", comment: "Purchase is being processed"))
                }
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
                if unlocked {
                    lastPurchasedPlanName = localizedPlanName(for: planType)
                    purchaseState = .success
                } else {
                    purchaseState = .failed(NSLocalizedString("paywall.purchase_pending_processing", comment: "Purchase is being processed"))
                }
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

    // MARK: - Early Bird Display Packages

    /// View-ready packages for the current offering, enriched with early-bird display metadata.
    ///
    /// For each package in the current offering:
    /// - `displayPrice` = the package's own localized price (early-bird price when in early_bird offering).
    /// - `originalPriceLineThrough` = the same-period package price from the *default* offering,
    ///   nil when not in early-bird mode. Sourced from RC SDK localized strings — never hardcoded.
    /// - `isEarlyBird` = true when repository reports early-bird offering.
    var displayPackages: [PaywallDisplayPackage] {
        guard case .loaded(let allOfferings) = offerings else { return [] }
        let isEarlyBird = subscriptionRepository.isEarlyBirdOffering
        let currentOfferingId = subscriptionRepository.currentOfferingIdentifier ?? Constants.IAP.defaultOfferingIdentifier

        // Find the current offering
        let currentOffering = allOfferings.first { $0.id == currentOfferingId }
            ?? allOfferings.first
        guard let currentOffering else { return [] }

        // Build lookup for default offering localized prices by period.
        // Used for line-through original price on early-bird cards.
        var defaultLocalizedPriceByPeriod: [SubscriptionPeriod: String] = [:]
        if isEarlyBird,
           let defaultOffering = allOfferings.first(where: { $0.id == Constants.IAP.defaultOfferingIdentifier }) {
            for pkg in defaultOffering.packages {
                defaultLocalizedPriceByPeriod[pkg.period] = pkg.localizedPrice
            }
        }

        return currentOffering.packages.map { pkg in
            let originalLineThrough: String? = isEarlyBird
                ? defaultLocalizedPriceByPeriod[pkg.period]
                : nil
            return PaywallDisplayPackage(
                package: pkg,
                displayPrice: pkg.localizedPrice,
                originalPriceLineThrough: originalLineThrough,
                isEarlyBird: isEarlyBird
            )
        }
    }

    /// View-ready packages for the *default* offering, used in the default section of the paywall.
    ///
    /// Always sourced from `allOfferings["default"]` regardless of which offering is current.
    /// Each package is marked `isEarlyBird = false` and has no line-through price —
    /// the default section shows standard pricing without promotional context.
    /// Returns an empty array when offerings are not yet loaded or default offering is absent.
    var defaultPackages: [PaywallDisplayPackage] {
        guard case .loaded(let allOfferings) = offerings,
              let defaultOffering = allOfferings.first(where: { $0.id == Constants.IAP.defaultOfferingIdentifier }) else {
            return []
        }
        return defaultOffering.packages.map { pkg in
            PaywallDisplayPackage(
                package: pkg,
                displayPrice: pkg.localizedPrice,
                originalPriceLineThrough: nil,
                isEarlyBird: false
            )
        }
    }

    // MARK: - Computed Properties

    /// Whether the current offering is the early-bird offering.
    /// Delegated to the repository; exposed here so Views can drive conditional UI.
    var isEarlyBirdOffering: Bool {
        subscriptionRepository.isEarlyBirdOffering
    }

    /// Whether the early-bird section should be shown in the paywall.
    /// True only when the current offering is the early-bird offering.
    var shouldShowEarlyBirdSection: Bool {
        isEarlyBirdOffering
    }

    /// Whether the default section should be shown in the paywall.
    /// Always true — both early-bird mode and default mode show the default section.
    var shouldShowDefaultSection: Bool {
        true
    }

    /// 試用期剩餘天數（trial 或 Apple intro trial 狀態時非 nil）。
    /// AC-PAYWALL-29: backend 16 天 trial 退場；trial 倒數優先使用 Apple intro offer 的 trialEndAt 或 expiresAt。
    /// backend `trialRemainingDays` 僅作為最終 fallback（後端不再回傳此值）。
    var trialDaysRemaining: Int? {
        guard let status = SubscriptionStateManager.shared.currentStatus else { return nil }

        // Apple intro trial: use trialEndAt first (from Apple intro offer end date)
        if status.inIntroTrial == true {
            if let trialEndAt = status.trialEndAt {
                let remaining = max(0, trialEndAt - Date().timeIntervalSince1970)
                return Int(ceil(remaining / 86400.0))
            }
            // Fallback to expiresAt for Apple intro trial countdown
            if status.expiresAt != nil {
                return status.daysRemaining
            }
        }

        // Legacy backend trial (.trial status) — keep for backward compatibility
        guard status.status == .trial else { return nil }
        if let backendValue = status.trialRemainingDays {
            return backendValue
        }
        guard status.expiresAt != nil else { return nil }
        return status.daysRemaining
    }

    /// Whether the user is currently in an Apple intro offer trial.
    /// Used to decide whether to show Trial Banner (true) or Trial Timeline (false).
    /// AC-PAYWALL-09, AC-PAYWALL-18, AC-PAYWALL-19.
    var isInAppleIntroTrial: Bool {
        guard let status = SubscriptionStateManager.shared.currentStatus else { return false }
        return status.inIntroTrial == true
    }

    /// Days remaining for Apple intro offer trial. Non-nil only when isInAppleIntroTrial == true.
    /// Falls back to trialDaysRemaining when inIntroTrial is set but no explicit countdown is available.
    var introTrialDaysRemaining: Int? {
        guard isInAppleIntroTrial else { return nil }
        return trialDaysRemaining
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
        // AC-PAYWALL-28: fire paywallOpened with source + optional sub_source
        let sourceString = trigger.paywallSource.rawValue
        let subSourceString: String? = trigger.isResubscribe ? subSource?.rawValue : nil
        analyticsService.track(.paywallOpened(source: sourceString, subSource: subSourceString))

        // Legacy event retained for backward compatibility
        analyticsService.track(.paywallView(
            trigger: trigger.analyticsString,
            trialRemainingDays: trialDaysRemaining
        ))
    }

    // MARK: - View Helpers

    /// Returns the offering identifier that should be passed to purchase().
    /// Prefers the repository's current offering identifier; falls back to the first
    /// offering that contains the given packages.
    func currentOfferingId(from offerings: [SubscriptionOfferingEntity]) -> String {
        if let id = subscriptionRepository.currentOfferingIdentifier {
            return id
        }
        return offerings.first?.id ?? Constants.IAP.defaultOfferingIdentifier
    }

    // MARK: - Private

    /// Maps the analytics planType ("yearly" / "monthly") to a localized display string for
    /// the success modal — called immediately on purchase so the modal is independent of
    /// RC webhook timing.
    private func localizedPlanName(for planType: String) -> String {
        switch planType {
        case "yearly":
            return NSLocalizedString("paywall.purchase_success.plan.yearly", comment: "Yearly plan")
        case "monthly":
            return NSLocalizedString("paywall.purchase_success.plan.monthly", comment: "Monthly plan")
        default:
            return NSLocalizedString("paywall.purchase_success.plan.premium", comment: "Premium subscription")
        }
    }

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
