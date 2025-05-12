import SwiftUI

/// Training type utility extensions
extension DayType {
    /// 中文名稱
    var chineseName: String {
        switch self {
        case .easyRun, .easy: return "輕鬆跑"
        case .recovery_run: return "恢復跑"
        case .interval: return "間歇跑"
        case .tempo: return "節奏跑"
        case .threshold: return "閾值跑"
        case .longRun: return "長距離跑"
        case .race: return "比賽"
        case .rest: return "休息"
        case .crossTraining: return "交叉訓練"
        case .lsd: return "長距離輕鬆跑"
        case .progression: return "漸速跑"
        case .strength: return "重量訓練"
        case .hiking: return "健行"
        case .yoga: return "瑜伽"
        case .cycling: return "騎車"
        }
    }
    /// 標籤顏色
    var labelColor: Color {
        switch self {
        case .easyRun, .easy, .recovery_run, .lsd, .yoga:
            return .green
        case .interval, .tempo, .threshold, .progression:
            return .orange
        case .longRun:
            return .blue
        case .race:
            return .red
        case .rest:
            return .gray
        case .crossTraining:
            return .purple
        case .strength:
            return .purple
        case .hiking, .cycling:
            return .blue
        }
    }
    /// 背景顏色
    var backgroundColor: Color {
        labelColor.opacity(0.2)
    }
}
