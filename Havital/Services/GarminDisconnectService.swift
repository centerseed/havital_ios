import Foundation

/// Garmin 解除綁定服務
/// 負責調用後端API來解除Garmin連接，確保符合隱私法規要求
class GarminDisconnectService {
    static let shared = GarminDisconnectService()
    
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
    
    /// 移除 Garmin 連接 (RESTful 標準)
    /// - Returns: HTTP 狀態碼和回應
    func removeGarminConnection() async throws -> (statusCode: Int, data: Data) {
        do {
            let rawData = try await httpClient.request(
                path: "/connect/garmin",
                method: .DELETE,
                body: nil
            )
            
            Logger.firebase(
                "Garmin 連接移除成功",
                level: .info,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "remove_garmin_connection"
                ]
            )
            
            // 假設成功時返回 200 狀態碼
            return (statusCode: 200, data: rawData)
            
        } catch {
            Logger.firebase(
                "Garmin 連接移除失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "remove_garmin_connection"
                ],
                jsonPayload: [
                    "error": error.localizedDescription
                ]
            )
            throw error
        }
    }
    
    /// 儲存 Garmin PKCE 數據
    /// - Parameters:
    ///   - codeVerifier: PKCE 代碼驗證器
    ///   - state: OAuth 狀態參數
    /// - Returns: HTTP 狀態碼和回應
    func storePKCE(codeVerifier: String, state: String) async throws -> (statusCode: Int, data: Data) {
        let requestData = [
            "code_verifier": codeVerifier,
            "state": state
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            
            let rawData = try await httpClient.request(
                path: "/connect/garmin/store-pkce",
                method: .POST,
                body: jsonData
            )
            
            Logger.firebase(
                "Garmin PKCE 儲存成功",
                level: .info,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "store_pkce"
                ],
                jsonPayload: [
                    "state": state
                ]
            )
            
            // 假設成功時返回 200 狀態碼
            return (statusCode: 200, data: rawData)
            
        } catch {
            Logger.firebase(
                "Garmin PKCE 儲存失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "GarminDisconnectService",
                    "action": "store_pkce"
                ],
                jsonPayload: [
                    "error": error.localizedDescription,
                    "state": state
                ]
            )
            throw error
        }
    }
    
    /// 解除Garmin綁定
    /// - Returns: 解除綁定結果
    func disconnectGarmin() async throws -> DisconnectResponse {
        do {
            let response: DisconnectResponse = try await makeAPICall(
                DisconnectResponse.self,
                path: "/connect/garmin/disconnect",
                method: .POST
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