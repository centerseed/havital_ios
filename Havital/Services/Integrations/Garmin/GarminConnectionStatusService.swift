import Foundation

/// Garmin 連線狀態檢查服務
/// Uses APICallHelper for unified error handling
class GarminConnectionStatusService {
    static let shared = GarminConnectionStatusService()

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "GarminConnectionStatus"
        )
    }

    /// 檢查 Garmin 連線狀態
    /// - Returns: 連線狀態回應
    func checkConnectionStatus() async throws -> GarminConnectionStatusResponse {
        return try await apiHelper.get(
            GarminConnectionStatusResponse.self,
            path: "/connect/garmin/status"
        )
    }
}

// MARK: - Response Models

struct GarminConnectionStatusResponse: Codable {
    let connected: Bool
    let provider: String
    let status: String
    let connectedAt: String?
    let lastUpdated: String?
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case connected, provider, status, message
        case connectedAt = "connected_at"
        case lastUpdated = "last_updated"
    }
    
    /// 檢查連線是否為活躍狀態
    var isActive: Bool {
        // 如果 status 為 "active"，就認為連接是活躍的
        // 不依賴 connected 欄位，因為後端可能沒有正確設置該欄位
        return status == "active"
    }
}