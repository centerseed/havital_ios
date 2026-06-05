import Foundation

struct WatchSegmentDTO: Codable {
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
        case label
        case targetMeters = "target_meters"
        case targetSeconds = "target_seconds"
        case paceLowSecPerKm = "pace_low_sec_per_km"
        case paceHighSecPerKm = "pace_high_sec_per_km"
        case repIndex = "rep_index"
        case repTotal = "rep_total"
    }
}

struct WatchPlanSnapshotDTO: Codable {
    let date: String
    let runType: String
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let planId: String
    let segments: [WatchSegmentDTO]

    enum CodingKeys: String, CodingKey {
        case date
        case segments
        case runType = "run_type"
        case totalDistanceMeters = "total_distance_meters"
        case totalSeconds = "total_seconds"
        case planId = "plan_id"
    }

    func toEntity() -> WatchPlanSnapshot {
        WatchPlanSnapshot(
            date: date,
            flowType: WorkoutFlowType(runType: runType),
            totalDistanceMeters: totalDistanceMeters,
            totalSeconds: totalSeconds,
            planId: planId,
            segments: segments.map { segment in
                WatchSegment(
                    kind: Self.mapKind(segment.kind),
                    measure: segment.measure == "time" ? .time : .distance,
                    targetMeters: segment.targetMeters,
                    targetSeconds: segment.targetSeconds,
                    paceLowSecPerKm: segment.paceLowSecPerKm,
                    paceHighSecPerKm: segment.paceHighSecPerKm,
                    label: segment.label,
                    repIndex: segment.repIndex,
                    repTotal: segment.repTotal
                )
            }
        )
    }

    private static func mapKind(_ value: String) -> WatchSegment.Kind {
        switch value {
        case "warmup":
            return .warmup
        case "rest":
            return .rest
        case "cooldown":
            return .cooldown
        case "work":
            return .work
        default:
            return .run
        }
    }
}
