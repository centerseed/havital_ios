import Foundation

struct WeeklyPlan: Codable {
    let purpose: String
    let tips: String
    let totalDistanceKm: Int?
    let weekOfPlan: Int
    let days: [TrainingDay]
    
    enum CodingKeys: String, CodingKey {
        case purpose
        case tips
        case totalDistanceKm = "total_distance_km"
        case weekOfPlan = "week_of_plan"
        case days
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: String { "\(dayIndex)" }
    let dayIndex: Int
    let dayTarget: String
    let type: DayType
    let tips: String?
    let reason: String?
    let isTrainingDay: Bool
    let trainingItems: [WeeklyTrainingItem]?
    
    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case dayTarget = "day_target"
        case type
        case tips
        case reason
        case isTrainingDay = "is_training_day"
        case trainingItems = "training_items"
    }
}

enum DayType: String, Codable {
    case easy = "easy"
    case strength = "strength"
    case rest = "rest"
}

struct WeeklyTrainingItem: Codable {
    let name: String
    let runDetails: String?
    let goals: TrainingGoals?
    
    enum CodingKeys: String, CodingKey {
        case name
        case runDetails = "run_details"
        case goals
    }
}

struct TrainingGoals: Codable {
    let pace: String?
    let distanceKm: Double?
    
    enum CodingKeys: String, CodingKey {
        case pace
        case distanceKm = "distance_km"
    }
}
