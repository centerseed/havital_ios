import XCTest
@testable import paceriz_dev

/// 課表頁投影（`App2PlanViewModel` 的 static 純函式）。
///
/// **`day_index` 是 1-based（1 = 週一 … 7 = 週日）。** 這條原本被當成 0-based，
/// 讓每一列的星期標籤與「今日」高亮整整錯一天（2026-08-25 修）。沒有測試才會漏，
/// 所以這裡把它鎖住。
@MainActor
final class App2PlanProjectionTests: XCTestCase {

    // MARK: - Helpers

    private func plan(_ json: String) throws -> WeeklyPlanV2DTO {
        try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
    }

    private func status(currentWeek: Int = 7, totalWeeks: Int = 8) throws -> PlanStatusV2Response {
        let json = """
        { "current_week": \(currentWeek), "total_weeks": \(totalWeeks),
          "next_action": "view_plan", "can_generate_next_week": false,
          "current_week_plan_id": "p_\(currentWeek)" }
        """
        return try JSONDecoder().decode(PlanStatusV2Response.self, from: Data(json.utf8))
    }

    /// 七天：一～日，全部有 primary。
    private func fullWeekJSON(weekOfTraining: Int, totalWeeks: Int) -> String {
        let days = (1...7).map { index in
            """
            { "day_index": \(index), "day_target": "第 \(index) 天", "reason": "r",
              "primary": { "run_type": "easy", "distance_km": 5.0 } }
            """
        }.joined(separator: ",")
        return """
        { "purpose": "p", "week_of_training": \(weekOfTraining),
          "total_weeks": \(totalWeeks), "total_distance_km": 35.0,
          "days": [\(days)] }
        """
    }

    /// 全休息週：七天都沒有 primary。
    private let allRestWeekJSON = """
    { "purpose": "p", "week_of_training": 2, "total_weeks": 8, "total_distance_km": 0,
      "days": [
        { "day_index": 1, "day_target": "休息", "reason": "r" },
        { "day_index": 2, "day_target": "休息", "reason": "r" },
        { "day_index": 3, "day_target": "休息", "reason": "r" },
        { "day_index": 4, "day_target": "休息", "reason": "r" },
        { "day_index": 5, "day_target": "休息", "reason": "r" },
        { "day_index": 6, "day_target": "休息", "reason": "r" },
        { "day_index": 7, "day_target": "休息", "reason": "r" }
      ] }
    """

    // MARK: - day_index 語意

    func test_weekdayLabel_dayIndexIsOneBased() {
        let symbols = Calendar.current.shortWeekdaySymbols   // [0] = 週日
        XCTAssertEqual(App2PlanViewModel.weekdayLabel(dayIndex: 1), symbols[1]) // 週一
        XCTAssertEqual(App2PlanViewModel.weekdayLabel(dayIndex: 6), symbols[6]) // 週六
        XCTAssertEqual(App2PlanViewModel.weekdayLabel(dayIndex: 7), symbols[0]) // 週日
    }

    // MARK: - 日期（設計 frame-01 每卡標題「週一 8/10」）

