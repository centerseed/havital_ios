import Foundation
import SwiftUI

// 定義符合API返回結構的模型
struct WeeklyTrainingSummary: Codable {
    let id: String
    let trainingCompletion: TrainingCompletion
    let trainingAnalysis: TrainingAnalysis
    let nextWeekSuggestions: NextWeekSuggestions
    let nextWeekAdjustments: NextWeekAdjustments

    enum CodingKeys: String, CodingKey {
        case id
        case trainingCompletion = "training_completion"
        case trainingAnalysis = "training_analysis"
        case nextWeekSuggestions = "next_week_suggestions"
        case nextWeekAdjustments = "next_week_adjustments"
    }
}

struct TrainingCompletion: Codable {
    let percentage: Double
    let evaluation: String
}

struct TrainingAnalysis: Codable {
    let heartRate: HeartRateAnalysis
    let pace: PaceAnalysis
    let distance: DistanceAnalysis
    
    enum CodingKeys: String, CodingKey {
        case heartRate = "heart_rate"
        case pace
        case distance
    }
}

struct HeartRateAnalysis: Codable {
    let average: Double
    let max: Double
    let evaluation: String
}

struct PaceAnalysis: Codable {
    let average: String
    let trend: String
    let evaluation: String
}

struct DistanceAnalysis: Codable {
    let total: Double
    let comparisonToPlan: String
    let evaluation: String
    
    enum CodingKeys: String, CodingKey {
        case total
        case comparisonToPlan = "comparison_to_plan"
        case evaluation
    }
}

struct NextWeekSuggestions: Codable {
    let focus: String
    let recommendations: [String]
}

struct AdjustmentItem: Codable, Identifiable {
    let id = UUID()
    let content: String
    let apply: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case apply
    }
}

struct NextWeekAdjustments: Codable {
    let status: String?
    let modifications: Modifications?
    let adjustmentReason: String?
    let items: [AdjustmentItem]?

    enum CodingKeys: String, CodingKey {
        case status
        case modifications
        case adjustmentReason = "adjustment_reason"
        case items
    }
}

struct Modifications: Codable {
    let intervalTraining: TrainingModification?
    let longRun: TrainingModification?
    
    enum CodingKeys: String, CodingKey {
        case intervalTraining = "interval_training"
        case longRun = "long_run"
    }
}

struct TrainingModification: Codable {
    let original: String
    let adjusted: String
}

struct WeeklySummaryResponse: Codable {
    let data: WeeklyTrainingSummary
}

// 新增對應 /summary/weekly/ API 的模型
struct WeeklySummaryItem: Codable {
    let weekIndex: Int
    let weekStart: String
    let weekStartTimestamp: TimeInterval?
    let distanceKm: Double?
    let weekPlan: String?
    let weekSummary: String?
    /// 本週完成百分比
    let completionPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case weekIndex = "week_index"
        case weekStart = "week_start"
        case weekStartTimestamp = "week_start_timestamp"
        case distanceKm = "distance_km"
        case weekPlan = "week_plan"
        case weekSummary = "week_summary"
        case completionPercentage = "completion_percentage"
    }

    /// 將 week_start 字符串轉換為 Date
    var weekStartDate: Date? {
        // 如果有 timestamp，優先使用
        if let timestamp = weekStartTimestamp {
            return Date(timeIntervalSince1970: timestamp)
        }

        // 否則解析字符串 "2025/10/13"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        // 使用用户设置的时区，如果未设置则使用设备当前时区
        if let userTimezone = UserPreferenceManager.shared.timezonePreference {
            formatter.timeZone = TimeZone(identifier: userTimezone)
        } else {
            formatter.timeZone = TimeZone.current
        }
        return formatter.date(from: weekStart)
    }
}

// MARK: - 調整建議 API 模型
struct UpdateAdjustmentsRequest: Codable {
    let items: [AdjustmentItem]
}

// MARK: - 強制更新週回顧 API 模型
struct CreateWeeklySummaryRequest: Codable {
    let forceUpdate: Bool?

    enum CodingKeys: String, CodingKey {
        case forceUpdate = "force_update"
    }

    init(forceUpdate: Bool? = nil) {
        self.forceUpdate = forceUpdate
    }
}

struct UpdateAdjustmentsResponse: Codable {
    let success: Bool
    let data: UpdateAdjustmentsData
}

struct UpdateAdjustmentsData: Codable {
    let items: [AdjustmentItem]
}
