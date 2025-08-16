import Foundation

class HealthDataService {
    static let shared = HealthDataService()
    
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
    
    // MARK: - Health Data API Methods
    
    /// 獲取健康日報數據
    /// - Parameter limit: 數據限制，預設 14 天
    /// - Returns: 健康日報回應
    func getHealthDaily(limit: Int = 14) async throws -> HealthDailyResponse {
        let response: HealthDailyResponse = try await makeAPICall(
            HealthDailyResponse.self,
            path: "/v2/workouts/health_daily?limit=\(limit)"
        )
        
        Logger.firebase(
            "健康日報數據獲取成功",
            level: .info,
            labels: [
                "module": "HealthDataService",
                "action": "get_health_daily"
            ],
            jsonPayload: [
                "data_count": response.healthData.count,
                "limit": limit
            ]
        )
        
        return response
    }
    
    /// 上傳健康數據到後端
    /// - Parameter healthData: 要上傳的健康數據
    func uploadHealthData(_ healthData: [String: Any]) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: healthData)
        
        try await makeAPICall(
            HealthDataEmptyResponse.self,
            path: "/v2/health/upload",
            method: .POST,
            body: bodyData
        )
        
        Logger.firebase(
            "健康數據上傳成功",
            level: .info,
            labels: [
                "module": "HealthDataService",
                "action": "upload_health_data"
            ]
        )
    }
    
    /// 獲取健康統計數據
    /// - Parameters:
    ///   - startDate: 開始日期 (ISO 8601)
    ///   - endDate: 結束日期 (ISO 8601)  
    /// - Returns: 健康統計回應
    func getHealthStats(startDate: String, endDate: String) async throws -> HealthStatsResponse {
        let path = "/v2/health/stats?start_date=\(startDate)&end_date=\(endDate)"
        
        let response: HealthStatsResponse = try await makeAPICall(
            HealthStatsResponse.self,
            path: path
        )
        
        Logger.firebase(
            "健康統計數據獲取成功",
            level: .info,
            labels: [
                "module": "HealthDataService",
                "action": "get_health_stats"
            ],
            jsonPayload: [
                "start_date": startDate,
                "end_date": endDate
            ]
        )
        
        return response
    }
}

// MARK: - Response Models
// 注意：HealthDailyResponse, HealthDailyData, HealthRecord 已在 APIClient.swift 中定義

/// 健康統計回應結構
struct HealthStatsResponse: Codable {
    let success: Bool
    let data: HealthStatsData
}

/// 健康統計數據結構
struct HealthStatsData: Codable {
    let totalSteps: Int
    let avgHeartRate: Double?
    let totalCalories: Double
    let totalDistance: Double
    
    enum CodingKeys: String, CodingKey {
        case totalSteps = "total_steps"
        case avgHeartRate = "avg_heart_rate"
        case totalCalories = "total_calories"
        case totalDistance = "total_distance"
    }
}

/// 空回應結構（用於上傳等操作）
struct HealthDataEmptyResponse: Codable {
    let success: Bool
    let message: String?
}