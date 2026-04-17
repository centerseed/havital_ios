import Foundation

// MARK: - TrainingPlan Repository Protocol
/// 定義訓練計畫數據存取介面
/// Domain Layer - 只定義介面，不涉及實作細節
///
/// - Warning: V1 legacy. V2 users must use `TrainingPlanV2Repository`.
///   Bug triage policy：除登入失敗 / crash 等嚴重情況外，V1 bug 僅 log，不修。
/// - Note: Scheduled for `@available(*, deprecated)` warning on 2026-07-17。
///   本階段（Phase A）刻意只加 doc comment，不啟用 compile warning 以避免 warning 爆量。
protocol TrainingPlanRepository {

    // MARK: - Weekly Plan

    /// 獲取指定週計畫（支援緩存）
    /// - Parameter planId: 週計畫 ID，格式為 "{overviewId}_{weekNumber}"
    /// - Returns: 週計畫實體
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan

    /// 強制刷新週計畫（跳過緩存）
    /// - Parameter planId: 週計畫 ID
    /// - Returns: 最新的週計畫
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan

    /// 創建新的週計畫
    /// - Parameters:
    ///   - week: 目標週數（可選，預設為下一週）
    ///   - startFromStage: 起始階段（可選）
    ///   - isBeginner: 是否為初學者模式
    /// - Returns: 新建立的週計畫
    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan

    /// 修改週計畫
    /// - Parameters:
    ///   - planId: 週計畫 ID
    ///   - updatedPlan: 更新後的計畫
    /// - Returns: 修改後的週計畫
    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan

    // MARK: - Training Overview

    /// 獲取訓練計畫概覽（支援緩存）
    /// - Returns: 訓練計畫概覽
    func getOverview() async throws -> TrainingPlanOverview

    /// 強制刷新訓練計畫概覽
    /// - Returns: 最新的訓練計畫概覽
    func refreshOverview() async throws -> TrainingPlanOverview

    /// 創建訓練計畫概覽
    /// - Parameters:
    ///   - startFromStage: 起始階段（可選）
    ///   - isBeginner: 是否為初學者模式
    /// - Returns: 新建立的訓練計畫概覽
    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview

    /// 更新訓練計畫概覽
    /// - Parameter overviewId: 概覽 ID
    /// - Returns: 更新後的訓練計畫概覽
    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview

    // MARK: - Plan Status

    /// 獲取計畫狀態（支援緩存）
    /// - Returns: 計畫狀態響應
    func getPlanStatus() async throws -> PlanStatusResponse

    /// 強制刷新計畫狀態
    /// - Returns: 最新的計畫狀態
    func refreshPlanStatus() async throws -> PlanStatusResponse

    // MARK: - Modifications

    /// 獲取所有修改項目
    /// - Returns: 修改項目列表
    func getModifications() async throws -> [Modification]

    /// 獲取修改描述
    /// - Returns: 修改描述文字
    func getModificationsDescription() async throws -> String

    /// 新增修改
    /// - Parameter modification: 新的修改項目
    /// - Returns: 創建後的修改項目
    func createModification(_ modification: NewModification) async throws -> Modification

    /// 更新多筆修改
    /// - Parameter modifications: 修改項目列表
    /// - Returns: 更新後的修改項目列表
    func updateModifications(_ modifications: [Modification]) async throws -> [Modification]

    /// 清除所有修改
    func clearModifications() async throws

    // MARK: - Weekly Summary

    /// 創建週回顧
    /// - Parameters:
    ///   - weekNumber: 週數（可選，預設為上一週）
    ///   - forceUpdate: 強制更新現有的回顧
    /// - Returns: 週回顧數據
    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary

    /// 獲取所有週回顧（歷史記錄）
    /// - Returns: 週回顧列表
    func getWeeklySummaries() async throws -> [WeeklySummaryItem]

    /// 獲取特定週的回顧
    /// - Parameter weekNumber: 週數
    /// - Returns: 週回顧數據
    func getWeeklySummary(weekNumber: Int) async throws -> WeeklyTrainingSummary

    /// 更新調整項目
    /// - Parameters:
    ///   - summaryId: 週回顧 ID
    ///   - items: 調整項目列表
    /// - Returns: 更新後的調整項目列表
    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> [AdjustmentItem]

    // MARK: - Cache Management

    /// 清除所有緩存
    func clearCache() async

    /// 預載入數據（用於優化啟動速度）
    func preloadData() async
}

// MARK: - Repository Errors
/// 訓練計畫相關錯誤
enum TrainingPlanError: Error, Equatable {
    /// 週計畫不存在
    case weeklyPlanNotFound(planId: String)

    /// 訓練概覽不存在
    case overviewNotFound

    /// 沒有有效的訓練計畫
    case noPlan

    /// 計畫狀態無效
    case invalidPlanStatus

    /// 緩存過期
    case cacheExpired

    /// 網路錯誤
    case networkError(String)

    /// 解析錯誤
    case parsingError(String)
}

// MARK: - TrainingPlanError to DomainError
extension TrainingPlanError {
    func toDomainError() -> DomainError {
        switch self {
        case .weeklyPlanNotFound(let planId):
            return .notFound("Weekly plan not found: \(planId)")
        case .overviewNotFound:
            return .notFound("Training overview not found")
        case .noPlan:
            return .notFound("No training plan available")
        case .invalidPlanStatus:
            return .validationFailure("Invalid plan status")
        case .cacheExpired:
            return .dataCorruption("Cache expired")
        case .networkError(let message):
            return .networkFailure(message)
        case .parsingError(let message):
            return .dataCorruption(message)
        }
    }
}
