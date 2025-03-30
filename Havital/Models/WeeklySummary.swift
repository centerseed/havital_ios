import Foundation
import SwiftUI

// 定義符合API返回結構的模型
struct WeeklyTrainingSummary: Codable {
    let trainingCompletion: TrainingCompletion
    let trainingAnalysis: TrainingAnalysis
    let nextWeekSuggestions: NextWeekSuggestions
    let nextWeekAdjustments: NextWeekAdjustments
    
    enum CodingKeys: String, CodingKey {
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

struct NextWeekAdjustments: Codable {
    let status: String
    let modifications: Modifications?
    let adjustmentReason: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case modifications
        case adjustmentReason = "adjustment_reason"
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
