import Foundation

/// 訓練強度分鐘數
struct IntensityMinutes: Codable, Equatable {
    let low: Double
    let medium: Double
    let high: Double
    
    static var zero: IntensityMinutes {
        return IntensityMinutes(low: 0, medium: 0, high: 0)
    }
    
    static func + (lhs: IntensityMinutes, rhs: IntensityMinutes) -> IntensityMinutes {
        return IntensityMinutes(
            low: lhs.low + rhs.low,
            medium: lhs.medium + rhs.medium,
            high: lhs.high + rhs.high
        )
    }
}

/// Wrapper for workout summary API response
typealias WorkoutSummaryResponse = WorkoutSummaryDataWrapper

struct WorkoutSummaryDataWrapper: Codable {
    let data: WorkoutSummaryData
}

struct WorkoutSummaryData: Codable {
    let workout: WorkoutSummary
}

/// Model for workout summary
struct WorkoutSummary: Codable {
    let avgHR: Double
    let avgPace: String
    let createdTS: TimeInterval
    let distanceKm: Double
    let durationMin: Double
    let hrZonePct: ZonePct
    let id: String
    let intervalCount: Int
    let maxHR: Double
    let minHR: Double
    let paceZonePct: ZonePct?
    let type: String
    let vdot: Double
    let trimp: Double?
    let intensityMinutes: IntensityMinutes?

    enum CodingKeys: String, CodingKey {
        case avgHR = "avg_hr"
        case avgPace = "avg_pace"
        case createdTS = "created_ts"
        case distanceKm = "distance_km"
        case durationMin = "duration_min"
        case hrZonePct = "hr_zone_pct"
        case id
        case intervalCount = "interval_count"
        case maxHR = "max_hr"
        case minHR = "min_hr"
        case paceZonePct = "pace_zone_pct"
        case type
        case vdot
        case trimp
        case intensityMinutes = "intensity_minutes"
    }

    /// 自訂解碼，避免 pace_zone_pct 缺少欄位導致錯誤
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avgHR = try container.decode(Double.self, forKey: .avgHR)
        avgPace = try container.decode(String.self, forKey: .avgPace)
        createdTS = try container.decode(TimeInterval.self, forKey: .createdTS)
        distanceKm = try container.decode(Double.self, forKey: .distanceKm)
        durationMin = try container.decode(Double.self, forKey: .durationMin)
        hrZonePct = try container.decode(ZonePct.self, forKey: .hrZonePct)
        id = try container.decode(String.self, forKey: .id)
        intervalCount = try container.decode(Int.self, forKey: .intervalCount)
        maxHR = try container.decode(Double.self, forKey: .maxHR)
        minHR = try container.decode(Double.self, forKey: .minHR)
        // paceZonePct optional，缺欄位則回傳 nil
        paceZonePct = try? container.decode(ZonePct.self, forKey: .paceZonePct)
        type = try container.decode(String.self, forKey: .type)
        vdot = try container.decode(Double.self, forKey: .vdot)
        trimp = try container.decodeIfPresent(Double.self, forKey: .trimp)
        intensityMinutes = try container.decodeIfPresent(IntensityMinutes.self, forKey: .intensityMinutes)
    }
}

/// Model for percentage in HR or pace zones
struct ZonePct: Codable {
    let anaerobic: Double
    let easy: Double
    let interval: Double
    let marathon: Double
    let recovery: Double
    let threshold: Double

    enum CodingKeys: String, CodingKey {
        case anaerobic, easy, interval, marathon, recovery, threshold
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anaerobic = try container.decodeIfPresent(Double.self, forKey: .anaerobic) ?? 0.0
        easy      = try container.decodeIfPresent(Double.self, forKey: .easy)      ?? 0.0
        interval  = try container.decodeIfPresent(Double.self, forKey: .interval)  ?? 0.0
        marathon  = try container.decodeIfPresent(Double.self, forKey: .marathon)  ?? 0.0
        recovery  = try container.decodeIfPresent(Double.self, forKey: .recovery)  ?? 0.0
        threshold = try container.decodeIfPresent(Double.self, forKey: .threshold) ?? 0.0
    }
}
