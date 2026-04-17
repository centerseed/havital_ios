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

    // MARK: - trialDaysRemaining (Phase 2 contract)

    func testTrialDaysRemainingUsesBackendValueWhenPresent() {
        // 後端權威值 12 天；expiresAt 可能早於或晚於都無所謂——App 必須直接採用後端值。
        let expiresAt = Date().addingTimeInterval(3 * 86400).timeIntervalSince1970
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(
                status: .trial,
                expiresAt: expiresAt,
                trialRemainingDays: 12
            )
        )

        XCTAssertEqual(sut.trialDaysRemaining, 12)
    }

    func testTrialDaysRemainingFallsBackToExpiresAtWhenNil() {
        // 後端未提供 trial_remaining_days（舊版後端）——fallback 到 expiresAt 計算的 daysRemaining。
        let expiresAt = Date().addingTimeInterval(5 * 86400 + 3600).timeIntervalSince1970
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(
                status: .trial,
                expiresAt: expiresAt,
                trialRemainingDays: nil
            )
        )

        // daysRemaining 用 ceil；5.04 天會算成 6 天
        XCTAssertEqual(sut.trialDaysRemaining, 6)
    }

    func testTrialDaysRemainingReturnsNilWhenNotTrialStatus() {
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(
                status: .active,
                expiresAt: Date().addingTimeInterval(10 * 86400).timeIntervalSince1970,
                trialRemainingDays: 7
            )
        )

        XCTAssertNil(sut.trialDaysRemaining)
    }

    func testTrialDaysRemainingReturnsNilWhenTrialAndNoBackendValueNoExpiresAt() {
        SubscriptionStateManager.shared.update(
            SubscriptionStatusEntity(
                status: .trial,
                expiresAt: nil,
                trialRemainingDays: nil
            )
        )

        XCTAssertNil(sut.trialDaysRemaining)
    }

    func testPurchase_WhenAlreadyOptimisticallyUnlocked_DoesNotForceBackendRefresh() async {
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.purchase(offeringId: "default", packageId: "$rc_monthly")

        XCTAssertEqual(repository.purchaseCallCount, 1)
        XCTAssertEqual(repository.refreshStatusCallCount, 0)
        XCTAssertEqual(sut.purchaseState, .success)
    }
}

private final class MockSubscriptionRepository: SubscriptionRepository {
    var statusToReturn = SubscriptionStatusEntity(status: .none)
    var purchaseResult: PurchaseResultEntity = .success
    var restoreError: Error?
    var refreshError: Error?

    private(set) var refreshStatusCallCount = 0
    private(set) var restorePurchasesCallCount = 0
    private(set) var purchaseCallCount = 0

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
        purchaseCallCount += 1
        return purchaseResult
    }

    func restorePurchases() async throws {
        restorePurchasesCallCount += 1
        if let restoreError {
            throw restoreError
        }
    }
}
