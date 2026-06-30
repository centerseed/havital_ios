import SwiftUI

/// 日曆每日格子的訓練類型色 bucket（五色語意，鏡像 DayType.labelColor 色相）。
enum CalendarTypeBucket {
    case green   // 輕鬆（含 D5：未知 / 無 run_type 的跑步）
    case orange  // 強度
    case blue    // 長距離 / 戶外有氧
    case red     // 比賽
    case indigo  // 重訓 / 交叉
}

/// 把 run_type 或 activity 字串對到 bucket。純函式、可單測。
/// 未知 / 空 / 一般跑步一律 green（spec D5）。
func calendarBucket(for trainingTypeOrActivity: String) -> CalendarTypeBucket {
    switch trainingTypeOrActivity.trimmingCharacters(in: .whitespaces).lowercased() {
    case "interval", "tempo", "threshold", "combination",
         "strides", "hill_repeats", "cruise_intervals", "short_interval",
         "long_interval", "norwegian_4x4", "norwegian_singles", "yasso800", "fartlek":
        return .orange
    case "lsd", "long_run", "progression", "fast_finish", "hiking", "cycling":
        return .blue
    case "race_pace", "race":
        return .red
    case "cross_training", "strength", "swimming", "elliptical", "rowing":
        return .indigo
    default:
        // easy / easy_run / recovery_run / yoga / "" / run / running / 未知 → green（D5）
        return .green
    }
}

extension CalendarTypeBucket {
    /// 加深、隨 light/dark 自適應的可讀文字 / icon 色（重用既有 PacerizColor 深色 token）。
    var deepColor: Color {
        switch self {
        case .green:  return PacerizColor.greenDeep
        case .orange: return PacerizColor.orangeDeep
        case .blue:   return PacerizColor.blueDeep
        case .red:    return PacerizColor.error
        case .indigo: return PacerizColor.indigo
        }
    }
}
