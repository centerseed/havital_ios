import Foundation

// MARK: - Request DTOs

/// Request body for modifying a weekly plan
struct WeeklyPlanModifyRequest: Encodable {
    let updatedPlan: WeeklyPlan

    enum CodingKeys: String, CodingKey {
        case updatedPlan = "updated_plan"
    }
}

// MARK: - TrainingPlan Remote DataSource
/// 負責與後端 API 通信，獲取訓練計畫數據
/// Data Layer - 只處理 HTTP 請求和響應
final class TrainingPlanRemoteDataSource {

    // MARK: - Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    // MARK: - Initialization
    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Weekly Plan APIs

    /// 獲取週計畫
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        let rawData = try await httpClient.request(
            path: "/plan/race_run/weekly/\(planId)",
            method: .GET
        )
        return try ResponseProcessor.extractData(WeeklyPlan.self, from: rawData, using: parser)
    }

    /// 創建新週計畫
    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        var params: [String: Any] = [:]
        if let week = week {
            params["week_of_training"] = week
        }
        if let stage = startFromStage {
            params["start_from_stage"] = stage
        }
        if isBeginner {
            params["is_beginner"] = true
        }

        Logger.debug("[RemoteDataSource] 📤 createWeeklyPlan - week: \(week?.description ?? "nil"), params: \(params)")

        let bodyData = params.isEmpty ? nil : try JSONSerialization.data(withJSONObject: params)

        let rawData = try await httpClient.request(
            path: "/plan/race_run/weekly/v2",
            method: .POST,
            body: bodyData
        )

        let plan = try ResponseProcessor.extractData(WeeklyPlan.self, from: rawData, using: parser)
        Logger.debug("[RemoteDataSource] 📥 createWeeklyPlan response - plan.id: \(plan.id), plan.weekOfPlan: \(plan.weekOfPlan)")

        return plan
    }

    /// 修改週計畫
    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        let requestBody = WeeklyPlanModifyRequest(updatedPlan: updatedPlan)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(requestBody)

        // 🔍 DEBUG: 打印實際編碼發送的 JSON
        if let jsonString = String(data: bodyData, encoding: .utf8) {
            Logger.debug("[RemoteDataSource] 📤 發送 JSON 到後端:")
            Logger.debug("[RemoteDataSource] URL: /plan/race_run/weekly/\(planId)/modify")
            Logger.debug("[RemoteDataSource] Method: PUT")

            // 美化 JSON 輸出（分多行打印）
            if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                let lines = prettyString.split(separator: "\n", omittingEmptySubsequences: false)
                for line in lines {
                    Logger.debug("[RemoteDataSource] \(line)")
                }
            } else {
                Logger.debug("[RemoteDataSource] Body: \(jsonString)")
            }
        }

        let rawData = try await httpClient.request(
            path: "/plan/race_run/weekly/\(planId)/modify",
            method: .PUT,
            body: bodyData
        )
        return try ResponseProcessor.extractData(WeeklyPlan.self, from: rawData, using: parser)
    }

    // MARK: - Overview APIs

    /// 獲取訓練概覽
    func getOverview() async throws -> TrainingPlanOverview {
        let rawData = try await httpClient.request(
            path: "/plan/race_run/overview",
            method: .GET
        )
        return try ResponseProcessor.extractData(TrainingPlanOverview.self, from: rawData, using: parser)
    }

    /// 創建訓練概覽
    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview {
        var params: [String: Any] = [:]
        if let stage = startFromStage {
            params["start_from_stage"] = stage
        }
        if isBeginner {
            params["is_beginner"] = true
        }

        let bodyData = params.isEmpty ? nil : try JSONSerialization.data(withJSONObject: params)

        let rawData = try await httpClient.request(
            path: "/plan/race_run/overview",
            method: .POST,
            body: bodyData
        )
        return try ResponseProcessor.extractData(TrainingPlanOverview.self, from: rawData, using: parser)
    }

    /// 更新訓練概覽
    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        let rawData = try await httpClient.request(
            path: "/plan/race_run/overview/\(overviewId)",
            method: .PUT
        )
        return try ResponseProcessor.extractData(TrainingPlanOverview.self, from: rawData, using: parser)
    }

    // MARK: - Plan Status APIs

    /// 獲取計畫狀態
    func getPlanStatus() async throws -> PlanStatusResponse {
        let rawData = try await httpClient.request(
            path: "/plan/race_run/status",
            method: .GET
        )
        return try ResponseProcessor.extractData(PlanStatusResponse.self, from: rawData, using: parser)
    }

    // MARK: - Modifications APIs

    /// 獲取所有修改
    func getModifications() async throws -> [Modification] {
        let rawData = try await httpClient.request(
            path: "/plan/modifications",
            method: .GET
        )
        return try ResponseProcessor.extractData([Modification].self, from: rawData, using: parser)
    }

    /// 獲取修改描述
    func getModificationsDescription() async throws -> String {
        let rawData = try await httpClient.request(
            path: "/plan/modifications/description",
            method: .GET
        )
        return try ResponseProcessor.extractData(String.self, from: rawData, using: parser)
    }

    /// 創建修改
    func createModification(_ modification: NewModification) async throws -> Modification {
        let bodyData = try JSONEncoder().encode(modification)

        let rawData = try await httpClient.request(
            path: "/plan/modifications",
            method: .POST,
            body: bodyData
        )
        return try ResponseProcessor.extractData(Modification.self, from: rawData, using: parser)
    }

    /// 更新修改
    func updateModifications(_ modifications: [Modification]) async throws -> [Modification] {
        let payload = ModificationsUpdateRequest(modifications: modifications)
        let bodyData = try JSONEncoder().encode(payload)

        let rawData = try await httpClient.request(
            path: "/plan/modifications",
            method: .PUT,
            body: bodyData
        )
        return try ResponseProcessor.extractData([Modification].self, from: rawData, using: parser)
    }

    /// 清除所有修改
    func clearModifications() async throws {
        _ = try await httpClient.request(
            path: "/plan/modifications",
            method: .DELETE
        )
    }

    // MARK: - Weekly Summary APIs

    // MARK: - Weekly Summary APIs

    /// 創建週回顧
    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary {
        // Use the path format from the legacy WeeklySummaryService
        let path: String
        if let week = weekNumber {
            path = "/summary/run_race/week/\(week)"
        } else {
            path = "/summary/run_race/week"
        }
            
        var params: [String: Any] = [:]
        // week_number is handled in the URL path, not the body
        if forceUpdate {
            params["force_update"] = true
        }

        let bodyData = params.isEmpty ? nil : try JSONSerialization.data(withJSONObject: params)

        let rawData = try await httpClient.request(
            path: path,
            method: .POST,
            body: bodyData
        )
        return try ResponseProcessor.extractData(WeeklyTrainingSummary.self, from: rawData, using: parser)
    }

    /// 獲取所有週回顧（歷史記錄）
    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        let rawData = try await httpClient.request(
            path: "/summary/weekly/",
            method: .GET
        )
        return try ResponseProcessor.extractData([WeeklySummaryItem].self, from: rawData, using: parser)
    }

    /// 獲取特定週的回顧
    func getWeeklySummary(weekNumber: Int) async throws -> WeeklyTrainingSummary {
        let rawData = try await httpClient.request(
            path: "/summary/run_race/week/\(weekNumber)",
            method: .GET
        )
        return try ResponseProcessor.extractData(WeeklyTrainingSummary.self, from: rawData, using: parser)
    }

    /// 更新調整項目
    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> [AdjustmentItem] {
        let bodyInput = AdjustmentUpdateInput(items: items)
        let bodyData = try JSONEncoder().encode(bodyInput)

        let rawData = try await httpClient.request(
            path: "/summary/\(summaryId)/adjustments",
            method: .PUT,
            body: bodyData
        )
        
        // Parse the dedicated response structure first
        let response = try ResponseProcessor.extractData(UpdateAdjustmentsResponse.self, from: rawData, using: parser)
        return response.data.items
    }
}

// Helper struct for adjustment update
private struct AdjustmentUpdateInput: Encodable {
    let items: [AdjustmentItem]
}

