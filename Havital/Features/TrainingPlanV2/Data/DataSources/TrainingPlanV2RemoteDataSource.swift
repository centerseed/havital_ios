import Foundation

// MARK: - TrainingPlanV2RemoteDataSource Protocol
protocol TrainingPlanV2RemoteDataSourceProtocol {
    // Target Types & Methodologies
    func getTargetTypes() async throws -> [TargetTypeV2]
    func getMethodologies(targetType: String?) async throws -> [MethodologyV2]

    // Plan Overview
    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO
    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?) async throws -> PlanOverviewV2DTO
    func getOverview() async throws -> PlanOverviewV2DTO
    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO

    // Weekly Plan
    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2DTO
    func deleteWeeklyPlan(planId: String) async throws

    // Weekly Summary
    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO
    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO
    func deleteWeeklySummary(summaryId: String) async throws
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

    // MARK: - Target Types & Methodologies APIs

    /// 獲取支援的目標類型
    /// - Returns: 目標類型列表
    func getTargetTypes() async throws -> [TargetTypeV2] {
        Logger.debug("[TrainingPlanV2RemoteDS] Fetching target types from /v2/target/types")

        let response: TargetTypesResponseV2 = try await apiHelper.get(
            TargetTypesResponseV2.self,
            path: "/v2/target/types"
        )

        Logger.info("[TrainingPlanV2RemoteDS] ✅ Fetched \(response.targetTypes.count) target types")
        return response.targetTypes
    }

    /// 獲取方法論列表
    /// - Parameter targetType: 目標類型（可選，不提供則返回所有方法論）
    /// - Returns: 方法論列表
    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        Logger.debug("[TrainingPlanV2RemoteDS] 🎯 Fetching methodologies for type: '\(targetType ?? "nil")'")

        var path = "/v2/methodologies"
        if let targetType = targetType {
            path += "?target_type=\(targetType)"
        }

        Logger.info("[TrainingPlanV2RemoteDS] 📡 API Request: GET \(path)")

        let response: MethodologiesResponseV2 = try await apiHelper.get(
            MethodologiesResponseV2.self,
            path: path
        )

        Logger.info("[TrainingPlanV2RemoteDS] ✅ API Response: \(response.methodologies.count) methodologies - IDs: \(response.methodologies.map { $0.id })")
        return response.methodologies
    }

    // MARK: - Plan Overview APIs

    /// 創建賽事模式訓練計畫概覽
    /// - Parameters:
    ///   - targetId: 目標 ID
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: Plan Overview DTO
    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Creating overview for race: \(targetId)")

        let request = CreateOverviewForRaceRequest(
            targetId: targetId,
            startFromStage: startFromStage
        )

        let overview = try await apiHelper.post(
            PlanOverviewV2DTO.self,
            path: "/v2/plan/overview",
            body: request
        )

        Logger.info("[TrainingPlanV2RemoteDS] Overview created: \(overview.id)")
        return overview
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

        let request = CreateOverviewForNonRaceRequest(
            targetType: targetType,
            trainingWeeks: trainingWeeks,
            availableDays: availableDays,
            methodologyId: methodologyId,
            startFromStage: startFromStage
        )

        let overview = try await apiHelper.post(
            PlanOverviewV2DTO.self,
            path: "/v2/plan/overview",
            body: request
        )

        Logger.info("[TrainingPlanV2RemoteDS] Overview created: \(overview.id)")
        return overview
    }

    /// 獲取當前 active 計畫概覽
    /// - Returns: Plan Overview DTO
    func getOverview() async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Fetching active overview")
        return try await apiHelper.get(PlanOverviewV2DTO.self, path: "/v2/plan/overview")
    }

    /// 更新計畫概覽
    /// - Parameters:
    ///   - overviewId: 概覽 ID
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: Updated Plan Overview DTO
    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Updating overview: \(overviewId)")

        let request = UpdateOverviewRequest(startFromStage: startFromStage)

        let overview = try await apiHelper.put(
            PlanOverviewV2DTO.self,
            path: "/v2/plan/overview/\(overviewId)",
            body: request
        )

        Logger.info("[TrainingPlanV2RemoteDS] Overview updated: \(overview.id)")
        return overview
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

        let request = GenerateWeeklyPlanRequest(
            weekOfTraining: weekOfTraining,
            forceGenerate: forceGenerate,
            promptVersion: promptVersion,
            methodology: methodology
        )

        let weeklyPlan = try await apiHelper.post(
            WeeklyPlanV2DTO.self,
            path: "/v2/plan/weekly",
            body: request
        )

        Logger.info("[TrainingPlanV2RemoteDS] Weekly plan generated: \(weeklyPlan.id)")
        return weeklyPlan
    }

    /// 刪除週課表 (Debug)
    /// - Parameter planId: 週課表 ID
    func deleteWeeklyPlan(planId: String) async throws {
        Logger.debug("[TrainingPlanV2RemoteDS] 🗑️ [DEBUG] Deleting weekly plan: \(planId)")
        try await apiHelper.delete(path: "/v2/plan/weekly/\(planId)")
        Logger.info("[TrainingPlanV2RemoteDS] ✅ [DEBUG] Weekly plan deleted: \(planId)")
    }

    // MARK: - Weekly Summary APIs

    /// 生成週摘要
    /// - Parameters:
    ///   - weekOfPlan: 訓練週次
    ///   - forceUpdate: 強制更新（可選）
    /// - Returns: Weekly Summary DTO
    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Generating weekly summary for week \(weekOfPlan)")

        let request = GenerateWeeklySummaryRequest(
            weekOfPlan: weekOfPlan,
            forceUpdate: forceUpdate
        )

        let summary = try await apiHelper.post(
            WeeklySummaryV2DTO.self,
            path: "/v2/summary/weekly",
            body: request
        )

        Logger.info("[TrainingPlanV2RemoteDS] Weekly summary generated: \(summary.id)")
        return summary
    }

    /// 獲取週摘要
    /// - Parameter weekOfPlan: 訓練週次
    /// - Returns: Weekly Summary DTO
    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2DTO {
        Logger.debug("[TrainingPlanV2RemoteDS] Fetching weekly summary for week \(weekOfPlan)")
        return try await apiHelper.get(WeeklySummaryV2DTO.self, path: "/v2/summary/weekly?week_of_plan=\(weekOfPlan)")
    }

    /// 刪除週摘要 (Debug)
    /// - Parameter summaryId: 週摘要 ID
    func deleteWeeklySummary(summaryId: String) async throws {
        Logger.debug("[TrainingPlanV2RemoteDS] 🗑️ [DEBUG] Deleting weekly summary: \(summaryId)")
        try await apiHelper.delete(path: "/v2/summary/weekly/\(summaryId)")
        Logger.info("[TrainingPlanV2RemoteDS] ✅ [DEBUG] Weekly summary deleted: \(summaryId)")
    }
}
