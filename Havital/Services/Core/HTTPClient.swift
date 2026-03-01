import Foundation
import FirebaseAuth

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

    // Clean Architecture: Use AuthSessionRepository instead of AuthenticationService
    private var authSessionRepository: AuthSessionRepository {
        DependencyContainer.shared.resolve()
    }

    // MARK: - Retry Configuration
    private let maxRetries = 3
    private let maxTotalRetryTime: TimeInterval = 10.0
    private let baseRetryDelay: TimeInterval = 1.0  // 指數退避：1s, 2s, 4s

    private init() {}
    
    func request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> Data {
        let request = try await buildRequest(path: path, method: method, body: body, customHeaders: customHeaders)

        // 🔍 記錄 API 調用來源和開始時間
        let source = APICallTracker.getCurrentSource()
        let startTime = Date()

        // 📱 記錄 API 調用開始
        print("📱 [API] \(source) → \(method.rawValue) \(path)")
        Logger.debug("📱 [API] \(source) → \(method.rawValue) \(path)")

        // 檢查網路連接
        if !NetworkMonitor.shared.isConnected {
            Logger.error("❌ 網路未連接")
            await APICallTracker.shared.logAPICallError(source: source, method: method.rawValue, path: path, error: HTTPError.noConnection)
            throw HTTPError.noConnection
        }

        // 🔄 帶重試機制的請求
        var lastError: Error?
        var retryCount = 0
        let retryStartTime = Date()

        while retryCount <= maxRetries {
            // 檢查是否超過最大重試時間
            if retryCount > 0 && Date().timeIntervalSince(retryStartTime) >= maxTotalRetryTime {
                Logger.warn("[HTTPClient] ⏱️ 重試超時，已用時 \(String(format: "%.1f", Date().timeIntervalSince(retryStartTime)))s")
                break
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    Logger.error("❌ 無效的 HTTP 回應")
                    throw HTTPError.invalidResponse("不是有效的 HTTP 回應")
                }

                // 🔒 401 錯誤自動重試機制（token 可能剛過期）
                if httpResponse.statusCode == 401 && !isAuthenticationEndpoint(path: path) {
                    Logger.warn("[HTTPClient] 收到 401 錯誤，嘗試刷新 token 並重試: \(method.rawValue) \(path)")

                    Logger.firebase(
                        "收到 401 錯誤 - 嘗試刷新 token",
                        level: .warn,
                        labels: [
                            "module": "HTTPClient",
                            "action": "401_retry",
                            "user_id": Auth.auth().currentUser?.uid ?? "unknown"
                        ],
                        jsonPayload: [
                            "path": path,
                            "method": method.rawValue
                        ]
                    )

                    // 強制刷新 token
                    do {
                        _ = try await authSessionRepository.refreshIdToken()

                        // 用新 token 重建請求
                        let retryRequest = try await buildRequest(path: path, method: method, body: body, customHeaders: customHeaders)
                        let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)

                        guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                            throw HTTPError.invalidResponse("重試請求無效回應")
                        }

                        Logger.debug("[HTTPClient] 重試成功: \(method.rawValue) \(path) -> \(retryHttpResponse.statusCode)")

                        Logger.firebase(
                            "401 重試成功",
                            level: .info,
                            labels: [
                                "module": "HTTPClient",
                                "action": "401_retry_success",
                                "user_id": Auth.auth().currentUser?.uid ?? "unknown"
                            ],
                            jsonPayload: [
                                "path": path,
                                "method": method.rawValue,
                                "status_code": retryHttpResponse.statusCode
                            ]
                        )

                        // 檢查重試的 HTTP 狀態碼
                        try validateHTTPResponse(retryHttpResponse, data: retryData)

                        return retryData
                    } catch {
                        Logger.error("[HTTPClient] Token 刷新或重試失敗: \(error.localizedDescription)")

                        Logger.firebase(
                            "401 重試失敗",
                            level: .error,
                            labels: [
                                "module": "HTTPClient",
                                "action": "401_retry_failed",
                                "user_id": Auth.auth().currentUser?.uid ?? "unknown"
                            ],
                            jsonPayload: [
                                "path": path,
                                "method": method.rawValue,
                                "error": error.localizedDescription
                            ]
                        )
                        // 繼續拋出原始 401 錯誤
                    }
                }

                // 🔄 5xx 錯誤重試機制
                if (500...599).contains(httpResponse.statusCode) && retryCount < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(retryCount))  // 指數退避：1s, 2s, 4s
                    Logger.warn("[HTTPClient] 🔄 服務器錯誤 \(httpResponse.statusCode)，\(String(format: "%.0f", delay))s 後重試 (\(retryCount + 1)/\(maxRetries)): \(method.rawValue) \(path)")

                    retryCount += 1
                    lastError = HTTPError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // 檢查 HTTP 狀態碼
                try validateHTTPResponse(httpResponse, data: data)

                // ✅ 記錄 API 調用成功
                let duration = Date().timeIntervalSince(startTime)
                let statusLog = retryCount > 0
                    ? "✅ \(httpResponse.statusCode) | \(String(format: "%.2fs", duration)) (重試 \(retryCount) 次後成功)"
                    : "✅ \(httpResponse.statusCode) | \(String(format: "%.2fs", duration))"
                print(statusLog)
                await APICallTracker.shared.logAPICallEnd(
                    source: source,
                    method: method.rawValue,
                    path: path,
                    statusCode: httpResponse.statusCode,
                    duration: duration
                )

                return data

            } catch let urlError as URLError {
                // 取消錯誤不重試
                if urlError.code == .cancelled {
                    Logger.debug("⚠️ 請求被取消")
                    throw mapURLErrorToHTTPError(urlError)
                }

                // 網路錯誤可重試
                if isRetryableURLError(urlError) && retryCount < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(retryCount))
                    Logger.warn("[HTTPClient] 🔄 網路錯誤，\(String(format: "%.0f", delay))s 後重試 (\(retryCount + 1)/\(maxRetries)): \(urlError.localizedDescription)")

                    retryCount += 1
                    lastError = urlError

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                Logger.error("❌ URL 錯誤: \(urlError.localizedDescription)")
                await APICallTracker.shared.logAPICallError(source: source, method: method.rawValue, path: path, error: urlError)
                throw mapURLErrorToHTTPError(urlError)

            } catch is CancellationError {
                Logger.debug("⚠️ 請求任務被取消")
                throw HTTPError.cancelled

            } catch {
                Logger.error("❌ \(error.localizedDescription)")
                await APICallTracker.shared.logAPICallError(source: source, method: method.rawValue, path: path, error: error)
                throw error
            }
        }

        // 所有重試都失敗
        if let lastError = lastError {
            Logger.error("[HTTPClient] ❌ 重試 \(retryCount) 次後仍失敗: \(method.rawValue) \(path)")
            await APICallTracker.shared.logAPICallError(source: source, method: method.rawValue, path: path, error: lastError)
            throw lastError
        }

        throw HTTPError.networkError("請求失敗")
    }

    /// 判斷 URLError 是否可重試
    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
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
            let languageCode = await MainActor.run { LanguageManager.shared.currentLanguage.apiCode }
            request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
        }
        
        // 添加自定義 headers（優先級最高）
        if let customHeaders = customHeaders {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加認證 token（除了登入相關端點，且沒有自定義 Authorization）
        if !isAuthenticationEndpoint(path: path) && customHeaders?["Authorization"] == nil {
            Logger.debug("[HTTPClient] 🔐 Adding authentication token for: \(method.rawValue) \(path)")
            let token = try await authSessionRepository.getIdToken()
            let tokenPreview = String(token.prefix(30))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            Logger.debug("[HTTPClient] 🔐 Authorization header set (token preview: \(tokenPreview)...)")
        } else if isAuthenticationEndpoint(path: path) {
            Logger.debug("[HTTPClient] ⚪ Skipping auth token for authentication endpoint: \(path)")
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
