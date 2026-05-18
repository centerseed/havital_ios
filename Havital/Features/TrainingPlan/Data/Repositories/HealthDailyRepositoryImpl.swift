import Foundation

final class HealthDailyRepositoryImpl: HealthDailyRepository {
    private let remoteDataSource: HealthDailyRemoteDataSource

    init(remoteDataSource: HealthDailyRemoteDataSource = HealthDailyRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
        try await remoteDataSource.fetchHealthDaily(limit: limit)
    }
}
