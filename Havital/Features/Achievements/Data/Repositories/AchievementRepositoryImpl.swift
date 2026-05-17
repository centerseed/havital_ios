import Foundation

final class AchievementRepositoryImpl: AchievementRepository {
    private let dataSource: AchievementRemoteDataSource
    private(set) var cachedSummary: AchievementSummary?

    init(dataSource: AchievementRemoteDataSource) {
        self.dataSource = dataSource
    }

    func fetchSummary(forceRefresh: Bool = false) async throws -> AchievementSummary {
        if !forceRefresh, let cachedSummary {
            return cachedSummary
        }

        do {
            let dto = try await dataSource.fetchSummary()
            let summary = AchievementMapper.toDomain(dto)
            cachedSummary = summary
            return summary
        } catch {
            Logger.error("[AchievementRepository] fetchSummary failed: \(error.localizedDescription)")
            throw AchievementError.fetchFailed(error.localizedDescription)
        }
    }

    func markFeedbackSeen(feedbackId: String) async throws {
        do {
            try await dataSource.markFeedbackSeen(feedbackId: feedbackId)
        } catch {
            Logger.error("[AchievementRepository] markFeedbackSeen failed: \(error.localizedDescription)")
            throw AchievementError.markFeedbackSeenFailed(error.localizedDescription)
        }
    }

    func ackBackfill() async throws {
        do {
            try await dataSource.ackBackfill()
            if let current = cachedSummary {
                cachedSummary = AchievementSummary(
                    generatedAt: current.generatedAt,
                    catalogVersion: current.catalogVersion,
                    backfill: AchievementBackfill(
                        status: current.backfill.status,
                        showBanner: false,
                        bannerKey: current.backfill.bannerKey,
                        historicalUnlockCount: current.backfill.historicalUnlockCount,
                        acknowledgedAt: current.generatedAt
                    ),
                    storySummary: current.storySummary,
                    badgeGroups: current.badgeGroups,
                    pbOverview: current.pbOverview,
                    lifetimeStats: current.lifetimeStats,
                    insights: current.insights,
                    recentShareables: current.recentShareables,
                    unlockFeedbackQueue: current.unlockFeedbackQueue,
                    privacyPolicy: current.privacyPolicy
                )
            }
        } catch {
            Logger.error("[AchievementRepository] ackBackfill failed: \(error.localizedDescription)")
            throw AchievementError.ackBackfillFailed(error.localizedDescription)
        }
    }
}

extension DependencyContainer {
    func registerAchievementModule() {
        let dataSource = AchievementRemoteDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        let repo = AchievementRepositoryImpl(dataSource: dataSource)
        register(repo as AchievementRepository, forProtocol: AchievementRepository.self)
        Logger.debug("[DI] Achievement module registered")
    }
}
