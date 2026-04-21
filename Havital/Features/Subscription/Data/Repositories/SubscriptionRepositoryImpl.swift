import Foundation
import RevenueCat
import StoreKit
import UIKit

// MARK: - SubscriptionRepositoryImpl
/// 訂閱 Repository 實作 - Data Layer
/// 協調 RemoteDataSource 和 LocalDataSource，實現 TTL 緩存策略
/// 以 Singleton 方式管理（在 DI 容器中只建立一個實例）
final class SubscriptionRepositoryImpl: SubscriptionRepository {

    // MARK: - Dependencies

    private let remoteDataSource: SubscriptionRemoteDataSourceProtocol
    private let localDataSource: SubscriptionLocalDataSourceProtocol

    /// 快取最近一次 fetchOfferings 結果，避免 purchase 時重複拉取
    private var cachedOfferings: Offerings?

    // MARK: - Initialization

    init(
        remoteDataSource: SubscriptionRemoteDataSourceProtocol = SubscriptionRemoteDataSource(),
        localDataSource: SubscriptionLocalDataSourceProtocol = SubscriptionLocalDataSource()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        Logger.debug("[SubscriptionRepositoryImpl] 初始化完成")
    }

    // MARK: - SubscriptionRepository Protocol

    func getStatus() async throws -> SubscriptionStatusEntity {
        if !localDataSource.isExpired(), let cachedDTO = localDataSource.getStatus() {
            Logger.debug("[SubscriptionRepositoryImpl] getStatus: cache hit")
            let cachedEntity = SubscriptionMapper.toEntity(from: cachedDTO)
            await SubscriptionStateManager.shared.update(cachedEntity)
            return cachedEntity
        }
        Logger.debug("[SubscriptionRepositoryImpl] getStatus: cache miss, fetching from API")
        do {
            return try await fetchAndCache()
        } catch {
            // Stale-on-error: 離線或 API 失敗時，回傳過期的 cache 而非拋錯
            // 避免已付費用戶因網路問題被誤顯示付費牆
            if let staleDTO = localDataSource.getStatus() {
                Logger.debug("[SubscriptionRepositoryImpl] getStatus: network error, using stale cache")
                let staleEntity = SubscriptionMapper.toEntity(from: staleDTO)
                await SubscriptionStateManager.shared.update(staleEntity)
                return staleEntity
            }
            throw error
        }
    }

    func refreshStatus() async throws -> SubscriptionStatusEntity {
        Logger.debug("[SubscriptionRepositoryImpl] refreshStatus: bypassing cache")
        return try await fetchAndCache()
    }

    func getCachedStatus() -> SubscriptionStatusEntity? {
        guard let cachedDTO = localDataSource.getStatus() else { return nil }
        return SubscriptionMapper.toEntity(from: cachedDTO)
    }

    func clearCache() {
        localDataSource.clearAll()
        Logger.debug("[SubscriptionRepositoryImpl] cache cleared")
    }

