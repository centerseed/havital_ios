import Foundation

// VDOT Data Models
struct VDOTDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let weightVdot: Double?
}

struct VDOTResponse: Codable {
    let data: VDOTData
}

struct VDOTData: Codable {
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
    let weightVdot: Double
    
    enum CodingKeys: String, CodingKey {
        case datetime
        case dynamicVdot = "dynamic_vdot"
        case weightVdot = "weight_vdot"
    }
}
