import Foundation
import RevenueCat

// MARK: - SubscriptionRepositoryImpl
/// 訂閱 Repository 實作 - Data Layer
/// 協調 RemoteDataSource 和 LocalDataSource，實現 TTL 緩存策略
/// 以 Singleton 方式管理（在 DI 容器中只建立一個實例）
final class SubscriptionRepositoryImpl: SubscriptionRepository {

    // MARK: - Dependencies

    private let remoteDataSource: SubscriptionRemoteDataSourceProtocol
    private let localDataSource: SubscriptionLocalDataSourceProtocol

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
            let reconciled = await reconcileWithRevenueCatIfNeeded(entity: cachedEntity, source: "cache")
            await SubscriptionStateManager.shared.update(reconciled)
            return reconciled
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
                let reconciled = await reconcileWithRevenueCatIfNeeded(entity: staleEntity, source: "stale_cache")
                await SubscriptionStateManager.shared.update(reconciled)
                return reconciled
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

    func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity {
        Logger.debug("[SubscriptionRepositoryImpl] purchase: offeringId=\(offeringId) packageId=\(packageId)")
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: offeringId),
              let package = offering.package(identifier: packageId) else {
            return .failed(DomainError.unknown("Package not found: \(offeringId)/\(packageId)"))
        }
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if userCancelled { return .cancelled }
            return customerInfo.entitlements[RevenueCatConfig.premiumEntitlement]?.isActive == true
                ? .success
                : .pendingProcessing
        } catch let error as RevenueCat.ErrorCode {
            switch error {
            case .purchaseCancelledError: return .cancelled
            case .paymentPendingError: return .pendingProcessing
            default: return .failed(error)
            }
        }
    }

    func restorePurchases() async throws {
        Logger.debug("[SubscriptionRepositoryImpl] restorePurchases: calling RevenueCat")
        let customerInfo = try await Purchases.shared.restorePurchases()
        if customerInfo.entitlements[RevenueCatConfig.premiumEntitlement]?.isActive == true {
            Logger.debug("[SubscriptionRepositoryImpl] restorePurchases: active entitlement, refreshing backend status")
            _ = try await refreshStatus()
        }
    }

    // MARK: - Private

    private func fetchAndCache() async throws -> SubscriptionStatusEntity {
        let dto = try await remoteDataSource.fetchStatus()
        let apiEntity = SubscriptionMapper.toEntity(from: dto)
        let entity = await reconcileWithRevenueCatIfNeeded(entity: apiEntity, source: "api")
        if entity.status == apiEntity.status {
            localDataSource.saveStatus(dto)
        } else {
            localDataSource.saveStatus(makeStatusDTO(from: entity))
        }
        await SubscriptionStateManager.shared.update(entity)
        return entity
    }

    private func reconcileWithRevenueCatIfNeeded(
        entity: SubscriptionStatusEntity,
        source: String
    ) async -> SubscriptionStatusEntity {
        guard entity.status == .none || entity.status == .expired || entity.status == .trial else {
            return entity
        }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            guard let entitlement = customerInfo.entitlements[RevenueCatConfig.premiumEntitlement],
                  entitlement.isActive else {
                return entity
            }
            let reconciled = SubscriptionStatusEntity(
                status: .active,
                expiresAt: entitlement.expirationDate?.timeIntervalSince1970 ?? entity.expiresAt,
                planType: entity.planType ?? "premium",
                rizoUsage: entity.rizoUsage,
                billingIssue: entity.billingIssue
            )
            Logger.debug("[SubscriptionRepositoryImpl] \(source): API says \(entity.status.rawValue), reconciled to active from RevenueCat entitlement")
            return reconciled
        } catch {
            Logger.debug("[SubscriptionRepositoryImpl] \(source): RevenueCat reconcile skipped: \(error.localizedDescription)")
            return entity
        }
    }

    private func makeStatusDTO(from entity: SubscriptionStatusEntity) -> SubscriptionStatusDTO {
        SubscriptionStatusDTO(
            status: entity.status.rawValue,
            expiresAt: entity.expiresAt.map(iso8601String(from:)),
            planType: entity.planType,
            rizoUsage: entity.rizoUsage.map { RizoUsageDTO(used: $0.used, limit: $0.limit) },
            billingIssue: entity.billingIssue
        )
    }

    private func iso8601String(from timestamp: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
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
        let baseDays = periodLengthInDays(value: basePeriodValue, unit: basePeriodUnit)

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

        let offerPeriodDays = periodLengthInDays(
            value: discount.subscriptionPeriod.value,
            unit: mapOfferPeriodUnit(discount.subscriptionPeriod.unit)
        )
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

    private func periodLengthInDays(value: Int, unit: SubscriptionOfferPeriodUnit) -> Double {
        let units = Double(max(1, value))
        switch unit {
        case .day:
            return units
        case .week:
            return units * 7
        case .month:
            return units * 30.4375
        case .year:
            return units * 365.25
        }
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
