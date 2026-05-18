import Foundation

protocol HealthDailyRepository {
    func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse
}
