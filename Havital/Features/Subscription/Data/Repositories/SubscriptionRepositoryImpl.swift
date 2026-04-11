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
            return SubscriptionMapper.toEntity(from: cachedDTO)
        }
        Logger.debug("[SubscriptionRepositoryImpl] getStatus: cache miss, fetching from API")
        do {
            return try await fetchAndCache()
        } catch {
            // Stale-on-error: 離線或 API 失敗時，回傳過期的 cache 而非拋錯
            // 避免已付費用戶因網路問題被誤顯示付費牆
            if let staleDTO = localDataSource.getStatus() {
                Logger.debug("[SubscriptionRepositoryImpl] getStatus: network error, using stale cache")
                return SubscriptionMapper.toEntity(from: staleDTO)
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
        let offerings = try await Purchases.shared.offerings()
        return offerings.all.values.map { offering in
            let packages = offering.availablePackages.map { package -> SubscriptionPackageEntity in
                let period: SubscriptionPeriod = package.packageType == .annual ? .yearly : .monthly
                return SubscriptionPackageEntity(
                    id: package.identifier,
                    productId: package.storeProduct.productIdentifier,
                    localizedPrice: package.localizedPriceString,
                    period: period
                )
            }
            return SubscriptionOfferingEntity(
                id: offering.identifier,
                title: offering.serverDescription,
                description: offering.serverDescription,
                packages: packages
            )
        }
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
        localDataSource.saveStatus(dto)
        let entity = SubscriptionMapper.toEntity(from: dto)
        await SubscriptionStateManager.shared.update(entity)
        return entity
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
