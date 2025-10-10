import Foundation

/// 基於丹尼爾跑步公式的配速計算器
/// 根據 VDOT 值計算各訓練區間的建議配速
struct PaceCalculator {

    // MARK: - 配速區間定義

    /// 訓練配速區間類型
    enum PaceZone: String, CaseIterable {
        case recovery = "恢復跑配速[R]"
        case easy = "輕鬆跑配速[Easy]"
        case tempo = "節奏跑配速[T]"
        case marathon = "全程馬拉松配速[M]"
        case threshold = "閾值跑配速[TH]"
        case anaerobic = "無氧配速[AN]"
        case interval = "間歇跑配速[I]"

        /// 配速區間對應的百分比範圍 (pct_low, pct_high)
        var percentageRange: (Double, Double) {
            switch self {
            case .recovery:   return (0.52, 0.59)
            case .easy:       return (0.59, 0.74)
            case .tempo:      return (0.75, 0.84)
            case .marathon:   return (0.78, 0.82)
            case .threshold:  return (0.83, 0.88)
            case .anaerobic:  return (0.88, 0.95)
            case .interval:   return (0.95, 1.0)
            }
        }

        /// 本地化顯示名稱
        var displayName: String {
            return rawValue
        }
    }

    // MARK: - 配速計算方法

    /// 計算所有訓練區間的配速表
    /// - Parameter vdot: VDOT 值（建議使用 weight_vdot）
    /// - Returns: 各訓練區間的配速字典，格式為 mm:ss
    static func calculateTrainingPaces(vdot: Double) -> [PaceZone: String] {
        // 將 VDOT 乘以 1.05 再計算配速表
        let adjustedVDOT = vdot * 1.05
        var result: [PaceZone: String] = [:]

        for zone in PaceZone.allCases {
            let (pctLow, pctHigh) = zone.percentageRange

            // 1. 計算速度（公尺/分鐘）
            let vLow = calculateVelocity(vdot: adjustedVDOT, percentage: pctLow)
            let vHigh = calculateVelocity(vdot: adjustedVDOT, percentage: pctHigh)

            // 2. 轉換為配速（分鐘/公里）
            let paceLow = 1000.0 / vLow
            let paceHigh = 1000.0 / vHigh

            // 3. 計算平均配速
            let avgPace = (paceLow + paceHigh) / 2.0

            // 4. 格式化為 mm:ss
            let formattedPace = formatPace(avgPace)
            result[zone] = formattedPace
        }

        return result
    }

    /// 根據訓練類型獲取建議配速
    /// - Parameters:
    ///   - trainingType: 訓練類型（例如：easy, tempo, interval）
    ///   - vdot: VDOT 值
    /// - Returns: 建議配速字串，格式為 mm:ss
    static func getSuggestedPace(for trainingType: String, vdot: Double) -> String? {
        guard let zone = mapTrainingTypeToZone(trainingType) else {
            return nil
        }

        // calculateTrainingPaces 內部會自動乘以 1.05
        let paces = calculateTrainingPaces(vdot: vdot)
        return paces[zone]
    }

    /// 獲取訓練類型對應的配速區間範圍（下限和上限）
    /// - Parameters:
    ///   - trainingType: 訓練類型
    ///   - vdot: VDOT 值
    /// - Returns: (下限配速, 上限配速) 的元組，格式為 mm:ss
    static func getPaceRange(for trainingType: String, vdot: Double) -> (min: String, max: String)? {
        guard let zone = mapTrainingTypeToZone(trainingType) else {
            return nil
        }

        // 將 VDOT 乘以 1.05 再計算配速範圍
        let adjustedVDOT = vdot * 1.05
        let (pctLow, pctHigh) = zone.percentageRange

        let vLow = calculateVelocity(vdot: adjustedVDOT, percentage: pctLow)
        let vHigh = calculateVelocity(vdot: adjustedVDOT, percentage: pctHigh)

        let paceLow = 1000.0 / vLow
        let paceHigh = 1000.0 / vHigh

        // 注意：配速數值越小越快，所以 paceHigh 是最快配速（下限），paceLow 是最慢配速（上限）
        return (min: formatPace(paceHigh), max: formatPace(paceLow))
    }

    // MARK: - 核心計算函數

