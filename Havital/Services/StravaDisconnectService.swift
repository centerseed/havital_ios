import Foundation

/// Strava 解除綁定服務
/// 負責調用後端API來解除Strava連接，確保符合隱私法規要求
class StravaDisconnectService {
    static let shared = StravaDisconnectService()
    
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
    
    /// 移除 Strava 連接 (RESTful 標準)
    /// - Returns: HTTP 狀態碼和回應
    func removeStravaConnection() async throws -> (statusCode: Int, data: Data) {
        do {
            let rawData = try await httpClient.request(
                path: "/connect/strava",
                method: .DELETE,
                body: nil
            )
            
            Logger.firebase(
                "Strava 連接移除成功",
                level: .info,
                labels: [
                    "module": "StravaDisconnectService",
                    "action": "remove_strava_connection"
                ]
            )
            
            // 假設成功時返回 200 狀態碼
            return (statusCode: 200, data: rawData)
            
        } catch {
            Logger.firebase(
                "Strava 連接移除失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "StravaDisconnectService",
                    "action": "remove_strava_connection"
                ],
                jsonPayload: [
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }
    
    /// 解除Strava綁定
    /// - Returns: 解除綁定結果
    func disconnectStrava() async throws -> StravaDisconnectResponse {
        do {
            let response: StravaDisconnectResponse = try await makeAPICall(
                StravaDisconnectResponse.self,
                path: "/connect/strava/disconnect",
                method: .POST
            )
            
            Logger.firebase(
                "Strava 解除綁定成功",
                level: .info,
                labels: [
                    "module": "StravaDisconnectService",
                    "action": "disconnect_strava"
                ],
                jsonPayload: [
                    "provider": response.data?.provider ?? "strava",
                    "user_id": response.data?.user_id ?? "unknown",
                    "disconnected_at": response.data?.disconnected_at ?? ""
                ]
            )
            
            return response
        } catch {
            Logger.firebase(
                "Strava 解除綁定失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "StravaDisconnectService",
                    "action": "disconnect_strava"
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

struct StravaDisconnectResponse: Codable {
    let success: Bool
    let message: String
    let data: StravaDisconnectData?
}

struct StravaDisconnectData: Codable {
    let provider: String
    let user_id: String
    let disconnected_at: String
    let note: String
}