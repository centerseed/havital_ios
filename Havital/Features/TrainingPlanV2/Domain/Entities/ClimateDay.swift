import Foundation

// MARK: - ClimateDay

/// 一週七天中某一天的氣候資訊（T-0165）。
///
/// 綁「日期」不綁「課表」：後端不再把氣候存進 weekly_plan 文件，而是讀取時依日期現算，
/// 以 plan-level `climate[7]` 回傳。課表被編輯 / 搬動 / 交換都不影響這筆資料。
///
/// 七天恆滿 —— 休息日、力量日、涼爽日（`comfortable`）都有。
///
/// **不要回頭去讀 `DayDetail.climateMeta`**：那是為了尚未升級的舊版 App 保留的投影欄位，
/// 只在 `mild` 以上的跑步日出現，休息日與涼爽日一律缺席。用它畫週視圖就會少掉三、四天。
struct ClimateDay: Codable, Equatable {
    /// 1 = 週一 … 7 = 週日
    let dayIndex: Int
    /// YYYY-MM-DD，用戶本地日期
    let date: String
    let feelsLikeTempC: Double
    /// comfortable / mild / moderate / high / danger
    let heatPressureLevel: String
    /// 建議配速下修百分比；comfortable 為 0
    let paceAdjustmentPct: Double
    /// 長跑距離建議保留比例（0.8 = 建議跑原訂距離的 80%，不是砍掉 80%）。mild 以下為 nil。
    let longRunKeepRatio: Double?
    let reasonText: String
    let source: String?
    /// 官方警示標籤（如中央氣象署高溫警戒）
    let warningLabel: String?
    let regionKey: String?
    /// 該熱等級建議的訓練時段（mild/moderate 為 early_morning + evening）
    let suggestedTrainingWindows: [String]

    var normalizedHeatPressureLevel: String {
        heatPressureLevel.lowercased()
    }

    /// 涼爽日「不說話」：只顯示溫度，無警示色、無圖示升級、詳情頁無卡片。
    var isComfortable: Bool {
        normalizedHeatPressureLevel == "comfortable" || normalizedHeatPressureLevel == "none"
    }

    /// mild 以上才有熱適應建議可講。
    var hasHeatAdvice: Bool {
        !isComfortable
    }

    /// 週視圖膠囊上的溫度文字。
    var temperatureText: String {
        String(format: "%.0f°", feelsLikeTempC)
    }

    /// 熱調整後的配速。後端不再送 `climate_adjusted_pace`，App 當場算。
    ///
    /// 回傳 nil 的情況：沒有基準配速、配速格式不合法、或該日無需調整（comfortable）。
    func climateAdjustedPace(forBasePace basePace: String) -> String? {
        guard paceAdjustmentPct > 0 else { return nil }
        guard let seconds = Self.paceToSeconds(basePace) else { return nil }
        let adjusted = Int((Double(seconds) * (1.0 + paceAdjustmentPct / 100.0)).rounded())
        return Self.secondsToPace(adjusted)
    }

    /// 長跑的建議距離（顯示用）。熱不砍處方距離，運動員保留處方、自己決定。
    func climateAdjustedDistanceKm(forPrescribedKm km: Double) -> Double? {
        guard let ratio = longRunKeepRatio, ratio > 0, ratio < 1, km > 0 else { return nil }
        let suggested = (km * ratio * 10).rounded() / 10
        return suggested < km ? suggested : nil
    }

    static func paceToSeconds(_ pace: String) -> Int? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }

    static func secondsToPace(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension Array where Element == ClimateDay {
    /// 依 day_index 取該天的氣候。氣候綁日期，所以永遠用 day_index 對，不用陣列位置。
    func forDayIndex(_ dayIndex: Int) -> ClimateDay? {
        first { $0.dayIndex == dayIndex }
    }
}
