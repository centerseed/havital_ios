import Foundation

// MARK: - Workout Errors
/// Workout 相關錯誤
enum WorkoutError: Error, Equatable {
    /// 訓練記錄不存在
    case workoutNotFound(id: String)

    /// 訓練數據格式錯誤
    case invalidWorkoutData(String)

    /// 同步失敗
    case syncFailed(String)

    /// 緩存過期
    case cacheExpired

    /// 網路錯誤
    case networkError(String)

    /// 解析錯誤
    case parsingError(String)
}

// MARK: - WorkoutError to DomainError
extension WorkoutError {
    func toDomainError() -> DomainError {
        switch self {
        case .workoutNotFound(let id):
            return .notFound("Workout not found: \(id)")
        case .invalidWorkoutData(let message):
            return .validationFailure("Invalid workout data: \(message)")
        case .syncFailed(let message):
            return .networkFailure("Sync failed: \(message)")
        case .cacheExpired:
            return .dataCorruption("Cache expired")
        case .networkError(let message):
            return .networkFailure(message)
        case .parsingError(let message):
            return .dataCorruption(message)
        }
    }
}
