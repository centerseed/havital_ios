import XCTest
@testable import paceriz_dev

final class AchievementAnalyticsPrivacyTests: XCTestCase {
    func testAchievementAnalyticsEventsOnlyExposeAllowedLowSensitivityKeys() {
        let events: [AnalyticsEvent] = [
            .achievementTabOpen(entry: "main_tab"),
            .achievementBadgeOpen(
                entry: "badge_collection",
                badgeId: "BADGE-START-FIRST-RUN",
                chapter: "start",
                status: "unlocked"
            ),
            .achievementShareTap(
                entry: "share_center",
                materialType: "badge",
                badgeId: "BADGE-START-FIRST-RUN",
                chapter: "start"
            ),
            .achievementShareComplete(
                entry: "share_preview",
                materialType: "pb",
                badgeId: nil,
                chapter: nil
            ),
            .achievementShareClose(
                entry: "share_preview",
                materialType: "badge",
                badgeId: "BADGE-START-FIRST-RUN",
                chapter: "start"
            )
        ]

        for event in events {
            XCTAssertFalse(AchievementAnalyticsPayloadGuard.containsSensitiveKey(event.parameters))
            XCTAssertTrue(Set(event.parameters.keys).isSubset(of: AchievementAnalyticsPayloadGuard.allowedKeys))
        }
    }

    func testPrivacyGuardDropsSensitiveKeys() {
        let sanitized = AchievementAnalyticsPayloadGuard.sanitized([
            "entry": "share_center",
            "badge_id": "BADGE-START-FIRST-RUN",
            "workout_id": "workout-123",
            "heart_rate": 150,
            "email": "runner@example.com",
            "route": "secret"
        ])

        XCTAssertEqual(Set(sanitized.keys), ["entry", "badge_id"])
    }
}
