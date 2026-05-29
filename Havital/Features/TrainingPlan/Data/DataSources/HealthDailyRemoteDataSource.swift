import Foundation

final class HealthDailyRemoteDataSource {
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
