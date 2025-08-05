import Foundation

/// Garmin 連線狀態檢查服務
class GarminConnectionStatusService {
    static let shared = GarminConnectionStatusService()
    
    private init() {}
    
    /// 檢查 Garmin 連線狀態
    /// - Returns: 連線狀態回應
    func checkConnectionStatus() async throws -> GarminConnectionStatusResponse {
        return try await APIClient.shared.request(
            GarminConnectionStatusResponse.self,
            path: "/connect/garmin/status",
            method: "GET"
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
        return connected && status == "active"
    }
}