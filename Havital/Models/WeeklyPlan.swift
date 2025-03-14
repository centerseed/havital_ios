import Foundation

struct WeeklyPlan: Codable {
    let id: String
    let purpose: String
    let weekOfPlan: Int
    let totalWeeks: Int
    let totalDistance: Double
    let days: [TrainingDay]
    
    enum CodingKeys: String, CodingKey {
        case id
        case purpose
        case weekOfPlan = "week_of_plan"
        case totalWeeks = "total_weeks"
        case totalDistance = "total_distance_km"
        case days
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // First, check if we're parsing the nested data structure
        if let dataContainer = try? decoder.container(keyedBy: DataCodingKeys.self),
           let nestedContainer = try? dataContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
            // Parse from nested data structure
            id = try nestedContainer.decode(String.self, forKey: .id)
            purpose = try nestedContainer.decode(String.self, forKey: .purpose)
            weekOfPlan = try nestedContainer.decode(Int.self, forKey: .weekOfPlan)
            totalWeeks = try nestedContainer.decode(Int.self, forKey: .totalWeeks)
            totalDistance = try nestedContainer.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0.0
            days = try nestedContainer.decode([TrainingDay].self, forKey: .days)
        } else {
            // Parse directly from root container
            id = try container.decode(String.self, forKey: .id)
            purpose = try container.decode(String.self, forKey: .purpose)
            weekOfPlan = try container.decode(Int.self, forKey: .weekOfPlan)
            totalWeeks = try container.decode(Int.self, forKey: .totalWeeks)
            totalDistance = try container.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0.0
            days = try container.decode([TrainingDay].self, forKey: .days)
        }
    }
    
    // For handling the outer "data" wrapper if present
    enum DataCodingKeys: String, CodingKey {
        case data
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: String { "\(dayIndex)" }
    let dayIndex: Int
    let dayTarget: String
    let reason: String?
    let tips: String?
    let trainingType: String
    let trainingDetails: TrainingDetails?
    
    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case dayTarget = "day_target"
        case reason
        case tips
        case trainingType = "training_type"
        case trainingDetails = "training_details"
    }
    
    var type: DayType {
        return DayType(rawValue: trainingType) ?? .rest
    }
    
    var isTrainingDay: Bool {
        return type != .rest
    }
    
    var trainingItems: [WeeklyTrainingItem]? {
        if let details = trainingDetails {
            switch type {
            case .easyRun, .easy, .longRun, .tempo:
                if let description = details.description, let distance = details.distanceKm, let pace = details.pace {
                    let item = WeeklyTrainingItem(
                        name: "輕鬆跑",
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: pace, distanceKm: distance, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            case .interval:
                var items: [WeeklyTrainingItem] = []
                if let work = details.work, let recovery = details.recovery, let repeats = details.repeats {
                    let workItem = WeeklyTrainingItem(
                        name: "間歇跑",
                        runDetails: work.description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: work.pace, distanceKm: work.distanceKm, heartRate: nil, times: repeats)
                    )
                    items.append(workItem)
                    
                    let recoveryItem = WeeklyTrainingItem(
                        name: "恢復跑",
                        runDetails: recovery.description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: recovery.pace, distanceKm: recovery.distanceKm, heartRate: nil, times: repeats)
                    )
                    items.append(recoveryItem)
                    return items
                }
            default:
                break
            }
        }
        return nil
    }
}

struct TrainingDetails: Codable {
    let description: String?
    let distanceKm: Double?
    let pace: String?
    let work: WorkoutSegment?
    let recovery: WorkoutSegment?
    let repeats: Int?
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case pace
        case work
        case recovery
        case repeats
    }
}

struct WorkoutSegment: Codable {
    let description: String
    let distanceKm: Double
    let pace: String
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case pace
    }
}

enum DayType: String, Codable {
    case easyRun = "easy_run"
    case easy = "easy"
    case interval = "interval"
    case tempo = "tempo"
    case longRun = "long_run"
    case race = "race"
    case rest = "rest"
    case crossTraining = "cross_training"
}

struct WeeklyTrainingItem: Identifiable {
    var id = UUID()
    let name: String
    let runDetails: String
    let durationMinutes: Int?
    let goals: TrainingGoals
}

struct TrainingGoals {
    let pace: String?
    let distanceKm: Double?
    let heartRate: String?
    let times: Int?
}
