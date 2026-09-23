import Foundation

protocol AthleteStateMetricsDataSourceProtocol {
    func fetchMetrics() async throws -> AthleteStateMetricsResponse
}

final class AthleteStateMetricsRemoteDataSource: AthleteStateMetricsDataSourceProtocol {
    private let apiHelper: APICallHelper

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "AthleteStateMetricsRemoteDS"
        )
    }

    func fetchMetrics() async throws -> AthleteStateMetricsResponse {
        try await tracked("AthleteStateMetricsRemoteDataSource: fetchMetrics") {
            try await apiHelper.get(
                AthleteStateMetricsResponse.self,
                path: "/v2/athlete-state/metrics"
            )
        }
    }
}