    func test_currentWeekStart_isMondayOfThatWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        // 2026-08-23 是週日 → 當週週一是 2026-08-17。
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 9))!
        let start = App2PlanViewModel.currentWeekStart(reference: sunday, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: start), 8)
        XCTAssertEqual(calendar.component(.day, from: start), 17)
        XCTAssertEqual(calendar.component(.weekday, from: start), 2)  // 2 = 週一
    }

    func test_dateLabel_isWeekStartPlusOneBasedDayIndex() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        XCTAssertEqual(App2PlanViewModel.dateLabel(dayIndex: 1, weekStart: monday, calendar: calendar), "8/10")
        XCTAssertEqual(App2PlanViewModel.dateLabel(dayIndex: 7, weekStart: monday, calendar: calendar), "8/16")
    }

    func test_planWeek_fillsDateLabelForEveryDay() throws {
        // 投影內部用 `Calendar.current`，所以週起點也用它建，避免跨時區飄一天。
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let week = App2PlanViewModel.planWeek(
            dto: try plan(fullWeekJSON(weekOfTraining: 7, totalWeeks: 8)),
            planStatus: try status(),
            completedKm: nil,
            todayIndex: 3,
            weekStart: monday
        )
        XCTAssertEqual(week.days.map(\.dateLabel).first, "8/10")
        XCTAssertFalse(week.days.contains { $0.dateLabel.isEmpty })
    }

    func test_todayDayIndex_matchesCalendarWeekdayWithMondayFirst() {
        let weekday = Calendar.current.component(.weekday, from: Date())  // 1 = 週日
        let expected = weekday == 1 ? 7 : weekday - 1
        XCTAssertEqual(App2PlanViewModel.todayDayIndex(), expected)
        XCTAssertTrue((1...7).contains(App2PlanViewModel.todayDayIndex()))
    }

    func test_planWeek_highlightsExactlyOneToday() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(fullWeekJSON(weekOfTraining: 7, totalWeeks: 8)),
            planStatus: try status(),
            completedKm: 11,
            todayIndex: 4
        )
        XCTAssertEqual(week.days.filter(\.isToday).count, 1)
        XCTAssertEqual(week.days.first(where: \.isToday)?.id, 4)
        // 週四 = shortWeekdaySymbols[4]
        XCTAssertEqual(
            week.days.first(where: \.isToday)?.weekdayLabel,
            Calendar.current.shortWeekdaySymbols[4]
        )
    }

    /// 今天不在這一週的 days 裡（例如只回傳了部分天）→ 沒有任何一列高亮，不 crash。
    func test_planWeek_todayMissingFromDays_highlightsNothing() throws {
        let json = """
        { "purpose": "p", "week_of_training": 3, "total_weeks": 8, "total_distance_km": 10,
          "days": [ { "day_index": 1, "day_target": "t", "reason": "r" } ] }
        """
        let week = App2PlanViewModel.planWeek(
            dto: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 5
        )
        XCTAssertTrue(week.days.allSatisfy { !$0.isToday })
    }

    // MARK: - 週次標籤

    func test_planWeek_firstWeek_labelIsLocalizedWeekNumber() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(fullWeekJSON(weekOfTraining: 1, totalWeeks: 18)),
            planStatus: try status(currentWeek: 1, totalWeeks: 18),
            completedKm: 0,
            todayIndex: 1
        )
        XCTAssertEqual(week.weekLabel, String(format: L10n.WeekSelector.weekNumber.localized, 1))
        XCTAssertEqual(week.totalWeeks, 18)
        // 裸數字不得直接落到畫面上。
        XCTAssertNotEqual(week.weekLabel, "1")
    }

    func test_planWeek_lastWeek_usesDTOWeekNumber() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(fullWeekJSON(weekOfTraining: 18, totalWeeks: 18)),
            planStatus: try status(currentWeek: 18, totalWeeks: 18),
            completedKm: 40,
            todayIndex: 7
        )
        XCTAssertEqual(week.weekLabel, String(format: L10n.WeekSelector.weekNumber.localized, 18))
        XCTAssertEqual(week.totalWeeks, 18)
    }

    /// DTO 沒帶週次時退回 `/v2/plan/status` 的 current_week。
    func test_planWeek_missingWeekNumber_fallsBackToPlanStatus() throws {
        let json = """
        { "purpose": "p", "total_distance_km": 20,
          "days": [ { "day_index": 1, "day_target": "t", "reason": "r" } ] }
        """
        let week = App2PlanViewModel.planWeek(
            dto: try plan(json),
            planStatus: try status(currentWeek: 9, totalWeeks: 12),
            completedKm: nil,
            todayIndex: 1
        )
        XCTAssertEqual(week.weekLabel, String(format: L10n.WeekSelector.weekNumber.localized, 9))
        XCTAssertEqual(week.totalWeeks, 12)
    }

    // MARK: - 全休息週 ／ 完成度

    func test_planWeek_allRestWeek_hasSevenRestDaysAndNoPlannedDistance() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(allRestWeekJSON), planStatus: try status(), completedKm: nil, todayIndex: 3
        )
        XCTAssertEqual(week.days.count, 7)
        XCTAssertTrue(week.days.allSatisfy { $0.dayType == .rest })
        XCTAssertTrue(week.days.allSatisfy { $0.planned == nil })
        XCTAssertTrue(week.days.allSatisfy { $0.tag == DayType.rest.localizedName })
        XCTAssertEqual(week.targetDistanceKm, 0)
    }

    func test_planWeek_completion_zeroAndFull() throws {
        let dto = try plan(fullWeekJSON(weekOfTraining: 4, totalWeeks: 8))
        let planStatus = try status()

        let zero = App2PlanViewModel.planWeek(
            dto: dto, planStatus: planStatus, completedKm: 0, todayIndex: 1
        )
        XCTAssertEqual(zero.completedDistanceKm, 0)

        let full = App2PlanViewModel.planWeek(
            dto: dto, planStatus: planStatus, completedKm: 35, todayIndex: 1
        )
        XCTAssertEqual(full.completedDistanceKm, 35)
        XCTAssertEqual(full.targetDistanceKm, 35)

        // 尚未取得 workouts → nil，畫面顯示 0 而不是假裝已完成。
        let unknown = App2PlanViewModel.planWeek(
            dto: dto, planStatus: planStatus, completedKm: nil, todayIndex: 1
        )
        XCTAssertNil(unknown.completedDistanceKm)
    }

    func test_planWeek_missingIntensityDistribution_staysNil() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(allRestWeekJSON), planStatus: try status(), completedKm: nil, todayIndex: 1
        )
        XCTAssertNil(week.intensityLowMinutes)
        XCTAssertNil(week.intensityMediumMinutes)
        XCTAssertNil(week.intensityHighMinutes)
    }

    func test_planWeek_climateProjectsFeelsLikeTemperature() throws {
        let json = """
        { "purpose": "p", "week_of_training": 5, "total_weeks": 8, "total_distance_km": 10,
          "days": [ { "day_index": 2, "day_target": "t", "reason": "r",
                      "primary": { "run_type": "easy", "distance_km": 8 } } ],
          "climate": [ { "day_index": 2, "date": "2026-08-25", "feels_like_temp_c": 29.4,
                         "heat_pressure_level": "moderate", "reason_text": "r" } ] }
        """
        let week = App2PlanViewModel.planWeek(
            dto: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 2
        )
        XCTAssertEqual(week.days.first?.temp, "29°C")
        XCTAssertEqual(week.days.first?.planned, "8.0 km")
    }

    // MARK: - 日卡內容（設計 frame-01：課表行 ＝ 量 · 配速；敘述行 ＝ day_target）

    /// 設計 frame-01 的課表行是「課表 4.0 km · 7:17/km」，不是裸距離。
    /// 有 `climate_adjusted_pace` 就用它（那才是當天實際要跑的配速）。
    func test_planWeek_plannedRowCarriesPace() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 8,
          "days": [ { "day_index": 2,
                      "day_target": "輕鬆跑：保持舒適配速，專注於有氧建立 4 km", "reason": "r",
                      "primary": { "run_type": "easy", "distance_km": 4.0,
                                   "pace": "6:50", "climate_adjusted_pace": "7:17" } } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                dto: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 2
            ).days.first
        )
        XCTAssertEqual(day.planned, "4.0 km · 7:17/km")
        XCTAssertEqual(day.description, "輕鬆跑：保持舒適配速，專注於有氧建立 4 km")
    }

    /// 休息日沒有課表行，敘述行（`休息與恢復`）就是那張卡唯一的內容。
    func test_planWeek_restDayKeepsDescriptionRow() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 0,
          "days": [ { "day_index": 3, "day_target": "休息與恢復", "reason": "r" } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                dto: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 1
            ).days.first
        )
        XCTAssertNil(day.planned)
        XCTAssertEqual(day.description, "休息與恢復")
    }

    /// 空 `day_target` 不畫空行。
    func test_planWeek_blankDayTargetHasNoDescription() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 0,
          "days": [ { "day_index": 3, "day_target": "   ", "reason": "r" } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                dto: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 1
            ).days.first
        )
        XCTAssertNil(day.description)
    }

    // MARK: - 課型與識別字

    func test_dayType_mapsRunStrengthCrossAndRest() throws {
        func primary(_ json: String) throws -> PrimaryActivityDTO? {
            try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8)).primary
        }
        let easy = try primary(#"{"day_index":1,"day_target":"t","reason":"r","primary":{"run_type":"easy"}}"#)
        XCTAssertEqual(App2PlanViewModel.dayType(easy), .easy)
        XCTAssertEqual(App2PlanViewModel.dayType(nil), .rest)
    }

    /// 後端識別字不得上畫面：`tag` 一律是 `DayType.localizedName`。
    func test_planWeek_tagNeverExposesRawRunType() throws {
        let week = App2PlanViewModel.planWeek(
            dto: try plan(fullWeekJSON(weekOfTraining: 1, totalWeeks: 8)),
            planStatus: try status(), completedKm: nil, todayIndex: 1
        )
        XCTAssertTrue(week.days.allSatisfy { $0.tag != "easy" })
        XCTAssertTrue(week.days.allSatisfy { $0.tag == DayType.easy.localizedName })
    }
}
