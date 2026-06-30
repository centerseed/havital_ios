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
}
