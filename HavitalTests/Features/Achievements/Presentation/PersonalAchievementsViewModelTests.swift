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

    func testLoadErrorPublishesErrorState() async throws {
        let repository = MockAchievementRepository(error: AchievementError.fetchFailed("boom"))
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.state, .error("boom"))
    }

    func testCancelledRequestThroughRealRepositoryDoesNotEnterErrorState() async throws {
        let httpClient = MockHTTPClient()
        httpClient.setError(for: "/v2/achievements/summary", error: HTTPError.cancelled)
        let repository = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource(httpClient: httpClient))
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load(forceRefresh: true)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(httpClient.callCount(for: "/v2/achievements/summary"), 1)
        if case .error = sut.state {
            XCTFail("取消的載入不得讓成就頁進入錯誤狀態，實際 state=\(sut.state)")
        }
    }

    func testRepositoryRethrowsCancellationUnwrapped() async {
        let httpClient = MockHTTPClient()
        httpClient.setError(for: "/v2/achievements/summary", error: HTTPError.cancelled)
        let repository = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource(httpClient: httpClient))

        do {
            _ = try await repository.fetchSummary(forceRefresh: true)
            XCTFail("expected cancellation")
        } catch {
            XCTAssertTrue(error.isCancellationError, "取消必須原樣往上拋，實際 \(error)")
        }
    }

    // MARK: - AC-PACH-06B：背景收到事件不重抓、回前景才重驗

    func testWorkoutEventInBackgroundDefersFetchUntilActive() async throws {
        await CacheEventBus.shared.resetForTesting()
        let repository = MockAchievementRepository(summary: .fixture(unlockedCount: 2))
        let appState = AppActiveStub(isActive: true)
        let sut = PersonalAchievementsViewModel(
            repository: repository,
            analyticsService: MockAchievementAnalyticsService(),
            isAppActive: { appState.isActive }
        )
        await sut.loadIfNeeded()
        XCTAssertEqual(repository.fetchCount, 1)

        appState.isActive = false
        CacheEventBus.shared.publish(.dataChanged(.workouts))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(repository.fetchCount, 1, "背景收到訓練事件不得發請求")

        // 回前景：距上次載入不到 60 秒，仍要重驗一次。
        appState.isActive = true
        await sut.loadIfNeeded()
        XCTAssertEqual(repository.fetchCount, 2, "回前景必須無視 60 秒門檻重驗")

        // 標記用過就清掉：再進一次不重抓。
        await sut.loadIfNeeded()
        XCTAssertEqual(repository.fetchCount, 2)
    }

    func testWorkoutEventInForegroundFetchesImmediately() async throws {
        await CacheEventBus.shared.resetForTesting()
        let repository = MockAchievementRepository(summary: .fixture(unlockedCount: 2))
        let sut = PersonalAchievementsViewModel(
            repository: repository,
            analyticsService: MockAchievementAnalyticsService(),
            isAppActive: { true }
        )
        await sut.loadIfNeeded()
        XCTAssertEqual(repository.fetchCount, 1)

        CacheEventBus.shared.publish(.dataChanged(.workouts))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(repository.fetchCount, 2, "前景收到訓練事件照舊立刻重抓")
        withExtendedLifetime(sut) {}
    }

    // MARK: - AC-PACH-06C：瞬時網路錯誤記 warn

    func testTimeoutThroughRealRepositoryIsReportedAsWarning() async throws {
        let httpClient = MockHTTPClient()
        httpClient.setError(for: "/v2/achievements/summary", error: URLError(.timedOut))
        let repository = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource(httpClient: httpClient))

        do {
            _ = try await repository.fetchSummary(forceRefresh: true)
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(PersonalAchievementsViewModel.errorReportLevel(for: error), .warn)
        }
        XCTAssertEqual(
            PersonalAchievementsViewModel.errorReportLevel(for: AchievementError.fetchFailed("decode")),
            .error
        )
    }

    // MARK: - AC-PACH-06D：2.0 首載失敗顯示錯誤與重試

    func testFirstLoadFailureWithoutSummaryShowsRetry() async throws {
        let repository = MockAchievementRepository(error: AchievementError.fetchFailed("boom"))
        let sut = PersonalAchievementsViewModel(
            repository: repository,
            analyticsService: MockAchievementAnalyticsService(),
            isAppActive: { true }
        )
        XCTAssertEqual(App2AchievementsView.placeholder(summary: sut.summary, state: sut.state), .loading)

        await sut.loadIfNeeded()

        XCTAssertNil(sut.summary)
        XCTAssertEqual(App2AchievementsView.placeholder(summary: sut.summary, state: sut.state), .loadFailed)

        await sut.forceRefresh()
        XCTAssertEqual(repository.fetchCount, 2, "重試走既有 forceRefresh，再抓一次")
    }

    func testBackfillAckHidesBanner() async throws {
        let repository = MockAchievementRepository(summary: .fixture(unlockedCount: 2, showBackfill: true))
        let sut = PersonalAchievementsViewModel(repository: repository, analyticsService: MockAchievementAnalyticsService())

        sut.load()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(sut.showBackfillBanner)

        sut.acknowledgeBackfill()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(repository.didAckBackfill)
        XCTAssertFalse(sut.showBackfillBanner)
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
    private(set) var fetchCount = 0
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
        fetchCount += 1
        return try summaryResult.get()
    }

    func markFeedbackSeen(feedbackId: String) async throws {}

    func ackBackfill() async throws {
        didAckBackfill = true
    }

    func getPinnedBadgeId() -> String? { nil }
    func setPinnedBadgeId(_ badgeId: String?) { pinnedSubject.send(badgeId) }
    func getDisplayBadge() -> AchievementBadge? { cachedSummary?.badgeGroups.flatMap { $0.badges }.first }
    func getInProgressBadges() -> [AchievementBadge] { [] }
    func getUnlockedBadges() -> [AchievementBadge] {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.filter { $0.status == .unlocked } ?? []
    }
    func findBadge(byId badgeId: String) -> AchievementBadge? {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.first { $0.badgeId == badgeId }
    }
}

private final class AppActiveStub {
    var isActive: Bool
    init(isActive: Bool) { self.isActive = isActive }
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

    static func fixture(unlockedCount: Int, showBackfill: Bool = false) -> AchievementSummary {
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
