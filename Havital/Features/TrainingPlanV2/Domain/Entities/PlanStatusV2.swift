import Foundation

// MARK: - PlanStatusV2 Enum

/// 訓練計畫狀態 V2（UI 使用）
enum PlanStatusV2: Equatable {
    case loading
    case noPlan            // 無計畫（顯示 Onboarding 提示）
    case noWeeklyPlan      // 有 Overview 但無週課表（顯示「產生週課表」按鈕）
    case needsWeeklySummary // 需要先產生週回顧才能產生下週課表（顯示「產生週回顧」按鈕）
    case ready(WeeklyPlanV2)  // 有計畫，顯示課表
    case completed         // 訓練完成
    case error(Error)      // 錯誤狀態

    static func == (lhs: PlanStatusV2, rhs: PlanStatusV2) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.noPlan, .noPlan),
             (.noWeeklyPlan, .noWeeklyPlan),
             (.needsWeeklySummary, .needsWeeklySummary),
             (.completed, .completed):
            return true
        case (.ready(let lhsPlan), .ready(let rhsPlan)):
            return lhsPlan.id == rhsPlan.id
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
