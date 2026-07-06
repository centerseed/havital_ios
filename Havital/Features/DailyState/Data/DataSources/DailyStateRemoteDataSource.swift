import Foundation

// MARK: - DailyStateRemoteDataSource Protocol
protocol DailyStateRemoteDataSourceProtocol {
    func fetchTodayState() async throws -> StateCardDTO
    func applyBenchmark(_ request: BenchmarkApplyRequestDTO) async throws -> BenchmarkApplyResultDTO
    func scheduleNextBenchmark(_ request: BenchmarkScheduleRequestDTO) async throws -> BenchmarkScheduleResultDTO
}

// MARK: - DailyStateRemoteDataSource
/// Data Layer — `GET /v2/state/today` 的遠端呼叫。
/// 用 APICallHelper 統一錯誤處理；用 tracked(...) 標記來源以利 production 追蹤。
final class DailyStateRemoteDataSource: DailyStateRemoteDataSourceProtocol {

    private let apiHelper: APICallHelper

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "DailyStateRemoteDS"
        )
    }

    func fetchTodayState() async throws -> StateCardDTO {
        Logger.debug("[DailyStateRemoteDS] Fetching today state")
        return try await tracked("DailyStateRemoteDataSource: fetchTodayState") {
            try await apiHelper.get(StateCardDTO.self, path: "/v2/state/today")
        }
    }

    func applyBenchmark(_ request: BenchmarkApplyRequestDTO) async throws -> BenchmarkApplyResultDTO {
        Logger.debug("[DailyStateRemoteDS] Applying benchmark calibration")
        return try await tracked("DailyStateRemoteDataSource: applyBenchmark") {
            try await apiHelper.post(
                BenchmarkApplyResultDTO.self,
                path: "/v2/workouts/benchmark/apply",
                body: request
            )
        }
    }

    func scheduleNextBenchmark(_ request: BenchmarkScheduleRequestDTO) async throws -> BenchmarkScheduleResultDTO {
        Logger.debug("[DailyStateRemoteDS] Scheduling next benchmark")
        return try await tracked("DailyStateRemoteDataSource: scheduleNextBenchmark") {
            try await apiHelper.post(
                BenchmarkScheduleResultDTO.self,
                path: "/v2/workouts/benchmark/schedule-next",
                body: request
            )
        }
    }
}
