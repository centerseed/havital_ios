import XCTest
@testable import paceriz_dev

final class AchievementDTOTests: XCTestCase {
    func testSummaryDecodesSnakeCaseNullableAndUnknownEnums() throws {
        let data = Data(Self.summaryJSON.utf8)

        let dto = try JSONDecoder().decode(AchievementSummaryResponse.self, from: data)
        let summary = AchievementMapper.toDomain(dto)

        XCTAssertEqual(summary.generatedAt, "2026-05-13T08:00:00Z")
        XCTAssertEqual(summary.catalogVersion, "achievement_catalog_v20260512")
        XCTAssertEqual(summary.backfill.status, .completed)
        XCTAssertEqual(summary.storySummary.recentUnlock?.badgeId, "BADGE-START-FIRST-RUN")
        XCTAssertNil(summary.badgeGroups[0].badges[0].unlockedAt)
        XCTAssertEqual(summary.badgeGroups[0].badges[0].status, .unknown)
        XCTAssertEqual(summary.pbOverview?.records[0].displayDistance, "5K")
        XCTAssertEqual(summary.pbOverview?.records[0].time, "23:20")
        XCTAssertEqual(summary.lifetimeStats.totalRuns, 8)
        XCTAssertEqual(summary.lifetimeStats.totalDistanceKm, 52.7)
        XCTAssertEqual(summary.lifetimeStats.completedWeeks, 8)
        XCTAssertEqual(summary.lifetimeStats.trainingWeeks, 8)
        XCTAssertEqual(summary.lifetimeStats.longestRunKm, 12.5)
        XCTAssertEqual(summary.lifetimeStats.firstWorkoutDate, "2026-04-12")
        XCTAssertEqual(summary.recentShareables[0].publicFields[0].key, "chapter")
        XCTAssertEqual(summary.privacyPolicy.defaultExcludedFields, ["route", "gps", "heart_rate", "sleep"])
        XCTAssertEqual(summary.unlockFeedbackQueue.count, 1)
    }

    func testDegradedSummaryDecodesAndMapsToEmptyContent() throws {
        let data = Data(Self.degradedSummaryJSON.utf8)

        let dto = try JSONDecoder().decode(AchievementSummaryResponse.self, from: data)
        let summary = AchievementMapper.toDomain(dto)

        XCTAssertEqual(summary.catalogVersion, "degraded")
        XCTAssertEqual(summary.backfill.status, .notNeeded)
        XCTAssertFalse(summary.backfill.showBanner)
        XCTAssertEqual(summary.storySummary.totalCount, 0)
        XCTAssertTrue(summary.badgeGroups.isEmpty)
        XCTAssertNil(summary.pbOverview)
        XCTAssertEqual(summary.lifetimeStats, .empty)
        XCTAssertTrue(summary.insights.isEmpty)
        XCTAssertTrue(summary.recentShareables.isEmpty)
        XCTAssertTrue(summary.unlockFeedbackQueue.isEmpty)
        XCTAssertTrue(summary.privacyPolicy.defaultExcludedFields.contains("gps"))
        // AchievementPrivacyPolicyDTO derives publicOnly = !defaultSensitiveFieldsEnabled when
        // public_only is absent. Degraded fixture has defaultSensitiveFieldsEnabled=false → publicOnly=true.
        XCTAssertTrue(summary.privacyPolicy.publicOnly)
        XCTAssertFalse(summary.hasVisibleContent)
    }

    func testSummaryDecodesAchievementTracksAndMapsToDomain() throws {
        let data = Data(Self.summaryWithAchievementTracksJSON.utf8)

        let dto = try JSONDecoder().decode(AchievementSummaryResponse.self, from: data)
        let summary = AchievementMapper.toDomain(dto)

        XCTAssertEqual(dto.achievementTracks.count, 3)
        XCTAssertEqual(summary.achievementTracks.count, 3)
        XCTAssertEqual(summary.achievementTracks[0].trackId, "distance")
        XCTAssertEqual(summary.achievementTracks[0].titleKey, "achievements.track.distance.title")
        XCTAssertEqual(summary.achievementTracks[0].storyKey, "achievements.track.distance.story")
        XCTAssertEqual(summary.achievementTracks[0].metricKey, "achievements.metric.distance")
        XCTAssertEqual(summary.achievementTracks[0].current, 52.7)
        XCTAssertEqual(summary.achievementTracks[0].nextBadge?.badgeId, "BADGE-DISTANCE-100K")
        XCTAssertEqual(summary.achievementTracks[0].badges.count, 2)
        XCTAssertEqual(summary.achievementTracks[1].trackId, "consistency")
        XCTAssertNil(summary.achievementTracks[1].metricKey)
        XCTAssertNil(summary.achievementTracks[1].current)
        XCTAssertNil(summary.achievementTracks[1].nextBadge)
        XCTAssertEqual(summary.achievementTracks[2].trackId, "pb")
    }

