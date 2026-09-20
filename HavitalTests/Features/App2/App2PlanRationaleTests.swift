import XCTest
@testable import paceriz_dev

// MARK: - 課表頁「這週為什麼這樣排」（AC-TRAIN-HUB-20）
/// 後端一直在寫這四段（`l5_response_builder.py:245-246` 落 `design_reason` 與
/// `coach_note`），2.0 的課表頁沒有任何畫面讀它們。這裡鎖的是投影那一段：
/// wire key → `App2PlanWeek.rationale`，以及「全空就不給入口」。
///
/// 與 `HavitalTests/TrainingPlan/Unit/APISchema/WeeklyPlanV2DecodingTests.swift:42,233`
/// 不重複：那支驗的是 DTO 解不解得出 `design_reason`，到 entity 為止；
/// 這支往下一層，驗 App2 的投影與入口的出現條件。
@MainActor
final class App2PlanRationaleTests: XCTestCase {

    private func plan(_ json: String) throws -> WeeklyPlanV2 {
        WeeklyPlanV2Mapper.toEntity(
            from: try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
        )
    }

    private func status() throws -> PlanStatusV2Response {
        try JSONDecoder().decode(
            PlanStatusV2Response.self,
            from: Data("""
            { "current_week": 3, "total_weeks": 8, "next_action": "view_plan",
              "can_generate_next_week": false, "current_week_plan_id": "p_3" }
            """.utf8)
        )
    }

    private let dayJSON = """
    { "day_index": 1, "day_target": "輕鬆跑", "reason": "r",
      "primary": { "run_type": "easy", "distance_km": 5.0 } }
    """

    private func week(_ plan: WeeklyPlanV2) throws -> App2PlanWeek {
        App2PlanViewModel.planWeek(
            plan: plan, planStatus: try status(), completedKm: nil, todayIndex: 1
        )
    }

    // MARK: -

    /// 四段齊全 → 四段都在，句子原樣，條列保持後端給的順序。
    func test_rationaleCarriesAllFourSectionsVerbatim() throws {
        let json = """
        { "purpose": "本週維持基礎量", "week_of_training": 3, "total_weeks": 8,
          "total_distance_km": 34.3,
          "coach_note": "本週維持 34.3 公里的總跑量，以穩定狀態為主。",
          "mileage_progression_note": "最近最高週是 48 km，本週 34.3 km。",
          "design_reason": ["基礎期安排 6 天跑步。", "保留 1 個重課刺激。"],
          "days": [\(dayJSON)] }
        """
        let rationale = try XCTUnwrap(try week(try plan(json)).rationale)

        XCTAssertEqual(rationale.coachNote, "本週維持 34.3 公里的總跑量，以穩定狀態為主。")
        XCTAssertEqual(rationale.purpose, "本週維持基礎量")
        XCTAssertEqual(rationale.mileageProgressionNote, "最近最高週是 48 km，本週 34.3 km。")
        XCTAssertEqual(rationale.designReasons, ["基礎期安排 6 天跑步。", "保留 1 個重課刺激。"])
    }

    /// 四段一個都沒有 → 入口不該出現，所以 `rationale` 必須是 nil 而不是空殼。
    ///
    /// `purpose` 在 DTO 是必填，所以「沒有」在 wire 上的形狀是空字串。
    func test_rationaleIsNilWhenNothingToSay() throws {
        let json = """
        { "purpose": "", "week_of_training": 3, "total_weeks": 8, "total_distance_km": 34.3,
          "coach_note": "", "design_reason": [], "days": [\(dayJSON)] }
        """
        XCTAssertNil(try week(try plan(json)).rationale)
    }

    /// 只有一段有東西也要給入口——四段是選配的，不是全有全無。
    func test_rationaleSurvivesWithASingleSection() throws {
        let json = """
        { "purpose": "", "week_of_training": 3, "total_weeks": 8, "total_distance_km": 34.3,
          "design_reason": ["基礎期安排 6 天跑步。"], "days": [\(dayJSON)] }
        """
        let rationale = try XCTUnwrap(try week(try plan(json)).rationale)

        XCTAssertNil(rationale.coachNote)
        XCTAssertNil(rationale.purpose)
        XCTAssertNil(rationale.mileageProgressionNote)
        XCTAssertEqual(rationale.designReasons, ["基礎期安排 6 天跑步。"])
    }

    /// 只有空白字元的一段等於沒有這一段；條列裡的空項目不佔一個編號。
    func test_blankSectionsAreDropped() throws {
        let json = """
        { "purpose": "   ", "week_of_training": 3, "total_weeks": 8, "total_distance_km": 34.3,
          "coach_note": "\\n",
          "design_reason": ["", "  ", "保留 1 個重課刺激。"], "days": [\(dayJSON)] }
        """
        let rationale = try XCTUnwrap(try week(try plan(json)).rationale)

        XCTAssertNil(rationale.purpose)
        XCTAssertNil(rationale.coachNote)
        XCTAssertEqual(rationale.designReasons, ["保留 1 個重課刺激。"])
    }
}
