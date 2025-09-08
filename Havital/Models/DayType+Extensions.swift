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
        case .easyRun, .easy, .recovery_run, .lsd, .yoga:
            return .green
        case .interval, .tempo, .threshold, .progression, .combination:
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
