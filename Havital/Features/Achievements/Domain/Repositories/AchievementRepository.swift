import Foundation

protocol AchievementRepository {
    var cachedSummary: AchievementSummary? { get }

    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary
    func markFeedbackSeen(feedbackId: String) async throws
    func ackBackfill() async throws
}
