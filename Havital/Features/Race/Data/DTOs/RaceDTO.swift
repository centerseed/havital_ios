import Foundation

// MARK: - RaceDTO
/// 賽事 DTO - Data Layer
/// snake_case + CodingKeys，符合 API 回傳格式
struct RaceDTO: Codable {
    let raceId: String
    let name: String
    let region: String
    let eventDate: String          // "YYYY-MM-DD"
    let city: String
    let location: String?
    let distances: [RaceDistanceDTO]
    let entryStatus: String?
    let isCurated: Bool?
    let courseType: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case raceId = "race_id"
        case name, region
        case eventDate = "event_date"
        case city, location, distances
        case entryStatus = "entry_status"
        case isCurated = "is_curated"
        case courseType = "course_type"
        case tags
    }
}

// MARK: - RaceDistanceDTO
/// 賽事距離 DTO - Data Layer
struct RaceDistanceDTO: Codable {
    let distanceKm: Double
    let name: String

    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case name
    }
}

// MARK: - RaceListResponseDTO
/// 賽事列表回應 DTO - Data Layer
/// 對應 API /v2/races 回傳的 data 物件
struct RaceListResponseDTO: Codable {
    let races: [RaceDTO]
    let total: Int
    let limit: Int
    let offset: Int
}