    // MARK: - RevenueCat 購買功能

    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] {
        Logger.debug("[SubscriptionRepositoryImpl] fetchOfferings: calling RevenueCat")
        do {
            let offerings = try await Purchases.shared.offerings()
            cachedOfferings = offerings
            let entities = offerings.all.values.map { offering in
                let packages = offering.availablePackages.map { package -> SubscriptionPackageEntity in
                    let period: SubscriptionPeriod = package.packageType == .annual ? .yearly : .monthly
                    let storeProduct = package.storeProduct
                    let billingPeriodValue = storeProduct.subscriptionPeriod?.value ?? 1
                    let billingPeriodUnit = storeProduct.subscriptionPeriod.map { self.mapOfferPeriodUnit($0.unit) }
                        ?? (period == .yearly ? .year : .month)

                    var candidateDiscounts: [StoreProductDiscount] = []
                    if let intro = storeProduct.introductoryDiscount {
                        candidateDiscounts.append(intro)
                    }
                    candidateDiscounts.append(contentsOf: storeProduct.discounts)

                    Logger.debug(
                        "[SubscriptionRepositoryImpl] product=\(storeProduct.productIdentifier) " +
                        "base=\(package.localizedPriceString) intro=\(storeProduct.introductoryDiscount != nil) " +
                        "discountCount=\(candidateDiscounts.count)"
                    )

                    let officialOffer = self.selectDisplayOffer(
                        from: candidateDiscounts,
                        regularPrice: storeProduct.price,
                        basePeriodValue: billingPeriodValue,
                        basePeriodUnit: billingPeriodUnit
                    )

                    if let officialOffer {
                        Logger.debug(
                            "[SubscriptionRepositoryImpl] product=\(storeProduct.productIdentifier) " +
                            "officialOffer type=\(officialOffer.type.rawValue) " +
                            "paymentMode=\(officialOffer.paymentMode.rawValue) " +
                            "price=\(officialOffer.localizedPrice)"
                        )
                    } else {
                        Logger.debug("[SubscriptionRepositoryImpl] product=\(storeProduct.productIdentifier) no official offer")
                    }

                    return SubscriptionPackageEntity(
                        id: package.identifier,
                        productId: storeProduct.productIdentifier,
                        localizedPrice: package.localizedPriceString,
                        price: storeProduct.price,
                        currencyCode: storeProduct.currencyCode,
                        localeIdentifier: storeProduct.priceFormatter?.locale.identifier,
                        period: period,
                        billingPeriodValue: billingPeriodValue,
                        billingPeriodUnit: billingPeriodUnit,
                        officialOffer: officialOffer
                    )
                }
                return SubscriptionOfferingEntity(
                    id: offering.identifier,
                    title: offering.serverDescription,
                    description: offering.serverDescription,
                    packages: packages
                )
            }
            let hasPackages = entities.contains { !$0.packages.isEmpty }
            if hasPackages { return entities }
            // Fall through to DEBUG mock if RevenueCat returned no packages
        } catch {
            Logger.debug("[SubscriptionRepositoryImpl] fetchOfferings: RevenueCat error: \(error)")
            // Fall through to DEBUG mock
        }
        // DEBUG fallback: RevenueCat returns empty/error until Apple approves IAP products.
        // Remove once paceriz.sub.monthly / paceriz.sub.yearly are approved.
        #if DEBUG
        Logger.debug("[SubscriptionRepositoryImpl] fetchOfferings: DEBUG fallback mock")
        return [SubscriptionOfferingEntity(
            id: "default", title: "Paceriz Premium", description: "Paceriz Premium",
            packages: [
                SubscriptionPackageEntity(
                    id: "$rc_annual",
                    productId: "paceriz.sub.yearly",
                    localizedPrice: "NT$1,790/年",
                    price: Decimal(string: "1790") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .yearly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .year,
                    officialOffer: nil
                ),
                SubscriptionPackageEntity(
                    id: "$rc_monthly",
                    productId: "paceriz.sub.monthly",
                    localizedPrice: "NT$180/月",
                    price: Decimal(string: "180") ?? .zero,
                    currencyCode: "TWD",
                    localeIdentifier: "zh_TW",
                    period: .monthly,
                    billingPeriodValue: 1,
                    billingPeriodUnit: .month,
                    officialOffer: nil
                )
            ]
        )]
        #else
        return []
        #endif
    }

    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity {
        Logger.debug(
            "[SubscriptionRepositoryImpl] purchase: offeringId=\(request.offeringId) " +
            "packageId=\(request.packageId) offerType=\(request.offerType?.rawValue ?? "standard") " +
            "offerIdentifier=\(request.offerIdentifier ?? "none")"
        )
        if let offerType = request.offerType, offerType == .winBack {
            Logger.debug(
                "[SubscriptionRepositoryImpl] purchase: \(offerType.rawValue) offer detected; " +
                "falling back to standard RevenueCat package purchase until win-back flow is implemented"
            )
        }
        let offerings: Offerings
        if let cached = cachedOfferings {
            offerings = cached
        } else {
            offerings = try await Purchases.shared.offerings()
        }
        guard let offering = offerings.offering(identifier: request.offeringId),
              let package = offering.package(identifier: request.packageId) else {
            return .failed(
                DomainError.unknown(
                    "Package not found: \(request.offeringId)/\(request.packageId)"
                )
            )
        }
        do {
            guard await AuthenticationViewModel.shared.ensureRevenueCatIdentitySynced() else {
                return .failed(DomainError.validationFailure("Unable to verify subscription identity. Please try again."))
            }

            let purchaseResultData: PurchaseResultData
            if request.offerType == .promotional,
               let promotionalOffer = await eligiblePromotionalOffer(
                   for: package.storeProduct,
                   preferredIdentifier: request.offerIdentifier
               ) {
                Logger.debug(
                    "[SubscriptionRepositoryImpl] purchase: applying promotional offer " +
                    "\(promotionalOffer.discount.offerIdentifier ?? promotionalOffer.signedData.identifier)"
                )
                purchaseResultData = try await Purchases.shared.purchase(
                    package: package,
                    promotionalOffer: promotionalOffer
                )
            } else {
                purchaseResultData = try await Purchases.shared.purchase(package: package)
            }

            let (_, customerInfo, userCancelled) = purchaseResultData
            if userCancelled { return .cancelled }
            if await publishOptimisticStatusIfPossible(from: customerInfo) {
                Task {
                    _ = try? await self.waitForBackendAuthorizedStatus()
                }
                return .success
            }
            return try await waitForBackendAuthorizedStatus()
        } catch let error as RevenueCat.ErrorCode {
            switch error {
            case .purchaseCancelledError: return .cancelled
            case .paymentPendingError: return .pendingProcessing
            default: return .failed(error)
            }
        } catch {
            return .failed(error)
        }
    }

    func redeemOfferCode() async throws -> PurchaseResultEntity {
        Logger.debug("[SubscriptionRepositoryImpl] redeemOfferCode: presenting Apple redeem sheet")

        guard await AuthenticationViewModel.shared.ensureRevenueCatIdentitySynced() else {
            return .failed(
                DomainError.validationFailure(
                    NSLocalizedString(
                        "paywall.offer_code_identity_sync_failed",
                        comment: "Unable to verify subscription identity before redeeming an offer code"
                    )
                )
            )
        }

        do {
            try await presentOfferCodeRedeemSheet()
            return try await waitForBackendAuthorizedStatus()
        } catch {
            return .failed(error.toDomainError())
        }
    }

    func restorePurchases() async throws {
        Logger.debug("[SubscriptionRepositoryImpl] restorePurchases: calling RevenueCat")
        guard await AuthenticationViewModel.shared.ensureRevenueCatIdentitySynced() else {
            throw DomainError.validationFailure("Unable to verify subscription identity. Please try again.")
        }
        let customerInfo = try await Purchases.shared.restorePurchases()
        if customerInfo.entitlements[RevenueCatConfig.premiumEntitlement]?.isActive == true {
            _ = await publishOptimisticStatusIfPossible(from: customerInfo)
            Logger.debug("[SubscriptionRepositoryImpl] restorePurchases: active entitlement, refreshing backend status")
            Task {
                _ = try? await self.waitForBackendAuthorizedStatus()
            }
        }
    }

    // MARK: - Private

    private func fetchAndCache() async throws -> SubscriptionStatusEntity {
        let dto = try await remoteDataSource.fetchStatus()
        let apiEntity = SubscriptionMapper.toEntity(from: dto)
        localDataSource.saveStatus(dto)
        await SubscriptionStateManager.shared.update(apiEntity)
        return apiEntity
    }

    @MainActor
    private func presentOfferCodeRedeemSheet() async throws {
        guard let scene = activeWindowScene() else {
            throw DomainError.validationFailure(
                NSLocalizedString(
                    "paywall.offer_code_scene_unavailable",
                    comment: "No active scene available for the Apple offer code sheet"
                )
            )
        }

        try await AppStore.presentOfferCodeRedeemSheet(in: scene)
    }

    @MainActor
    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        return scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            ?? scenes.first
    }

    private func waitForBackendAuthorizedStatus(
        maxAttempts: Int = 15,
        delaySeconds: UInt64 = 2
    ) async throws -> PurchaseResultEntity {
        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }

            let status = try await fetchAndCache()
            switch status.status {
            case .active, .trial, .cancelled, .gracePeriod:
                return .success
            case .expired, .none:
                continue
            }
        }

        return .pendingProcessing
    }

    private func eligiblePromotionalOffer(
        for product: StoreProduct,
        preferredIdentifier: String?
    ) async -> PromotionalOffer? {
        let eligibleOffers = await product.eligiblePromotionalOffers()
        guard !eligibleOffers.isEmpty else {
            Logger.debug("[SubscriptionRepositoryImpl] purchase: no eligible promotional offers found")
            return nil
        }

        if let preferredIdentifier,
           let matchingOffer = eligibleOffers.first(where: { offer in
               offer.discount.offerIdentifier == preferredIdentifier || offer.signedData.identifier == preferredIdentifier
           }) {
            return matchingOffer
        }

        Logger.debug("[SubscriptionRepositoryImpl] purchase: preferred promotional offer not found, using first eligible offer")
        return eligibleOffers.first
    }

    private func publishOptimisticStatusIfPossible(from customerInfo: CustomerInfo) async -> Bool {
        guard let entitlement = customerInfo.entitlements[RevenueCatConfig.premiumEntitlement],
              entitlement.isActive else {
            return false
        }

        let dto = SubscriptionStatusDTO(
            status: "subscribed",
            expiresAt: entitlement.expirationDate.map { Self.iso8601String(from: $0) },
            planType: resolvePlanType(from: entitlement.productIdentifier),
            rizoUsage: nil,
            billingIssue: false,
            enforcementEnabled: localDataSource.getStatus()?.enforcementEnabled ?? true
        )
        localDataSource.saveStatus(dto)

        let entity = SubscriptionMapper.toEntity(from: dto)
        await SubscriptionStateManager.shared.update(entity)
        Logger.debug("[SubscriptionRepositoryImpl] optimistic unlock published: status=\(entity.status.rawValue)")
        return true
    }

    private func resolvePlanType(from productIdentifier: String?) -> String? {
        guard let productIdentifier = productIdentifier?.lowercased() else { return nil }
        if productIdentifier.contains("year") || productIdentifier.contains("annual") {
            return "yearly"
        }
        if productIdentifier.contains("month") {
            return "monthly"
        }
        return nil
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func mapOfferType(_ type: StoreProductDiscount.DiscountType) -> SubscriptionOfferType {
        switch type {
        case .introductory:
            return .introductory
        case .promotional:
            return .promotional
        case .winBack:
            return .winBack
        @unknown default:
            return .introductory
        }
    }

    private func mapOfficialOffer(_ discount: StoreProductDiscount) -> SubscriptionOfficialOffer {
        SubscriptionOfficialOffer(
            offerIdentifier: discount.offerIdentifier,
            type: mapOfferType(discount.type),
            paymentMode: mapOfferPaymentMode(discount.paymentMode),
            price: discount.price,
            localizedPrice: discount.localizedPriceString,
            periodValue: discount.subscriptionPeriod.value,
            periodUnit: mapOfferPeriodUnit(discount.subscriptionPeriod.unit),
            numberOfPeriods: discount.numberOfPeriods
        )
    }

    private func selectDisplayOffer(
        from discounts: [StoreProductDiscount],
        regularPrice: Decimal,
        basePeriodValue: Int,
        basePeriodUnit: SubscriptionOfferPeriodUnit
    ) -> SubscriptionOfficialOffer? {
        guard !discounts.isEmpty else { return nil }
        let regularPriceValue = NSDecimalNumber(decimal: regularPrice).doubleValue
        let baseDays = basePeriodUnit.lengthInDays(value: basePeriodValue)

        let bestDiscount = discounts.max { lhs, rhs in
            let leftScore = offerScore(discount: lhs, regularPrice: regularPriceValue, baseDays: baseDays)
            let rightScore = offerScore(discount: rhs, regularPrice: regularPriceValue, baseDays: baseDays)
            return leftScore < rightScore
        }

        guard let bestDiscount else { return nil }
        return mapOfficialOffer(bestDiscount)
    }

    private func offerScore(discount: StoreProductDiscount, regularPrice: Double, baseDays: Double) -> Double {
        if discount.paymentMode == .freeTrial {
            return 1_000_000
        }

        let offerPeriodUnit = mapOfferPeriodUnit(discount.subscriptionPeriod.unit)
        let offerPeriodDays = offerPeriodUnit.lengthInDays(value: discount.subscriptionPeriod.value)
        let totalPeriods = Double(max(1, discount.numberOfPeriods))
        let offerTotalDays = offerPeriodDays * totalPeriods
        guard regularPrice > 0, baseDays > 0, offerTotalDays > 0 else { return 0 }

        let regularTotal = regularPrice * (offerTotalDays / baseDays)
        let offerPrice = NSDecimalNumber(decimal: discount.price).doubleValue
        let offerTotal: Double = {
            switch discount.paymentMode {
            case .payAsYouGo:
                return offerPrice * totalPeriods
            case .payUpFront:
                return offerPrice
            case .freeTrial:
                return 0
            @unknown default:
                return offerPrice
            }
        }()

        guard regularTotal > 0 else { return 0 }
        let savingsRatio = max(0, (regularTotal - offerTotal) / regularTotal)
        return savingsRatio
    }


    private func mapOfferPaymentMode(_ mode: StoreProductDiscount.PaymentMode) -> SubscriptionOfferPaymentMode {
        switch mode {
        case .payAsYouGo:
            return .payAsYouGo
        case .payUpFront:
            return .payUpFront
        case .freeTrial:
            return .freeTrial
        @unknown default:
            return .payUpFront
        }
    }

    private func mapOfferPeriodUnit(_ unit: RevenueCat.SubscriptionPeriod.Unit) -> SubscriptionOfferPeriodUnit {
        switch unit {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        @unknown default:
            return .month
        }
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {

    /// 註冊 Subscription 模組依賴
    func registerSubscriptionModule() {
        Logger.debug("[DI] registerSubscriptionModule() called")

        // 已在 Singleton 模式下只建立一個實例
        let repository = SubscriptionRepositoryImpl()
        register(repository as SubscriptionRepository, forProtocol: SubscriptionRepository.self)

        Logger.debug("[DI] ✅ Subscription module registered")
    }
}
