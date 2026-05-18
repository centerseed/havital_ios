import XCTest
import SwiftUI
@testable import paceriz_dev

final class CelebrationShareCardPrivacyTests: XCTestCase {

    func test_heartRateFieldsExcluded_fromPublicFields() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [
                CelebrationShareCardView.ShareField(key: "heart_rate_avg", labelKey: "x", value: "150"),
                CelebrationShareCardView.ShareField(key: "pace", labelKey: "y", value: "5:00"),
            ],
            date: "2026-05-17"
        )
        let exposed = card.exposableFields()
        XCTAssertFalse(exposed.contains { $0.key == "heart_rate_avg" })
        XCTAssertTrue(exposed.contains { $0.key == "pace" })
    }

    func test_routeAndGpsFieldsExcluded() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [
                CelebrationShareCardView.ShareField(key: "route_geojson", labelKey: "x", value: "..."),
                CelebrationShareCardView.ShareField(key: "gps_track", labelKey: "y", value: "..."),
                CelebrationShareCardView.ShareField(key: "location_start", labelKey: "z", value: "..."),
                CelebrationShareCardView.ShareField(key: "coord_array", labelKey: "w", value: "..."),
                CelebrationShareCardView.ShareField(key: "polyline_encoded", labelKey: "v", value: "..."),
            ],
            date: "2026-05-17"
        )
        XCTAssertTrue(card.exposableFields().isEmpty)
    }

    func test_paceSeriesAndLapFieldsExcluded() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [
                CelebrationShareCardView.ShareField(key: "pace_series", labelKey: "x", value: "..."),
                CelebrationShareCardView.ShareField(key: "split_1", labelKey: "y", value: "..."),
                CelebrationShareCardView.ShareField(key: "lap_5", labelKey: "z", value: "..."),
            ],
            date: "2026-05-17"
        )
        XCTAssertTrue(card.exposableFields().isEmpty)
    }

    func test_caseInsensitiveExclusion() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [
                CelebrationShareCardView.ShareField(key: "HEART_RATE_MAX", labelKey: "x", value: "190"),
                CelebrationShareCardView.ShareField(key: "ROUTE_GEOJSON", labelKey: "y", value: "..."),
            ],
            date: "2026-05-17"
        )
        XCTAssertTrue(card.exposableFields().isEmpty)
    }

    func test_emptyOptionalFields_exposeNone() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [],
            date: "2026-05-17"
        )
        XCTAssertTrue(card.exposableFields().isEmpty)
    }

    func test_allSafeFields_exposed() {
        let card = CelebrationShareCardView.ShareData(
            content: .pbOnly(makePB()),
            optionalFields: [
                CelebrationShareCardView.ShareField(key: "distance", labelKey: "x", value: "10K"),
                CelebrationShareCardView.ShareField(key: "pace", labelKey: "y", value: "5:00"),
                CelebrationShareCardView.ShareField(key: "duration", labelKey: "z", value: "50:00"),
            ],
            date: "2026-05-17"
        )
        XCTAssertEqual(card.exposableFields().count, 3)
    }

    // MARK: - Helpers

    private func makePB() -> PersonalBestUpdate {
        PersonalBestUpdate(
            distance: "10",
            oldTime: 2600,
            newTime: 2538,
            improvementSeconds: 62,
            workoutDate: "2026-05-17",
            workoutId: "w1",
            detectedAt: Date()
        )
    }
}
