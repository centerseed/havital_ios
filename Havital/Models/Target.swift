import Foundation

struct PlanOverviewUpdateStatus: Codable, Equatable {
    let status: String
    let overviewId: String?
    let pollAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case overviewId = "overview_id"
        case pollAfterSeconds = "poll_after_seconds"
    }

    var shouldPoll: Bool {
        status == "queued" || status == "running"
    }
}

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
    let raceId: String?   // 賽事資料庫 ID（選填，手動輸入則為 nil）
    let planOverviewUpdate: PlanOverviewUpdateStatus?

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
        case raceId = "race_id"
        case planOverviewUpdate = "plan_overview_update"
    }

    // 初始化器，預設時區為台北，raceId 選填
    init(id: String = "", type: String, name: String, distanceKm: Int,
         targetTime: Int, targetPace: String, raceDate: Int,
         isMainRace: Bool, trainingWeeks: Int, timezone: String = "Asia/Taipei",
         raceId: String? = nil,
         planOverviewUpdate: PlanOverviewUpdateStatus? = nil) {
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
        self.raceId = raceId
        self.planOverviewUpdate = planOverviewUpdate
    }

    // 從 Decoder 解碼時的處理
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        if let intDistance = try? container.decode(Int.self, forKey: .distanceKm) {
            distanceKm = intDistance
        } else {
            let doubleDistance = try container.decode(Double.self, forKey: .distanceKm)
            distanceKm = Int(doubleDistance.rounded())
        }
        targetTime = try container.decode(Int.self, forKey: .targetTime)
        targetPace = try container.decode(String.self, forKey: .targetPace)
        raceDate = try container.decode(Int.self, forKey: .raceDate)
        isMainRace = try container.decode(Bool.self, forKey: .isMainRace)
        trainingWeeks = try container.decode(Int.self, forKey: .trainingWeeks)

        // 時區欄位是選填的，預設為台北時區
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "Asia/Taipei"

        // raceId 選填：後端暫未回傳時容錯
        raceId = try container.decodeIfPresent(String.self, forKey: .raceId)
        planOverviewUpdate = try container.decodeIfPresent(PlanOverviewUpdateStatus.self, forKey: .planOverviewUpdate)
    }
}
