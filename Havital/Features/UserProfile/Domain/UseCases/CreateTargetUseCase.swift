import Foundation

// MARK: - CreateTargetUseCase
/// Use case for creating a new race target
struct CreateTargetUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Input
    struct Input {
        let target: Target

        init(target: Target) {
            self.target = target
        }
    }

    // MARK: - Execute
    func execute(input: Input) async throws {
        Logger.debug("[CreateTargetUseCase] Creating target: \(input.target.name)")

        do {
            try await repository.createTarget(input.target)
            Logger.debug("[CreateTargetUseCase] Success")

        } catch {
            Logger.error("[CreateTargetUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
