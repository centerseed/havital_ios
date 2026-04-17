import Foundation

// MARK: - RaceEvent
/// 賽事實體 - Domain Layer
/// camelCase，不加 Codable（Domain 不耦合序列化格式）
struct RaceEvent: Identifiable, Equatable {
    let raceId: String
    let name: String
    let region: String
    let eventDate: Date
    let city: String
    let location: String?
    let distances: [RaceDistance]
    let entryStatus: String?
    let isCurated: Bool
    let courseType: String?
    let tags: [String]

    var id: String { raceId }

    /// 距離賽事天數
    var daysUntilEvent: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: eventDate).day ?? 0
    }

    /// 是否時間不足（< 4 週）
    var isTimeTight: Bool {
        daysUntilEvent < 28
    }
}

// MARK: - RaceDistance
/// 賽事距離選項 - Domain Layer
struct RaceDistance: Identifiable, Equatable {
    let distanceKm: Double
    let name: String

    var id: Double { distanceKm }
}
