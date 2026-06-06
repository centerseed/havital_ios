import Foundation

// MARK: - DailyStateRepositoryImpl
/// Data Layer — 持有 RemoteDataSource，協調 API 呼叫 + DTO→Entity 映射。
/// ⚠️ Repository 為被動資料存取，不碰 CacheEventBus（事件流屬於 ViewModel/Service 層）。
final class DailyStateRepositoryImpl: DailyStateRepository {

    private let remoteDataSource: DailyStateRemoteDataSourceProtocol

    init(remoteDataSource: DailyStateRemoteDataSourceProtocol = DailyStateRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
        Logger.debug("[DailyStateRepositoryImpl] 初始化完成")
    }

    func fetchTodayState() async throws -> DailyStateCard {
        let dto = try await remoteDataSource.fetchTodayState()
        return StateCardMapper.toEntity(from: dto)
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {
    /// 註冊 DailyState 模組依賴。
    /// RepositoryImpl 註冊為 singleton（對應 DailyStateRepository protocol）。
    func registerDailyStateModule() {
        let remoteDS = DailyStateRemoteDataSource()
        let repository = DailyStateRepositoryImpl(remoteDataSource: remoteDS)
        register(repository as DailyStateRepository, forProtocol: DailyStateRepository.self)

        Logger.debug("[DI] DailyState module dependencies registered")
    }
}
