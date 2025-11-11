import Foundation
import Network

// 網路錯誤類型 - 與TrainingPlanViewModel中的NetworkError保持一致
enum APINetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverError
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return NSLocalizedString("無法連接到網路，請檢查您的網路連接", comment: "No internet connection")
        case .timeout:
            return NSLocalizedString("網路請求超時，請稍後再試", comment: "Request timeout")
        case .serverError:
            return NSLocalizedString("服務器錯誤，請稍後再試", comment: "Server error")
        case .badResponse:
            return NSLocalizedString("無效的服務器回應", comment: "Invalid server response")
        }
    }
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

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, timeoutInterval: TimeInterval = 60) async throws -> URLRequest {
        let urlString = APIConfig.baseURL + path
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
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
                                body: Data? = nil,
                                timeoutInterval: TimeInterval = 60) async throws -> T {
        let req = try await makeRequest(path: path, method: method, body: body, timeoutInterval: timeoutInterval)
        
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

    // TSB Metrics - 從嵌套的 tsb_metrics 對象中提取
    let atl: Double?
    let ctl: Double?
    let fitness: Double?
    let tsb: Double?
    let updatedAt: Int?
    let workoutTrigger: Bool?
    let totalTss: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dailyCalories = "daily_calories"
        case hrvLastNightAvg = "hrv_last_night_avg"
        case restingHeartRate = "resting_heart_rate"
        case tsbMetrics = "tsb_metrics"
    }

    // 動態 CodingKeys 用於處理緩存格式
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    // 嵌套的 TSB Metrics 結構
    struct TSBMetrics: Codable {
        let atl: Double?
        let ctl: Double?
        let fitness: Double?
        let tsb: Double?
        let updatedAt: Int?
        let workoutTrigger: Bool?
        let totalTss: Double?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case atl, ctl, fitness, tsb
            case updatedAt = "updated_at"
            case workoutTrigger = "workout_trigger"
            case totalTss = "total_tss"
            case createdAt = "created_at"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        date = try container.decode(String.self, forKey: .date)
        dailyCalories = try container.decodeIfPresent(Int.self, forKey: .dailyCalories)
        hrvLastNightAvg = try container.decodeIfPresent(Double.self, forKey: .hrvLastNightAvg)
        restingHeartRate = try container.decodeIfPresent(Int.self, forKey: .restingHeartRate)

        // 嘗試解析嵌套的 tsb_metrics（來自 API 或緩存）
        if let tsbMetrics = try container.decodeIfPresent(TSBMetrics.self, forKey: .tsbMetrics) {
            atl = tsbMetrics.atl
            ctl = tsbMetrics.ctl
            fitness = tsbMetrics.fitness
            tsb = tsbMetrics.tsb
            updatedAt = tsbMetrics.updatedAt
            workoutTrigger = tsbMetrics.workoutTrigger
            totalTss = tsbMetrics.totalTss
            createdAt = tsbMetrics.createdAt
        } else {
            // 如果沒有 tsbMetrics 字段，可能是直接編碼的格式，嘗試直接讀取字段
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)

            atl = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "atl")!)
            ctl = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "ctl")!)
            fitness = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "fitness")!)
            tsb = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "tsb")!)
            updatedAt = try dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "updatedAt")!)
            workoutTrigger = try dynamicContainer.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "workoutTrigger")!)
            totalTss = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "totalTss")!)
            createdAt = try dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "createdAt")!)

            if atl != nil || ctl != nil || fitness != nil || tsb != nil {
                print("🔍 直接解析 TSB 字段成功: fitness=\(fitness?.description ?? "nil"), tsb=\(tsb?.description ?? "nil")")
            } else {
                print("❌ TSBMetrics 解析失敗或不存在")
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(dailyCalories, forKey: .dailyCalories)
        try container.encodeIfPresent(hrvLastNightAvg, forKey: .hrvLastNightAvg)
        try container.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)

        // 編碼 TSB metrics 為嵌套對象
        if atl != nil || ctl != nil || fitness != nil || tsb != nil || updatedAt != nil || workoutTrigger != nil || totalTss != nil || createdAt != nil {
            let tsbMetrics = TSBMetrics(
                atl: atl,
                ctl: ctl,
                fitness: fitness,
                tsb: tsb,
                updatedAt: updatedAt,
                workoutTrigger: workoutTrigger,
                totalTss: totalTss,
                createdAt: createdAt
            )
            try container.encode(tsbMetrics, forKey: .tsbMetrics)
        }
    }

    // 便利初始化器，保持向後兼容性
    init(
        date: String,
        dailyCalories: Int? = nil,
        hrvLastNightAvg: Double? = nil,
        restingHeartRate: Int? = nil,
        atl: Double? = nil,
        ctl: Double? = nil,
        fitness: Double? = nil,
        tsb: Double? = nil,
        updatedAt: Int? = nil,
        workoutTrigger: Bool? = nil,
        totalTss: Double? = nil,
        createdAt: String? = nil
    ) {
        self.date = date
        self.dailyCalories = dailyCalories
        self.hrvLastNightAvg = hrvLastNightAvg
        self.restingHeartRate = restingHeartRate
        self.atl = atl
        self.ctl = ctl
        self.fitness = fitness
        self.tsb = tsb
        self.updatedAt = updatedAt
        self.workoutTrigger = workoutTrigger
        self.totalTss = totalTss
        self.createdAt = createdAt
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
