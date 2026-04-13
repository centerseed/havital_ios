import XCTest
@testable import paceriz_dev

@MainActor
final class PaywallViewModelTests: XCTestCase {

    private var repository: MockSubscriptionRepository!
    private var sut: PaywallViewModel!

    override func setUp() {
        super.setUp()
        repository = MockSubscriptionRepository()
        sut = PaywallViewModel(trigger: .apiGated, subscriptionRepository: repository)
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
    }

    override func tearDown() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
        sut = nil
        repository = nil
        super.tearDown()
    }

    func testRestorePurchases_WhenCancelled_SetsIdleAndDoesNotThrow() async throws {
        repository.restoreError = URLError(.cancelled)

        try await sut.restorePurchases()

        XCTAssertEqual(repository.restorePurchasesCallCount, 1)
        XCTAssertEqual(repository.refreshStatusCallCount, 0)
        XCTAssertEqual(sut.purchaseState, .idle)
    }

    func testRestorePurchases_WhenRestoreSucceedsAndSubscriptionIsActive_SetsSuccess() async throws {
        repository.statusToReturn = SubscriptionStatusEntity(status: .active)

        try await sut.restorePurchases()

        XCTAssertEqual(repository.restorePurchasesCallCount, 1)
        XCTAssertEqual(repository.refreshStatusCallCount, 1)
        XCTAssertEqual(sut.purchaseState, .success)
    }

    func testRestorePurchases_WhenRestoreSucceedsAndSubscriptionIsCancelled_SetsSuccess() async throws {
        repository.statusToReturn = SubscriptionStatusEntity(status: .cancelled)

        try await sut.restorePurchases()

        XCTAssertEqual(repository.restorePurchasesCallCount, 1)
        XCTAssertEqual(repository.refreshStatusCallCount, 1)
        XCTAssertEqual(sut.purchaseState, .success)
    }

    func testRestorePurchases_WhenRestoreSucceedsAndSubscriptionIsGracePeriod_SetsSuccess() async throws {
        repository.statusToReturn = SubscriptionStatusEntity(status: .gracePeriod)

        try await sut.restorePurchases()

        XCTAssertEqual(repository.restorePurchasesCallCount, 1)
        XCTAssertEqual(repository.refreshStatusCallCount, 1)
        XCTAssertEqual(sut.purchaseState, .success)
    }

    func testRestorePurchases_WhenNonCancellationError_SetsFailedAndThrows() async {
        repository.restoreError = NSError(domain: "PaywallTests", code: 500, userInfo: [NSLocalizedDescriptionKey: "restore failed"])

        do {
            try await sut.restorePurchases()
            XCTFail("Expected restorePurchases() to throw")
        } catch {
            if case .failed(let message) = sut.purchaseState {
                XCTAssertEqual(message, "restore failed")
            } else {
                XCTFail("Expected purchaseState to be .failed, got \(sut.purchaseState)")
            }
        }
    }

    func testShouldShowRestoreButton_WhenStatusIsNone_ReturnsTrue() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))

        XCTAssertTrue(sut.shouldShowRestoreButton)
    }

    func testShouldShowRestoreButton_WhenStatusIsExpired_ReturnsTrue() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .expired))

        XCTAssertTrue(sut.shouldShowRestoreButton)
    }

    func testShouldShowRestoreButton_WhenStatusIsCancelled_ReturnsTrue() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .cancelled))

        XCTAssertTrue(sut.shouldShowRestoreButton)
    }

    func testShouldShowRestoreButton_WhenStatusIsTrial_ReturnsFalse() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .trial))

        XCTAssertFalse(sut.shouldShowRestoreButton)
    }

    func testShouldShowRestoreButton_WhenStatusIsActive_ReturnsFalse() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        XCTAssertFalse(sut.shouldShowRestoreButton)
    }

    func testShouldShowRestoreButton_WhenStatusIsGracePeriod_ReturnsFalse() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .gracePeriod))

        XCTAssertFalse(sut.shouldShowRestoreButton)
    }
}

private final class MockSubscriptionRepository: SubscriptionRepository {
    var statusToReturn = SubscriptionStatusEntity(status: .none)
    var restoreError: Error?
    var refreshError: Error?

    private(set) var refreshStatusCallCount = 0
    private(set) var restorePurchasesCallCount = 0

    func getStatus() async throws -> SubscriptionStatusEntity {
        statusToReturn
    }

    func refreshStatus() async throws -> SubscriptionStatusEntity {
        refreshStatusCallCount += 1
        if let refreshError {
            throw refreshError
        }
        return statusToReturn
    }

    func getCachedStatus() -> SubscriptionStatusEntity? {
        nil
    }

    func clearCache() {}

    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] {
        []
    }

    func purchase(offeringId _: String, packageId _: String) async throws -> PurchaseResultEntity {
        .success
    }

    func restorePurchases() async throws {
        restorePurchasesCallCount += 1
        if let restoreError {
            throw restoreError
        }
    }
}
