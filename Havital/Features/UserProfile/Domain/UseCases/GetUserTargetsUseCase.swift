import Foundation

// MARK: - GetUserTargetsUseCase
/// Use case for fetching user's race targets
struct GetUserTargetsUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Output
    struct Output {
        let targets: [Target]
        let mainRace: Target?
    }

    // MARK: - Execute
    func execute() async throws -> Output {
        Logger.debug("[GetUserTargetsUseCase] Fetching user targets")

        do {
            let targets = try await repository.getTargets()

            // Find the main race target
            let mainRace = targets.first { $0.isMainRace }

            Logger.debug("[GetUserTargetsUseCase] Success: \(targets.count) targets")
            return Output(targets: targets, mainRace: mainRace)

        } catch {
            Logger.error("[GetUserTargetsUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
