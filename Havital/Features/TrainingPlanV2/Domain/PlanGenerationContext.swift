import Foundation

// MARK: - PlanGenerationContext
/// Snapshot of data available immediately before plan generation.
/// Passed to LoadingAnimationView to show pipeline narrative messages.
struct PlanGenerationContext {
    let weekNumber: Int
    let totalWeeks: Int?
    let vdot: Double?
    let lastWeekVolumeKm: Double?
    let phaseName: String?
    let phaseWeek: Int?
    let phaseTotalWeeks: Int?
}

// MARK: - Builder Helpers

extension PlanGenerationContext {

    struct PhaseInfo {
        let localizedKey: String
        let phaseWeek: Int
        let phaseTotalWeeks: Int
    }

    static func stageIdToLocalizationKey(_ stageId: String) -> String {
        localizationKey(forStageId: stageId) ?? L10n.Training.Stage.unknown
    }

    /// 期別識別字 → 在地化 key，**認不得就回 nil**。
    ///
    /// 與 `stageIdToLocalizationKey` 同一張表（那一支就是這一支加上「認不得＝訓練中」）。
    /// 分出 nil 的版本，是因為有些欄位（`plan_context.current_phase`）後端**有時給
    /// 識別字、有時給自由文字**：識別字要翻，自由文字要原樣留著，把它一律翻成
    /// 「訓練中」等於把後端的話蓋掉。
    static func localizationKey(forStageId stageId: String) -> String? {
        switch stageId.lowercased() {
        case "base":       return L10n.Training.Stage.base
        case "build":      return L10n.Training.Stage.build
        case "peak":       return L10n.Training.Stage.peak
        case "taper":      return L10n.Training.Stage.taper
        case "conversion": return L10n.Training.Stage.conversion
        default:           return nil
        }
    }

    static func phaseInfo(from stages: [TrainingStageV2], targetWeek: Int) -> PhaseInfo? {
        guard let stage = stages.first(where: { $0.contains(week: targetWeek) }) else { return nil }
        return PhaseInfo(
            localizedKey: stageIdToLocalizationKey(stage.stageId),
            phaseWeek: targetWeek - stage.weekStart + 1,
            phaseTotalWeeks: stage.durationWeeks
        )
    }
}
