import XCTest
@testable import paceriz_dev

final class NoPlanConversionContentTests: XCTestCase {
    func test_completedWeeks_isCurrentWeekMinusOne() {
        let c = NoPlanConversionContent(currentWeek: 6, totalWeeks: 16, raceName: "北海道", daysToRace: 80, upcomingWeeks: [])
        XCTAssertEqual(c.completedWeeks, 5)
        XCTAssertEqual(c.totalWeeks, 16)
    }
    func test_completedWeeks_neverNegative() {
        let c = NoPlanConversionContent(currentWeek: 1, totalWeeks: 16, raceName: nil, daysToRace: nil, upcomingWeeks: [])
        XCTAssertEqual(c.completedWeeks, 0)
    }
    func test_showsRaceCountdown_onlyWhenRaceDataPresent() {
        let withRace = NoPlanConversionContent(currentWeek: 3, totalWeeks: 16, raceName: "北海道", daysToRace: 40, upcomingWeeks: [])
        XCTAssertTrue(withRace.showsRaceCountdown)
        let noRace = NoPlanConversionContent(currentWeek: 3, totalWeeks: 16, raceName: nil, daysToRace: nil, upcomingWeeks: [])
        XCTAssertFalse(noRace.showsRaceCountdown)
    }
    func test_nextWeekPreview_isFirstUpcoming() {
        let w6 = WeekPreview(week: 6, stageId: "build", targetKm: 48, targetKmDisplay: nil, distanceUnit: nil, isRecovery: false, milestoneRef: nil, intensityRatio: nil, qualityOptions: [], longRun: nil)
        let w7 = WeekPreview(week: 7, stageId: "build", targetKm: 52, targetKmDisplay: nil, distanceUnit: nil, isRecovery: false, milestoneRef: nil, intensityRatio: nil, qualityOptions: [], longRun: nil)
        let c = NoPlanConversionContent(currentWeek: 6, totalWeeks: 16, raceName: nil, daysToRace: nil, upcomingWeeks: [w6, w7])
        XCTAssertEqual(c.nextWeekPreview?.week, 6)
        XCTAssertEqual(c.nextWeekPreview?.targetKm, 48)
    }
    func test_nextWeekPreview_nilWhenEmpty() {
        let c = NoPlanConversionContent(currentWeek: 6, totalWeeks: 16, raceName: nil, daysToRace: nil, upcomingWeeks: [])
        XCTAssertNil(c.nextWeekPreview)
    }
}
