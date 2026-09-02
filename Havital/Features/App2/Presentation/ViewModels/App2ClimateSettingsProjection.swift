import Foundation

/// 熱適應設定頁的判斷（T-0392）。版面留在 view，會出錯的判斷放這裡：
/// 哪幾段該出現、目前狀態要畫實測還是退回設定摘要、配速那一格印什麼、滑桿的界。
///
/// 抽出來是因為這些在 1.4 是散在 `List` 的 `if` 裡，改版面時最容易被順手改掉。
enum App2ClimateSettingsProjection {

    /// 手動起調門檻的滑桿界。與 1.4 同值：低於 24°C 沒有調整的意義，
    /// 高於 30°C 已進危險帶（`uiSummary.dangerTempC`），不該讓人自己往上調。
    static let thresholdRange: ClosedRange<Double> = 24...30
    static let thresholdStep: Double = 0.5

    enum Section: Equatable {
        case enable
        case currentStatus
        case controls
        case explanation
    }

    /// 關掉熱適應時只留開關那一段——底下每一段講的都是「怎麼調整」，
    /// 沒在調整時全部沒有意義。
    static func sections(enabled: Bool) -> [Section] {
        enabled ? [.enable, .currentStatus, .controls, .explanation] : [.enable]
    }

    enum StatusMode: Equatable {
        /// 有當日觀測：畫實測（是否調整、體感溫度、配速調整、長跑折減）。
        case live
        /// 沒有觀測：退回「你的設定」摘要（設定標籤、起調溫度、常見調整幅度）。
        case fallback
    }

    static func statusMode(currentStatus: ClimateCurrentStatus?) -> StatusMode {
        currentStatus == nil ? .fallback : .live
    }

    /// 配速那一格。沒調整就是 `0%`；有調整但後端沒給百分比時只講「已調整」，
    /// **不印 0%** —— 那會讓人以為沒調整。
    static func paceText(
        _ status: ClimateCurrentStatus,
        adjustedLabel: @autoclosure () -> String
    ) -> String {
        guard status.isAdjusted else { return "0%" }
        guard let pct = status.paceAdjustmentPct else { return adjustedLabel() }
        return String(format: "%.1f%%", pct)
    }
}
