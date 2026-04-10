import Foundation

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
        return try await fetchAndCache()
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

    // MARK: - ADR-002 Stubs (RevenueCat not yet configured)

    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] {
        Logger.debug("[SubscriptionRepositoryImpl] fetchOfferings: stub — RevenueCat not configured")
        return []
    }

    func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity {
        Logger.debug("[SubscriptionRepositoryImpl] purchase: stub — RevenueCat not configured")
        return .failed(DomainError.unknown("RevenueCat not configured"))
    }

    func restorePurchases() async throws {
        Logger.debug("[SubscriptionRepositoryImpl] restorePurchases: stub — RevenueCat not configured")
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
