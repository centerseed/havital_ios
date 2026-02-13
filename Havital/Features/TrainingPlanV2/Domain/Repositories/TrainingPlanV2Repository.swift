import Foundation

// MARK: - TrainingPlanV2 Repository Protocol
/// 定義訓練計畫 V2 數據存取介面
/// Domain Layer - 只定義介面，不涉及實作細節
protocol TrainingPlanV2Repository {

    // MARK: - Target Types & Methodologies

    /// 獲取支援的目標類型
    /// - Returns: 目標類型列表
    func getTargetTypes() async throws -> [TargetTypeV2]

    /// 獲取方法論列表
    /// - Parameter targetType: 目標類型（可選，不提供則返回所有方法論）
    /// - Returns: 方法論列表
    func getMethodologies(targetType: String?) async throws -> [MethodologyV2]

    // MARK: - Plan Overview

    /// 創建訓練計畫概覽（賽事模式）
    /// - Parameters:
    ///   - targetId: 目標 ID（必填）
    ///   - startFromStage: 起始階段（可選，預設 "base"）
    /// - Returns: 新建立的計畫概覽
    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2

    /// 創建訓練計畫概覽（非賽事模式）
    /// - Parameters:
    ///   - targetType: 目標類型（beginner, maintenance）
    ///   - trainingWeeks: 訓練週數
    ///   - availableDays: 每週可訓練天數（可選，預設 5）
    ///   - methodologyId: 方法論 ID（可選）
    ///   - startFromStage: 起始階段（可選，預設 "base"）
    /// - Returns: 新建立的計畫概覽
    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?
    ) async throws -> PlanOverviewV2

    /// 獲取當前 active 計畫概覽（支援緩存）
    /// - Returns: 計畫概覽實體
    func getOverview() async throws -> PlanOverviewV2

    /// 強制刷新計畫概覽（跳過緩存）
    /// - Returns: 最新的計畫概覽
    func refreshOverview() async throws -> PlanOverviewV2

    /// 更新計畫概覽
    /// - Parameters:
    ///   - overviewId: 概覽 ID
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: 更新後的計畫概覽
    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2

    // MARK: - Weekly Plan

    /// 生成週課表
    /// - Parameters:
    ///   - weekOfTraining: 訓練週次（1-based）
    ///   - forceGenerate: 強制重新生成（可選，預設 false）
    ///   - promptVersion: Prompt 版本（可選，預設 "v2"）
    ///   - methodology: 方法論（可選，預設 "paceriz"）
    /// - Returns: 週課表實體
    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2

    /// 獲取週課表（支援緩存，cache miss 時從 API 讀取）
    /// - Parameter weekOfTraining: 訓練週次
    /// - Returns: 週課表實體
    func getWeeklyPlan(weekOfTraining: Int) async throws -> WeeklyPlanV2

    /// 透過 planId 從 API 讀取週課表
    /// - Parameter planId: 週課表 ID
    /// - Returns: 週課表實體
    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2

    /// 更新週課表（合併更新）
    /// - Parameters:
    ///   - planId: 週課表 ID
    ///   - updates: 要更新的欄位
    /// - Returns: 更新後的週課表
    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2

    /// 強制刷新週課表
    /// - Parameter weekOfTraining: 訓練週次
    /// - Returns: 最新的週課表
    func refreshWeeklyPlan(weekOfTraining: Int) async throws -> WeeklyPlanV2

    /// 刪除週課表 (Debug)
    /// - Parameter planId: 週課表 ID
    func deleteWeeklyPlan(planId: String) async throws

    // MARK: - Weekly Summary

    /// 生成週摘要
    /// - Parameters:
    ///   - weekOfPlan: 訓練週次
    ///   - forceUpdate: 強制更新（可選，預設 false）
    /// - Returns: 週摘要實體
    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2

    /// 獲取週摘要（支援緩存）
    /// - Parameter weekOfPlan: 訓練週次
    /// - Returns: 週摘要實體
    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2

    /// 強制刷新週摘要
    /// - Parameter weekOfPlan: 訓練週次
    /// - Returns: 最新的週摘要
    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2

    /// 刪除週摘要 (Debug)
    /// - Parameter summaryId: 週摘要 ID
    func deleteWeeklySummary(summaryId: String) async throws

    // MARK: - Cache Management

    /// 清除所有緩存
    func clearCache() async

    /// 清除計畫概覽緩存
    func clearOverviewCache() async

    /// 清除週課表緩存
    /// - Parameter weekOfTraining: 特定週次（nil 表示清除全部）
    func clearWeeklyPlanCache(weekOfTraining: Int?) async

    /// 清除週摘要緩存
    /// - Parameter weekOfPlan: 特定週次（nil 表示清除全部）
    func clearWeeklySummaryCache(weekOfPlan: Int?) async

    /// 預載入數據（用於優化啟動速度）
    func preloadData() async
}

