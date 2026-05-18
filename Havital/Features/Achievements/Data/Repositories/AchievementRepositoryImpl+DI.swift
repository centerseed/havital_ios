import Foundation

// MARK: - DependencyContainer Extension for Achievements Module
extension DependencyContainer {
    /// Register the Achievements module.
    /// Phase B: stub implementation returns nil until backend badge endpoint is available.
    func registerAchievementsModule() {
        register(AchievementRepositoryImpl.shared as AchievementRepository, forProtocol: AchievementRepository.self)
        Logger.debug("[DI] Achievements module dependencies registered (stub)")
    }
}
