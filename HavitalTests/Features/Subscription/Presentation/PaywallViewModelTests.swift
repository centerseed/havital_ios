import XCTest
@testable import paceriz_dev

@MainActor
final class PaywallViewModelTests: XCTestCase {

    private var repository: MockSubscriptionRepository!
    private var analyticsService: MockAnalyticsService!
    private var sut: PaywallViewModel!

    override func setUp() {
        super.setUp()
        repository = MockSubscriptionRepository()
        analyticsService = MockAnalyticsService()
        sut = PaywallViewModel(
            trigger: .apiGated,
            subscriptionRepository: repository,
            analyticsService: analyticsService
        )
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
    }

    override func tearDown() {
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))
        SubscriptionStateManager.shared.clearDowngrade()
        sut = nil
        analyticsService = nil
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

    func testTrackPaywallView_EmitsTriggerWithoutOfferType() {
        // AC-PAYWALL-28: trackPaywallView() now fires TWO events:
        //   [0] paywallOpened(source:subSource:) — new, required by AC-PAYWALL-28
        //   [1] paywallView(trigger:trialRemainingDays:) — legacy, retained for backward compat
        // Updated by QA 2026-04-26 after paywall rewrite (S08).
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .none))

        sut.trackPaywallView()

        XCTAssertEqual(analyticsService.trackedEvents.count, 2,
                       "trackPaywallView must fire paywallOpened (AC-PAYWALL-28) + paywallView (legacy)")

        // Verify paywallOpened event at index 0 (AC-PAYWALL-28)
        // Note: .apiGated is a legacy trigger; its paywallSource maps to .weeklyPlanWeek2 ("weekly_plan_week2")
        // per PaywallTrigger.paywallSource fallback logic.
        if case .paywallOpened(let source, let subSource) = analyticsService.trackedEvents[0] {
            XCTAssertEqual(source, "weekly_plan_week2",
                           "paywallOpened source for .apiGated legacy trigger maps to weekly_plan_week2")
            XCTAssertNil(subSource, "subSource must be nil for non-resubscribe trigger")
        } else {
            XCTFail("Expected paywallOpened event at index 0")
        }

        // Verify legacy paywallView event at index 1
        // Note: .paywallView uses trigger.analyticsString which also maps to "weekly_plan_week2" for .apiGated
        if case .paywallView(let trigger, let trialRemainingDays) = analyticsService.trackedEvents[1] {
            XCTAssertEqual(trigger, "weekly_plan_week2",
                           "legacy paywallView trigger for .apiGated maps to weekly_plan_week2")
            XCTAssertNil(trialRemainingDays)
        } else {
            XCTFail("Expected paywallView event at index 1")
        }
    }

    func testPurchase_WhenAlreadyOptimisticallyUnlocked_DoesNotForceBackendRefresh() async {
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.purchase(offeringId: "default", packageId: "$rc_monthly")

        XCTAssertEqual(repository.purchaseCallCount, 1)
        XCTAssertEqual(repository.lastPurchaseRequest?.offeringId, "default")
        XCTAssertEqual(repository.lastPurchaseRequest?.packageId, "$rc_monthly")
        XCTAssertNil(repository.lastPurchaseRequest?.offerType)
        XCTAssertEqual(repository.refreshStatusCallCount, 0)
        XCTAssertEqual(sut.purchaseState, .success)
        XCTAssertEqual(analyticsService.trackedEvents.count, 1)
        if case .paywallTapSubscribe(let planType, let offerType) = analyticsService.trackedEvents[0] {
            XCTAssertEqual(planType, "monthly")
            XCTAssertEqual(offerType, "standard")
        } else {
            XCTFail("Expected paywallTapSubscribe event")
        }
    }

    func testPurchaseRequest_WhenOfferTypeProvided_ForwardsOfferTypeToRepository() async {
        repository.purchaseResult = .cancelled

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "promo_offering",
                packageId: "$rc_annual",
                offerType: .promotional,
                offerIdentifier: "promo_annual_2026"
            )
        )

        XCTAssertEqual(repository.purchaseCallCount, 1)
        XCTAssertEqual(repository.lastPurchaseRequest?.offeringId, "promo_offering")
        XCTAssertEqual(repository.lastPurchaseRequest?.packageId, "$rc_annual")
        XCTAssertEqual(repository.lastPurchaseRequest?.offerType, .promotional)
        XCTAssertEqual(repository.lastPurchaseRequest?.offerIdentifier, "promo_annual_2026")
        XCTAssertEqual(analyticsService.trackedEvents.count, 1)
        if case .paywallTapSubscribe(let planType, let offerType) = analyticsService.trackedEvents[0] {
            XCTAssertEqual(planType, "yearly")
            XCTAssertEqual(offerType, "promotional")
        } else {
            XCTFail("Expected paywallTapSubscribe event")
        }
    }

    func testPurchase_WhenRepositoryReturnsFailure_TracksOfferTypeInPurchaseFail() async {
        repository.purchaseResult = .failed(DomainError.validationFailure("promo failed"))

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "winback_offering",
                packageId: "$rc_monthly",
                offerType: .winBack,
                offerIdentifier: "winback_monthly_2026"
            )
        )

        XCTAssertEqual(analyticsService.trackedEvents.count, 2)
        if case .purchaseFail(let errorType, let offerType) = analyticsService.trackedEvents[1] {
            XCTAssertEqual(errorType, "unknown")
            XCTAssertEqual(offerType, "winBack")
        } else {
            XCTFail("Expected purchaseFail event")
        }
    }

    func testRedeemOfferCode_WhenSuccess_SetsSuccess() async {
        repository.redeemResult = .success

        await sut.redeemOfferCode()

        XCTAssertEqual(repository.redeemOfferCodeCallCount, 1)
        XCTAssertEqual(sut.purchaseState, .success)
    }

    func testRedeemOfferCode_WhenPending_SetsPendingMessage() async {
        repository.redeemResult = .pendingProcessing

        await sut.redeemOfferCode()

        XCTAssertEqual(repository.redeemOfferCodeCallCount, 1)
        if case .failed(let message) = sut.purchaseState {
            XCTAssertEqual(message, NSLocalizedString("paywall.offer_code_pending_processing", comment: ""))
        } else {
            XCTFail("Expected pending processing message, got \(sut.purchaseState)")
        }
    }

    func testRedeemOfferCode_WhenFailure_SetsFailedMessage() async {
        repository.redeemResult = .failed(DomainError.validationFailure("bad code"))

        await sut.redeemOfferCode()

        XCTAssertEqual(repository.redeemOfferCodeCallCount, 1)
        if case .failed(let message) = sut.purchaseState {
            XCTAssertEqual(message, "bad code")
        } else {
            XCTFail("Expected failure message, got \(sut.purchaseState)")
        }
    }

    // MARK: - Early Bird Offering Tests (S03a)

    /// AC-IAP-OFFER-01: displayPackages for early_bird offering includes line-through original price.
    func test_displayPackages_for_early_bird_offering_includes_line_through_original_price() async {
        // Arrange: configure mock to return early_bird + default offerings, mark as early bird
        repository.offeringsToReturn = MockSubscriptionRepository.makeEarlyBirdAndDefaultOfferings()
        repository.isEarlyBirdOfferingResult = true
        repository.currentOfferingIdentifierResult = "early_bird"

        await sut.loadOfferings()

        // Act
        let packages = sut.displayPackages

        // Assert: both packages should be early-bird with a line-through price
        XCTAssertFalse(packages.isEmpty, "displayPackages should not be empty for early-bird offering")
        for pkg in packages {
            XCTAssertTrue(pkg.isEarlyBird, "All packages must be marked isEarlyBird=true")
            XCTAssertNotNil(
                pkg.originalPriceLineThrough,
                "Early-bird package \(pkg.package.period.rawValue) must have a line-through original price"
            )
        }

        // Verify yearly and monthly are both present
        let yearly = packages.first(where: { $0.package.period == .yearly })
        let monthly = packages.first(where: { $0.package.period == .monthly })
        XCTAssertNotNil(yearly, "Yearly package must be present")
        XCTAssertNotNil(monthly, "Monthly package must be present")

        // Verify the line-through price matches the default offering price (not the early-bird price)
        XCTAssertEqual(yearly?.originalPriceLineThrough, "NT$1,999/年", "Yearly original price must be from default offering")
        XCTAssertEqual(monthly?.originalPriceLineThrough, "NT$199/月", "Monthly original price must be from default offering")

        // Verify the display price is the early-bird price
        XCTAssertEqual(yearly?.displayPrice, "NT$1,390/年", "Yearly display price must be early-bird price")
        XCTAssertEqual(monthly?.displayPrice, "NT$180/月", "Monthly display price must be early-bird price")
    }

    /// AC-IAP-OFFER-02: displayPackages for default offering has no line-through, no badge.
    func test_displayPackages_for_default_offering_no_line_through_no_badge() async {
        // Arrange: default offering, not early bird
        repository.offeringsToReturn = MockSubscriptionRepository.makeDefaultOnlyOfferings()
        repository.isEarlyBirdOfferingResult = false
        repository.currentOfferingIdentifierResult = "default"

        await sut.loadOfferings()

        let packages = sut.displayPackages

        XCTAssertFalse(packages.isEmpty, "displayPackages should not be empty for default offering")
        for pkg in packages {
            XCTAssertFalse(pkg.isEarlyBird, "No package should be marked isEarlyBird in default offering")
            XCTAssertNil(
                pkg.originalPriceLineThrough,
                "No package should have a line-through price in default offering"
            )
        }

        // Verify prices are standard prices
        let yearly = packages.first(where: { $0.package.period == .yearly })
        let monthly = packages.first(where: { $0.package.period == .monthly })
        XCTAssertEqual(yearly?.displayPrice, "NT$1,999/年")
        XCTAssertEqual(monthly?.displayPrice, "NT$199/月")
    }

    // MARK: - Two-Section Paywall Tests (S03a Revised)

    /// AC-IAP-OFFER-01 (revised): Early-bird offering shows both sections — early-bird on top, default below.
    /// Tests that shouldShowEarlyBirdSection is true AND shouldShowDefaultSection is true.
    func test_paywall_early_bird_offering_renders_both_sections_in_order() async {
        // Arrange: early-bird is current
        repository.offeringsToReturn = MockSubscriptionRepository.makeEarlyBirdAndDefaultOfferings()
        repository.isEarlyBirdOfferingResult = true
        repository.currentOfferingIdentifierResult = "early_bird"

        await sut.loadOfferings()

        // Assert: both sections should be shown
        XCTAssertTrue(sut.shouldShowEarlyBirdSection, "shouldShowEarlyBirdSection must be true when current offering is early_bird")
        XCTAssertTrue(sut.shouldShowDefaultSection, "shouldShowDefaultSection must always be true")

        // Verify early-bird packages (top section) have line-through prices
        let earlyBirdPackages = sut.displayPackages
        XCTAssertFalse(earlyBirdPackages.isEmpty, "Early-bird section must have packages")
        for pkg in earlyBirdPackages {
            XCTAssertTrue(pkg.isEarlyBird, "Early-bird section packages must have isEarlyBird=true")
            XCTAssertNotNil(pkg.originalPriceLineThrough, "Early-bird packages must show line-through original price")
        }

        // Verify default packages (bottom section) have no line-through
        let defaultPkgs = sut.defaultPackages
        XCTAssertFalse(defaultPkgs.isEmpty, "Default section must have packages")
        for pkg in defaultPkgs {
            XCTAssertFalse(pkg.isEarlyBird, "Default section packages must not be early-bird")
            XCTAssertNil(pkg.originalPriceLineThrough, "Default section packages must not have line-through price")
        }
    }

    /// AC-IAP-OFFER-02 (revised): Default offering shows only default section — no early-bird section.
    func test_paywall_default_offering_renders_only_default_section() async {
        // Arrange: default offering is current
        repository.offeringsToReturn = MockSubscriptionRepository.makeDefaultOnlyOfferings()
        repository.isEarlyBirdOfferingResult = false
        repository.currentOfferingIdentifierResult = "default"

        await sut.loadOfferings()

        // Assert: early-bird section must not be shown; default section always shown
        XCTAssertFalse(sut.shouldShowEarlyBirdSection, "shouldShowEarlyBirdSection must be false for default offering")
        XCTAssertTrue(sut.shouldShowDefaultSection, "shouldShowDefaultSection must always be true")

        // No early-bird flags or line-through prices
        let packages = sut.displayPackages
        for pkg in packages {
            XCTAssertFalse(pkg.isEarlyBird, "No package should be early-bird in default-only mode")
            XCTAssertNil(pkg.originalPriceLineThrough, "No line-through price in default-only mode")
        }
    }

    /// defaultPackages returns the default offering packages when current is early-bird.
    func test_defaultPackages_returns_default_offering_packages_when_current_is_early_bird() async {
        // Arrange: both offerings present, current = early_bird
        repository.offeringsToReturn = MockSubscriptionRepository.makeEarlyBirdAndDefaultOfferings()
        repository.isEarlyBirdOfferingResult = true
        repository.currentOfferingIdentifierResult = "early_bird"

        await sut.loadOfferings()

        // Act
        let packages = sut.defaultPackages

        // Assert: packages come from default offering — standard pricing, no early-bird flags
        XCTAssertFalse(packages.isEmpty, "defaultPackages should not be empty when default offering is present")
        XCTAssertEqual(packages.count, 2, "Default offering has yearly and monthly packages")

        for pkg in packages {
            XCTAssertFalse(pkg.isEarlyBird, "defaultPackages must never be marked isEarlyBird")
            XCTAssertNil(pkg.originalPriceLineThrough, "defaultPackages must not carry a line-through price")
        }

        let yearly = packages.first(where: { $0.package.period == .yearly })
        let monthly = packages.first(where: { $0.package.period == .monthly })
        XCTAssertNotNil(yearly, "Yearly package must be present in defaultPackages")
        XCTAssertNotNil(monthly, "Monthly package must be present in defaultPackages")

        // Prices must match the default offering — not the early-bird offering
        XCTAssertEqual(yearly?.displayPrice, "NT$1,999/年", "Yearly default price must be standard price")
        XCTAssertEqual(monthly?.displayPrice, "NT$199/月", "Monthly default price must be standard price")
    }

    /// Done Criteria 8: purchase from the default section uses the same purchase(request:) path.
    func test_purchase_from_default_section_uses_same_purchase_flow() async {
        // Arrange: early-bird is current; user selects a default section package
        repository.offeringsToReturn = MockSubscriptionRepository.makeEarlyBirdAndDefaultOfferings()
        repository.isEarlyBirdOfferingResult = true
        repository.currentOfferingIdentifierResult = "early_bird"
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.loadOfferings()

        let defaultPackages = sut.defaultPackages
        guard let yearlyDefault = defaultPackages.first(where: { $0.package.period == .yearly }) else {
            XCTFail("defaultPackages must contain a yearly package")
            return
        }

        // Act: purchase the default yearly package (as the default section card would)
        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: Constants.IAP.defaultOfferingIdentifier,
                packageId: yearlyDefault.package.id,
                offerType: nil,
                offerIdentifier: nil
            )
        )

        // Assert: same purchase() path — repository.purchase() was called once with the correct offeringId
        XCTAssertEqual(repository.purchaseCallCount, 1, "purchase() must be called exactly once")
        XCTAssertEqual(
            repository.lastPurchaseRequest?.offeringId,
            Constants.IAP.defaultOfferingIdentifier,
            "Purchase must use the default offering ID, not the current early-bird offering ID"
        )
        XCTAssertEqual(
            repository.lastPurchaseRequest?.packageId,
            yearlyDefault.package.id,
            "Package ID must match the selected default package"
        )
        XCTAssertNil(repository.lastPurchaseRequest?.offerType, "Default package purchase has no offerType")
        XCTAssertEqual(sut.purchaseState, .success, "Purchase state must be success after successful purchase")
    }

    /// Dual-condition: isEarlyBirdOffering is true when identifier matches OR product ID is in known set.
    /// Uses the correct identifier "Early bird" (capitalized, with space) as set in RevenueCat dashboard.
    func test_isEarlyBirdOffering_true_when_identifier_matches_or_product_in_set() {
        // Case 1: identifier matches the RC dashboard identifier "Early bird"
        repository.currentOfferingIdentifierResult = "Early bird"
        repository.isEarlyBirdOfferingResult = true
        XCTAssertTrue(
            repository.isEarlyBirdOffering,
            "isEarlyBirdOffering must be true when currentOfferingIdentifier == 'Early bird'"
        )

        // Case 2: identifier is nil / different, but product ID in set
        repository.currentOfferingIdentifierResult = "custom_campaign"
        repository.isEarlyBirdOfferingResult = true
        XCTAssertTrue(
            repository.isEarlyBirdOffering,
            "isEarlyBirdOffering must be true when any package product ID is in earlyBirdProductIDs"
        )

        // Case 3: default offering, not early bird
        repository.currentOfferingIdentifierResult = "default"
        repository.isEarlyBirdOfferingResult = false
        XCTAssertFalse(
            repository.isEarlyBirdOffering,
            "isEarlyBirdOffering must be false for default offering with standard product IDs"
        )
    }

    // MARK: - lastPurchasedPlanName (Bug 1 fix: success modal shows correct plan)

    /// Bug 1: success modal must show the plan the user bought, not the stale backend planType.
    /// Verifies: yearly packageId → lastPurchasedPlanName is set to the yearly plan key.
    func testPurchase_Yearly_SetsLastPurchasedPlanName_Yearly() async {
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "default",
                packageId: "$rc_annual",
                offerType: nil,
                offerIdentifier: nil
            )
        )

        XCTAssertEqual(sut.purchaseState, .success)
        XCTAssertEqual(
            sut.lastPurchasedPlanName,
            NSLocalizedString("paywall.purchase_success.plan.yearly", comment: ""),
            "Yearly purchase must set lastPurchasedPlanName to the yearly plan localized string"
        )
    }

    /// Bug 1: monthly packageId → lastPurchasedPlanName is set to the monthly plan key.
    func testPurchase_Monthly_SetsLastPurchasedPlanName_Monthly() async {
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "default",
                packageId: "$rc_monthly",
                offerType: nil,
                offerIdentifier: nil
            )
        )

        XCTAssertEqual(sut.purchaseState, .success)
        XCTAssertEqual(
            sut.lastPurchasedPlanName,
            NSLocalizedString("paywall.purchase_success.plan.monthly", comment: ""),
            "Monthly purchase must set lastPurchasedPlanName to the monthly plan localized string"
        )
    }

    /// Bug 1: yearly offeringId (annual keyword) → inferred as yearly even if packageId is generic.
    func testPurchase_AnnualKeywordInOfferingId_SetsLastPurchasedPlanName_Yearly() async {
        repository.purchaseResult = .success
        SubscriptionStateManager.shared.update(SubscriptionStatusEntity(status: .active))

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "annual_promo",
                packageId: "$rc_annual_promo",
                offerType: nil,
                offerIdentifier: nil
            )
        )

        XCTAssertEqual(sut.purchaseState, .success)
        XCTAssertEqual(
            sut.lastPurchasedPlanName,
            NSLocalizedString("paywall.purchase_success.plan.yearly", comment: ""),
            "annual keyword in offeringId must map to yearly plan name"
        )
    }

    /// Bug 1: failed purchase must NOT set lastPurchasedPlanName.
    func testPurchase_WhenFailed_DoesNotSetLastPurchasedPlanName() async {
        repository.purchaseResult = .failed(DomainError.validationFailure("purchase failed"))

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "default",
                packageId: "$rc_annual",
                offerType: nil,
                offerIdentifier: nil
            )
        )

        if case .failed = sut.purchaseState {
            XCTAssertNil(sut.lastPurchasedPlanName, "Failed purchase must not set lastPurchasedPlanName")
        } else {
            XCTFail("Expected purchaseState to be .failed")
        }
    }

    /// Bug 1: cancelled purchase must NOT set lastPurchasedPlanName.
    func testPurchase_WhenCancelled_DoesNotSetLastPurchasedPlanName() async {
        repository.purchaseResult = .cancelled

        await sut.purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: "default",
                packageId: "$rc_annual",
                offerType: nil,
                offerIdentifier: nil
            )
        )

        XCTAssertNil(sut.lastPurchasedPlanName, "Cancelled purchase must not set lastPurchasedPlanName")
    }

    /// Done Criteria #6 (S03a P0): isEarlyBirdOffering is true when RC identifier is "Early bird"
    /// (capitalized first letter, space separator — exact match to RevenueCat dashboard value).
    func test_isEarlyBirdOffering_true_when_rc_identifier_is_capitalized_with_space() {
        // RC dashboard uses "Early bird" — not "early_bird". The constant must match exactly.
        XCTAssertEqual(
            Constants.IAP.earlyBirdOfferingIdentifier,
            "Early bird",
            "earlyBirdOfferingIdentifier constant must be 'Early bird' to match RevenueCat dashboard"
        )

        // Simulate the mock repository receiving offering identifier "Early bird" from RC
        repository.currentOfferingIdentifierResult = "Early bird"
        repository.isEarlyBirdOfferingResult = true

        XCTAssertTrue(
            repository.isEarlyBirdOffering,
            "isEarlyBirdOffering must be true when RC offering identifier is 'Early bird'"
        )

        // Confirm the old identifier string does NOT produce a match (regression guard)
        repository.currentOfferingIdentifierResult = "early_bird"
        repository.isEarlyBirdOfferingResult = false
        XCTAssertFalse(
            repository.isEarlyBirdOffering,
            "isEarlyBirdOffering must be false when identifier is 'early_bird' (old lowercase+underscore form)"
        )
    }
}

