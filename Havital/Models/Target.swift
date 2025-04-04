import Foundation

struct Target: Codable, Identifiable {
    let id: String
    let type: String
    let name: String
    let distanceKm: Int
    let targetTime: Int
    let targetPace: String
    let raceDate: Int
    let isMainRace: Bool
    let trainingWeeks: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case distanceKm = "distance_km"
        case targetTime = "target_time"
        case targetPace = "target_pace"
        case raceDate = "race_date"
        case isMainRace = "is_main_race"
        case trainingWeeks = "training_weeks"
    }
}

