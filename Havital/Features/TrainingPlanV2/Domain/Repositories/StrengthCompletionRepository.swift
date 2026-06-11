import Foundation

/// 力量訓練完成回報（窄協定，便於 ViewModel 依賴與測試）。
/// 由 TrainingPlanV2RepositoryImpl conform。
protocol StrengthCompletionRepository {
    func completeStrengthSession(
        dayDate: String,
        strengthType: String,
        inputs: [StrengthExerciseInput],
        overallRpe: Int,
        durationMinutes: Int?,
        weeklyPlanId: String?
    ) async throws -> StrengthCompletionResult
}
