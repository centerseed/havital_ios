import Foundation

// MARK: - GetUserProfileUseCase
/// Use case for fetching user profile
/// Supports cache-first strategy with optional force refresh
struct GetUserProfileUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Input
    struct Input {
        let forceRefresh: Bool

        init(forceRefresh: Bool = false) {
            self.forceRefresh = forceRefresh
        }
    }

    // MARK: - Output
    struct Output {
        let profile: User
        let fromCache: Bool
    }

    // MARK: - Execute
    func execute(input: Input = Input()) async throws -> Output {
        Logger.debug("[GetUserProfileUseCase] Fetching user profile (force: \(input.forceRefresh))")

        do {
            let profile: User
            let fromCache: Bool

            if input.forceRefresh {
                profile = try await repository.refreshUserProfile()
                fromCache = false
            } else {
                profile = try await repository.getUserProfile()
                fromCache = !repository.isCacheExpired()
            }

            Logger.debug("[GetUserProfileUseCase] Success: \(profile.displayName ?? "Unknown")")
            return Output(profile: profile, fromCache: fromCache)

        } catch {
            Logger.error("[GetUserProfileUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
