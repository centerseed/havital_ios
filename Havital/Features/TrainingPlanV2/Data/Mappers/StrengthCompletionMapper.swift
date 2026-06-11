import Foundation

enum StrengthCompletionMapper {

    static func toRequestDTO(
        dayDate: String,
        strengthType: String,
        inputs: [StrengthExerciseInput],
        overallRpe: Int,
        durationMinutes: Int?,
        weeklyPlanId: String?
    ) -> StrengthCompletionRequestDTO {
        StrengthCompletionRequestDTO(
            dayDate: dayDate,
            strengthType: strengthType,
            exercises: inputs.map {
                StrengthExerciseStatusDTO(
                    exerciseId: $0.exerciseId,
                    seriesId: $0.seriesId,
                    status: $0.status.rawValue
                )
            },
            overallRpe: overallRpe,
            durationMinutes: durationMinutes,
            weeklyPlanId: weeklyPlanId
        )
    }

    static func toEntity(from dto: StrengthCompletionResponseDTO) -> StrengthCompletionResult {
        StrengthCompletionResult(
            progressUpdates: dto.progressUpdates.map { u in
                StrengthProgressUpdate(
                    seriesId: u.seriesId,
                    previousLevel: u.previousLevel,
                    newLevel: u.newLevel,
                    reason: reason(from: u.reason)
                )
            }
        )
    }

    private static func reason(from raw: String) -> StrengthProgressReason {
        switch raw {
        case "rpe_upgrade": return .upgrade
        case "rpe_downgrade": return .downgrade
        default: return .unknown
        }
    }
}
