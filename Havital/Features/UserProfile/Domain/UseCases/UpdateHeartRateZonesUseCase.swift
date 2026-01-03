import Foundation

// MARK: - UpdateHeartRateZonesUseCase
/// Use case for updating heart rate parameters and recalculating zones
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

        init(maxHR: Int, restingHR: Int) {
            self.maxHR = maxHR
            self.restingHR = restingHR
        }
    }

    // MARK: - Output
    struct Output {
        let zones: [HeartRateZonesManager.HeartRateZone]
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
            let zones = try await repository.updateHeartRateZones(maxHR: input.maxHR, restingHR: input.restingHR)

            Logger.debug("[UpdateHeartRateZonesUseCase] Success: \(zones.count) zones calculated")
            return Output(zones: zones)

        } catch {
            Logger.error("[UpdateHeartRateZonesUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
