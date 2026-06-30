import XCTest
@testable import paceriz_dev

final class CalendarTrainingColorTests: XCTestCase {
    func test_runTypes_mapToExpectedBuckets() {
        XCTAssertEqual(calendarBucket(for: "easy"), .green)
        XCTAssertEqual(calendarBucket(for: "easy_run"), .green)
        XCTAssertEqual(calendarBucket(for: "recovery_run"), .green)
        XCTAssertEqual(calendarBucket(for: "interval"), .orange)
        XCTAssertEqual(calendarBucket(for: "tempo"), .orange)
        XCTAssertEqual(calendarBucket(for: "fartlek"), .orange)
        XCTAssertEqual(calendarBucket(for: "long_run"), .blue)
        XCTAssertEqual(calendarBucket(for: "lsd"), .blue)
        XCTAssertEqual(calendarBucket(for: "race_pace"), .red)
        XCTAssertEqual(calendarBucket(for: "strength"), .indigo)
        XCTAssertEqual(calendarBucket(for: "swimming"), .indigo)
        XCTAssertEqual(calendarBucket(for: "cycling"), .blue)
    }
    func test_caseInsensitiveAndWhitespace() {
        XCTAssertEqual(calendarBucket(for: " Interval "), .orange)
        XCTAssertEqual(calendarBucket(for: "LONG_RUN"), .blue)
    }
    func test_unknownAndEmpty_fallBackToGreen_perD5() {
        XCTAssertEqual(calendarBucket(for: ""), .green)
        XCTAssertEqual(calendarBucket(for: "run"), .green)
        XCTAssertEqual(calendarBucket(for: "running"), .green)
        XCTAssertEqual(calendarBucket(for: "totally_unknown"), .green)
    }

    func test_intervalFamily_getsDistinctIcon_butThresholdTempoDoNot() {
        // 間歇家族 → 碼錶 icon
        XCTAssertTrue(isCalendarIntervalType("interval"))
        XCTAssertTrue(isCalendarIntervalType("short_interval"))
        XCTAssertTrue(isCalendarIntervalType("long_interval"))
        XCTAssertTrue(isCalendarIntervalType("hill_repeats"))
        XCTAssertTrue(isCalendarIntervalType("yasso800"))
        XCTAssertTrue(isCalendarIntervalType(" Interval "))
        // 閾值 / 節奏跑同為橘色但 NOT 間歇 → 維持跑者 icon（靠 icon 形狀區分）
        XCTAssertFalse(isCalendarIntervalType("threshold"))
        XCTAssertFalse(isCalendarIntervalType("tempo"))
        XCTAssertFalse(isCalendarIntervalType("easy"))
        XCTAssertFalse(isCalendarIntervalType("long_run"))
    }
}
