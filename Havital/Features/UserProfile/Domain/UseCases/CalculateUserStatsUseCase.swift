import Foundation

// MARK: - CalculateUserStatsUseCase
/// Use case for calculating user statistics from profile and targets
struct CalculateUserStatsUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Output
    struct Output {
        let statistics: UserStatistics
    }

    // MARK: - Execute
    func execute() async -> Output? {
        Logger.debug("[CalculateUserStatsUseCase] Calculating user statistics")

        guard let statistics = await repository.calculateStatistics() else {
            Logger.debug("[CalculateUserStatsUseCase] No statistics available")
            return nil
        }

        Logger.debug("[CalculateUserStatsUseCase] Success: stats calculated")
        return Output(statistics: statistics)
    }
}
