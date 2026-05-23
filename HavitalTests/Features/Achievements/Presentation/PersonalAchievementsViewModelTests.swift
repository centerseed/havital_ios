import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class PersonalAchievementsViewModelTests: XCTestCase {
    func testLoadSuccessPublishesLoadedState() async throws {
        let repository = MockAchievementRepository(summary: .fixture(unlockedCount: 2))
        let analytics = MockAchievementAnalyticsService()
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: analytics)

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.summary?.storySummary.unlockedCount, 2)
    }

    func testLoadEmptyPublishesEmptyState() async throws {
        let repository = MockAchievementRepository(summary: .emptyFixture())
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state, .empty)
    }

    func testLoadLegacyBadgeGroupsWithoutAchievementTracksPublishesEmptyState() async throws {
        let repository = MockAchievementRepository(summary: .legacyOnlyFixture())
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state, .empty)
    }

    func testLoadErrorPublishesErrorState() async throws {
        let repository = MockAchievementRepository(error: AchievementError.fetchFailed("boom"))
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state, .error("boom"))
    }

    func testBackfillAckHidesBannerAndPreservesAchievementTracks() async throws {
        let repository = MockAchievementRepository(summary: .fixture(unlockedCount: 2, showBackfill: true, includeTracks: true))
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(sut.showBackfillBanner)
        XCTAssertEqual(sut.summary?.achievementTracks.count, 1)

        sut.acknowledgeBackfill()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(repository.didAckBackfill)
        XCTAssertFalse(sut.showBackfillBanner)
        XCTAssertEqual(sut.summary?.achievementTracks.count, 1)
        XCTAssertEqual(sut.summary?.achievementTracks.first?.trackId, "plan")
    }

    func testBadgeAndShareAnalyticsUseLowSensitivityPayload() {
        let summary = AchievementSummary.fixture(unlockedCount: 1)
        let repository = MockAchievementRepository(summary: summary)
        let analytics = MockAchievementAnalyticsService()
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: analytics)
        let badge = summary.badgeGroups[0].badges[0]
        let shareable = summary.recentShareables[0]

        sut.trackTabOpenIfNeeded()
        sut.openBadge(badge)
        sut.selectShareable(shareable)
        sut.completeShare()
        sut.closeShare()

        XCTAssertEqual(analytics.trackedEvents.map(\.name), [
            "achievement_tab_open",
            "achievement_badge_open",
            "achievement_share_tap",
            "achievement_share_complete",
            "achievement_share_close"
        ])
        analytics.trackedEvents.forEach { event in
            XCTAssertFalse(AchievementAnalyticsPayloadGuard.containsSensitiveKey(event.parameters))
        }
    }
}

private final class MockAchievementRepository: AchievementRepository {
    private let summaryResult: Result<AchievementSummary, Error>
    private(set) var didAckBackfill = false
    private(set) var cachedSummary: AchievementSummary?

    private let pinnedSubject = CurrentValueSubject<String?, Never>(nil)
    var pinnedBadgeIdDidChange: AnyPublisher<String?, Never> { pinnedSubject.eraseToAnyPublisher() }

    init(summary: AchievementSummary) {
        self.summaryResult = .success(summary)
        self.cachedSummary = summary
    }

    init(error: Error) {
        self.summaryResult = .failure(error)
    }

    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary {
        try summaryResult.get()
    }

    func markFeedbackSeen(feedbackId: String) async throws {}

    func ackBackfill() async throws {
        didAckBackfill = true
    }

    func getPinnedBadgeId() -> String? { nil }
    func setPinnedBadgeId(_ badgeId: String?) { pinnedSubject.send(badgeId) }
    func getDisplayBadge() -> AchievementBadge? { cachedSummary?.badgeGroups.flatMap { $0.badges }.first }
    func getInProgressBadges() -> [AchievementBadge] { [] }
    func findBadge(byId badgeId: String) -> AchievementBadge? {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.first { $0.badgeId == badgeId }
    }
}

private final class MockAchievementAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_ value: String, forName name: String) {}
}

private extension AchievementSummary {
    static func emptyFixture() -> AchievementSummary {
        AchievementSummary(
            generatedAt: "2026-05-13T08:00:00Z",
            catalogVersion: "v1",
            backfill: AchievementBackfill(status: .notNeeded, showBanner: false, bannerKey: nil, historicalUnlockCount: 0, acknowledgedAt: nil),
            storySummary: AchievementStorySummary(unlockedCount: 0, totalCount: 0, recentUnlock: nil, nextBadge: nil, emptyStateKey: "achievements.empty.start"),
            badgeGroups: [],
            pbOverview: nil,
            lifetimeStats: .empty,
            insights: [],
            recentShareables: [],
            unlockFeedbackQueue: [],
            privacyPolicy: AchievementPrivacyPolicy(defaultExcludedFields: [], sensitiveFields: [], publicOnly: true)
        )
    }

