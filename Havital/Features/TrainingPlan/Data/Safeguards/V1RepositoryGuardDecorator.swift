import Foundation

// MARK: - V1RepositoryGuardDecorator
/// V1 Repository 深度防禦裝飾器（A-4）
///
/// 目的：
/// - 即使上層 ViewModel 層的 V1/V2 分流有遺漏，此 decorator 為 V1 網路呼叫的最後一道防線
/// - V2 用戶若任何路徑意外進入 V1 Repo，會被攔截並記錄到 Cloud Logging
///
/// 設計決策：
/// - 採用 decorator 而非修改 `TrainingPlanRepositoryImpl`，符合 CLAUDE.md「Repository 被動」原則
/// - Guard 只包覆會觸發 V1 HTTP 的方法；`clearCache` / `preloadData` 為本地 cache 操作，直通不攔
/// - Cold start race：若 UserProfileRepository 尚未 bootstrap，`isV2User()` 會 default v1 → 不攔（可接受的 race window）
///
/// 日誌：
/// - 攔截事件 `labels.operation = "v1_endpoint_blocked_for_v2_user"`，對應 B-3 Alert #1
final class V1RepositoryGuardDecorator: TrainingPlanRepository {

    // MARK: - Dependencies

    private let wrapped: TrainingPlanRepository
    private let versionRouter: TrainingVersionRouting

    // MARK: - Initialization

    init(wrapped: TrainingPlanRepository, versionRouter: TrainingVersionRouting) {
        self.wrapped = wrapped
        self.versionRouter = versionRouter
    }

    // MARK: - Guard

    /// V2 用戶走 V1 Repo 時攔截並 throw；V1 用戶（或 cold start race 未知）放行
    private func guardV1Access(method: String) async throws {
        if await versionRouter.isV2User() {
            Logger.firebase(
                "v1_endpoint_blocked_for_v2_user",
                level: .error,
                labels: [
                    "cloud_logging": "true",
                    "module": "V1Guard",
                    "operation": "v1_endpoint_blocked_for_v2_user"
                ],
                jsonPayload: [
                    "method": method,
                    "uid": AuthenticationService.shared.user?.uid ?? ""
                ]
            )
            throw DomainError.incorrectVersionRouting(context: "V1Guard.\(method)")
        }
    }

    // MARK: - Weekly Plan

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        try await guardV1Access(method: "getWeeklyPlan")
        return try await wrapped.getWeeklyPlan(planId: planId)
    }

    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        try await guardV1Access(method: "refreshWeeklyPlan")
        return try await wrapped.refreshWeeklyPlan(planId: planId)
    }

    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        try await guardV1Access(method: "createWeeklyPlan")
        return try await wrapped.createWeeklyPlan(week: week, startFromStage: startFromStage, isBeginner: isBeginner)
    }

    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        try await guardV1Access(method: "modifyWeeklyPlan")
        return try await wrapped.modifyWeeklyPlan(planId: planId, updatedPlan: updatedPlan)
    }

    // MARK: - Training Overview

    func getOverview() async throws -> TrainingPlanOverview {
        try await guardV1Access(method: "getOverview")
        return try await wrapped.getOverview()
    }

    func refreshOverview() async throws -> TrainingPlanOverview {
        try await guardV1Access(method: "refreshOverview")
        return try await wrapped.refreshOverview()
    }

    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview {
        try await guardV1Access(method: "createOverview")
        return try await wrapped.createOverview(startFromStage: startFromStage, isBeginner: isBeginner)
    }

    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        try await guardV1Access(method: "updateOverview")
        return try await wrapped.updateOverview(overviewId: overviewId)
    }

    // MARK: - Plan Status

    func getPlanStatus() async throws -> PlanStatusResponse {
        try await guardV1Access(method: "getPlanStatus")
        return try await wrapped.getPlanStatus()
    }

    func refreshPlanStatus() async throws -> PlanStatusResponse {
        try await guardV1Access(method: "refreshPlanStatus")
        return try await wrapped.refreshPlanStatus()
    }

    // MARK: - Modifications

    func getModifications() async throws -> [Modification] {
        try await guardV1Access(method: "getModifications")
        return try await wrapped.getModifications()
    }

    func getModificationsDescription() async throws -> String {
        try await guardV1Access(method: "getModificationsDescription")
        return try await wrapped.getModificationsDescription()
    }

    func createModification(_ modification: NewModification) async throws -> Modification {
        try await guardV1Access(method: "createModification")
        return try await wrapped.createModification(modification)
    }

    func updateModifications(_ modifications: [Modification]) async throws -> [Modification] {
        try await guardV1Access(method: "updateModifications")
        return try await wrapped.updateModifications(modifications)
    }

    func clearModifications() async throws {
        try await guardV1Access(method: "clearModifications")
        try await wrapped.clearModifications()
    }

    // MARK: - Weekly Summary

    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary {
        try await guardV1Access(method: "createWeeklySummary")
        return try await wrapped.createWeeklySummary(weekNumber: weekNumber, forceUpdate: forceUpdate)
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        try await guardV1Access(method: "getWeeklySummaries")
        return try await wrapped.getWeeklySummaries()
    }

    func getWeeklySummary(weekNumber: Int) async throws -> WeeklyTrainingSummary {
        try await guardV1Access(method: "getWeeklySummary")
        return try await wrapped.getWeeklySummary(weekNumber: weekNumber)
    }

    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> [AdjustmentItem] {
        try await guardV1Access(method: "updateAdjustments")
        return try await wrapped.updateAdjustments(summaryId: summaryId, items: items)
    }

    // MARK: - Cache Management (本地操作，不觸發 V1 HTTP，直通)

    func clearCache() async {
        await wrapped.clearCache()
    }

    func preloadData() async {
        await wrapped.preloadData()
    }
}
