import XCTest
@testable import paceriz_dev
final class WeeklySummaryV2EntityTests: XCTestCase {
    func test_weekly_story_entity_constructs() {
        let s = WeeklyStory(text: "kept rhythm 4 weeks", thread: "consistency", callback: nil)
        XCTAssertEqual(s.thread, "consistency")
    }
}