    func testSummaryDefaultsAchievementTracksToEmptyWhenAbsent() throws {
        let data = Data(Self.degradedSummaryJSON.utf8)

        let dto = try JSONDecoder().decode(AchievementSummaryResponse.self, from: data)
        let summary = AchievementMapper.toDomain(dto)

        XCTAssertTrue(dto.achievementTracks.isEmpty)
        XCTAssertTrue(summary.achievementTracks.isEmpty)
    }

    func testRemoteDataSourceUsesAchievementsEndpoints() async throws {
        let httpClient = MockHTTPClient()
        let parser = MockAPIParser()
        let sut = AchievementRemoteDataSource(httpClient: httpClient, parser: parser)

        httpClient.setResponse(for: "/v2/achievements/summary", data: Data(Self.summaryJSON.utf8))
        httpClient.setResponse(for: "/v2/achievements/feedback/fb_1/seen", method: .POST, data: Data())
        httpClient.setResponse(for: "/v2/achievements/backfill/ack", method: .POST, data: Data())

        _ = try await sut.fetchSummary()
        try await sut.markFeedbackSeen(feedbackId: "fb_1")
        try await sut.ackBackfill()

        XCTAssertTrue(httpClient.wasPathCalled("/v2/achievements/summary", method: .GET))
        XCTAssertTrue(httpClient.wasPathCalled("/v2/achievements/feedback/fb_1/seen", method: .POST))
        XCTAssertTrue(httpClient.wasPathCalled("/v2/achievements/backfill/ack", method: .POST))
    }

    private static let summaryJSON = """
    {
      "generated_at": "2026-05-13T08:00:00Z",
      "catalog_version": "achievement_catalog_v20260512",
      "backfill": {
        "status": "completed",
        "show_banner": true,
        "banner_key": "achievements.backfill.ready",
        "historical_unlock_count": 3,
        "acknowledged_at": null
      },
      "story_summary": {
        "unlocked_count": 2,
        "total_count": 30,
        "recent_unlock": {
          "badge_id": "BADGE-START-FIRST-RUN",
          "chapter": "start",
          "name_key": "badge.start.first_run.name",
          "story_key": "badge.start.first_run.story",
          "status": "unlocked"
        },
        "next_badge": null,
        "empty_state_key": null
      },
      "badge_groups": [
        {
          "chapter": "start",
          "title_key": "achievements.chapter.start",
          "badges": [
            {
              "badge_id": "BADGE-START-FIRST-RUN",
              "chapter": "future_chapter",
              "name_key": "badge.start.first_run.name",
              "story_key": "badge.start.first_run.story",
              "status": "server_added_status",
              "progress": {
                "current": 1,
                "target": 2,
                "unit_key": null,
                "summary_key": "achievement.progress.current_target",
                "summary_params": { "current": 1, "target": 2 }
              },
              "unlocked_at": null,
              "unlock_reason_key": null,
              "source_ref": {
                "type": "workout",
                "label_key": "achievement.source.workout",
                "summary_key": "achievements.share.summary.badge",
                "summary_params": {}
              },
              "historical_backfill": false,
              "shareable": false,
              "asset_name": null
            }
          ]
        }
      ],
      "pb_overview": {
        "records": [
          {
            "distance_key": "5",
            "complete_time": 1400,
            "pace": "4:40",
            "workout_date": "2026-05-12"
          }
        ]
      },
      "lifetime_stats": {
        "total_runs": 8,
        "total_distance_km": 52.7,
        "completed_weeks": 8,
        "training_weeks": 8,
        "longest_run_km": 12.5,
        "first_workout_date": "2026-04-12"
      },
      "insights": [
        {
          "insight_id": "insight_1",
          "type": "completed_weeks",
          "display_key": "achievements.insight.completed_weeks",
          "display_params": { "weeks": 12 },
          "evidence": { "source_count": 12 },
          "confidence": "high",
          "shareable": false
        }
      ],
      "recent_shareables": [
        {
          "material_id": "mat_1",
          "material_type": "badge",
          "title_key": "badge.start.first_run.name",
          "summary_key": "achievements.share.summary.badge",
          "summary_params": {},
          "source_ref": {
            "type": "workout",
            "label_key": "achievement.source.workout",
            "summary_key": "achievements.share.summary.badge",
            "summary_params": {}
          },
          "public_fields": [
            { "key": "chapter", "label_key": "achievements.field.chapter", "value": "Start" }
          ],
          "default_sensitive_fields_enabled": false,
          "badge_id": "BADGE-START-FIRST-RUN",
          "chapter": "start"
        }
      ],
      "unlock_feedback_queue": [
        {
          "feedback_id": "unlock_summary:2:BADGE-START-FIRST-RUN",
          "type": "summary",
          "count": 2,
          "items": []
        },
        {
          "feedback_id": "fb_1",
          "badge_id": "BADGE-START-FIRST-RUN",
          "chapter": "start",
          "name_key": "badge.start.first_run.name",
          "story_key": "badge.start.first_run.story"
        }
      ],
      "privacy_policy": {
        "default_sensitive_fields_enabled": false,
        "excluded_fields": ["route", "gps", "heart_rate", "sleep"]
      }
    }
    """

