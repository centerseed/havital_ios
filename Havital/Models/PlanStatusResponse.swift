import Foundation

// MARK: - Plan Status Response Models

/// 訓練計畫狀態回應（對應後端 GET /plan/race_run/status API）
struct PlanStatusResponse: Codable {
    /// 後端計算的當前訓練週數（從 1 開始）
    let currentWeek: Int

    /// 訓練計畫總週數
    let totalWeeks: Int

    /// 前端應執行的下一步操作
    let nextAction: NextAction

    /// 是否允許提前產生下週課表（例如：週六、週日可以提前產生）
    let canGenerateNextWeek: Bool

    /// 當前週課表 ID（如果存在）
    let currentWeekPlanId: String?

    /// 上週回顧 ID（如果存在）
    let previousWeekSummaryId: String?

    /// 下週課表資訊（週六日才提供）
    let nextWeekInfo: NextWeekInfo?

    /// 額外的時間和時區資訊
    let metadata: PlanStatusMetadata

    enum CodingKeys: String, CodingKey {
        case currentWeek = "current_week"
        case totalWeeks = "total_weeks"
        case nextAction = "next_action"
        case canGenerateNextWeek = "can_generate_next_week"
        case currentWeekPlanId = "current_week_plan_id"
        case previousWeekSummaryId = "previous_week_summary_id"
        case nextWeekInfo = "next_week_info"
        case metadata
    }
}

// MARK: - Next Action Enum

/// 前端應執行的下一步操作
enum NextAction: String, Codable {
    /// 當前週課表已存在，直接顯示
    case viewPlan = "view_plan"

    /// 需要先產生上週的週回顧
    case createSummary = "create_summary"

    /// 可以直接產生當前週課表（無需週回顧或已完成）
    case createPlan = "create_plan"

    /// 訓練計畫已全部完成
    case trainingCompleted = "training_completed"

    /// 用戶沒有啟動中的訓練計畫
    case noActivePlan = "no_active_plan"
}

// MARK: - Next Week Info

/// 下週課表資訊
struct NextWeekInfo: Codable {
    /// 下週的週數
    let weekNumber: Int

    /// 下週課表是否已存在
    let hasPlan: Bool

    /// 是否可以現在產生下週課表
    let canGenerate: Bool

    /// 產生下週課表前是否需要先完成當前週回顧
    let requiresCurrentWeekSummary: Bool

    /// 產生下週課表的下一步操作
    /// 例如："create_summary_for_week_3" 或 "create_plan_for_week_4"
    let nextAction: String

    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case hasPlan = "has_plan"
        case canGenerate = "can_generate"
        case requiresCurrentWeekSummary = "requires_current_week_summary"
        case nextAction = "next_action"
    }
}

// MARK: - Metadata

/// 額外的時間和時區資訊（用於 debug）
struct PlanStatusMetadata: Codable {
    /// 訓練計畫開始日期
    let trainingStartDate: String

    /// 當前週的週一日期
    let currentWeekStartDate: String

    /// 當前週的週日日期
    let currentWeekEndDate: String

    /// 用戶時區（IANA 格式）
    let userTimezone: String

    /// 伺服器當前時間
    let serverTime: String

    enum CodingKeys: String, CodingKey {
        case trainingStartDate = "training_start_date"
        case currentWeekStartDate = "current_week_start_date"
        case currentWeekEndDate = "current_week_end_date"
        case userTimezone = "user_timezone"
        case serverTime = "server_time"
    }
}

// MARK: - Convenience Extensions

extension PlanStatusResponse {
    /// 是否正在查看未來週課表
    func isViewingFutureWeek(selectedWeek: Int) -> Bool {
        return selectedWeek > currentWeek
    }

    /// 是否可以產生下週課表
    var canGenerateNext: Bool {
        return nextWeekInfo?.canGenerate ?? false
    }

    /// 下週週數
    var nextWeekNumber: Int? {
        return nextWeekInfo?.weekNumber
    }
}

extension NextAction {
    /// 是否需要顯示「產生週回顧」按鈕
    var shouldShowCreateSummaryButton: Bool {
        return self == .createSummary
    }

    /// 是否需要顯示「產生課表」按鈕
    var shouldShowCreatePlanButton: Bool {
        return self == .createPlan
    }

    /// 是否應該載入並顯示課表
    var shouldLoadPlan: Bool {
        return self == .viewPlan
    }
}
