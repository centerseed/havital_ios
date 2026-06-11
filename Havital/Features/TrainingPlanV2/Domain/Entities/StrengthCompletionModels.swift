import Foundation

enum StrengthExerciseStatus: String, Equatable {
    case completed
    case skipped
}

struct StrengthExerciseInput: Equatable {
    let exerciseId: String?
    let seriesId: String?
    let status: StrengthExerciseStatus
}

enum StrengthProgressReason: Equatable {
    case upgrade
    case downgrade
    case unknown
}

struct StrengthProgressUpdate: Equatable {
    let seriesId: String
    let previousLevel: Int
    let newLevel: Int
    let reason: StrengthProgressReason
}

struct StrengthCompletionResult: Equatable {
    let progressUpdates: [StrengthProgressUpdate]
}
