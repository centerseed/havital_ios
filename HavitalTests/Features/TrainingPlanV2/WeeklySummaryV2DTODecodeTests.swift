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

    func test_decision_chain_block_decodes_without_numbers_in_focus() throws {
        let withDecisionChain = minimal.replacingOccurrences(
            of: "}",
            with: ",\"decision_chain\":{\"focus\":{\"kind\":\"metric\",\"metric\":\"speed_endurance\",\"direction\":\"improving\",\"start_day\":\"2026-08-24\",\"end_day\":\"2026-09-20\"},\"narrative\":{\"headline\":\"Speed is moving\",\"retrospect\":\"The week held together.\",\"next_week\":\"Keep the direction.\"},\"execution\":{\"completed_km\":40.3,\"planned_km\":41.5,\"run_count\":6,\"quality_count\":1}}}",
            range: minimal.range(of: "}", options: .backwards)
        )

        let dto = try decode(withDecisionChain)
        XCTAssertEqual(dto.decisionChain?.focus?.metric, "speed_endurance")
        XCTAssertEqual(dto.decisionChain?.narrative?.headline, "Speed is moving")
        XCTAssertEqual(dto.decisionChain?.execution?.qualityCount, 1)
    }

    /// `weekly_highlights` 的三個陣列缺席或給 null 時當空陣列，**不得讓整頁掛掉**。
    ///
    /// 後端現行契約三個都會給（`data_models/weekly_summary_v2.py:462`），但
    /// `422aa744`（休息週欄位 null）與 `dd07409f`／`59fd1aff`（解碼 bug 讓週回顧
    /// 整頁掛掉）都是這個形狀 —— 少一句話 vs 白畫面，代價不對等。
    func test_weekly_highlights_missing_or_null_arrays_default_to_empty() throws {
        let tolerant = minimal.replacingOccurrences(
            of: """
            "weekly_highlights": {
                "highlights": [],
                "achievements": [],
                "areas_for_improvement": []
              }
            """,
            with: "\"weekly_highlights\": { \"achievements\": null }"
        )
        let highlights = try decode(tolerant).weeklyHighlights
        XCTAssertEqual(highlights.highlights, [])       // 整個欄位缺席
        XCTAssertEqual(highlights.achievements, [])     // 給了 null
        XCTAssertEqual(highlights.areasForImprovement, [])
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
