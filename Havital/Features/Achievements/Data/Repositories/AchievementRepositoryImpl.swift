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
                    achievementTracks: current.achievementTracks,
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
        let resolved = selectDisplayBadge.execute(
            pinnedBadgeId: pinnedBadgeSubject.value,
            allBadges: allBadges
        )

        if !allBadges.isEmpty {
            // Cache 已載入 = 權威來源：把快照同步成真值（或清除），供下次冷啟動即時渲染。
            DisplayBadgeStorage.save(resolved)
            return resolved
        }

        // Cache 尚未載入（冷啟動 summary 還沒回來）：用上次持久化的快照即時、穩定渲染，避免閃暫代值。
        return DisplayBadgeStorage.load() ?? resolved
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
        if !summary.achievementTracks.isEmpty {
            return summary.achievementTracks.flatMap(\.badges)
        }
        return []
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
