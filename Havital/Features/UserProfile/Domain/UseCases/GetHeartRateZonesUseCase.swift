import Foundation

// MARK: - GetHeartRateZonesUseCase
/// Use case for fetching calculated heart rate zones
/// Domain Layer - Coordinates repository calls for heart rate zone data
struct GetHeartRateZonesUseCase {

    // MARK: - Dependencies
    private let repository: UserProfileRepository

    // MARK: - Initialization
    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    // MARK: - Output
    struct Output {
        let zones: [HeartRateZone]
        let maxHR: Int
        let restingHR: Int
    }

    // MARK: - Execute
    func execute() async throws -> Output {
        Logger.debug("[GetHeartRateZonesUseCase] Fetching heart rate zones")

        do {
            // Get zones from repository (calculates based on user's HR data)
            let zones = try await repository.getHeartRateZones()

            // Also get the user profile to return the HR values
            let profile = try await repository.getUserProfile()

            guard let maxHR = profile.maxHr, let restingHR = profile.relaxingHr else {
                throw UserProfileError.invalidHeartRate(message: "Missing heart rate data in profile")
            }

            Logger.debug("[GetHeartRateZonesUseCase] Success: \(zones.count) zones")
            return Output(zones: zones, maxHR: maxHR, restingHR: restingHR)

        } catch {
            Logger.error("[GetHeartRateZonesUseCase] Failed: \(error.localizedDescription)")
            throw error
        }
    }
}
