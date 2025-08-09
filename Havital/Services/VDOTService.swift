import Foundation

class VDOTService {
    static let shared = VDOTService()
    
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
    
    // MARK: - VDOT API Methods
    
    /// 獲取 VDOT 數據
    /// - Parameter limit: 數據限制，預設 50
    /// - Returns: VDOT 回應
    func getVDOTs(limit: Int = 50) async throws -> VDOTResponse {
        let response: VDOTResponse = try await makeAPICall(
            VDOTResponse.self,
            path: "/v2/workouts/vdots?limit=\(limit)"
        )
        
        Logger.firebase(
            "VDOT 數據獲取成功",
            level: .info,
            labels: [
                "module": "VDOTService",
                "action": "get_vdots"
            ],
            jsonPayload: [
                "data_count": response.data.vdots.count,
                "limit": limit
            ]
        )
        
        return response
    }
    
    /// 計算 VDOT 值
    /// - Parameters:
    ///   - distance: 距離 (公尺)
    ///   - time: 時間 (秒)
    /// - Returns: VDOT 計算回應
    func calculateVDOT(distance: Double, time: Double) async throws -> VDOTCalculationResponse {
        let requestData = [
            "distance": distance,
            "time": time
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: requestData)
        
        let response: VDOTCalculationResponse = try await makeAPICall(
            VDOTCalculationResponse.self,
            path: "/v2/vdot/calculate",
            method: .POST,
            body: bodyData
        )
        
        Logger.firebase(
            "VDOT 計算成功",
            level: .info,
            labels: [
                "module": "VDOTService",
                "action": "calculate_vdot"
            ],
            jsonPayload: [
                "distance": distance,
                "time": time,
                "calculated_vdot": response.data.vdot
            ]
        )
        
        return response
    }
    
    /// 獲取 VDOT 統計數據
    /// - Parameter days: 統計天數，預設 30 天
    /// - Returns: VDOT 統計回應
    func getVDOTStats(days: Int = 30) async throws -> VDOTStatsResponse {
        let response: VDOTStatsResponse = try await makeAPICall(
            VDOTStatsResponse.self,
            path: "/v2/vdot/stats?days=\(days)"
        )
        
        Logger.firebase(
            "VDOT 統計數據獲取成功",
            level: .info,
            labels: [
                "module": "VDOTService",
                "action": "get_vdot_stats"
            ],
            jsonPayload: [
                "period_days": days,
                "current_vdot": response.data.currentVDOT,
                "trend": response.data.trend
            ]
        )
        
        return response
    }
    
    /// 上傳訓練數據用於 VDOT 計算
    /// - Parameter trainingData: 訓練數據
    func uploadTrainingData(_ trainingData: [String: Any]) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: trainingData)
        
        try await makeAPICall(
            EmptyResponse.self,
            path: "/v2/vdot/training",
            method: .POST,
            body: bodyData
        )
        
        Logger.firebase(
            "訓練數據上傳成功",
            level: .info,
            labels: [
                "module": "VDOTService",
                "action": "upload_training_data"
            ]
        )
    }
}

// MARK: - Response Models
// 注意：VDOTResponse, VDOTData, VDOTEntry 已在 VDOTModels.swift 中定義

/// VDOT 計算回應結構
struct VDOTCalculationResponse: Codable {
    let success: Bool
    let data: VDOTCalculationData
}

/// VDOT 計算數據結構
struct VDOTCalculationData: Codable {
    let vdot: Double
    let pace: String
    let predictedTimes: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case vdot
        case pace
        case predictedTimes = "predicted_times"
    }
}

/// VDOT 統計回應結構
struct VDOTStatsResponse: Codable {
    let success: Bool
    let data: VDOTStatsData
}

/// VDOT 統計數據結構
struct VDOTStatsData: Codable {
    let currentVDOT: Double
    let trend: String
    let improvementRate: Double?
    let totalWorkouts: Int
    
    enum CodingKeys: String, CodingKey {
        case currentVDOT = "current_vdot"
        case trend
        case improvementRate = "improvement_rate"
        case totalWorkouts = "total_workouts"
    }
}