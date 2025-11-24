import Foundation

final class TrainingPlanService {
    static let shared = TrainingPlanService()
    
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
    
    /// 無回應數據的 API 調用
    private func makeAPICallNoResponse(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
    
    func postTrainingPlanOverview(startFromStage: String? = nil, isBeginner: Bool = false) async throws -> TrainingPlanOverview {
        let bodyData: Data?

        // 構建請求體參數
        var params: [String: Any] = [:]
        if let stage = startFromStage {
            params["start_from_stage"] = stage
        }
        if isBeginner {
            params["is_beginner"] = true
        }

        // 如果有參數，轉換為 JSON
        if !params.isEmpty {
            bodyData = try JSONSerialization.data(withJSONObject: params)

            // Debug logging
            if let jsonString = String(data: bodyData!, encoding: .utf8) {
                print("[TrainingPlanService] 📤 POST /plan/race_run/overview with body: \(jsonString)")
            }
        } else {
            bodyData = nil
            print("[TrainingPlanService] 📤 POST /plan/race_run/overview with no body")
        }

        return try await makeAPICall(TrainingPlanOverview.self,
            path: "/plan/race_run/overview", method: .POST, body: bodyData)
    }
    
    func updateTrainingPlanOverview(overviewId: String) async throws -> TrainingPlanOverview {
        return try await makeAPICall(TrainingPlanOverview.self,
            path: "/plan/race_run/overview/\(overviewId)", method: .PUT)
    }
    
    // MARK: - Modifications APIs
    /// 取得修改描述
    func getModificationsDescription() async throws -> String {
        return try await makeAPICall(String.self, path: "/plan/modifications/description")
    }
    
    /// 取得所有修改項目
    func getModifications() async throws -> [Modification] {
        return try await makeAPICall([Modification].self, path: "/plan/modifications")
    }
    
    /// 新增單筆修改
    func createModification(_ newMod: NewModification) async throws -> Modification {
        let body = try JSONEncoder().encode(newMod)
        return try await makeAPICall(Modification.self,
            path: "/plan/modifications", method: .POST, body: body)
    }
    
    /// 更新多筆修改
    func updateModifications(_ mods: [Modification]) async throws -> [Modification] {
        let payload = ModificationsUpdateRequest(modifications: mods)
        let data = try JSONEncoder().encode(payload)
        return try await makeAPICall([Modification].self,
            path: "/plan/modifications", method: .PUT, body: data)
    }
    
    /// 清除所有修改
    func clearModifications() async throws {
        try await makeAPICallNoResponse(path: "/plan/modifications", method: .DELETE)
    }
    
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        return try await makeAPICall(TrainingPlanOverview.self, path: "/plan/race_run/overview")
    }

    // MARK: - Plan Status API

    /// 獲取訓練計畫狀態（新 API）
    /// - Returns: 包含當前週數、下一步操作、下週資訊等的完整狀態
    func getPlanStatus() async throws -> PlanStatusResponse {
        return try await makeAPICall(PlanStatusResponse.self, path: "/plan/race_run/status")
    }

    /*
    func getWeeklyPlan(caller: String = #function) async throws -> WeeklyPlan {
        return try await APIClient.shared.request(WeeklyPlan.self,
            path: "/plan/race_run/weekly")
    }*/
    
    /// 週計畫查詢錯誤
    enum WeeklyPlanError: Error {
        /// 指定週計畫不存在
        case notFound
    }
    
    func getWeeklyPlanById(planId: String) async throws -> WeeklyPlan {
        do {
            return try await makeAPICall(WeeklyPlan.self, path: "/plan/race_run/weekly/\(planId)")
        } catch let httpError as HTTPError {
            // 檢查是否為 HTTP 404 錯誤（資源不存在）
            if case .notFound(_) = httpError {
                throw WeeklyPlanError.notFound
            } else {
                throw httpError
            }
        } catch let error as NSError where error.code == 404 {
            // 舊架構相容性：也檢查 NSError 404
            throw WeeklyPlanError.notFound
        } catch {
            // 其他錯誤（如網路不穩定、超時等）保持原樣
            throw error
        }
    }
    
