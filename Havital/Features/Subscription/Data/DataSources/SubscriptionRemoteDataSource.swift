import Foundation

// MARK: - SubscriptionRemoteDataSource Protocol
protocol SubscriptionRemoteDataSourceProtocol {
    func fetchStatus() async throws -> SubscriptionStatusDTO
}

// MARK: - SubscriptionRemoteDataSource
/// 訂閱狀態遠端資料來源 - Data Layer
/// 負責從 API 取得訂閱狀態
final class SubscriptionRemoteDataSource: SubscriptionRemoteDataSourceProtocol {

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "SubscriptionRemoteDS"
        )
    }

    // MARK: - API Methods

    /// 從 API 取得訂閱狀態
    /// - Returns: 訂閱狀態 DTO
    func fetchStatus() async throws -> SubscriptionStatusDTO {
        Logger.debug("[SubscriptionRemoteDS] fetchStatus: GET /api/v1/subscription/status")
        return try await apiHelper.get(SubscriptionStatusDTO.self, path: "/api/v1/subscription/status")
    }
}
