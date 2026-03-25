import SwiftUI

/// Training type utility extensions
extension DayType {
    /// 本地化名稱
    var localizedName: String {
        switch self {
        case .easyRun, .easy: return L10n.Training.TrainingType.easy.localized
        case .recovery_run: return L10n.Training.TrainingType.recovery.localized
        case .interval: return L10n.Training.TrainingType.interval.localized
        case .tempo: return L10n.Training.TrainingType.tempo.localized
        case .threshold: return L10n.Training.TrainingType.threshold.localized
        case .longRun: return L10n.Training.TrainingType.long.localized
        case .race: return L10n.Training.TrainingType.race.localized
        case .rest: return L10n.Training.TrainingType.rest.localized
        case .crossTraining: return L10n.Training.TrainingType.crossTraining.localized
        case .lsd: return L10n.Training.TrainingType.lsd.localized
        case .progression: return L10n.Training.TrainingType.progression.localized
        case .combination: return L10n.Training.TrainingType.combination.localized
        case .strength: return L10n.Training.TrainingType.strength.localized
        case .hiking: return L10n.Training.TrainingType.hiking.localized
        case .yoga: return L10n.Training.TrainingType.yoga.localized
        case .cycling: return L10n.Training.TrainingType.cycling.localized
        // 新增間歇訓練類型
        case .strides: return L10n.Training.TrainingType.strides.localized
        case .hillRepeats: return L10n.Training.TrainingType.hillRepeats.localized
        case .cruiseIntervals: return L10n.Training.TrainingType.cruiseIntervals.localized
        case .shortInterval: return L10n.Training.TrainingType.shortInterval.localized
        case .longInterval: return L10n.Training.TrainingType.longInterval.localized
        case .norwegian4x4: return L10n.Training.TrainingType.norwegian4x4.localized
        case .yasso800: return L10n.Training.TrainingType.yasso800.localized
        // 新增組合訓練類型
        case .fartlek: return L10n.Training.TrainingType.fartlek.localized
        case .fastFinish: return L10n.Training.TrainingType.fastFinish.localized
        // 新增比賽配速訓練
        case .racePace: return L10n.Training.TrainingType.racePace.localized
        // V3 交叉訓練新增類型
        case .swimming: return L10n.ActivityType.swimming.localized
        case .elliptical: return L10n.ActivityType.elliptical.localized
        case .rowing: return L10n.ActivityType.rowing.localized
        }
    }
    
    /// 中文名稱（已棄用，請使用 localizedName）
    @available(*, deprecated, message: "Use localizedName instead")
    var chineseName: String {
        return localizedName
    }
    /// 標籤顏色
    var labelColor: Color {
        switch self {
        // 輕鬆訓練 - 綠色
        case .easyRun, .easy, .recovery_run, .yoga:
            return .green
        // 強度訓練 - 橘色
        case .interval, .tempo, .threshold, .combination:
            return .orange
        case .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            return .orange
        case .fartlek: return .orange      // 法特雷克 - 橘色（變速訓練，屬強度訓練）
        case .racePace:
            return .red
        // 長距離訓練 - 藍色
        case .lsd, .longRun, .progression, .fastFinish:
            return .blue
        // 休息日 - 灰色
        case .race:
            return .red
        case .rest:
            return .gray
        // 交叉訓練 - 紫色
        case .crossTraining, .strength:
            return .purple
        case .hiking, .cycling:
            return .blue
        // V3 交叉訓練新增類型
        case .swimming, .elliptical, .rowing:
            return .purple
        }
    }
    /// 背景顏色
    var backgroundColor: Color {
        labelColor.opacity(0.2)
    }

    /// 是否為跑步活動（用於判斷是否顯示距離等跑步相關資訊）
    var isRunningActivity: Bool {
        switch self {
        case .rest, .crossTraining, .strength, .yoga, .hiking, .cycling, .swimming, .elliptical, .rowing:
            return false
        default:
            return true
        }
    }
}
