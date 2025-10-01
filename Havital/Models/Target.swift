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
    let timezone: String  // 新增：賽事時區

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
        case timezone
    }

    // 初始化器，預設時區為台北
    init(id: String = "", type: String, name: String, distanceKm: Int,
         targetTime: Int, targetPace: String, raceDate: Int,
         isMainRace: Bool, trainingWeeks: Int, timezone: String = "Asia/Taipei") {
        self.id = id
        self.type = type
        self.name = name
        self.distanceKm = distanceKm
        self.targetTime = targetTime
        self.targetPace = targetPace
        self.raceDate = raceDate
        self.isMainRace = isMainRace
        self.trainingWeeks = trainingWeeks
        self.timezone = timezone
    }

    // 從 Decoder 解碼時的處理
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        distanceKm = try container.decode(Int.self, forKey: .distanceKm)
        targetTime = try container.decode(Int.self, forKey: .targetTime)
        targetPace = try container.decode(String.self, forKey: .targetPace)
        raceDate = try container.decode(Int.self, forKey: .raceDate)
        isMainRace = try container.decode(Bool.self, forKey: .isMainRace)
        trainingWeeks = try container.decode(Int.self, forKey: .trainingWeeks)

        // 時區欄位是選填的，預設為台北時區
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "Asia/Taipei"
    }
}

