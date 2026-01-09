import Foundation

/// Domain-level constants for workout-related business rules
enum WorkoutConstants {
    /// Maximum character limit for training notes
    /// Backend constraint: training_notes field limited to 1000 characters
    static let maxTrainingNotesLength = 1000
}