    func createWeeklyPlan(targetWeek: Int? = nil, startFromStage: String? = nil, isBeginner: Bool = false) async throws -> WeeklyPlan {
        let bodyData: Data?

        // 構建請求體參數
        var params: [String: Any] = [:]
        if let week = targetWeek {
            params["week_of_training"] = week
        }
        if let stage = startFromStage {
            params["start_from_stage"] = stage
        }
        if isBeginner {
            params["is_beginner"] = true
        }

        // 如果有參數，轉換為 JSON
        if !params.isEmpty {
            bodyData = try JSONSerialization.data(withJSONObject: params)

            // Debug logging
            if let jsonString = String(data: bodyData!, encoding: .utf8) {
                print("[TrainingPlanService] 📤 POST /plan/race_run/weekly/v2 with body: \(jsonString)")
            }
        } else {
            bodyData = nil
        }

        return try await makeAPICall(WeeklyPlan.self,
            path: "/plan/race_run/weekly/v2", method: .POST, body: bodyData)
    }
    
    /// 修改週訓練計劃
    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        let requestBody = WeeklyPlanModifyRequest(updatedPlan: updatedPlan)
        let bodyData = try JSONEncoder().encode(requestBody)

        return try await makeAPICall(
            WeeklyPlan.self,
            path: "/plan/race_run/weekly/\(planId)/modify",
            method: .PUT,
            body: bodyData
        )
    }
}

// MARK: - Weekly Plan Modify Models

/// 修改週課表請求體
struct WeeklyPlanModifyRequest: Codable {
    let updatedPlan: WeeklyPlan
    
    enum CodingKeys: String, CodingKey {
        case updatedPlan = "updated_plan"
    }
}

// API 直接回傳 WeeklyPlan，不需要包裝結構

/// 修改摘要
struct ModificationSummary: Codable {
    let modificationId: String
    let totalChanges: Int
    let summary: [String: Any]?
    let intensityDiff: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case modificationId = "modification_id"
        case totalChanges = "total_changes"
        case summary
        case intensityDiff = "intensity_diff"
    }
    
    // 自定義編解碼處理 Any 類型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modificationId = try container.decode(String.self, forKey: .modificationId)
        totalChanges = try container.decode(Int.self, forKey: .totalChanges)
        // Note: [String: Any] cannot be decoded directly with Codable
        // Using JSONSerialization as fallback or define proper Codable types
        summary = nil // TODO: Implement proper Codable handling
        intensityDiff = nil // TODO: Implement proper Codable handling
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modificationId, forKey: .modificationId)
        try container.encode(totalChanges, forKey: .totalChanges)
        // Any 類型的編碼需要特殊處理，這裡簡化處理
    }
}

/// 強度警告
struct IntensityWarning: Codable {
    let hasWarning: Bool
    let warningType: String?
    let messages: [String]
    let details: IntensityWarningDetails?
    
    enum CodingKeys: String, CodingKey {
        case hasWarning = "has_warning"
        case warningType = "warning_type"
        case messages
        case details
    }
}

/// 強度警告詳情
struct IntensityWarningDetails: Codable {
    let originalIntensity: WeeklyPlan.IntensityTotalMinutes?
    let updatedIntensity: WeeklyPlan.IntensityTotalMinutes?
    let changes: [String: Any]?
    let lowIncreasePercent: Double?
    let mediumHighIncreasePercent: Double?
    
    enum CodingKeys: String, CodingKey {
        case originalIntensity = "original_intensity"
        case updatedIntensity = "updated_intensity"
        case changes
        case lowIncreasePercent = "low_increase_percent"
        case mediumHighIncreasePercent = "medium_high_increase_percent"
    }
    
    // 自定義編解碼處理 Any 類型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        originalIntensity = try container.decodeIfPresent(WeeklyPlan.IntensityTotalMinutes.self, forKey: .originalIntensity)
        updatedIntensity = try container.decodeIfPresent(WeeklyPlan.IntensityTotalMinutes.self, forKey: .updatedIntensity)
        // Note: [String: Any] cannot be decoded directly with Codable
        changes = nil // TODO: Implement proper Codable handling
        lowIncreasePercent = try container.decodeIfPresent(Double.self, forKey: .lowIncreasePercent)
        mediumHighIncreasePercent = try container.decodeIfPresent(Double.self, forKey: .mediumHighIncreasePercent)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(originalIntensity, forKey: .originalIntensity)
        try container.encodeIfPresent(updatedIntensity, forKey: .updatedIntensity)
        try container.encodeIfPresent(lowIncreasePercent, forKey: .lowIncreasePercent)
        try container.encodeIfPresent(mediumHighIncreasePercent, forKey: .mediumHighIncreasePercent)
    }
}
