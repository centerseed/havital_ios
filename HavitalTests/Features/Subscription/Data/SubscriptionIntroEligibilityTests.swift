import XCTest
@testable import paceriz_dev

final class SubscriptionIntroEligibilityTests: XCTestCase {

    func testEligibleAppleGroupDisplaysIntro() async {
        let provider = StubIntroOfferEligibilityProvider(isEligible: true)
        let resolver = IntroOfferEligibilityResolver(provider: provider)

        let decision = await resolver.resolve(
            subscriptionGroupIdentifier: "paceriz-premium",
            revenueCatIdentityIsSynced: true
        )

        XCTAssertEqual(decision, .eligible(subscriptionGroupIdentifier: "paceriz-premium"))
        XCTAssertTrue(decision.shouldDisplayIntro)
        XCTAssertEqual(provider.requestedGroupIdentifiers, ["paceriz-premium"])
    }

    func testIneligibleAppleGroupHidesIntro() async {
        let provider = StubIntroOfferEligibilityProvider(isEligible: false)
        let resolver = IntroOfferEligibilityResolver(provider: provider)

        let decision = await resolver.resolve(
            subscriptionGroupIdentifier: "paceriz-premium",
            revenueCatIdentityIsSynced: true
        )

        XCTAssertEqual(decision, .ineligible(subscriptionGroupIdentifier: "paceriz-premium"))
        XCTAssertFalse(decision.shouldDisplayIntro)
    }

    func testMissingSubscriptionGroupHidesIntroWithoutQueryingApple() async {
        let provider = StubIntroOfferEligibilityProvider(isEligible: true)
        let resolver = IntroOfferEligibilityResolver(provider: provider)

        let decision = await resolver.resolve(
            subscriptionGroupIdentifier: nil,
            revenueCatIdentityIsSynced: true
        )

        XCTAssertEqual(decision, .unavailable(.missingSubscriptionGroupIdentifier))
        XCTAssertFalse(decision.shouldDisplayIntro)
        XCTAssertTrue(provider.requestedGroupIdentifiers.isEmpty)
    }

    func testUnsyncedRevenueCatIdentityHidesIntroWithoutQueryingApple() async {
        let provider = StubIntroOfferEligibilityProvider(isEligible: true)
        let resolver = IntroOfferEligibilityResolver(provider: provider)

        let decision = await resolver.resolve(
            subscriptionGroupIdentifier: "paceriz-premium",
            revenueCatIdentityIsSynced: false
        )

        XCTAssertEqual(decision, .unavailable(.revenueCatIdentityNotSynced))
        XCTAssertFalse(decision.shouldDisplayIntro)
        XCTAssertTrue(provider.requestedGroupIdentifiers.isEmpty)
    }
}

private final class StubIntroOfferEligibilityProvider: IntroOfferEligibilityProviding {
    private let isEligible: Bool
    private(set) var requestedGroupIdentifiers: [String] = []

    init(isEligible: Bool) {
        self.isEligible = isEligible
    }

    func isEligibleForIntroOffer(subscriptionGroupIdentifier: String) async -> Bool {
        requestedGroupIdentifiers.append(subscriptionGroupIdentifier)
        return isEligible
    }
}
