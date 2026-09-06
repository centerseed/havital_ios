import Foundation

// MARK: - AthleteStateSeriesDataSourceProtocol
/// `GET /v2/athlete-state/metrics/series` 的窄介面。
///
/// 為什麼是這條而不是首頁那條：`/v2/state/today` 只交當下那一格（卡片層評好級的
/// 文案），逐日序列另有端點，**且首頁請求不因為詳情頁多任何查詢**
/// （SPEC-today-state §4.5：卡片本身不帶序列）。
protocol AthleteStateSeriesDataSourceProtocol {
    func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse
}

final class AthleteStateSeriesRemoteDataSource: AthleteStateSeriesDataSourceProtocol {
    private let apiHelper: APICallHelper

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "AthleteStateSeriesRemoteDS"
        )
    }

    /// 窗一定要明給。不給的話後端預設 90 天，那是三倍的資料量與三倍的補算範圍
    /// （這條 GET 會補算缺的日子）。
    func fetchMetricSeries(startDay: String, endDay: String) async throws -> AthleteStateSeriesResponse {
        try await tracked("AthleteStateSeriesRemoteDataSource: fetchMetricSeries") {
            try await apiHelper.get(
                AthleteStateSeriesResponse.self,
                path: "/v2/athlete-state/metrics/series?start_day=\(startDay)&end_day=\(endDay)"
            )
        }
    }
}
