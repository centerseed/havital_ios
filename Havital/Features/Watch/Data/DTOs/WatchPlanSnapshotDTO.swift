import Foundation

struct WatchPlanSnapshotDTO: Codable, Equatable {
    let date: String
    let runType: String
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let planId: String
    let segments: [WatchSegmentDTO]

    enum CodingKeys: String, CodingKey {
        case date
        case runType = "run_type"
        case totalDistanceMeters = "total_distance_meters"
        case totalSeconds = "total_seconds"
        case planId = "plan_id"
        case segments
    }
}

struct WatchSegmentDTO: Codable, Equatable {
    let kind: String
    let measure: String
    let targetMeters: Double?
    let targetSeconds: Int?
    let paceLowSecPerKm: Int?
    let paceHighSecPerKm: Int?
    let label: String
    let repIndex: Int?
    let repTotal: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case measure
        case targetMeters = "target_meters"
        case targetSeconds = "target_seconds"
        case paceLowSecPerKm = "pace_low_sec_per_km"
        case paceHighSecPerKm = "pace_high_sec_per_km"
        case label
        case repIndex = "rep_index"
        case repTotal = "rep_total"
    }
}
