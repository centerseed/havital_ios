import Foundation

// MARK: - UpdateUserProfileUseCase
/// Use case for updating user profile data
struct UpdateUserProfileUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Input
    struct Input {
        let updates: [String: Any]

        init(updates: [String: Any]) {
            self.updates = updates
        }

        // Convenience initializers for common updates
        static func weeklyDistance(_ distance: Int) -> Input {
            Input(updates: ["current_week_distance": distance])
        }

        static func dataSource(_ source: String) -> Input {
            Input(updates: ["data_source": source])
        }

        static func heartRate(maxHR: Int, restingHR: Int) -> Input {
            Input(updates: [
                "max_heart_rate": maxHR,
                "resting_heart_rate": restingHR
            ])
        }
    }

    // MARK: - Output
    struct Output {
        let updatedProfile: User
    }

    // MARK: - Execute
    func execute(input: Input) async throws -> Output {
        Logger.debug("[UpdateUserProfileUseCase] Updating with \(input.updates.count) fields")

        guard !input.updates.isEmpty else {
            throw UserProfileError.invalidUpdateData(field: "empty updates")
        }

        do {
            let updatedProfile = try await repository.updateUserProfile(input.updates)

            Logger.debug("[UpdateUserProfileUseCase] Success")
            return Output(updatedProfile: updatedProfile)

        } catch {
            Logger.error("[UpdateUserProfileUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
