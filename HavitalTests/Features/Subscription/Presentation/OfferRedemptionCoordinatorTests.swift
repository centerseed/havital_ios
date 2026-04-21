import XCTest
@testable import paceriz_dev

@MainActor
final class OfferRedemptionCoordinatorTests: XCTestCase {
    func testRedeem_ForwardsToRepositoryAndReturnsSuccess() async {
        let repository = MockOfferRedemptionSubscriptionRepository()
        repository.result = .success
        let sut = OfferRedemptionCoordinator(subscriptionRepository: repository)

        let result = await sut.redeem(entryPoint: .paywall)

        XCTAssertEqual(repository.redeemOfferCodeCallCount, 1)
        if case .success = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected success, got \(result)")
        }
    }

    func testRedeem_WhenRepositoryThrows_MapsToFailedDomainError() async {
        let repository = MockOfferRedemptionSubscriptionRepository()
        repository.throwingError = DomainError.validationFailure("scene unavailable")
        let sut = OfferRedemptionCoordinator(subscriptionRepository: repository)

        let result = await sut.redeem(entryPoint: .profile)

        XCTAssertEqual(repository.redeemOfferCodeCallCount, 1)
        guard case .failed(let error) = result else {
            return XCTFail("Expected failed result, got \(result)")
        }
        XCTAssertEqual(error.toDomainError(), .validationFailure("scene unavailable"))
    }
}

private final class MockOfferRedemptionSubscriptionRepository: SubscriptionRepository {
    var result: PurchaseResultEntity = .success
    var throwingError: Error?
    private(set) var redeemOfferCodeCallCount = 0

    func getStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func refreshStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func getCachedStatus() -> SubscriptionStatusEntity? { nil }
    func clearCache() {}
    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] { [] }
    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity { .cancelled }

    func redeemOfferCode() async throws -> PurchaseResultEntity {
        redeemOfferCodeCallCount += 1
        if let throwingError { throw throwingError }
        return result
    }

    func restorePurchases() async throws {}
}
