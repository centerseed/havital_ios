import Foundation

// MARK: - ClimateDayDTO

/// plan-level `climate[7]` 的單日條目（T-0165）。
///
/// 後端契約：`domains/climate/models.py` 的 `WeeklyClimateDay`。
/// 七天恆滿（含休息日與 `comfortable`）；用戶關閉氣候調整或預報缺失時，整個 `climate` 欄位缺席。
struct ClimateDayDTO: Codable, Equatable {
    let dayIndex: Int
    let date: String
    let feelsLikeTempC: Double
    let heatPressureLevel: String
    let paceAdjustmentPct: Double?
    /// 後端誠實命名：這是「保留比例」（0.8 = 跑原訂的 80%），不是縮減幅度。
    let longRunKeepRatio: Double?
    let reasonText: String
    let source: String?
    let warningLabel: String?
    let regionKey: String?
    let suggestedTrainingWindows: [String]?

    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case date
        case feelsLikeTempC = "feels_like_temp_c"
        case heatPressureLevel = "heat_pressure_level"
        case paceAdjustmentPct = "pace_adjustment_pct"
        case longRunKeepRatio = "long_run_keep_ratio"
        case reasonText = "reason_text"
        case source
        case warningLabel = "warning_label"
        case regionKey = "region_key"
        case suggestedTrainingWindows = "suggested_training_windows"
    }
}
