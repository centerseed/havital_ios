import Foundation
import Combine

final class AchievementRepositoryImpl: AchievementRepository {
    private let dataSource: AchievementRemoteDataSource
    private(set) var cachedSummary: AchievementSummary?

    private let pinnedBadgeSubject: CurrentValueSubject<String?, Never>
    private let selectDisplayBadge = SelectDisplayBadgeUseCase()

    var pinnedBadgeIdDidChange: AnyPublisher<String?, Never> {
        pinnedBadgeSubject.eraseToAnyPublisher()
    }

    init(dataSource: AchievementRemoteDataSource) {
        self.dataSource = dataSource
        self.pinnedBadgeSubject = CurrentValueSubject(PinnedBadgeStorage.load())
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

    func getPinnedBadgeId() -> String? {
        pinnedBadgeSubject.value
    }

    func setPinnedBadgeId(_ badgeId: String?) {
        PinnedBadgeStorage.save(badgeId)
        pinnedBadgeSubject.send(badgeId)
    }

    func getDisplayBadge() -> AchievementBadge? {
        let allBadges = allBadgesFromCache()
        return selectDisplayBadge.execute(
            pinnedBadgeId: pinnedBadgeSubject.value,
            allBadges: allBadges
        )
    }

    func getInProgressBadges() -> [AchievementBadge] {
        allBadgesFromCache().filter { $0.status == .inProgress }
    }

    func getUnlockedBadges() -> [AchievementBadge] {
        allBadgesFromCache()
            .filter { $0.status == .unlocked }
            .sorted { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") }
    }

    func findBadge(byId badgeId: String) -> AchievementBadge? {
        allBadgesFromCache().first { $0.badgeId == badgeId }
    }

    // MARK: - Private

    private func allBadgesFromCache() -> [AchievementBadge] {
        guard let summary = cachedSummary else { return [] }
        return summary.badgeGroups.flatMap { $0.badges }
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
