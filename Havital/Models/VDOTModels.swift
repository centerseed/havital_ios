import Foundation

// VDOT Data Models
struct VDOTDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let weightVdot: Double?
}

struct VDOTResponse: Codable {
    let needUpdatedHrRange: Bool
    let vdots: [VDOTEntry]
    
    enum CodingKeys: String, CodingKey {
        case needUpdatedHrRange = "need_updated_hr_range"
        case vdots
    }
}

struct VDOTEntry: Codable {
    let datetime: TimeInterval
    let dynamicVdot: Double
    let paceVdot: Double?
    let liveVdot: Double?
    let weightVdot: Double?

    var resolvedPaceVdot: Double { paceVdot ?? dynamicVdot }
    
    enum CodingKeys: String, CodingKey {
        case datetime
        case dynamicVdot = "dynamic_vdot"
        case paceVdot = "pace_vdot"
        case liveVdot = "live_vdot"
        case weightVdot = "weight_vdot"
    }
}
