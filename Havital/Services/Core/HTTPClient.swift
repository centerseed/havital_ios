import Foundation

// MARK: - HTTP Client Protocol

/// 純粹的 HTTP 通信介面，不涉及具體業務邏輯
protocol HTTPClient {
    /// 發送 HTTP 請求並返回原始數據
    /// - Parameters:
    ///   - path: API 路徑
    ///   - method: HTTP 方法
    ///   - body: 請求體數據
    ///   - customHeaders: 自定義 HTTP 標頭（可選）
    /// - Returns: 原始 JSON 數據
    func request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> Data
}

// MARK: - HTTPClient Extension

extension HTTPClient {
    /// 向後相容的請求方法，不使用自定義 headers
    func request(path: String, method: HTTPMethod = .GET, body: Data? = nil) async throws -> Data {
        return try await request(path: path, method: method, body: body, customHeaders: nil)
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - HTTP Client Implementation

/// 預設的 HTTP 客戶端實現
actor DefaultHTTPClient: HTTPClient {
    static let shared = DefaultHTTPClient()
    private init() {}
    
    func request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> Data {
        let request = try await buildRequest(path: path, method: method, body: body, customHeaders: customHeaders)
        
        // 增強日誌：記錄請求詳情
        Logger.debug("[HTTPClient] 發送請求: \(method.rawValue) \(path)")
        if let bodyData = body {
            Logger.debug("[HTTPClient] 請求體大小: \(bodyData.count) bytes")
        }
        
        // 檢查網路連接
        if !NetworkMonitor.shared.isConnected {
            Logger.error("[HTTPClient] 網路未連接")
            throw HTTPError.noConnection
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("[HTTPClient] 無效的 HTTP 回應")
                throw HTTPError.invalidResponse("不是有效的 HTTP 回應")
            }
            
            Logger.debug("[HTTPClient] \(method.rawValue) \(path) -> \(httpResponse.statusCode), 響應大小: \(data.count) bytes")
            
            // 檢查 HTTP 狀態碼
            try validateHTTPResponse(httpResponse, data: data)
            
            return data
            
        } catch let urlError as URLError {
            // 取消錯誤使用 debug 級別，其他錯誤使用 error 級別
            if urlError.code == .cancelled {
                Logger.debug("[HTTPClient] 請求被取消 - \(method.rawValue) \(path)")
            } else {
                Logger.error("[HTTPClient] URL 錯誤 - 請求: \(method.rawValue) \(path)")
                Logger.error("[HTTPClient] 錯誤詳情: \(urlError.localizedDescription)")
                Logger.error("[HTTPClient] 錯誤代碼: \(urlError.code.rawValue)")
                if let failingURL = urlError.failingURL {
                    Logger.error("[HTTPClient] 失敗的 URL: \(failingURL.absoluteString)")
                }
            }
            throw mapURLErrorToHTTPError(urlError)
        }
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> URLRequest {
        let urlString = APIConfig.baseURL + path
        guard let url = URL(string: urlString) else {
            throw HTTPError.invalidURL(urlString)
        }
        
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加 Accept-Language 標頭（除非自定義 headers 中已包含）
        if customHeaders?["Accept-Language"] == nil {
            request.setValue(LanguageManager.shared.currentLanguage.apiCode, forHTTPHeaderField: "Accept-Language")
        }
        
        // 添加自定義 headers（優先級最高）
        if let customHeaders = customHeaders {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加認證 token（除了登入相關端點，且沒有自定義 Authorization）
        if !isAuthenticationEndpoint(path: path) && customHeaders?["Authorization"] == nil {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 設置請求體
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func validateHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(response.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "無法解析錯誤回應"
            Logger.error("HTTP 錯誤 \(response.statusCode): \(errorBody)")
            
            switch response.statusCode {
            case 400:
                throw HTTPError.badRequest(errorBody)
            case 401:
                throw HTTPError.unauthorized(errorBody)
            case 403:
                throw HTTPError.forbidden(errorBody)
            case 404:
                throw HTTPError.notFound(errorBody)
            case 500...599:
                throw HTTPError.serverError(response.statusCode, errorBody)
            default:
                throw HTTPError.httpError(response.statusCode, errorBody)
            }
        }
    }
    
    private func mapURLErrorToHTTPError(_ error: URLError) -> HTTPError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .badServerResponse:
            return .invalidResponse("伺服器回應無效")
        case .cancelled:
            return .cancelled
        default:
            return .networkError(error.localizedDescription)
        }
    }
    
    private func isAuthenticationEndpoint(path: String) -> Bool {
        return path.hasPrefix("/login/") ||
               path.hasPrefix("/verify/") ||
               path.hasPrefix("/resend/") ||
               path.hasPrefix("/register/")
    }
}

// MARK: - HTTP Errors

enum HTTPError: Error, LocalizedError {
    case invalidURL(String)
    case noConnection
    case timeout
    case cancelled
    case badRequest(String)
    case unauthorized(String)
    case forbidden(String)
    case notFound(String)
    case httpError(Int, String)
    case serverError(Int, String)
    case networkError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "無效的 URL: \(url)"
        case .noConnection:
            return "無網路連接"
        case .timeout:
            return "請求超時"
        case .cancelled:
            return "請求已取消"
        case .badRequest(let message):
            return "請求錯誤: \(message)"
        case .unauthorized(let message):
            return "未授權: \(message)"
        case .forbidden(let message):
            return "禁止訪問: \(message)"
        case .notFound(let message):
            return "資源不存在: \(message)"
        case .httpError(let code, let message):
            return "HTTP 錯誤 \(code): \(message)"
        case .serverError(let code, let message):
            return "伺服器錯誤 \(code): \(message)"
        case .networkError(let message):
            return "網路錯誤: \(message)"
        case .invalidResponse(let message):
            return "無效回應: \(message)"
        }
    }
    
    // 判斷是否為取消錯誤
    var isCancelled: Bool {
        if case .cancelled = self {
            return true
        }
        return false
    }
    
    // 判斷是否為網路相關錯誤
    var isNetworkError: Bool {
        switch self {
        case .noConnection, .timeout, .networkError:
            return true
        default:
            return false
        }
    }
}