    private static let degradedSummaryJSON = """
    {
      "generated_at": "2026-05-17T03:00:00Z",
      "catalog_version": "degraded",
      "backfill": {
        "status": "not_needed",
        "show_banner": false,
        "banner_key": null,
        "historical_unlock_count": 0,
        "acknowledged_at": null
      },
      "story_summary": {
        "unlocked_count": 0,
        "total_count": 0,
        "recent_unlock": null,
        "next_badge": null,
        "empty_state_key": "achievements.empty.degraded"
      },
      "badge_groups": [],
      "pb_overview": null,
      "lifetime_stats": {
        "total_runs": 0,
        "total_distance_km": 0,
        "completed_weeks": 0,
        "training_weeks": 0,
        "longest_run_km": 0,
        "first_workout_date": null
      },
      "insights": [],
      "recent_shareables": [],
      "unlock_feedback_queue": [],
      "privacy_policy": {
        "default_sensitive_fields_enabled": false,
        "excluded_fields": [
          "route",
          "gps",
          "location",
          "coordinates",
          "heart_rate",
          "sleep",
          "injury",
          "full_plan_details",
          "pii"
        ]
      },
      "cache": {
        "status": "degraded",
        "reason": "summary_unavailable"
      }
    }
    """

    private static let summaryWithAchievementTracksJSON = """
    {
      "generated_at": "2026-05-13T08:00:00Z",
      "catalog_version": "achievement_catalog_v20260512",
      "backfill": {
        "status": "completed",
        "show_banner": false,
        "banner_key": null,
        "historical_unlock_count": 0,
        "acknowledged_at": null
      },
      "story_summary": {
        "unlocked_count": 1,
        "total_count": 3,
        "recent_unlock": null,
        "next_badge": null,
        "empty_state_key": null
      },
      "badge_groups": [],
      "achievement_tracks": [
        {
          "track_id": "distance",
          "title_key": "achievements.track.distance.title",
          "story_key": "achievements.track.distance.story",
          "metric_key": "achievements.metric.distance",
          "current": 52.7,
          "next_badge": {
            "badge_id": "BADGE-DISTANCE-100K",
            "chapter": "build",
            "name_key": "badge.distance.100k.name",
            "story_key": "badge.distance.100k.story",
            "status": "in_progress",
            "progress": {
              "current": 52.7,
              "target": 100,
              "unit_key": "km",
              "summary_key": "achievement.progress.current_target",
              "summary_params": { "current": 52.7, "target": 100 }
            },
            "unlocked_at": null,
            "unlock_reason_key": null,
            "source_ref": null,
            "historical_backfill": false,
            "shareable": false,
            "asset_name": null
          },
          "badges": [
            {
              "badge_id": "BADGE-DISTANCE-50K",
              "chapter": "build",
              "name_key": "badge.distance.50k.name",
              "story_key": "badge.distance.50k.story",
              "status": "unlocked",
              "progress": null,
              "unlocked_at": "2026-05-10",
              "unlock_reason_key": null,
              "source_ref": null,
              "historical_backfill": false,
              "shareable": true,
              "asset_name": null
            },
            {
              "badge_id": "BADGE-DISTANCE-100K",
              "chapter": "build",
              "name_key": "badge.distance.100k.name",
              "story_key": "badge.distance.100k.story",
              "status": "in_progress",
              "progress": null,
              "unlocked_at": null,
              "unlock_reason_key": null,
              "source_ref": null,
              "historical_backfill": false,
              "shareable": false,
              "asset_name": null
            }
          ]
        },
        {
          "track_id": "consistency",
          "title_key": "achievements.track.consistency.title",
          "story_key": "achievements.track.consistency.story",
          "metric_key": null,
          "current": null,
          "next_badge": null,
          "badges": []
        },
        {
          "track_id": "pb",
          "title_key": "achievements.track.pb.title",
          "story_key": "achievements.track.pb.story",
          "metric_key": "achievements.metric.pb",
          "current": 1,
          "next_badge": null,
          "badges": []
        }
      ],
      "pb_overview": null,
      "lifetime_stats": null,
      "insights": [],
      "recent_shareables": [],
      "unlock_feedback_queue": [],
      "privacy_policy": {
        "default_sensitive_fields_enabled": false,
        "excluded_fields": ["route"]
      }
    }
    """
}
