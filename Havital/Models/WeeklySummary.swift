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

// MARK: - 休息週 / 無訓練容錯解碼
//
// 後端休息週回應實況（prod 驗證）：省略 `id`、省略整個 `heart_rate` 物件、`pace.average` 回 null。
// Swift Codable 是「全有或全無」——任一非 optional 欄位缺漏 / 為 null，整包 throw，
// 導致該用戶週回顧頁完全開不出來（非「少顯示某個值」）。
// 以下自訂 init(from:) 以 decodeIfPresent + 預設值容錯，語意對齊 V2 的 WeeklySummaryV2DTO（欄位皆 optional）。
// init 放 extension：保留各 struct 的 memberwise init，供上層建構預設物件。

extension WeeklyTrainingSummary {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.trainingCompletion = try c.decode(TrainingCompletion.self, forKey: .trainingCompletion)
        self.trainingAnalysis = try c.decode(TrainingAnalysis.self, forKey: .trainingAnalysis)
        self.nextWeekSuggestions = try c.decodeIfPresent(NextWeekSuggestions.self, forKey: .nextWeekSuggestions)
            ?? NextWeekSuggestions(focus: "", recommendations: [])
        self.nextWeekAdjustments = try c.decodeIfPresent(NextWeekAdjustments.self, forKey: .nextWeekAdjustments)
            ?? NextWeekAdjustments(status: nil, modifications: nil, adjustmentReason: nil, items: nil)
    }
}

extension TrainingAnalysis {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.heartRate = try c.decodeIfPresent(HeartRateAnalysis.self, forKey: .heartRate)
            ?? HeartRateAnalysis(average: 0, max: 0, evaluation: "")
        self.pace = try c.decodeIfPresent(PaceAnalysis.self, forKey: .pace)
            ?? PaceAnalysis(average: "", trend: "", evaluation: "")
        self.distance = try c.decodeIfPresent(DistanceAnalysis.self, forKey: .distance)
            ?? DistanceAnalysis(total: 0, comparisonToPlan: "", evaluation: "")
    }
}

extension HeartRateAnalysis {
    enum CodingKeys: String, CodingKey { case average, max, evaluation }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.average = try c.decodeIfPresent(Double.self, forKey: .average) ?? 0
        self.max = try c.decodeIfPresent(Double.self, forKey: .max) ?? 0
        self.evaluation = try c.decodeIfPresent(String.self, forKey: .evaluation) ?? ""
    }
}

extension PaceAnalysis {
    enum CodingKeys: String, CodingKey { case average, trend, evaluation }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.average = try c.decodeIfPresent(String.self, forKey: .average) ?? ""
        self.trend = try c.decodeIfPresent(String.self, forKey: .trend) ?? ""
        self.evaluation = try c.decodeIfPresent(String.self, forKey: .evaluation) ?? ""
    }
}

extension DistanceAnalysis {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        self.comparisonToPlan = try c.decodeIfPresent(String.self, forKey: .comparisonToPlan) ?? ""
        self.evaluation = try c.decodeIfPresent(String.self, forKey: .evaluation) ?? ""
    }
}

extension NextWeekSuggestions {
    enum CodingKeys: String, CodingKey { case focus, recommendations }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.focus = try c.decodeIfPresent(String.self, forKey: .focus) ?? ""
        self.recommendations = try c.decodeIfPresent([String].self, forKey: .recommendations) ?? []
    }
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
        if let userTimezone = UserPreferencesManager.shared.timezonePreference {
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
