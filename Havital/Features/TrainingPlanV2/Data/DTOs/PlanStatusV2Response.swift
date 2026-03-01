import Foundation

// MARK: - PlanStatusV2Response
/// V2 計畫狀態回應 DTO
/// API: GET /v2/plan/status
/// Data Layer - 與 API JSON 結構一一對應，使用 snake_case 命名
struct PlanStatusV2Response: Codable {

    // MARK: - 核心狀態欄位

    /// 當前訓練週數（後端計算）
    let currentWeek: Int

    /// 總訓練週數
    let totalWeeks: Int

    /// 下一步動作（決定 UI 顯示）
    /// 可能值: "create_plan" | "view_plan" | "create_summary" | "training_completed"
    let nextAction: String

    /// 是否可產生下週課表
    let canGenerateNextWeek: Bool

    /// 當前週課表 ID（如果存在）
    let currentWeekPlanId: String?

    /// 上週摘要 ID（如果存在）
    let previousWeekSummaryId: String?

    // MARK: - V2 新增欄位

    /// 目標類型
    /// 可能值: "race" | "beginner" | "maintenance"
    let targetType: String?

    /// 方法論 ID
    let methodologyId: String?

    // MARK: - 可選擴展欄位

    /// 下週資訊（後端可能提供）
    let nextWeekInfo: NextWeekInfoV2?

    /// 元數據（時間、時區等）
    let metadata: PlanStatusV2Metadata?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case currentWeek = "current_week"
        case totalWeeks = "total_weeks"
        case nextAction = "next_action"
        case canGenerateNextWeek = "can_generate_next_week"
        case currentWeekPlanId = "current_week_plan_id"
        case previousWeekSummaryId = "previous_week_summary_id"
        case targetType = "target_type"
        case methodologyId = "methodology_id"
        case nextWeekInfo = "next_week_info"
        case metadata
    }
}

// MARK: - NextWeekInfoV2
/// 下週資訊（可選）
struct NextWeekInfoV2: Codable {

    /// 下週週數
    let weekNumber: Int

    /// 是否已有課表
    let hasPlan: Bool

    /// 是否可產生
    let canGenerate: Bool

    /// 是否需要當前週摘要
    let requiresCurrentWeekSummary: Bool?

    /// 下週的 nextAction
    let nextAction: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case hasPlan = "has_plan"
        case canGenerate = "can_generate"
        case requiresCurrentWeekSummary = "requires_current_week_summary"
        case nextAction = "next_action"
    }
}

// MARK: - PlanStatusV2Metadata
/// 計畫狀態元數據（V2）
struct PlanStatusV2Metadata: Codable {

    /// 訓練開始日期（ISO8601 格式）
    let trainingStartDate: String?

    /// 當前週開始日期（ISO8601 格式）
    let currentWeekStartDate: String?

    /// 當前週結束日期（ISO8601 格式）
    let currentWeekEndDate: String?

    /// 使用者時區
    let userTimezone: String?

    /// 伺服器時間（ISO8601 格式）
    let serverTime: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case trainingStartDate = "training_start_date"
        case currentWeekStartDate = "current_week_start_date"
        case currentWeekEndDate = "current_week_end_date"
        case userTimezone = "user_timezone"
        case serverTime = "server_time"
    }
}
