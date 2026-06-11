import Foundation

struct StrengthExerciseStatusDTO: Encodable, Equatable {
    let exerciseId: String?
    let seriesId: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case seriesId = "series_id"
        case status
    }
}

struct StrengthCompletionRequestDTO: Encodable, Equatable {
    let dayDate: String
    let strengthType: String
    let exercises: [StrengthExerciseStatusDTO]
    let overallRpe: Int
    let durationMinutes: Int?
    let weeklyPlanId: String?

    enum CodingKeys: String, CodingKey {
        case dayDate = "day_date"
        case strengthType = "strength_type"
        case exercises
        case overallRpe = "overall_rpe"
        case durationMinutes = "duration_minutes"
        case weeklyPlanId = "weekly_plan_id"
    }
}

struct ProgressUpdateDTO: Codable, Equatable {
    let seriesId: String
    let previousLevel: Int
    let newLevel: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case previousLevel = "previous_level"
        case newLevel = "new_level"
        case reason
    }
}

struct StrengthCompletionResponseDTO: Codable, Equatable {
    let progressUpdates: [ProgressUpdateDTO]

    enum CodingKeys: String, CodingKey {
        case progressUpdates = "progress_updates"
    }
}
