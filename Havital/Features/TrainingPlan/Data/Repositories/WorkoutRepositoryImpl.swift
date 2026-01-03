import Foundation

// MARK: - Workout Repository Implementation
/// 訓練記錄 Repository 實作
/// Data Layer - 封裝 UnifiedWorkoutManager 的存取
final class WorkoutRepositoryImpl: WorkoutRepository {

    // MARK: - Singleton (for backwards compatibility)

    static let shared = WorkoutRepositoryImpl()

    // MARK: - Properties

    private let workoutManager: UnifiedWorkoutManager

    // MARK: - Initialization

    init(workoutManager: UnifiedWorkoutManager = .shared) {
        self.workoutManager = workoutManager
    }

    // MARK: - WorkoutRepository Protocol

    var workoutsDidUpdateNotification: Notification.Name {
        return .workoutsDidUpdate
    }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        return workoutManager.getWorkoutsInDateRange(startDate: startDate, endDate: endDate)
    }

    func getAllWorkouts() -> [WorkoutV2] {
        return workoutManager.workouts
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {

    /// 註冊 WorkoutRepository 模組
    func registerWorkoutModule() {
        // 檢查是否已註冊
        guard !isRegistered(WorkoutRepository.self) else {
            return
        }

        // 註冊 Repository
        let repository = WorkoutRepositoryImpl.shared
        register(repository as WorkoutRepository, forProtocol: WorkoutRepository.self)

        Logger.debug("[DI] WorkoutModule registered")
    }
}