    static func legacyOnlyFixture() -> AchievementSummary {
        let legacyBadge = AchievementBadge(
            badgeId: "BADGE-LEGACY-START",
            chapter: .start,
            nameKey: "badge.legacy.name",
            storyKey: "badge.legacy.story",
            status: .unlocked,
            progress: nil,
            unlockedAt: "2026-05-12",
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: nil
        )
        return AchievementSummary(
            generatedAt: "2026-05-13T08:00:00Z",
            catalogVersion: "legacy",
            backfill: AchievementBackfill(status: .notNeeded, showBanner: false, bannerKey: nil, historicalUnlockCount: 0, acknowledgedAt: nil),
            storySummary: AchievementStorySummary(unlockedCount: 1, totalCount: 1, recentUnlock: nil, nextBadge: nil, emptyStateKey: nil),
            badgeGroups: [AchievementBadgeGroup(chapter: .start, titleKey: "achievements.chapter.start", badges: [legacyBadge])],
            achievementTracks: [],
            pbOverview: nil,
            lifetimeStats: .empty,
            insights: [],
            recentShareables: [],
            unlockFeedbackQueue: [],
            privacyPolicy: AchievementPrivacyPolicy(defaultExcludedFields: [], sensitiveFields: [], publicOnly: true)
        )
    }

    static func fixture(unlockedCount: Int, showBackfill: Bool = false, includeTracks: Bool = false) -> AchievementSummary {
        let badge = AchievementBadge(
            badgeId: "BADGE-START-FIRST-RUN",
            chapter: .start,
            nameKey: "badge.start.first_run.name",
            storyKey: "badge.start.first_run.story",
            status: .unlocked,
            progress: nil,
            unlockedAt: "2026-05-12",
            unlockReasonKey: "badge.start.first_run.reason",
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: nil
        )
        let shareable = AchievementShareable(
            materialId: "mat_1",
            materialType: .badge,
            titleKey: "badge.start.first_run.name",
            summaryKey: "achievements.share.summary.badge",
            summaryParams: [:],
            publicFields: [
                AchievementPublicField(key: "chapter", labelKey: "achievements.field.chapter", value: "Start")
            ],
            defaultSensitiveFieldsEnabled: false,
            badgeId: badge.badgeId,
            chapter: badge.chapter
        )
        let tracks = includeTracks
            ? [
                AchievementTrack(
                    trackId: "plan",
                    titleKey: "achievements.track.plan.title",
                    storyKey: "achievements.track.plan.story",
                    metricKey: "qualified_plan_weeks",
                    current: 1,
                    nextBadge: nil,
                    badges: [badge]
                )
            ]
            : []
        return AchievementSummary(
            generatedAt: "2026-05-13T08:00:00Z",
            catalogVersion: "v1",
            backfill: AchievementBackfill(status: .completed, showBanner: showBackfill, bannerKey: "achievements.backfill.ready", historicalUnlockCount: 2, acknowledgedAt: nil),
            storySummary: AchievementStorySummary(
                unlockedCount: unlockedCount,
                totalCount: 30,
                recentUnlock: AchievementBadgeSnapshot(
                    badgeId: badge.badgeId,
                    chapter: badge.chapter,
                    nameKey: badge.nameKey,
                    storyKey: badge.storyKey,
                    status: badge.status
                ),
                nextBadge: nil,
                emptyStateKey: nil
            ),
            badgeGroups: [AchievementBadgeGroup(chapter: .start, titleKey: "achievements.chapter.start", badges: [badge])],
            achievementTracks: tracks,
            pbOverview: AchievementPBOverview(titleKey: "achievements.pb.title", updatedAt: nil, records: [
                AchievementPBRecord(distance: "5k", displayDistance: "5K", time: "24:10", achievedAt: "2026-05-12", isRecent: true)
            ]),
            lifetimeStats: AchievementLifetimeStats(
                totalRuns: 8,
                totalDistanceKm: 52.7,
                completedWeeks: 8,
                trainingWeeks: 8,
                longestRunKm: 12.5,
                firstWorkoutDate: "2026-04-12"
            ),
            insights: [
                AchievementInsight(
                    insightId: "insight_1",
                    type: "completed_weeks",
                    displayKey: "achievements.insight.completed_weeks",
                    displayParams: ["weeks": .int(12)],
                    evidence: ["source_count": .int(12)],
                    confidence: .high,
                    shareable: false
                )
            ],
            recentShareables: [shareable],
            unlockFeedbackQueue: [],
            privacyPolicy: AchievementPrivacyPolicy(defaultExcludedFields: ["route"], sensitiveFields: ["heart_rate"], publicOnly: true)
        )
    }
}
