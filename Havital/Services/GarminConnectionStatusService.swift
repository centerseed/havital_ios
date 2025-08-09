import Foundation

/// Garmin 連線狀態檢查服務
class GarminConnectionStatusService {
    static let shared = GarminConnectionStatusService()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser
    
    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }
    
    // MARK: - Unified API Call Method
    
    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
    
    /// 檢查 Garmin 連線狀態
    /// - Returns: 連線狀態回應
    func checkConnectionStatus() async throws -> GarminConnectionStatusResponse {
        return try await makeAPICall(
            GarminConnectionStatusResponse.self,
            path: "/connect/garmin/status",
            method: .GET
        )
    }
}

// MARK: - Response Models

struct GarminConnectionStatusResponse: Codable {
    let success: Bool
    let data: GarminConnectionStatusData?
}

struct GarminConnectionStatusData: Codable {
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