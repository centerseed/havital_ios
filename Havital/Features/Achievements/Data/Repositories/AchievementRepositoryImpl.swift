import Foundation

// MARK: - AchievementRepositoryImpl
/// Stub implementation of AchievementRepository.
///
/// NOTE: The backend badge endpoint does not yet exist (Phase B investigation finding).
/// This implementation returns nil for all calls until the backend is ready.
/// Phase C will replace this with a real network fetch.
final class AchievementRepositoryImpl: AchievementRepository {

    static let shared = AchievementRepositoryImpl()

    private init() {}

    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary? {
        // Backend badge endpoint not yet available — return nil (safe fallback).
        // WeekOverviewCardV2 will show PRPlaceholderBadge when nil.
        return nil
    }
}
