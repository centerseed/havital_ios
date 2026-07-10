import XCTest
@testable import paceriz_dev

/// plan-level `climate[7]`（T-0165）。
///
/// 核心不變式：氣候綁「日期」不綁「課表」。交換兩天的課表，溫度不跟著走。
final class ClimateDayTests: XCTestCase {

    // MARK: - 解碼

    private func decodePlan(_ json: String) throws -> WeeklyPlanV2 {
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private var sevenDayPlanJSON: String {
        """
        {
          "id": "ov_1", "purpose": "base", "total_distance_km": 30.0,
          "days": [
            {"day_index": 1, "day_target": "easy", "reason": "r", "category": "run",
             "primary": {"run_type": "easy_run", "pace": "6:00", "distance_km": 6.0}},
            {"day_index": 2, "day_target": "rest", "reason": "r", "category": "rest"}
          ],
          "climate": [
            {"day_index": 1, "date": "2026-07-13", "feels_like_temp_c": 26.0,
             "heat_pressure_level": "comfortable", "pace_adjustment_pct": 0.0,
             "reason_text": "Comfortable", "region_key": "taiwan"},
            {"day_index": 2, "date": "2026-07-14", "feels_like_temp_c": 33.0,
             "heat_pressure_level": "moderate", "pace_adjustment_pct": 4.0,
             "long_run_keep_ratio": 0.8, "reason_text": "Moderate heat stress", "region_key": "taiwan",
             "suggested_training_windows": ["early_morning", "evening"]}
          ]
        }
        """
    }

    func testDecodesPlanLevelClimateIncludingComfortableAndRestDay() throws {
        let plan = try decodePlan(sevenDayPlanJSON)

        XCTAssertEqual(plan.climateDays.count, 2)
        // 涼爽日在 climate[7] 裡
        XCTAssertEqual(plan.climateDays.forDayIndex(1)?.heatPressureLevel, "comfortable")
        XCTAssertEqual(plan.climateDays.forDayIndex(1)?.feelsLikeTempC, 26.0)
        // 休息日（day2 category=rest）也有溫度 —— 這是 todo #1 的核心需求
        XCTAssertEqual(plan.climateDays.forDayIndex(2)?.feelsLikeTempC, 33.0)
    }

    func testMissingClimateFieldDecodesToNil() throws {
        let json = """
        {"id": "ov_1", "purpose": "base", "total_distance_km": 30.0, "days": []}
        """
        let plan = try decodePlan(json)
        XCTAssertNil(plan.climate)
        XCTAssertTrue(plan.climateDays.isEmpty)
    }

    func testSuggestedTrainingWindowsSurvive() throws {
        let plan = try decodePlan(sevenDayPlanJSON)
        XCTAssertEqual(plan.climateDays.forDayIndex(2)?.suggestedTrainingWindows,
                       ["early_morning", "evening"])
    }

    // MARK: - 氣候綁日期，不綁課表

    func testClimateIsLookedUpByDayIndexNotArrayPosition() throws {
        let plan = try decodePlan(sevenDayPlanJSON)
        // 陣列反過來也要拿到同一天
        let reversed: [ClimateDay] = plan.climateDays.reversed()
        XCTAssertEqual(reversed.forDayIndex(1)?.date, "2026-07-13")
        XCTAssertEqual(reversed.forDayIndex(2)?.date, "2026-07-14")
    }

    // MARK: - 顯示規則

    func testComfortableDaySaysNothing() {
        let cool = makeClimateDay(level: "comfortable", pct: 0)
        XCTAssertTrue(cool.isComfortable)
        XCTAssertFalse(cool.hasHeatAdvice)
        XCTAssertNil(cool.badgeSystemImageName, "comfortable day must not escalate the icon")
        XCTAssertNil(cool.adjustmentText, "must not render a +0% pace adjustment")
    }

    func testHotDayHasAdviceAndIcon() {
        let hot = makeClimateDay(level: "high", pct: 6.5)
        XCTAssertTrue(hot.hasHeatAdvice)
        XCTAssertNotNil(hot.badgeSystemImageName)
        XCTAssertNotNil(hot.adjustmentText)
    }

    func testTemperatureTextRounds() {
        XCTAssertEqual(makeClimateDay(level: "mild", pct: 2, temp: 28.6).temperatureText, "29°")
    }

    // MARK: - 配速當場算（後端不再送 climate_adjusted_pace）

    func testClimateAdjustedPaceDerivedFromPrescription() {
        let day = makeClimateDay(level: "moderate", pct: 4.0)
        // 360s × 1.04 = 374.4 → 374s → 6:14
        XCTAssertEqual(day.climateAdjustedPace(forBasePace: "6:00"), "6:14")
    }

    func testAdjustedPaceDiffersByAbility() {
        let day = makeClimateDay(level: "moderate", pct: 4.0)
        let novice = day.climateAdjustedPace(forBasePace: "7:30")
        let elite = day.climateAdjustedPace(forBasePace: "4:20")
        XCTAssertNotEqual(novice, elite)
        XCTAssertEqual(novice, "7:48")
        XCTAssertEqual(elite, "4:30")
    }

    func testDangerDayGetsAdjustedPaceFromBackendPct() {
        // heat_profile 的 danger policy 是 pace_adjustment_pct=9.0，不是 nil。
        // 改版前 iOS 有一條「danger 後端不給百分比」的 fallback，那是死 code。
        let danger = makeClimateDay(level: "danger", pct: 9.0)
        XCTAssertEqual(danger.climateAdjustedPace(forBasePace: "6:00"), "6:32")
    }

    func testComfortableDayHasNoAdjustedPace() {
        XCTAssertNil(makeClimateDay(level: "comfortable", pct: 0).climateAdjustedPace(forBasePace: "6:00"))
    }

    func testMalformedPaceReturnsNil() {
        let day = makeClimateDay(level: "high", pct: 6.5)
        XCTAssertNil(day.climateAdjustedPace(forBasePace: "abc"))
        XCTAssertNil(day.climateAdjustedPace(forBasePace: ""))
    }

    // MARK: - 長跑：保留比例，不是縮減幅度

    func testLongRunSuggestedDistanceUsesKeepRatio() {
        let day = makeClimateDay(level: "high", pct: 6.5, keepRatio: 0.7)
        // 保留 70% → 20.0 km 建議跑 14.0 km
        XCTAssertEqual(day.climateAdjustedDistanceKm(forPrescribedKm: 20.0), 14.0)
    }

    func testLongRunReductionTextShowsReductionNotKeepRatio() {
        let day = makeClimateDay(level: "high", pct: 6.5, keepRatio: 0.7)
        let text = day.longRunReductionText
        XCTAssertNotNil(text)
        // 改版前把 0.7 直接餵進 "%.0f%%" → 顯示「縮減 1%」。應為 30%。
        XCTAssertTrue(text!.contains("30"), "expected a 30% reduction, got: \(text!)")
        XCTAssertFalse(text!.contains(" 1%"), "keep-ratio 0.7 must not surface as 1%")
    }

    func testNoKeepRatioMeansNoReductionText() {
        XCTAssertNil(makeClimateDay(level: "mild", pct: 2.0).longRunReductionText)
    }

    // MARK: - 過渡期退路：response 沒有 climate[7] 時退回 legacy climate_meta

    /// 後端只對帶 week_start_date 錨點的 doc 現算 climate[7]，錨點是新管線生成時才寫入的。
    /// 上線那一秒所有現存用戶的當週課表都是舊 doc → 沒有 climate[7]。少了這條退路，
    /// 熱適應會整個空白到下次課表生成為止。
    func testFallsBackToLegacyClimateMetaWhenPlanHasNoClimateArray() throws {
        let json = """
        {
          "id": "ov_1", "purpose": "base", "total_distance_km": 30.0,
          "days": [
            {"day_index": 1, "day_target": "easy", "reason": "r", "category": "run",
             "climate_meta": {"heat_pressure_level": "high", "feels_like_temp_c": 34.0,
                              "pace_adjustment_pct": 6.5, "reason_text": "hot"},
             "primary": {"run_type": "easy_run", "pace": "6:00"}}
          ]
        }
        """
        let plan = try decodePlan(json)
        XCTAssertNil(plan.climate, "a legacy doc yields no climate[7] in the response")

        let day = try XCTUnwrap(plan.climate(forDayIndex: 1), "must fall back to legacy climate_meta, not nil")
        XCTAssertEqual(day.heatPressureLevel, "high")
        XCTAssertEqual(day.feelsLikeTempC, 34.0)
        XCTAssertEqual(day.climateAdjustedPace(forBasePace: "6:00"), "6:23")
    }

    func testFreshClimateWinsOverLegacyMeta() throws {
        let json = """
        {
          "id": "ov_1", "purpose": "base", "total_distance_km": 30.0,
          "days": [
            {"day_index": 1, "day_target": "easy", "reason": "r", "category": "run",
             "climate_meta": {"heat_pressure_level": "danger", "feels_like_temp_c": 41.0,
                              "pace_adjustment_pct": 9.0, "reason_text": "stale"},
             "primary": {"run_type": "easy_run", "pace": "6:00"}}
          ],
          "climate": [
            {"day_index": 1, "date": "2026-07-13", "feels_like_temp_c": 26.0,
             "heat_pressure_level": "comfortable", "pace_adjustment_pct": 0.0,
             "reason_text": "cool", "region_key": "taiwan"}
          ]
        }
        """
        let plan = try decodePlan(json)
        // climate[7] 是現算的真相；doc 裡殘留的 climate_meta 是過期投影，不得勝出。
        XCTAssertEqual(plan.climate(forDayIndex: 1)?.heatPressureLevel, "comfortable")
        XCTAssertEqual(plan.climate(forDayIndex: 1)?.feelsLikeTempC, 26.0)
    }

    func testNoClimateAnywhereReturnsNil() throws {
        let json = """
        {"id": "ov_1", "purpose": "base", "total_distance_km": 30.0,
         "days": [{"day_index": 1, "day_target": "e", "reason": "r", "category": "run",
                   "primary": {"run_type": "easy_run", "pace": "6:00"}}]}
        """
        let plan = try decodePlan(json)
        XCTAssertNil(plan.climate(forDayIndex: 1))
    }

    func testRestDayHasNoLegacyFallback() throws {
        // legacy climate_meta 只存在於 mild+ 的跑步日 —— 這正是為何它不能當主要來源。
        let json = """
        {"id": "ov_1", "purpose": "base", "total_distance_km": 30.0,
         "days": [{"day_index": 3, "day_target": "rest", "reason": "r", "category": "rest"}]}
        """
        let plan = try decodePlan(json)
        XCTAssertNil(plan.climate(forDayIndex: 3))
    }

    func testCapsuleTextIsNilWhenLegacyMetaHasNoTemperature() {
        let meta = ClimateMeta(feelsLikeTempC: nil, heatPressureLevel: "high",
                               paceAdjustmentPct: 6.5, reasonText: "r", longRunReductionPct: nil)
        let day = ClimateDay(legacyMeta: meta, dayIndex: 1)
        XCTAssertNil(day.temperatureText, "no temperature -> capsule degrades to icon only")
        XCTAssertNotNil(day.badgeSystemImageName)
    }

    // MARK: - Helper

    private func makeClimateDay(
        level: String,
        pct: Double,
        temp: Double = 32.0,
        keepRatio: Double? = nil
    ) -> ClimateDay {
        ClimateDay(
            dayIndex: 1,
            date: "2026-07-13",
            feelsLikeTempC: temp,
            heatPressureLevel: level,
            paceAdjustmentPct: pct,
            longRunKeepRatio: keepRatio,
            reasonText: "r",
            source: "open_meteo",
            warningLabel: nil,
            regionKey: "taiwan",
            suggestedTrainingWindows: []
        )
    }
}
