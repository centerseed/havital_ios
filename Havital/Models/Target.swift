import Foundation

struct Target: Codable {
    let type: String
    let name: String
    let distanceKm: Int
    let targetTime: Int
    let targetPace: String
    let raceDate: Int
    let isMainRace: Bool
    let trainingWeeks: Int
    
    enum CodingKeys: String, CodingKey {
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
