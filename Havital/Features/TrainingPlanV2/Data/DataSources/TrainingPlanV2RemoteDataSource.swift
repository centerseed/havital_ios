import Foundation

// MARK: - TrainingPlanV2RemoteDataSource Protocol
protocol TrainingPlanV2RemoteDataSourceProtocol {
    // Plan Overview
    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO
    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?) async throws -> PlanOverviewV2DTO
    func getOverview() async throws -> PlanOverviewV2DTO
    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO

    // Weekly Plan
    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2DTO

    // Weekly Summary
    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO
    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO
}

// MARK: - TrainingPlanV2RemoteDataSource
/// Handles all API calls related to Training Plan V2
/// Data Layer - Pure HTTP communication, no caching logic
/// Uses APICallHelper for unified error handling
final class TrainingPlanV2RemoteDataSource: TrainingPlanV2RemoteDataSourceProtocol {

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "TrainingPlanV2RemoteDS"
        )
    }

    // MARK: - Plan Overview APIs

    /// 創建賽事模式訓練計畫概覽
    /// - Parameters:
    ///   - targetId: 目標 ID
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: Plan Overview DTO
    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Creating overview for race: \(targetId)")

        var requestBody: [String: Any] = ["target_id": targetId]
        if let startFromStage = startFromStage {
            requestBody["start_from_stage"] = startFromStage
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: PlanOverviewV2Response = try await apiHelper.post(PlanOverviewV2Response.self, path: "/v2/plan/overview", body: body)

        Logger.info("[TrainingPlanV2RemoteDS] Overview created: \(response.data.id)")
        return response.data
    }

    /// 創建非賽事模式訓練計畫概覽
    /// - Parameters:
    ///   - targetType: 目標類型（beginner, maintenance）
    ///   - trainingWeeks: 訓練週數
    ///   - availableDays: 每週可訓練天數（可選）
    ///   - methodologyId: 方法論 ID（可選）
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: Plan Overview DTO
    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?
    ) async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Creating overview for \(targetType)")

        var requestBody: [String: Any] = [
            "target_type": targetType,
            "training_weeks": trainingWeeks
        ]

        if let availableDays = availableDays {
            requestBody["available_days"] = availableDays
        }
        if let methodologyId = methodologyId {
            requestBody["methodology_id"] = methodologyId
        }
        if let startFromStage = startFromStage {
            requestBody["start_from_stage"] = startFromStage
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: PlanOverviewV2Response = try await apiHelper.post(PlanOverviewV2Response.self, path: "/v2/plan/overview", body: body)

        Logger.info("[TrainingPlanV2RemoteDS] Overview created: \(response.data.id)")
        return response.data
    }

    /// 獲取當前 active 計畫概覽
    /// - Returns: Plan Overview DTO
    func getOverview() async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Fetching active overview")
        let response: PlanOverviewV2Response = try await apiHelper.get(PlanOverviewV2Response.self, path: "/v2/plan/overview")
        return response.data
    }

    /// 更新計畫概覽
    /// - Parameters:
    ///   - overviewId: 概覽 ID
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: Updated Plan Overview DTO
    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Updating overview: \(overviewId)")

        var requestBody: [String: Any] = [:]
        if let startFromStage = startFromStage {
            requestBody["start_from_stage"] = startFromStage
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: PlanOverviewV2Response = try await apiHelper.put(PlanOverviewV2Response.self, path: "/v2/plan/overview/\(overviewId)", body: body)

        Logger.info("[TrainingPlanV2RemoteDS] Overview updated: \(response.data.id)")
        return response.data
    }

    // MARK: - Weekly Plan APIs

    /// 生成週課表
    /// - Parameters:
    ///   - weekOfTraining: 訓練週次
    ///   - forceGenerate: 強制重新生成（可選）
    ///   - promptVersion: Prompt 版本（可選）
    ///   - methodology: 方法論（可選）
    /// - Returns: Weekly Plan DTO
    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Generating weekly plan for week \(weekOfTraining)")

        var requestBody: [String: Any] = ["week_of_training": weekOfTraining]

        if let forceGenerate = forceGenerate {
            requestBody["force_generate"] = forceGenerate
        }
        if let promptVersion = promptVersion {
            requestBody["prompt_version"] = promptVersion
        }
        if let methodology = methodology {
            requestBody["methodology"] = methodology
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: WeeklyPlanV2Response = try await apiHelper.post(WeeklyPlanV2Response.self, path: "/v2/plan/weekly", body: body)

        Logger.info("[TrainingPlanV2RemoteDS] Weekly plan generated: \(response.data.id)")
        return response.data
    }

    // MARK: - Weekly Summary APIs

    /// 生成週摘要
    /// - Parameters:
    ///   - weekOfPlan: 訓練週次
    ///   - forceUpdate: 強制更新（可選）
    /// - Returns: Weekly Summary DTO
    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Generating weekly summary for week \(weekOfPlan)")

        var requestBody: [String: Any] = ["week_of_plan": weekOfPlan]

        if let forceUpdate = forceUpdate {
            requestBody["force_update"] = forceUpdate
        }

        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: WeeklySummaryV2Response = try await apiHelper.post(WeeklySummaryV2Response.self, path: "/v2/summary/weekly", body: body)

        Logger.info("[TrainingPlanV2RemoteDS] Weekly summary generated: \(response.data.id)")
        return response.data
    }

    /// 獲取週摘要
    /// - Parameter weekOfPlan: 訓練週次
    /// - Returns: Weekly Summary DTO
    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Fetching weekly summary for week \(weekOfPlan)")
        let response: WeeklySummaryV2Response = try await apiHelper.get(WeeklySummaryV2Response.self, path: "/v2/summary/weekly?week_of_plan=\(weekOfPlan)")
        return response.data
    }
}
