import Foundation
import Network

// 網路錯誤類型 - 與TrainingPlanViewModel中的NetworkError保持一致
enum APINetworkError: Error {
    case noConnection
    case timeout
    case serverError
    case badResponse
}

// 網路狀態監測
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected: Bool = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
}

// APIResponse is now defined in Services/Core/UnifiedAPIResponse.swift

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
        
        // 檢查網路連接狀態
        if !NetworkMonitor.shared.isConnected {
            throw APINetworkError.noConnection
        }
        
        let (data, resp): (Data, URLResponse)
        
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let urlError as URLError {
            // 處理URLError錯誤
            throw self.classifyURLError(urlError)
        } catch {
            // 其他錯誤直接拋出
            throw error
        }
        
        guard let http = resp as? HTTPURLResponse else {
            throw APINetworkError.badResponse
        }
        
        Logger.debug("\(method) \(path) status code: \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            Logger.error("Error response body: \(bodyStr)")
            
            // 根據狀態碼判斷錯誤類型
            let error = self.classifyError(statusCode: http.statusCode, responseBody: bodyStr)
            throw error
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
                
                // 特別檢查是否為運動詳情請求
                if path.contains("/v2/workouts/") && !path.contains("stats") {
                    print("⚠️ [運動詳情] 這是運動詳情 API 請求，檢查 V2 模型是否正確使用 SafeDouble/SafeInt")
                    
                    // 嘗試解析成基本 JSON 來檢查結構
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                        print("🔍 [運動詳情] JSON 結構檢查:")
                        if let dict = jsonObject as? [String: Any] {
                            print("  - 頂層鍵: \(dict.keys.sorted())")
                            if let success = dict["success"] {
                                print("  - success: \(success)")
                            }
                            if let dataObj = dict["data"] as? [String: Any] {
                                print("  - data 鍵: \(dataObj.keys.sorted())")
                                if let basicMetrics = dataObj["basic_metrics"] as? [String: Any] {
                                    print("  - basic_metrics 鍵: \(basicMetrics.keys.sorted())")
                                }
                                if let advancedMetrics = dataObj["advanced_metrics"] as? [String: Any] {
                                    print("  - advanced_metrics 鍵: \(advancedMetrics.keys.sorted())")
                                }
                            }
                        }
                    }
                }
                
                print("=====================================")
                
                // If both fail, throw the original APIResponse parsing error
                throw finalError
            }
        }
    }

    /// 通用無回傳請求
    func requestNoResponse(path: String, method: String = "DELETE", body: Data? = nil) async throws {
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
    
    // MARK: - Error Classification
    
    /// 根據狀態碼分類錯誤
    private func classifyError(statusCode: Int, responseBody: String) -> Error {
        switch statusCode {
        case 404:
            // 404錯誤保持原來的NSError格式，不改變現有流程
            return NSError(domain: "APIClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: responseBody])
        case 500...599:
            return APINetworkError.serverError
        case 408:
            return APINetworkError.timeout
        default:
            return NSError(domain: "APIClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: responseBody])
        }
    }
    
    /// 根據URLError分類錯誤
    private func classifyURLError(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return APINetworkError.noConnection
        case .timedOut:
            return APINetworkError.timeout
        case .badServerResponse:
            return APINetworkError.badResponse
        default:
            return error
        }
    }
}

// MARK: - Health Daily API Extension
extension APIClient {
    /// 獲取每日健康數據
    func fetchHealthDaily(limit: Int = 7) async throws -> HealthDailyResponse {
        let path = "/v2/workouts/health_daily?limit=\(limit)"
        return try await request(HealthDailyResponse.self, path: path)
    }
}

// MARK: - Health Data Models
struct HealthRecord: Codable, Equatable {
    let date: String
    let dailyCalories: Int?
    let hrvLastNightAvg: Double?
    let restingHeartRate: Int?
    
    enum CodingKeys: String, CodingKey {
        case date
        case dailyCalories = "daily_calories"
        case hrvLastNightAvg = "hrv_last_night_avg"
        case restingHeartRate = "resting_heart_rate"
    }
}

struct HealthDailyResponse: Codable {
    let healthData: [HealthRecord]
    let count: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case healthData = "health_data"
        case count, limit
    }
}
