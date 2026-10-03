import Foundation

// MARK: - UpdateHeartRateZonesUseCase
/// Use case for updating heart rate parameters and recalculating zones
/// Domain Layer - Validates input and coordinates repository update
struct UpdateHeartRateZonesUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Input
    struct Input {
        let maxHR: Int
        let restingHR: Int
        let updates: [String: Any]?

        init(maxHR: Int, restingHR: Int, updates: [String: Any]? = nil) {
            self.maxHR = maxHR
            self.restingHR = restingHR
            self.updates = updates
        }
    }

    // MARK: - Output
    struct Output {
        let zones: [HeartRateZone]
        /// 後端回報這次心率真的有變（決定要不要問重算，`SPEC-hr-zones` §5.5 規則 1）。
        let heartRateChanged: Bool
        let profile: User
    }

    // MARK: - Execute
    func execute(input: Input) async throws -> Output {
        Logger.debug("[UpdateHeartRateZonesUseCase] Updating HR zones (max: \(input.maxHR), resting: \(input.restingHR))")

        // Validate input
        guard input.maxHR > input.restingHR else {
            throw UserProfileError.invalidHeartRate(message: "Maximum heart rate must be greater than resting heart rate")
        }

        guard input.maxHR > 0 && input.restingHR > 0 else {
            throw UserProfileError.invalidHeartRate(message: "Heart rate values must be positive")
        }

        guard input.maxHR <= 250 && input.restingHR >= 30 else {
            throw UserProfileError.invalidHeartRate(message: "Heart rate values out of valid range")
        }

        do {
            let result: HeartRateUpdateResult
            if let updates = input.updates {
                result = try await repository.updateHeartRateZones(maxHR: input.maxHR, restingHR: input.restingHR, updates: updates)
            } else {
                result = try await repository.updateHeartRateZones(maxHR: input.maxHR, restingHR: input.restingHR)
            }

            Logger.debug("[UpdateHeartRateZonesUseCase] Success: \(result.zones.count) zones calculated")
            return Output(zones: result.zones, heartRateChanged: result.changed, profile: result.profile)

        } catch {
            Logger.error("[UpdateHeartRateZonesUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
