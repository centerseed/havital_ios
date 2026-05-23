#if DEBUG
import SwiftUI
import Foundation
import Combine

struct UITestAchievementsHostView: View {
    var body: some View {
        PersonalAchievementsView(
            viewModel: PersonalAchievementsViewModel(
                repository: UITestAchievementRepository(),
                analyticsService: UITestAchievementAnalyticsService()
            )
        )
    }
}

private final class UITestAchievementRepository: AchievementRepository {
    var cachedSummary: AchievementSummary?

    private let pinnedSubject = CurrentValueSubject<String?, Never>(nil)
    var pinnedBadgeIdDidChange: AnyPublisher<String?, Never> { pinnedSubject.eraseToAnyPublisher() }

    init() {
        cachedSummary = Self.summary
    }

    func fetchSummary(forceRefresh: Bool) async throws -> AchievementSummary {
        Self.summary
    }

    func markFeedbackSeen(feedbackId: String) async throws {}

    func ackBackfill() async throws {}

    func getPinnedBadgeId() -> String? { nil }

    func setPinnedBadgeId(_ badgeId: String?) { pinnedSubject.send(badgeId) }

    func getDisplayBadge() -> AchievementBadge? {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.first
    }

    func getInProgressBadges() -> [AchievementBadge] { [] }

    func getUnlockedBadges() -> [AchievementBadge] {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.filter { $0.status == .unlocked } ?? []
    }

    func findBadge(byId badgeId: String) -> AchievementBadge? {
        cachedSummary?.badgeGroups.flatMap { $0.badges }.first { $0.badgeId == badgeId }
    }

