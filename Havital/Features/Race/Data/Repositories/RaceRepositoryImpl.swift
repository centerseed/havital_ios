import Foundation

// MARK: - RaceRepositoryImpl
/// 賽事 Repository 實作 - Data Layer
/// 實作 RaceRepository Protocol，串接 DataSource + Mapper
final class RaceRepositoryImpl: RaceRepository {

    // MARK: - Dependencies

    private let remoteDataSource: RaceRemoteDataSourceProtocol

    // MARK: - Initialization

    init(remoteDataSource: RaceRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - RaceRepository

    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> [RaceEvent] {
        Logger.debug("[RaceRepo] getRaces: region=\(region ?? "all"), curatedOnly=\(curatedOnly ?? false)")

        do {
            let response = try await remoteDataSource.getRaces(
                region: region,
                distanceMin: distanceMin,
                distanceMax: distanceMax,
                dateFrom: dateFrom,
                dateTo: dateTo,
                query: query,
                curatedOnly: curatedOnly,
                limit: limit,
                offset: offset
            )

            let entities = RaceMapper.toEntities(from: response.races)
            Logger.info("[RaceRepo] getRaces: \(entities.count) events mapped (raw=\(response.races.count))")
            return entities
        } catch {
            Logger.error("[RaceRepo] getRaces failed: \(error.localizedDescription)")
            throw error.toDomainError()
        }
    }
}

// MARK: - Dependency Injection
extension DependencyContainer {

    /// 註冊 Race 模組依賴
    /// 包含 DataSources、Repository 的註冊
    func registerRaceModule() {
        let remoteDS = RaceRemoteDataSource()
        register(remoteDS, forProtocol: RaceRemoteDataSourceProtocol.self)

        let repository = RaceRepositoryImpl(
            remoteDataSource: resolve() as RaceRemoteDataSourceProtocol
        )
        register(repository as RaceRepository, forProtocol: RaceRepository.self)

        Logger.debug("[DI] Race module dependencies registered")
    }
}
