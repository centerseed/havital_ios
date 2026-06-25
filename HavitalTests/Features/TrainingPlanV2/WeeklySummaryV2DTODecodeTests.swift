import XCTest
@testable import paceriz_dev

final class WeeklySummaryV2DTODecodeTests: XCTestCase {
    private func decode(_ json: String) throws -> WeeklySummaryV2DTO {
        try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
    }

    // minimal JSON 含非 optional 欄位的最小必要值：
    // trainingCompletion, trainingAnalysis, weeklyHighlights, nextWeekAdjustments 是 non-optional，
    // 各需填最少讓 decode 成功的欄位。
    private let minimal = """
    {
      "id": "x_1_summary",
      "week_of_training": 1,
      "training_completion": {
        "percentage": 0,
        "planned_km": 0,
        "completed_km": 0,
        "planned_sessions": 0,
        "completed_sessions": 0,
        "evaluation": ""
      },
      "training_analysis": {},
      "weekly_highlights": {
        "highlights": [],
        "achievements": [],
        "areas_for_improvement": []
      },
      "next_week_adjustments": {
        "items": [],
        "summary": "",
        "methodology_constraints_considered": false,
        "based_on_flags": []
      }
    }
    """

    func test_missing_weekly_story_is_nil() throws {
        XCTAssertNil(try decode(minimal).weeklyStory)
    }

    func test_present_weekly_story_parsed() throws {
        // Use ASCII text in fixture — the field accepts any string, locale doesn't matter for decode test
        let withStory = minimal.replacingOccurrences(
            of: "}",
            with: ",\"weekly_story\":{\"text\":\"You kept the rhythm for 4 weeks.\",\"thread\":\"consistency\"}}",
            range: minimal.range(of: "}", options: .backwards)
        )
        let dto = try decode(withStory)
        XCTAssertEqual(dto.weeklyStory?.text, "You kept the rhythm for 4 weeks.")
        XCTAssertEqual(dto.weeklyStory?.thread, "consistency")
    }

    func test_unknown_thread_does_not_crash() throws {
        let withStory = minimal.replacingOccurrences(
            of: "}",
            with: ",\"weekly_story\":{\"text\":\"x\",\"thread\":\"future_thread_v9\"}}",
            range: minimal.range(of: "}", options: .backwards)
        )
        XCTAssertEqual(try decode(withStory).weeklyStory?.thread, "future_thread_v9")
    }
}
