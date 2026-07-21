import StoreKit

protocol IntroOfferEligibilityProviding {
    func isEligibleForIntroOffer(subscriptionGroupIdentifier: String) async -> Bool
}

struct StoreKitIntroOfferEligibilityProvider: IntroOfferEligibilityProviding {
    func isEligibleForIntroOffer(subscriptionGroupIdentifier: String) async -> Bool {
        await StoreKit.Product.SubscriptionInfo.isEligibleForIntroOffer(
            for: subscriptionGroupIdentifier
        )
    }
}

enum IntroOfferEligibilityDecision: Equatable {
    enum UnavailableReason: String, Equatable {
        case missingSubscriptionGroupIdentifier = "missing_subscription_group_identifier"
        case revenueCatIdentityNotSynced = "revenuecat_identity_not_synced"
    }

    case eligible(subscriptionGroupIdentifier: String)
    case ineligible(subscriptionGroupIdentifier: String)
    case unavailable(UnavailableReason)

    var shouldDisplayIntro: Bool {
        if case .eligible = self { return true }
        return false
    }

    var diagnosticValue: String {
        switch self {
        case .eligible(let groupIdentifier):
            return "eligible(group=\(groupIdentifier))"
        case .ineligible(let groupIdentifier):
            return "ineligible(group=\(groupIdentifier))"
        case .unavailable(let reason):
            return "unavailable(reason=\(reason.rawValue))"
        }
    }
}

struct IntroOfferEligibilityResolver {
    private let provider: IntroOfferEligibilityProviding

    init(provider: IntroOfferEligibilityProviding = StoreKitIntroOfferEligibilityProvider()) {
        self.provider = provider
    }

    func resolve(
        subscriptionGroupIdentifier: String?,
        revenueCatIdentityIsSynced: Bool
    ) async -> IntroOfferEligibilityDecision {
        guard revenueCatIdentityIsSynced else {
            return .unavailable(.revenueCatIdentityNotSynced)
        }
        guard let subscriptionGroupIdentifier, !subscriptionGroupIdentifier.isEmpty else {
            return .unavailable(.missingSubscriptionGroupIdentifier)
        }

        let isEligible = await provider.isEligibleForIntroOffer(
            subscriptionGroupIdentifier: subscriptionGroupIdentifier
        )
        return isEligible
            ? .eligible(subscriptionGroupIdentifier: subscriptionGroupIdentifier)
            : .ineligible(subscriptionGroupIdentifier: subscriptionGroupIdentifier)
    }
}
