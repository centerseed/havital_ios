import XCTest
import Combine
@testable import paceriz_dev

final class AchievementRepositoryPinTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PinnedBadgeStorage.clear()
    }

    override func tearDown() {
        PinnedBadgeStorage.clear()
        super.tearDown()
    }

    func test_setPinnedBadgeId_persistsAndEmitsChange() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())

        var observed: [String?] = []
        let cancellable = sut.pinnedBadgeIdDidChange.sink { observed.append($0) }
        defer { cancellable.cancel() }

        sut.setPinnedBadgeId("BADGE-X")

        XCTAssertEqual(sut.getPinnedBadgeId(), "BADGE-X")
        XCTAssertEqual(observed.count, 2, "Should receive initial nil emission + the new BADGE-X")
        XCTAssertTrue(observed.first == .some(nil), "CurrentValueSubject should emit current value (nil) on subscribe")
        XCTAssertEqual(observed.last, "BADGE-X")
    }

    func test_getDisplayBadge_returnsNil_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertNil(sut.getDisplayBadge())
    }

    func test_setPinnedBadgeId_nil_clearsPin() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        sut.setPinnedBadgeId("BADGE-X")
        sut.setPinnedBadgeId(nil)

        XCTAssertNil(sut.getPinnedBadgeId())
    }

    func test_getInProgressBadges_returnsEmpty_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertTrue(sut.getInProgressBadges().isEmpty)
    }

    func test_findBadge_returnsNil_whenNoCachedSummary() {
        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        XCTAssertNil(sut.findBadge(byId: "BADGE-X"))
    }

    func test_getDisplayBadge_ignoresLegacyBadgeGroupsWhenAchievementTracksAreMissing() async throws {
        let httpClient = MockHTTPClient()
        httpClient.setResponse(for: "/v2/achievements/summary", data: Data(Self.legacyOnlySummaryJSON.utf8))
        let dataSource = AchievementRemoteDataSource(httpClient: httpClient, parser: MockAPIParser())
        let sut = AchievementRepositoryImpl(dataSource: dataSource)

        _ = try await sut.fetchSummary(forceRefresh: true)

        XCTAssertNil(sut.getDisplayBadge())
    }

    func test_getDisplayBadge_usesAchievementTracks() async throws {
        let httpClient = MockHTTPClient()
        httpClient.setResponse(for: "/v2/achievements/summary", data: Data(Self.trackSummaryJSON.utf8))
        let dataSource = AchievementRemoteDataSource(httpClient: httpClient, parser: MockAPIParser())
        let sut = AchievementRepositoryImpl(dataSource: dataSource)

        _ = try await sut.fetchSummary(forceRefresh: true)

        XCTAssertEqual(sut.getDisplayBadge()?.badgeId, "BADGE-PLAN-01")
    }

    func test_ackBackfill_preservesCachedAchievementTracks() async throws {
        let httpClient = MockHTTPClient()
        httpClient.setResponse(for: "/v2/achievements/summary", data: Data(Self.trackSummaryJSON.utf8))
        httpClient.setResponse(for: "/v2/achievements/backfill/ack", method: .POST, data: Data())
        let dataSource = AchievementRemoteDataSource(httpClient: httpClient, parser: MockAPIParser())
        let sut = AchievementRepositoryImpl(dataSource: dataSource)

        _ = try await sut.fetchSummary(forceRefresh: true)
        try await sut.ackBackfill()

        XCTAssertEqual(sut.getDisplayBadge()?.badgeId, "BADGE-PLAN-01")
    }

    func test_pinnedBadgeIdDidChange_emitsInitialValue() {
        // Seed a pinned badge before creating the repo
        PinnedBadgeStorage.save("SEED-BADGE")

        let sut = AchievementRepositoryImpl(dataSource: AchievementRemoteDataSource())
        var observed: [String?] = []
        let cancellable = sut.pinnedBadgeIdDidChange.sink { observed.append($0) }
        defer { cancellable.cancel() }

        // CurrentValueSubject emits immediately on subscribe
        XCTAssertEqual(observed.first, "SEED-BADGE")
    }

    private static let legacyOnlySummaryJSON = """
    {
      "generated_at": "2026-05-20T00:00:00Z",
      "catalog_version": "achievement_catalog_v20260520",
      "backfill": {
        "status": "completed",
        "show_banner": false,
        "banner_key": null,
        "historical_unlock_count": 0,
        "acknowledged_at": null
      },
      "story_summary": {
        "unlocked_count": 1,
        "total_count": 1,
        "recent_unlock": null,
        "next_badge": null,
        "empty_state_key": null
      },
      "badge_groups": [
        {
          "chapter": "start",
          "title_key": "achievements.chapter.start",
          "badges": [
            {
              "badge_id": "BADGE-LEGACY-START",
              "chapter": "start",
              "name_key": "badge.legacy.name",
              "story_key": "badge.legacy.story",
              "status": "unlocked",
              "progress": null,
              "unlocked_at": null,
              "unlock_reason_key": null,
              "source_ref": null,
              "historical_backfill": false,
              "shareable": true,
              "asset_name": null
            }
          ]
        }
      ],
      "pb_overview": null,
      "lifetime_stats": null,
      "insights": [],
      "recent_shareables": [],
      "unlock_feedback_queue": [],
      "privacy_policy": {
        "default_sensitive_fields_enabled": false,
        "excluded_fields": []
      }
    }
    """

    private static let trackSummaryJSON = """
    {
      "generated_at": "2026-05-20T00:00:00Z",
      "catalog_version": "achievement_catalog_v20260520",
      "backfill": {
        "status": "completed",
        "show_banner": false,
        "banner_key": null,
        "historical_unlock_count": 0,
        "acknowledged_at": null
      },
      "story_summary": {
        "unlocked_count": 1,
        "total_count": 1,
        "recent_unlock": null,
        "next_badge": null,
        "empty_state_key": null
      },
      "badge_groups": [],
      "achievement_tracks": [
        {
          "track_id": "plan",
          "title_key": "achievements.track.plan.title",
          "story_key": "achievements.track.plan.story",
          "metric_key": "qualified_plan_weeks",
          "current": 1,
          "next_badge": null,
          "badges": [
            {
              "badge_id": "BADGE-PLAN-01",
              "chapter": "build",
              "name_key": "badge.plan.01.name",
              "story_key": "badge.plan.01.story",
              "status": "unlocked",
              "progress": null,
              "unlocked_at": null,
              "unlock_reason_key": null,
              "source_ref": null,
              "historical_backfill": false,
              "shareable": true,
              "asset_name": null
            }
          ]
        }
      ],
      "pb_overview": null,
      "lifetime_stats": null,
      "insights": [],
      "recent_shareables": [],
      "unlock_feedback_queue": [],
      "privacy_policy": {
        "default_sensitive_fields_enabled": false,
        "excluded_fields": []
      }
    }
    """
}