    /// 丹尼爾速度公式：根據 VDOT 和百分比計算速度
    /// - Parameters:
    ///   - vdot: VDOT 值
    ///   - percentage: 百分比（0.52 到 1.0 之間）
    /// - Returns: 速度（公尺/分鐘）
    ///
    /// 公式：v = (-0.182258 + √(0.033218 - 0.000416 × (-4.6 - vdot × pct))) / 0.000208
    private static func calculateVelocity(vdot: Double, percentage: Double) -> Double {
        let a = -4.6 - (vdot * percentage)
        let b = 0.000416 * a
        let c = 0.033218 - b
        let d = sqrt(c)
        let e = -0.182258 + d
        let v = e / 0.000208

        return v // 公尺/分鐘
    }

    /// 將配速（分鐘為單位的浮點數）格式化為 mm:ss 格式
    /// - Parameter minutes: 配速（分鐘）
    /// - Returns: 格式化後的配速字串（例如："5:35"）
    ///
    /// 特點：秒數會四捨五入到最接近的 0 或 5
    private static func formatPace(_ minutes: Double) -> String {
        var totalSeconds = Int(minutes * 60)
        var mins = totalSeconds / 60
        var secs = totalSeconds % 60

        // 秒數四捨五入到 0 或 5
        let remainder = secs % 5
        if remainder < 3 {
            // 0, 1, 2 → 向下取整到最近的 5 的倍數
            secs = (secs / 5) * 5
        } else {
            // 3, 4 → 向上取整到最近的 5 的倍數
            secs = ((secs / 5) + 1) * 5

            // 處理進位
            if secs >= 60 {
                secs = 0
                mins += 1
            }
        }

        // 格式化為 mm:ss
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - 訓練類型映射

    /// 將訓練類型字串映射到配速區間
    /// - Parameter trainingType: 訓練類型（例如："easy"、"tempo"、"interval"）
    /// - Returns: 對應的配速區間，如果無法映射則返回 nil
    private static func mapTrainingTypeToZone(_ trainingType: String) -> PaceZone? {
        let type = trainingType.lowercased()

        switch type {
        case "recovery_run", "recovery":
            return .recovery

        case "easy", "easyrun", "easy_run", "lsd":
            return .easy

        case "tempo", "tempo_run":
            return .tempo

        case "threshold", "threshold_run":
            return .threshold

        case "marathon", "marathon_pace":
            return .marathon

        case "interval", "intervals", "interval_run":
            return .interval

        case "longrun", "long_run":
            // 長距離跑通常使用馬拉松配速
            return .marathon

        case "progression", "combination":
            // 組合跑和漸進跑可能包含多個區間，返回節奏跑作為中等強度參考
            return .tempo

        default:
            return nil
        }
    }

    // MARK: - 配速表生成

    /// 生成完整的配速表文字（用於顯示或複製）
    /// - Parameter vdot: VDOT 值
    /// - Returns: 格式化的配速表字串
    static func generatePaceTableText(vdot: Double) -> String {
        // calculateTrainingPaces 內部會自動乘以 1.05
        let paces = calculateTrainingPaces(vdot: vdot)
        let adjustedVDOT = vdot * 1.05

        var text = "***** 參考配速表 (VDOT: \(String(format: "%.1f", vdot)) × 1.05 = \(String(format: "%.1f", adjustedVDOT))) *****\n\n"

        for zone in PaceZone.allCases {
            if let pace = paces[zone] {
                text += "\(zone.displayName): \(pace)\n"
            }
        }

        return text
    }

    /// 驗證 VDOT 值是否在合理範圍內
    /// - Parameter vdot: VDOT 值
    /// - Returns: 是否有效
    static func isValidVDOT(_ vdot: Double) -> Bool {
        // VDOT 通常在 20 到 85 之間
        return vdot >= 20.0 && vdot <= 85.0
    }

    /// 獲取預設 VDOT 值（當用戶沒有 VDOT 數據時使用）
    static var defaultVDOT: Double {
        return 45.0 // 中等水平跑者的 VDOT
    }
}

// MARK: - 訓練類型枚舉擴展

extension DayType {
    /// 獲取該訓練類型對應的配速區間
    var paceZone: PaceCalculator.PaceZone? {
        switch self {
        case .recovery_run:
            return .recovery
        case .easyRun, .easy, .lsd:
            return .easy
        case .tempo:
            return .tempo
        case .threshold:
            return .threshold
        case .interval:
            return .interval
        case .longRun:
            return .marathon
        case .progression, .combination:
            return .tempo
        default:
            return nil
        }
    }
}
