import SwiftUI

extension Color {
    // MARK: - Paceriz 主色調

    /// 主色藍（基於 app icon）
    static let pacerizPrimary = Color(hex: "1E90FF")

    /// 輔助藍色
    static let pacerizSecondary = Color(hex: "00BFFF")

    /// 深色背景
    static let pacerizBackground = Color(hex: "1C1C1E")

    /// 卡片表面顏色
    static let pacerizSurface = Color(hex: "2C2C2E")

    // MARK: - 心率區間顏色

    /// Z1 輕鬆區間（綠色）
    static let hrZone1 = Color(hex: "4CAF50")

    /// Z2 馬拉松區間（藍色）
    static let hrZone2 = Color(hex: "2196F3")

    /// Z3 閾值區間（黃色）
    static let hrZone3 = Color(hex: "FFC107")

    /// Z4 有氧區間（橙色）
    static let hrZone4 = Color(hex: "FF9800")

    /// Z5 無氧/間歇區間（紅色）
    static let hrZone5 = Color(hex: "F44336")

    /// 根據區間號獲取顏色
    static func heartRateZoneColor(zone: Int) -> Color {
        switch zone {
        case 1: return .hrZone1
        case 2: return .hrZone2
        case 3: return .hrZone3
        case 4: return .hrZone4
        case 5: return .hrZone5
        default: return .gray
        }
    }

    // MARK: - 訓練類型顏色（與 DayType 一致）

    /// 輕鬆訓練（綠色）
    static let trainingEasy = Color.green

    /// 高強度訓練（橙色）
    static let trainingIntense = Color.orange

    /// 長距離訓練（藍色）
    static let trainingLong = Color.blue

    /// 比賽（紅色）
    static let trainingRace = Color.red

    /// 休息（灰色）
    static let trainingRest = Color.gray

    /// 交叉訓練（紫色）
    static let trainingCross = Color.purple

    /// 根據訓練類型獲取顏色
    static func trainingTypeColor(type: DayType) -> Color {
        switch type {
        case .easy, .easyRun, .recovery_run, .lsd, .yoga:
            return .trainingEasy
        case .interval, .tempo, .threshold, .progression, .combination:
            return .trainingIntense
        case .longRun, .hiking, .cycling:
            return .trainingLong
        case .race:
            return .trainingRace
        case .rest:
            return .trainingRest
        case .crossTraining, .strength:
            return .trainingCross
        }
    }

    // MARK: - 狀態顏色

    /// 成功/理想狀態
    static let statusSuccess = Color.green

    /// 警告狀態
    static let statusWarning = Color.orange

    /// 錯誤/危險狀態
    static let statusError = Color.red

    /// 信息狀態
    static let statusInfo = Color.blue

    // MARK: - Hex 初始化器

    /// 從 Hex 字符串創建顏色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
