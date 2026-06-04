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
        switch stageId.lowercased() {
        case "base":       return L10n.Training.Stage.base
        case "build":      return L10n.Training.Stage.build
        case "peak":       return L10n.Training.Stage.peak
        case "taper":      return L10n.Training.Stage.taper
        case "conversion": return L10n.Training.Stage.conversion
        default:           return L10n.Training.Stage.unknown
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
