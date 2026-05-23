import Foundation

struct ClimateForecastSettings: Codable, Equatable {
    let enabled: Bool
    let adaptationLevel: String
    let manualStartThresholdC: Double?
    let regionKey: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case adaptationLevel = "adaptation_level"
        case manualStartThresholdC = "manual_start_threshold_c"
        case regionKey = "region_key"
    }
}

struct ClimateForecastDay: Codable, Equatable, Identifiable {
    let dayIndex: Int
    let date: String
    let feelsLikeTempC: Double?
    let heatPressureLevel: String
    let paceAdjustmentPct: Double?
    let longRunReductionPct: Double?
    let reasonText: String?
    let source: String?
    let warningLabel: String?
    let regionKey: String?
    let snapshotID: String?
    let pointID: String?
    let isAdjusted: Bool

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case date
        case feelsLikeTempC = "feels_like_temp_c"
        case heatPressureLevel = "heat_pressure_level"
        case paceAdjustmentPct = "pace_adjustment_pct"
        case longRunReductionPct = "long_run_reduction_pct"
        case reasonText = "reason_text"
        case source
        case warningLabel = "warning_label"
        case regionKey = "region_key"
        case snapshotID = "snapshot_id"
        case pointID = "point_id"
        case isAdjusted = "is_adjusted"
    }
}

struct ClimateForecastResponse: Codable, Equatable {
    let uid: String
    let locale: String
    let enabled: Bool
    let regionKey: String
    let source: String
    let startDate: String
    let daysRequested: Int
    let dataStatus: String
    let snapshotRefreshedAt: String?
    let settings: ClimateForecastSettings
    let days: [ClimateForecastDay]

    enum CodingKeys: String, CodingKey {
        case uid
        case locale
        case enabled
        case regionKey = "region_key"
        case source
        case startDate = "start_date"
        case daysRequested = "days_requested"
        case dataStatus = "data_status"
        case snapshotRefreshedAt = "snapshot_refreshed_at"
        case settings
        case days
    }
}