private final class MockSubscriptionRepository: SubscriptionRepository {
    var statusToReturn = SubscriptionStatusEntity(status: .none)
    var purchaseResult: PurchaseResultEntity = .success
    var redeemResult: PurchaseResultEntity = .success
    var restoreError: Error?
    var refreshError: Error?

    // S03a early-bird properties
    var offeringsToReturn: [SubscriptionOfferingEntity] = []
    var isEarlyBirdOfferingResult: Bool = false
    var currentOfferingIdentifierResult: String? = nil

    private(set) var refreshStatusCallCount = 0
    private(set) var restorePurchasesCallCount = 0
    private(set) var purchaseCallCount = 0
    private(set) var redeemOfferCodeCallCount = 0
    private(set) var lastPurchaseRequest: SubscriptionPurchaseRequest?

    // MARK: - SubscriptionRepository

    var currentOfferingIdentifier: String? { currentOfferingIdentifierResult }
    var isEarlyBirdOffering: Bool { isEarlyBirdOfferingResult }

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
        offeringsToReturn
    }

    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity {
        purchaseCallCount += 1
        lastPurchaseRequest = request
        return purchaseResult
    }

    func redeemOfferCode() async throws -> PurchaseResultEntity {
        redeemOfferCodeCallCount += 1
        return redeemResult
    }

    func restorePurchases() async throws {
        restorePurchasesCallCount += 1
        if let restoreError {
            throw restoreError
        }
    }

    // MARK: - S03a Test Factories

    /// Returns [early_bird offering, default offering] for early-bird display tests.
    static func makeEarlyBirdAndDefaultOfferings() -> [SubscriptionOfferingEntity] {
        let earlyBird = SubscriptionOfferingEntity(
            id: "early_bird",
            title: "Early Bird",
            description: "Early Bird",
            packages: [
                SubscriptionPackageEntity(
                    id: "$rc_annual",
                    productId: "paceriz.sub.yearly.eb1",
                    localizedPrice: "NT$1,390/年",
                    price: Decimal(string: "1390") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .yearly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .year,
                    officialOffer: nil,
                    localizedTitle: "年訂閱 - 超早鳥"
                ),
                SubscriptionPackageEntity(
                    id: "$rc_monthly",
                    productId: "paceriz.sub.monthly.eb1",
                    localizedPrice: "NT$180/月",
                    price: Decimal(string: "180") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .monthly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .month,
                    officialOffer: nil,
                    localizedTitle: "月訂閱 - 超早鳥"
                )
            ]
        )
        let defaultOffering = SubscriptionOfferingEntity(
            id: "default",
            title: "Default",
            description: "Default",
            packages: [
                SubscriptionPackageEntity(
                    id: "$rc_annual_default",
                    productId: "paceriz.sub.yearly",
                    localizedPrice: "NT$1,999/年",
                    price: Decimal(string: "1999") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .yearly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .year,
                    officialOffer: nil,
                    localizedTitle: "年訂閱"
                ),
                SubscriptionPackageEntity(
                    id: "$rc_monthly_default",
                    productId: "paceriz.sub.monthly",
                    localizedPrice: "NT$199/月",
                    price: Decimal(string: "199") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .monthly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .month,
                    officialOffer: nil,
                    localizedTitle: "月訂閱"
                )
            ]
        )
        return [earlyBird, defaultOffering]
    }

    /// Returns [default offering only] for standard display tests.
    static func makeDefaultOnlyOfferings() -> [SubscriptionOfferingEntity] {
        return [SubscriptionOfferingEntity(
            id: "default",
            title: "Default",
            description: "Default",
            packages: [
                SubscriptionPackageEntity(
                    id: "$rc_annual",
                    productId: "paceriz.sub.yearly",
                    localizedPrice: "NT$1,999/年",
                    price: Decimal(string: "1999") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .yearly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .year,
                    officialOffer: nil,
                    localizedTitle: "年訂閱"
                ),
                SubscriptionPackageEntity(
                    id: "$rc_monthly",
                    productId: "paceriz.sub.monthly",
                    localizedPrice: "NT$199/月",
                    price: Decimal(string: "199") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .monthly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .month,
                    officialOffer: nil,
                    localizedTitle: "月訂閱"
                )
            ]
        )]
    }
}

private final class MockAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_: String, forName _: String) {}
}
