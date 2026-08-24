import Foundation

// MARK: - App2RemoteDataSource
/// Data Layer — 2.0 骨架自己要打、而 repo 內尚無呼叫端的端點。
///
/// 目前只有一條：`GET /v2/athlete-state/metrics`（§3.1a 指標網格）。其餘畫面一律
/// 走既有的 repository／data source，不在這裡開第二條路：
///
/// | 需要的東西 | 走哪個既有出口 |
/// |---|---|
/// | `StateCard.headline`／`narrative_text` | `DailyStateRepository` |
/// | `current_week`／`total_weeks` | `TrainingPlanV2RemoteDataSource.getPlanStatus()` |
/// | 目標賽事名／日期／目標成績 | `TargetRepository.getTargets()`（`/user/targets`） |
/// | 預估完賽 | `TrainingReadinessViewModel.estimatedRaceTime` |
/// | 週課表 | `TrainingPlanV2RemoteDataSource.getWeeklyPlan(planId:)` |
/// | 30 天彙總／8 週序列／YTD | `WorkoutRemoteDataSource.fetchWorkoutStats(days:weeks:)` |
/// | 訓練紀錄清單 | `WorkoutRemoteDataSource.fetchRecentWorkouts(pageSize:)` |
protocol App2RemoteDataSourceProtocol {
    func fetchAthleteStateMetrics() async throws -> AthleteStateMetricsDTO
}

final class App2RemoteDataSource: App2RemoteDataSourceProtocol {

    private let apiHelper: APICallHelper

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "App2RemoteDS"
        )
    }

    func fetchAthleteStateMetrics() async throws -> AthleteStateMetricsDTO {
        Logger.debug("[App2RemoteDS] Fetching athlete state metrics")
        return try await tracked("App2RemoteDataSource: fetchAthleteStateMetrics") {
            try await apiHelper.call(AthleteStateMetricsDTO.self, path: "/v2/athlete-state/metrics")
        }
    }
}

// MARK: - AthleteStateMetricsDTO
/// Wire DTO for `GET /v2/athlete-state/metrics`。
///
/// `envelope` 由 estimator 決定形狀，本層**不強型別化**：`read_materialized_metrics`
/// 的規格是「envelope 原封不動交出、no grading、no sentence rendering」
/// （ME-INV-05）。強行把它打成固定欄位會在 estimator 換版時靜默掉值。
struct AthleteStateMetricsDTO: Codable {
    let uid: String?
    let maturity: String?
    let metrics: [String: AthleteStateMetricRowDTO]?
}

struct AthleteStateMetricRowDTO: Codable {
    let itemId: String?
    let asOf: String?
    let estimatorVersion: String?
    /// `nil` ＋ `deliveryStatus == "not_computed"` = 這一列從沒被算過。
    let deliveryStatus: String?
    let envelope: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case asOf = "as_of"
        case estimatorVersion = "estimator_version"
        case deliveryStatus = "delivery_status"
        case envelope
    }

    /// 從 envelope 撈點估計。estimator 之間欄位名不一致，逐一試已知的鍵。
    var pointEstimate: Double? {
        guard let envelope else { return nil }
        for key in ["point_estimate", "value", "estimate", "score", "level"] {
            if let number = envelope[key]?.doubleValue {
                return number
            }
        }
        return nil
    }
}
