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

    /// 真實 payload 形狀 → domain entity。走的是正式路徑上的同一支 mapper
    /// （`WeeklyPlanV2Mapper`），投影測到的東西才跟 App 看到的一致。
    private func plan(_ json: String) throws -> WeeklyPlanV2 {
        WeeklyPlanV2Mapper.toEntity(
            from: try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
        )
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
          "intensity_total_minutes": { "low": 296, "medium": 0, "high": 22 },
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
        let start = App2WeekCalendar.currentWeekStart(reference: sunday, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: start), 8)
        XCTAssertEqual(calendar.component(.day, from: start), 17)
        XCTAssertEqual(calendar.component(.weekday, from: start), 2)  // 2 = 週一
    }

    func test_dateLabel_isWeekStartPlusOneBasedDayIndex() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        XCTAssertEqual(App2WeekCalendar.dateLabel(dayIndex: 1, weekStart: monday, calendar: calendar), "8/10")
        XCTAssertEqual(App2WeekCalendar.dateLabel(dayIndex: 7, weekStart: monday, calendar: calendar), "8/16")
    }

    // MARK: - 本週已完成量的週界（2026-08-31 實機：13 km vs 正確的 8.46 km）

    /// 週界是**週一**，不是 locale 週首。日曆刻意設成 `firstWeekday = 1`（週日，
    /// zh-TW 與 en-US 都是這個值），舊實作的 `dateInterval(of: .weekOfYear)` 會把
    /// 起點退到週日 8/30，於是週日那筆跑量被算進本週。
    func test_completedThisWeekWindow_startsOnMondayNotLocaleWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar.firstWeekday = 1                                     // 週日起始（zh-TW）
        // 2026-08-31 是週一。
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!

        let window = App2PlanViewModel.completedThisWeekWindow(now: monday, calendar: calendar)

        XCTAssertEqual(calendar.component(.weekday, from: window.start), 2, "起點必須是週一")
        XCTAssertEqual(calendar.component(.day, from: window.start), 31)
        XCTAssertEqual(window.end, monday)
    }

    /// 釘住實機那一筆：週日 2026-08-30 的跑步屬於**上週**，不得落進本週的查詢窗。
    func test_completedThisWeekWindow_excludesSundayWorkoutOfPreviousWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar.firstWeekday = 1
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!
        let sundayRun = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 8))!

        let window = App2PlanViewModel.completedThisWeekWindow(now: monday, calendar: calendar)

        XCTAssertLessThan(sundayRun, window.start, "週日 8/30 的跑量是上週的，不計入本週")
    }

    func test_planWeek_fillsDateLabelForEveryDay() throws {
        // 投影內部用 `Calendar.current`，所以週起點也用它建，避免跨時區飄一天。
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let week = App2PlanViewModel.planWeek(
            plan: try plan(fullWeekJSON(weekOfTraining: 7, totalWeeks: 8)),
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
        XCTAssertEqual(App2WeekCalendar.todayDayIndex(), expected)
        XCTAssertTrue((1...7).contains(App2WeekCalendar.todayDayIndex()))
    }

    func test_planWeek_highlightsExactlyOneToday() throws {
        let week = App2PlanViewModel.planWeek(
            plan: try plan(fullWeekJSON(weekOfTraining: 7, totalWeeks: 8)),
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
            plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 5
        )
        XCTAssertTrue(week.days.allSatisfy { !$0.isToday })
    }

    // MARK: - 週次標籤

    func test_planWeek_firstWeek_labelIsLocalizedWeekNumber() throws {
        let week = App2PlanViewModel.planWeek(
            plan: try plan(fullWeekJSON(weekOfTraining: 1, totalWeeks: 18)),
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
            plan: try plan(fullWeekJSON(weekOfTraining: 18, totalWeeks: 18)),
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
            plan: try plan(json),
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
            plan: try plan(allRestWeekJSON), planStatus: try status(), completedKm: nil, todayIndex: 3
        )
        XCTAssertEqual(week.days.count, 7)
        XCTAssertTrue(week.days.allSatisfy { $0.dayType == .rest })
        XCTAssertTrue(week.days.allSatisfy { $0.planned == nil })
        XCTAssertTrue(week.days.allSatisfy { $0.tag == DayType.rest.localizedName })
        XCTAssertEqual(week.targetDistanceKm, 0)
    }

    func test_planWeek_completion_zeroAndFull() throws {
        let weekPlan = try plan(fullWeekJSON(weekOfTraining: 4, totalWeeks: 8))
        let planStatus = try status()

        let zero = App2PlanViewModel.planWeek(
            plan: weekPlan, planStatus: planStatus, completedKm: 0, todayIndex: 1
        )
        XCTAssertEqual(zero.completedDistanceKm, 0)

        let full = App2PlanViewModel.planWeek(
            plan: weekPlan, planStatus: planStatus, completedKm: 35, todayIndex: 1
        )
        XCTAssertEqual(full.completedDistanceKm, 35)
        XCTAssertEqual(full.targetDistanceKm, 35)

        // 尚未取得 workouts → nil，畫面顯示 0 而不是假裝已完成。
        let unknown = App2PlanViewModel.planWeek(
            plan: weekPlan, planStatus: planStatus, completedKm: nil, todayIndex: 1
        )
        XCTAssertNil(unknown.completedDistanceKm)
    }

    func test_planWeek_missingIntensityDistribution_staysNil() throws {
        let week = App2PlanViewModel.planWeek(
            plan: try plan(allRestWeekJSON), planStatus: try status(), completedKm: nil, todayIndex: 1
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
            plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 2
        )
        XCTAssertEqual(week.days.first?.temp, "29°C")
        XCTAssertEqual(week.days.first?.planned, "8.0 km")
    }

    // MARK: - 日卡內容（設計 frame-01：課表行 ＝ 量 · 配速；敘述行 ＝ day_target）

    /// 設計 frame-01 的課表行是「課表 4.0 km · 6:50/km」，不是裸距離。
    /// **一律顯示處方配速**（2026-05 使用者裁決，2026-08-26 起 App2 全面適用）：
    /// 課表行不得被 `climate_adjusted_pace` 蓋掉，熱調整值只出現在熱適應卡。
    /// 樣本是節奏跑：輕鬆跑與長距離輕鬆跑一律不顯示配速（2026-09-11 使用者裁決，
    /// 見 `test_planWeek_easyRunRowOmitsPace`），拿它當樣本會量不到「不用氣候值」這件事。
    func test_planWeek_plannedRowCarriesPrescribedPaceNotClimateAdjusted() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 8,
          "days": [ { "day_index": 2,
                      "day_target": "節奏跑：維持乳酸閾值強度 4 km", "reason": "r",
                      "primary": { "run_type": "tempo", "distance_km": 4.0,
                                   "pace": "6:50", "climate_adjusted_pace": "7:17" } } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 2
            ).days.first
        )
        XCTAssertEqual(day.planned, "4.0 km · 6:50/km")
        XCTAssertEqual(day.description, "節奏跑：維持乳酸閾值強度 4 km")
    }

    /// 課表頁的日卡：輕鬆跑那一行只有距離。
    func test_planWeek_easyRunRowOmitsPace() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 8,
          "days": [ { "day_index": 2,
                      "day_target": "輕鬆跑：保持舒適配速，專注於有氧建立 4 km", "reason": "r",
                      "primary": { "run_type": "easy", "distance_km": 4.0,
                                   "pace": "6:50", "climate_adjusted_pace": "7:17" } } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 2
            ).days.first
        )
        XCTAssertEqual(day.planned, "4.0 km")
    }

    /// 休息日沒有課表行，敘述行（`休息與恢復`）就是那張卡唯一的內容。
    func test_planWeek_restDayKeepsDescriptionRow() throws {
        let json = """
        { "purpose": "p", "week_of_training": 1, "total_weeks": 6, "total_distance_km": 0,
          "days": [ { "day_index": 3, "day_target": "休息與恢復", "reason": "r" } ] }
        """
        let day = try XCTUnwrap(
            App2PlanViewModel.planWeek(
                plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 1
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
                plan: try plan(json), planStatus: try status(), completedKm: nil, todayIndex: 1
            ).days.first
        )
        XCTAssertNil(day.description)
    }

    // MARK: - 課型與識別字

    func test_dayType_mapsRunStrengthCrossAndRest() throws {
        func primary(_ json: String) throws -> PrimaryActivity? {
            TrainingSessionMapper.toEntity(
                from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
            ).session?.primary
        }
        let easy = try primary(#"{"day_index":1,"day_target":"t","reason":"r","primary":{"run_type":"easy"}}"#)
        XCTAssertEqual(App2PlanViewModel.dayType(easy), .easy)
        XCTAssertEqual(App2PlanViewModel.dayType(nil), .rest)
    }

    /// 後端識別字不得上畫面：`tag` 一律是 `DayType.localizedName`。
    func test_planWeek_tagNeverExposesRawRunType() throws {
        let week = App2PlanViewModel.planWeek(
            plan: try plan(fullWeekJSON(weekOfTraining: 1, totalWeeks: 8)),
            planStatus: try status(), completedKm: nil, todayIndex: 1
        )
        XCTAssertTrue(week.days.allSatisfy { $0.tag != "easy" })
        XCTAssertTrue(week.days.allSatisfy { $0.tag == DayType.easy.localizedName })
    }

    /// 實跑條的三段是實跑分鐘，不是課表目標。2026-09-02 用戶截圖：間歇週跑了
    /// low 97 / medium 38.5 / high 9.25 分鐘，畫面卻拿目標 296/0/22 畫成「中等 0」。
    func test_planWeek_intensityBarUsesCompletedMinutesNotPlanTargets() throws {
        let plan = try plan(fullWeekJSON(weekOfTraining: 7, totalWeeks: 8))
        let week = App2PlanViewModel.planWeek(
            plan: plan,
            planStatus: try status(),
            completedKm: 22.9,
            completedIntensity: App2IntensityMinutes(low: 97.2, medium: 38.5, high: 9.25),
            todayIndex: 3
        )
        XCTAssertEqual(week.intensityLowMinutes, 97)
        XCTAssertEqual(week.intensityMediumMinutes, 39)
        XCTAssertEqual(week.intensityHighMinutes, 9)

        // 沒有紀錄 → 三格都 nil，不得退回課表目標把空條畫出顏色。
        let none = App2PlanViewModel.planWeek(
            plan: plan, planStatus: try status(), completedKm: nil, todayIndex: 3
        )
        XCTAssertNil(none.intensityLowMinutes)
        XCTAssertNil(none.intensityMediumMinutes)
        XCTAssertNil(none.intensityHighMinutes)
    }

    func test_planEdit_usesBackendDailyTotalThroughDTOMapperWithoutChangingPrimaryDistance() throws {
        let json = #"{"day_index":6,"day_target":"LSD","reason":"r","category":"run","distance_km":19.5,"warmup":{"distance_km":2.0},"cooldown":{"distance_km":1.0},"primary":{"run_type":"lsd","distance_km":16.5,"pace":"6:30"}}"#
        let dto = try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        let entity = TrainingSessionMapper.toEntity(from: dto)
        let day = MutableTrainingDay(from: entity)

        XCTAssertEqual(entity.distanceKm, 19.5)
        XCTAssertEqual(entity.primaryRunActivity?.distanceKm, 16.5)
        XCTAssertEqual(App2PlanEditView.distanceKm(of: day), 19.5, accuracy: 0.001)
        XCTAssertEqual([day].reduce(0) { $0 + App2PlanEditView.distanceKm(of: $1) }, 19.5, accuracy: 0.001)
    }

    func test_planEdit_legacyPrimaryDistanceWithWrappersReconstructsVisibleDailyTotal() throws {
        let json = #"{"day_index":6,"day_target":"Interval","reason":"r","category":"run","warmup":{"distance_km":2.0},"cooldown":{"distance_km":1.0},"primary":{"run_type":"interval","distance_km":6.0}}"#
        let dto = try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        let day = MutableTrainingDay(from: TrainingSessionMapper.toEntity(from: dto))

        XCTAssertNil(day.visibleDailyDistanceKm)
        XCTAssertEqual(day.trainingDetails?.distanceKm, 6.0)
        XCTAssertEqual(App2PlanEditView.distanceKm(of: day), 9.0, accuracy: 0.001)
    }

    func test_planEdit_reconstructsMetreOnlyPrimarySegmentsWithAndWithoutWrappers() throws {
        let plainJSON = #"{"day_index":2,"day_target":"Interval","reason":"r","category":"run","primary":{"run_type":"interval","segments":[{"distance_m":4000},{"distance_m":2000}]}}"#
        let wrappedJSON = #"{"day_index":2,"day_target":"Interval","reason":"r","category":"run","warmup":{"distance_km":1.0},"cooldown":{"distance_km":0.5},"primary":{"run_type":"interval","segments":[{"distance_m":4000},{"distance_m":2000}]}}"#
        let plainDTO = try JSONDecoder().decode(DayDetailDTO.self, from: Data(plainJSON.utf8))
        let wrappedDTO = try JSONDecoder().decode(DayDetailDTO.self, from: Data(wrappedJSON.utf8))
        let plain = MutableTrainingDay(from: TrainingSessionMapper.toEntity(from: plainDTO))
        let wrapped = MutableTrainingDay(from: TrainingSessionMapper.toEntity(from: wrappedDTO))

        XCTAssertEqual(App2PlanEditView.distanceKm(of: plain), 6.0, accuracy: 0.001)
        XCTAssertEqual(App2PlanEditView.distanceKm(of: wrapped), 7.5, accuracy: 0.001)
    }

    func test_planEdit_prescriptionMutationInvalidatesBackendDailyTotal() throws {
        let json = #"{"day_index":6,"day_target":"Easy","reason":"r","category":"run","distance_km":19.5,"primary":{"run_type":"easy","distance_km":16.5}}"#
        let dto = try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        var day = MutableTrainingDay(from: TrainingSessionMapper.toEntity(from: dto))
        XCTAssertEqual(App2PlanEditView.distanceKm(of: day), 19.5, accuracy: 0.001)

        day.trainingDetails?.distanceKm = 17.5
        day.invalidateVisibleDailyDistanceAfterPrescriptionChange()
        XCTAssertEqual(App2PlanEditView.distanceKm(of: day), 17.5, accuracy: 0.001)

        day.visibleDailyDistanceKm = 19.5
        day.trainingType = DayType.rest.rawValue
        day.invalidateVisibleDailyDistanceAfterPrescriptionChange()
        XCTAssertEqual(App2PlanEditView.distanceKm(of: day), 0, accuracy: 0.001)
    }

    func test_lsd_uses_the_canonical_training_type_i18n_name() {
        XCTAssertEqual(
            DayType.lsd.localizedName,
            NSLocalizedString("training.type.lsd", comment: "")
        )
        XCTAssertNotEqual(DayType.lsd.localizedName, "LONG · Z2-Z3")
        XCTAssertEqual(
            PlannedSessionDetailView.WorkoutMeta.chipLabel(for: .lsd),
            DayType.lsd.localizedName
        )
    }

    func test_edit_top_bar_pace_table_label_stays_single_line() {
        XCTAssertEqual(App2EditTopBar.paceTableTextLineLimit, 1)
        XCTAssertTrue(App2EditTopBar.paceTableTextFixedHorizontally)
    }

    func test_planEdit_userEditInvalidatesBackendDailyTotalAndRecalculatesWeek() throws {
        let json = #"{"day_index":6,"day_target":"Fartlek","reason":"r","category":"run","distance_km":19.5,"warmup":{"distance_km":2.0},"cooldown":{"distance_km":1.0},"primary":{"run_type":"fartlek","segments":[{"distance_km":16.5,"pace":"6:30"}]}}"#
        let dto = try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        let mappedDay = MutableTrainingDay(from: TrainingSessionMapper.toEntity(from: dto))
        let state = TrainingDayEditState(from: mappedDay)
        state.segments[0].distance = 17.5
        let edited = state.toMutableTrainingDay(originalDay: mappedDay)

        XCTAssertNil(edited.visibleDailyDistanceKm)
        XCTAssertEqual(App2PlanEditView.distanceKm(of: edited), 20.5, accuracy: 0.001)
        XCTAssertEqual([edited].reduce(0) { $0 + App2PlanEditView.distanceKm(of: $1) }, 20.5, accuracy: 0.001)

        let weeklyPlan = WeeklyPlanV2Mapper.toEntity(from: try JSONDecoder().decode(
            WeeklyPlanV2DTO.self,
            from: Data(#"{"purpose":"p","week_of_training":1,"total_weeks":1,"total_distance_km":19.5,"days":[{"day_index":6,"day_target":"Fartlek","reason":"r","category":"run","distance_km":19.5,"warmup":{"distance_km":2.0},"cooldown":{"distance_km":1.0},"primary":{"run_type":"fartlek","segments":[{"distance_km":16.5,"pace":"6:30"}]}}]}"#.utf8)
        ))
        let saveVM = EditScheduleV2ViewModel(weeklyPlan: weeklyPlan, repository: MockTrainingPlanV2Repository())
        let savedDTO = saveVM.debug_buildDayDetailDTO(from: edited)
        XCTAssertNil(savedDTO.distanceKm, "Edited DTO must not submit stale backend daily total")
        XCTAssertEqual(savedDTO.warmup?.distanceKm, 2.0)
        XCTAssertEqual(savedDTO.cooldown?.distanceKm, 1.0)
        guard case .run(let savedPrimary) = savedDTO.primary else { return XCTFail("Expected run primary") }
        XCTAssertEqual(savedPrimary.segments?.first?.distanceKm, 17.5)
    }
}
