import Foundation

@MainActor
final class OfferRedemptionCoordinator {
    private let subscriptionRepository: SubscriptionRepository

    init(subscriptionRepository: SubscriptionRepository? = nil) {
        self.subscriptionRepository = subscriptionRepository ?? DependencyContainer.shared.resolve()
    }

    func redeem(entryPoint: OfferEntryPoint) async -> PurchaseResultEntity {
        Logger.debug("[OfferRedemptionCoordinator] redeem from \(entryPoint.rawValue)")

        do {
            return try await subscriptionRepository.redeemOfferCode()
        } catch {
            Logger.error("[OfferRedemptionCoordinator] redeem failed: \(error.localizedDescription)")
            return .failed(error.toDomainError())
        }
    }
}
