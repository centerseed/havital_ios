import Foundation

// MARK: - HealthDailyDataSourceProtocol
/// `GET /v2/workouts/health_daily` 的窄介面。
///
/// 為什麼補 protocol：2.0 的「恢復」指標詳情（checklist §53）是 ViewModel 直接讀這條
/// 序列，而 `.claude/rules/architecture.md` 要求 ViewModel 依 protocol 而非具體實作。
/// **沒有第二份實作**，只是把依賴方向立起來、讓投影能離線測。
protocol HealthDailyDataSourceProtocol {
    func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse
}

final class HealthDailyRemoteDataSource: HealthDailyDataSourceProtocol {
    private let httpClient: HTTPClient
    private let parser: APIParser

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
        let path = "/v2/workouts/health_daily?limit=\(limit)"
        let rawData = try await tracked("HealthDailyRemoteDataSource: fetchHealthDaily") {
            try await httpClient.request(path: path, method: .GET, body: nil)
        }
        return try ResponseProcessor.extractData(HealthDailyResponse.self, from: rawData, using: parser)
    }
}
