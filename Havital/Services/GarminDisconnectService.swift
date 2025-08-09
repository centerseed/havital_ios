import Foundation

/// Garmin 解除綁定服務
/// 負責調用後端API來解除Garmin連接，確保符合隱私法規要求
class GarminDisconnectService {
    static let shared = GarminDisconnectService()
    
    private init() {}
    
    /// 解除Garmin綁定
    /// - Returns: 解除綁定結果
    func disconnectGarmin() async throws -> DisconnectResponse {
        do {
            let response = try await APIClient.shared.request(
                DisconnectResponse.self,
                path: "/connect/garmin/disconnect",
                method: "POST"
            )
            
            Logger.firebase(
                "Garmin 解除綁定成功",
                level: .info,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "disconnect_garmin"
                ],
                jsonPayload: [
                    "provider": response.data?.provider ?? "garmin",
                    "user_id": response.data?.user_id ?? "unknown",
                    "disconnected_at": response.data?.disconnected_at ?? ""
                ]
            )
            
            return response
        } catch {
            Logger.firebase(
                "Garmin 解除綁定失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "disconnect_garmin"
                ],
                jsonPayload: [
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }
}

// MARK: - Response Models

struct DisconnectResponse: Codable {
    let success: Bool
    let message: String
    let data: DisconnectData?
}

struct DisconnectData: Codable {
    let provider: String
    let user_id: String
    let disconnected_at: String
    let note: String
} 