    private static let summary: AchievementSummary = {
        let badges = [
            AchievementBadge(
                badgeId: "BADGE-START-FIRST-RUN",
                chapter: .start,
                nameKey: "achievements.badge.start.first_run.name",
                storyKey: "achievements.badge.start.first_run.story",
                status: .unlocked,
                progress: nil,
                unlockedAt: "2026-04-12",
                unlockReasonKey: nil,
                sourceRef: nil,
                historicalBackfill: false,
                shareable: true,
                assetName: "achievement_badge_start_first_run_trail"
            ),
            AchievementBadge(
                badgeId: "BADGE-BUILD-LONG-RUN-DONE",
                chapter: .build,
                nameKey: "achievements.badge.build.long_run_done.name",
                storyKey: "achievements.badge.build.long_run_done.story",
                status: .unlocked,
                progress: nil,
                unlockedAt: "2026-04-20",
                unlockReasonKey: nil,
                sourceRef: nil,
                historicalBackfill: false,
                shareable: true,
                assetName: "achievement_badge_build_long_run_route_pin_alt"
            ),
            AchievementBadge(
                badgeId: "BADGE-PROVE-NEW-PB",
                chapter: .prove,
                nameKey: "achievements.badge.prove.new_pb.name",
                storyKey: "achievements.badge.prove.new_pb.story",
                status: .unlocked,
                progress: nil,
                unlockedAt: "2026-05-01",
                unlockReasonKey: nil,
                sourceRef: nil,
                historicalBackfill: false,
                shareable: true,
                assetName: "achievement_badge_prove_new_pb"
            )
        ]
        let rhythmNextBadge = AchievementBadge(
            badgeId: "BADGE-RHYTHM-02-RETURN-WEEK",
            chapter: .build,
            nameKey: "achievements.badge.rhythm.return_week.name",
            storyKey: "achievements.badge.rhythm.return_week.story",
            status: .inProgress,
            progress: AchievementProgress(
                current: 1,
                target: 2,
                unitKey: "achievements.progress.unit.week",
                summaryKey: nil,
                summaryParams: [:]
            ),
            unlockedAt: nil,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: "achievement_badge_rhythm_02_return_week"
        )
        let planNextBadge = AchievementBadge(
            badgeId: "BADGE-PLAN-01-FIRST-QUALIFIED-WEEK",
            chapter: .adapt,
            nameKey: "achievements.badge.plan.first_qualified_week.name",
            storyKey: "achievements.badge.plan.first_qualified_week.story",
            status: .inProgress,
            progress: AchievementProgress(
                current: 0,
                target: 1,
                unitKey: "achievements.progress.unit.week",
                summaryKey: nil,
                summaryParams: [:]
            ),
            unlockedAt: nil,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: "achievement_badge_plan_01_first_qualified_week"
        )
        let resultsNextBadge = AchievementBadge(
            badgeId: "BADGE-RESULTS-01-FIRST-MAJOR-RESULT",
            chapter: .prove,
            nameKey: "achievements.badge.results.first_major_result.name",
            storyKey: "achievements.badge.results.first_major_result.story",
            status: .inProgress,
            progress: AchievementProgress(
                current: 0,
                target: 1,
                unitKey: "achievements.progress.unit.count",
                summaryKey: nil,
                summaryParams: [:]
            ),
            unlockedAt: nil,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: true,
            assetName: "achievement_badge_results_01_first_major_result"
        )
        let tracks = [
            AchievementTrack(
                trackId: "rhythm",
                titleKey: "achievements.track.rhythm.title",
                storyKey: "achievements.track.rhythm.story",
                metricKey: "active_weeks",
                current: 1,
                nextBadge: rhythmNextBadge,
                badges: [rhythmNextBadge]
            ),
            AchievementTrack(
                trackId: "plan",
                titleKey: "achievements.track.plan.title",
                storyKey: "achievements.track.plan.story",
                metricKey: "qualified_plan_weeks",
                current: 0,
                nextBadge: planNextBadge,
                badges: [planNextBadge]
            ),
            AchievementTrack(
                trackId: "results",
                titleKey: "achievements.track.results.title",
                storyKey: "achievements.track.results.story",
                metricKey: "major_results",
                current: 0,
                nextBadge: resultsNextBadge,
                badges: [resultsNextBadge]
            )
        ]

        let shareables = [
            AchievementShareable(
                materialId: "badge:BADGE-START-FIRST-RUN",
                materialType: .badge,
                titleKey: badges[0].nameKey,
                summaryKey: "achievements.share.badge.summary",
                summaryParams: [:],
                publicFields: [
                    AchievementPublicField(
                        key: "chapter",
                        labelKey: "achievements.field.chapter",
                        value: "開始起跑"
                    ),
                    AchievementPublicField(
                        key: "date",
                        labelKey: "achievements.field.date",
                        value: "2026-04-12"
                    )
                ],
                defaultSensitiveFieldsEnabled: false,
                badgeId: badges[0].badgeId,
                chapter: badges[0].chapter
            )
        ]

        return AchievementSummary(
            generatedAt: "2026-05-14T00:00:00Z",
            catalogVersion: "achievement_catalog_v20260512",
            backfill: AchievementBackfill(status: .completed, showBanner: false, bannerKey: nil, historicalUnlockCount: 0, acknowledgedAt: nil),
            storySummary: AchievementStorySummary(
                unlockedCount: 3,
                totalCount: 34,
                recentUnlock: AchievementBadgeSnapshot(
                    badgeId: badges[2].badgeId,
                    chapter: badges[2].chapter,
                    nameKey: badges[2].nameKey,
                    storyKey: badges[2].storyKey,
                    status: badges[2].status
                ),
                nextBadge: nil,
                emptyStateKey: nil
            ),
            badgeGroups: [
                AchievementBadgeGroup(chapter: .start, titleKey: "achievements.chapter.start", badges: [badges[0]]),
                AchievementBadgeGroup(chapter: .build, titleKey: "achievements.chapter.build", badges: [badges[1]]),
                AchievementBadgeGroup(chapter: .prove, titleKey: "achievements.chapter.prove", badges: [badges[2]])
            ],
            achievementTracks: tracks,
            pbOverview: AchievementPBOverview(
                titleKey: "achievements.pb.title",
                updatedAt: "2026-05-01",
                records: [
                    AchievementPBRecord(distance: "5k", displayDistance: "5K", time: "23:20", achievedAt: "2026-05-01", isRecent: true),
                    AchievementPBRecord(distance: "10k", displayDistance: "10K", time: "49:40", achievedAt: "2026-04-28", isRecent: false)
                ]
            ),
            lifetimeStats: AchievementLifetimeStats(
                totalRuns: 8,
                totalDistanceKm: 52.7,
                completedWeeks: 8,
                trainingWeeks: 8,
                longestRunKm: 12.5,
                firstWorkoutDate: "2026-04-12"
            ),
            insights: [],
            recentShareables: shareables,
            unlockFeedbackQueue: [],
            privacyPolicy: AchievementPrivacyPolicy(defaultExcludedFields: [], sensitiveFields: [], publicOnly: true)
        )
    }()
}

private final class UITestAchievementAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
    func setUserProperty(_ value: String, forName name: String) {}
}
#endif