// MARK: - Repository Errors
/// 訓練計畫 V2 相關錯誤
enum TrainingPlanV2Error: Error, Equatable {

    // MARK: - Overview Errors

    /// 訓練概覽不存在
    case overviewNotFound

    /// 沒有 active 訓練計畫
    case noActivePlan

    /// 創建概覽失敗
    case overviewCreationFailed(String)

    /// 更新概覽失敗
    case overviewUpdateFailed(String)

    // MARK: - Weekly Plan Errors

    /// 週課表不存在
    case weeklyPlanNotFound(week: Int)

    /// 生成週課表失敗
    case weeklyPlanGenerationFailed(week: Int, reason: String)

    /// 無效的週次
    case invalidWeekNumber(week: Int)

    // MARK: - Weekly Summary Errors

    /// 週摘要不存在
    case weeklySummaryNotFound(week: Int)

    /// 生成週摘要失敗
    case weeklySummaryGenerationFailed(week: Int, reason: String)

    // MARK: - Validation Errors

    /// 參數驗證失敗
    case validationFailure(String)

    /// 無效的目標類型
    case invalidTargetType(String)

    /// 無效的方法論 ID
    case invalidMethodologyId(String)

    // MARK: - Cache Errors

    /// 緩存過期
    case cacheExpired

    /// 緩存損壞
    case cacheCorrupted(String)

    // MARK: - Network Errors

    /// 網路錯誤
    case networkError(String)

    /// 伺服器錯誤
    case serverError(Int, String)

    /// 解析錯誤
    case parsingError(String)

    // MARK: - Unknown

    /// 未知錯誤
    case unknown(String)
}

// MARK: - TrainingPlanV2Error to DomainError
extension TrainingPlanV2Error {

    /// 將 TrainingPlanV2Error 轉換為 DomainError
    /// - Returns: 對應的 DomainError
    func toDomainError() -> DomainError {
        switch self {
        // Overview Errors
        case .overviewNotFound:
            return .notFound("訓練計畫概覽不存在")
        case .noActivePlan:
            return .notFound("沒有有效的訓練計畫")
        case .overviewCreationFailed(let reason):
            return .validationFailure("創建計畫概覽失敗: \(reason)")
        case .overviewUpdateFailed(let reason):
            return .validationFailure("更新計畫概覽失敗: \(reason)")

        // Weekly Plan Errors
        case .weeklyPlanNotFound(let week):
            return .notFound("第 \(week) 週課表不存在")
        case .weeklyPlanGenerationFailed(let week, let reason):
            return .validationFailure("生成第 \(week) 週課表失敗: \(reason)")
        case .invalidWeekNumber(let week):
            return .validationFailure("無效的週次: \(week)")

        // Weekly Summary Errors
        case .weeklySummaryNotFound(let week):
            return .notFound("第 \(week) 週摘要不存在")
        case .weeklySummaryGenerationFailed(let week, let reason):
            return .validationFailure("生成第 \(week) 週摘要失敗: \(reason)")

        // Validation Errors
        case .validationFailure(let message):
            return .validationFailure(message)
        case .invalidTargetType(let type):
            return .validationFailure("無效的目標類型: \(type)")
        case .invalidMethodologyId(let id):
            return .validationFailure("無效的方法論 ID: \(id)")

        // Cache Errors
        case .cacheExpired:
            return .dataCorruption("緩存已過期")
        case .cacheCorrupted(let message):
            return .dataCorruption("緩存損壞: \(message)")

        // Network Errors
        case .networkError(let message):
            return .networkFailure(message)
        case .serverError(let code, let message):
            return .serverError(code, message)
        case .parsingError(let message):
            return .dataCorruption("解析錯誤: \(message)")

        // Unknown
        case .unknown(let message):
            return .unknown(message)
        }
    }
}
