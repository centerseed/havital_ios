import Foundation

enum AchievementMapper {
    static func toDomain(_ dto: AchievementSummaryResponse) -> AchievementSummary {
        AchievementSummary(
            generatedAt: dto.generatedAt,
            catalogVersion: dto.catalogVersion,
            backfill: toDomain(dto.backfill),
            storySummary: toDomain(dto.storySummary),
            badgeGroups: dto.badgeGroups.map(toDomain),
            achievementTracks: dto.achievementTracks.map(toDomain),
            pbOverview: dto.pbOverview.map(toDomain),
            lifetimeStats: dto.lifetimeStats.map(toDomain) ?? .empty,
            insights: dto.insights.map(toDomain),
            recentShareables: dto.recentShareables.map(toDomain),
            unlockFeedbackQueue: dto.unlockFeedbackQueue.compactMap(toDomain),
            privacyPolicy: toDomain(dto.privacyPolicy)
        )
    }

    private static func toDomain(_ dto: AchievementLifetimeStatsDTO) -> AchievementLifetimeStats {
        AchievementLifetimeStats(
            totalRuns: dto.totalRuns,
            totalDistanceKm: dto.totalDistanceKm,
            completedWeeks: dto.completedWeeks,
            trainingWeeks: dto.trainingWeeks,
            longestRunKm: dto.longestRunKm,
            firstWorkoutDate: dto.firstWorkoutDate
        )
    }

    private static func toDomain(_ dto: AchievementBackfillDTO) -> AchievementBackfill {
        AchievementBackfill(
            status: AchievementBackfillStatus(rawValue: dto.status),
            showBanner: dto.showBanner,
            bannerKey: dto.bannerKey,
            historicalUnlockCount: dto.historicalUnlockCount,
            acknowledgedAt: dto.acknowledgedAt
        )
    }

    private static func toDomain(_ dto: AchievementStorySummaryDTO) -> AchievementStorySummary {
        AchievementStorySummary(
            unlockedCount: dto.unlockedCount,
            totalCount: dto.totalCount,
            recentUnlock: dto.recentUnlock.map(toDomain),
            nextBadge: dto.nextBadge.map(toDomain),
            emptyStateKey: dto.emptyStateKey
        )
    }

    private static func toDomain(_ dto: AchievementBadgeSnapshotDTO) -> AchievementBadgeSnapshot {
        AchievementBadgeSnapshot(
            badgeId: dto.badgeId,
            chapter: AchievementChapter(rawValue: dto.chapter),
            nameKey: dto.nameKey,
            storyKey: dto.storyKey,
            status: dto.status.map(AchievementBadgeStatus.init(rawValue:))
        )
    }

    private static func toDomain(_ dto: AchievementBadgeGroupDTO) -> AchievementBadgeGroup {
        AchievementBadgeGroup(
            chapter: AchievementChapter(rawValue: dto.chapter),
            titleKey: dto.titleKey,
            badges: dto.badges.map(toDomain)
        )
    }

    private static func toDomain(_ dto: AchievementTrackDTO) -> AchievementTrack {
        AchievementTrack(
            trackId: dto.trackId,
            titleKey: dto.titleKey,
            storyKey: dto.storyKey,
            metricKey: dto.metricKey,
            current: dto.current,
            nextBadge: dto.nextBadge.map(toDomain),
            badges: dto.badges.map(toDomain)
        )
    }

    private static func toDomain(_ dto: AchievementBadgeDTO) -> AchievementBadge {
        AchievementBadge(
            badgeId: dto.badgeId,
            chapter: AchievementChapter(rawValue: dto.chapter),
            nameKey: dto.nameKey,
            storyKey: dto.storyKey,
            status: AchievementBadgeStatus(rawValue: dto.status),
            progress: dto.progress.map(toDomain),
            unlockedAt: dto.unlockedAt,
            unlockReasonKey: dto.unlockReasonKey,
            sourceRef: dto.sourceRef.map(toDomain),
            historicalBackfill: dto.historicalBackfill,
            shareable: dto.shareable,
            assetName: dto.assetName
        )
    }

    private static func toDomain(_ dto: AchievementProgressDTO) -> AchievementProgress {
        AchievementProgress(
            current: dto.current,
            target: dto.target,
            unitKey: dto.unitKey,
            summaryKey: dto.summaryKey,
            summaryParams: dto.summaryParams
        )
    }

    private static func toDomain(_ dto: AchievementSourceRefDTO) -> AchievementSourceRef {
        AchievementSourceRef(
            type: dto.type,
            labelKey: dto.labelKey,
            summaryKey: dto.summaryKey,
            summaryParams: dto.summaryParams
        )
    }

    private static func toDomain(_ dto: AchievementPBOverviewDTO) -> AchievementPBOverview {
        AchievementPBOverview(
            titleKey: dto.titleKey,
            updatedAt: dto.updatedAt,
            records: dto.records.map {
                AchievementPBRecord(
                    distance: $0.distance,
                    displayDistance: $0.displayDistance,
                    time: $0.time,
                    achievedAt: $0.achievedAt,
                    isRecent: $0.isRecent
                )
            }
        )
    }

    private static func toDomain(_ dto: AchievementInsightDTO) -> AchievementInsight {
        AchievementInsight(
            insightId: dto.insightId,
            type: dto.type,
            displayKey: dto.displayKey,
            displayParams: dto.displayParams,
            evidence: dto.evidence,
            confidence: AchievementInsightConfidence(rawValue: dto.confidence),
            shareable: dto.shareable
        )
    }

    private static func toDomain(_ dto: AchievementShareableDTO) -> AchievementShareable {
        AchievementShareable(
            materialId: dto.materialId,
            materialType: AchievementShareableType(rawValue: dto.materialType),
            titleKey: dto.titleKey,
            summaryKey: dto.summaryKey,
            summaryParams: dto.summaryParams,
            publicFields: dto.publicFields.map(toDomain),
            defaultSensitiveFieldsEnabled: dto.defaultSensitiveFieldsEnabled,
            badgeId: dto.badgeId,
            chapter: dto.chapter.map(AchievementChapter.init(rawValue:))
        )
    }

    private static func toDomain(_ dto: AchievementPublicFieldDTO) -> AchievementPublicField {
        AchievementPublicField(key: dto.key, labelKey: dto.labelKey, value: dto.value)
    }

    private static func toDomain(_ dto: AchievementUnlockFeedbackDTO) -> AchievementUnlockFeedback? {
        guard let badgeId = dto.badgeId,
              let chapter = dto.chapter,
              let nameKey = dto.nameKey else {
            return nil
        }
        return AchievementUnlockFeedback(
            feedbackId: dto.feedbackId,
            badgeId: badgeId,
            chapter: AchievementChapter(rawValue: chapter),
            nameKey: nameKey,
            storyKey: dto.storyKey ?? nameKey
        )
    }

    private static func toDomain(_ dto: AchievementPrivacyPolicyDTO) -> AchievementPrivacyPolicy {
        AchievementPrivacyPolicy(
            defaultExcludedFields: dto.defaultExcludedFields,
            sensitiveFields: dto.sensitiveFields,
            publicOnly: dto.publicOnly
        )
    }
}
