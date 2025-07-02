import Foundation

/// 通用 API 回應結構
// MARK: - API Response Base
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

struct APIErrorResponse: Codable {
    let success: Bool
    let error: APIError
    
    struct APIError: Codable {
        let code: String
        let message: String
    }
}

/// 通用 API 客戶端，管理請求、認證與解碼
actor APIClient {
    static let shared = APIClient()
    private init() {}

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) async throws -> URLRequest {
        let urlString = APIConfig.baseURL + path
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Bearer Token: include for all except login, verify, resend
        if !(path.hasPrefix("/login/email") || path.hasPrefix("/verify/email") || path.hasPrefix("/resend/email") || path.hasPrefix("/register/email")) {
            let token = try await AuthenticationService.shared.getIdToken()
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // 將 request body 設置到 httpBody
        if let body = body {
            req.httpBody = body
        }
        return req
    }

    /// 通用請求並解碼 APIResponse 包裝的資料
    func request<T: Codable>(_ type: T.Type,
                                path: String,
                                method: String = "GET",
                                body: Data? = nil) async throws -> T {
        let req = try await makeRequest(path: path, method: method, body: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.debug("\(method) \(path) status code: \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            Logger.error("Error response body: \(bodyStr)")
            throw NSError(domain: "APIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: bodyStr])
        }
        let decoder = JSONDecoder()
        do {
            let wrapped = try decoder.decode(APIResponse<T>.self, from: data)
            return wrapped.data
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "data" {
            // Fallback: parse raw T if data field missing
            return try decoder.decode(T.self, from: data)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "success" {
            // Fallback: parse raw T if success field missing (API doesn't use APIResponse wrapper)
            return try decoder.decode(T.self, from: data)
        } catch {
            // If APIResponse parsing fails, try parsing raw T directly
            do {
                return try decoder.decode(T.self, from: data)
            } catch let finalError {
                // 輸出原始 API 回應到 console 以便 debug
                let responseString = String(data: data, encoding: .utf8) ?? "無法解析回應內容"
                print("🚨 [APIClient] JSON 解析失敗")
                print("🔍 請求路徑: \(path)")
                print("🔍 期望類型: \(String(describing: T.self))")
                print("🔍 原始 API 回應:")
                print(responseString)
                print("🔍 解析錯誤: \(finalError)")
                print("=====================================")
                
                // If both fail, throw the original APIResponse parsing error
                throw finalError
            }
        }
    }

    /// 通用無回傳請求
    func requestNoResponse(path: String, method: String = "DELETE", body: Data? = nil) async throws {
        let req = try await makeRequest(path: path, method: method, body: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.debug("\(method) \(path) status code: \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            let bodyData = try await URLSession.shared.data(for: req).0
            let bodyStr = String(data: bodyData, encoding: .utf8) ?? ""
            Logger.error("Error response body: \(bodyStr)")
            throw NSError(domain: "APIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: bodyStr])
        }
    }

    /// 發送請求並返回 HTTP 狀態，供上層檢查
    func requestWithStatus(path: String, method: String = "GET", body: Data? = nil) async throws -> HTTPURLResponse {
        let req = try await makeRequest(path: path, method: method, body: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.debug("\(method) \(path) status code: \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            Logger.error("Error response body: \(bodyStr)")
            throw NSError(domain: "APIClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: bodyStr])
        }
        return http
    }
}
