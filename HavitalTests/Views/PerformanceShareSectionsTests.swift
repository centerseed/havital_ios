import XCTest
@testable import paceriz_dev

final class PerformanceShareSectionsTests: XCTestCase {

    func test_defaultPerformanceShareSections_matchesOnScreenSectionOrder_withoutDuplicateTrainingLoad() {
        XCTAssertEqual(
            defaultPerformanceShareSections(),
            [
                .trainingReadiness,
                .trainingLoad,
                .weeklyVolume,
                .combinedHeartRate,
            ]
        )
    }
}
