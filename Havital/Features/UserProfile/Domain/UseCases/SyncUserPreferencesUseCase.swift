import Foundation

// MARK: - SyncUserPreferencesUseCase
/// Use case for syncing user data to local preferences
/// Merges User model data with local preferences storage
struct SyncUserPreferencesUseCase {

    // MARK: - Dependencies
    private let preferencesRepository: UserPreferencesRepository

    // MARK: - Initialization
    init(preferencesRepository: UserPreferencesRepository) {
        self.preferencesRepository = preferencesRepository
    }

    // MARK: - Input
    struct Input {
        let user: User

        init(user: User) {
            self.user = user
        }
    }

    // MARK: - Execute
    func execute(input: Input) async {
        Logger.debug("[SyncUserPreferencesUseCase] Syncing preferences from user data")

        // Sync heart rate data
        preferencesRepository.syncHeartRateData(from: input.user)

        // Sync data source if present
        if let dataSourceString = input.user.dataSource,
           let dataSource = DataSourceType(rawValue: dataSourceString) {
            await preferencesRepository.updateDataSource(dataSource)
            Logger.debug("[SyncUserPreferencesUseCase] Data source synced: \(dataSource.displayName)")
        }

        Logger.debug("[SyncUserPreferencesUseCase] Sync complete")
    }
}
