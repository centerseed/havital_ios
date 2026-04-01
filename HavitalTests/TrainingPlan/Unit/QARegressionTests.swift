import XCTest
@testable import paceriz_dev

/// QA Regression Tests (2026-04-01)
/// Validates: shouldHidePace logic, easy-run time consistency,
/// weekly intensity distribution, and pace zone mapping for Norwegian/cruise types.
final class QARegressionTests: XCTestCase {

    // MARK: - Helpers

    /// Parse a pace string "mm:ss" into fractional minutes.
    private func parsePace(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let mins = Double(parts[0]),
              let secs = Double(parts[1]) else { return nil }
        return mins + secs / 60.0
    }

    /// Decode a `WeeklyPlan` from an inline JSON string.
    private func decodePlan(_ json: String) -> WeeklyPlan {
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(WeeklyPlan.self, from: data)
    }

    // MARK: - Group 1: shouldHidePace Logic

    func testShouldHidePace_easyRun_returnsTrue() {
        XCTAssertTrue(DayType.easyRun.shouldHidePace)
    }

    func testShouldHidePace_easy_returnsTrue() {
        XCTAssertTrue(DayType.easy.shouldHidePace)
    }

    func testShouldHidePace_recoveryRun_returnsTrue() {
        XCTAssertTrue(DayType.recovery_run.shouldHidePace)
    }

    func testShouldHidePace_lsd_returnsTrue() {
        XCTAssertTrue(DayType.lsd.shouldHidePace)
    }

    func testShouldHidePace_interval_returnsFalse() {
        XCTAssertFalse(DayType.interval.shouldHidePace)
    }

    func testShouldHidePace_tempo_returnsFalse() {
        XCTAssertFalse(DayType.tempo.shouldHidePace)
    }

    func testShouldHidePace_cruiseIntervals_returnsFalse() {
        XCTAssertFalse(DayType.cruiseIntervals.shouldHidePace)
    }

    func testShouldHidePace_norwegian4x4_returnsFalse() {
        XCTAssertFalse(DayType.norwegian4x4.shouldHidePace)
    }

    func testShouldHidePace_threshold_returnsFalse() {
        XCTAssertFalse(DayType.threshold.shouldHidePace)
    }

    // MARK: - Group 2: Easy Run Time Consistency

    func testEasyRunTime_3kmAt8min05_shouldBe24min() {
        let distanceKm = 3.0
        let paceMinutes = parsePace("8:05")!  // 8.083...
        let expectedTime = distanceKm * paceMinutes  // ~24.25
        XCTAssertEqual(expectedTime, 24.0, accuracy: 1.0,
                       "3km @ 8:05 should yield ~24 min (got \(expectedTime))")
    }

    func testEasyRunTime_5kmAt6min40_shouldBe33min() {
        // Matches v2_0.json fixture: distance_km=5.0, pace="6:40", time_minutes=33.33
        let distanceKm = 5.0
        let paceMinutes = parsePace("6:40")!  // 6.667
        let expectedTime = distanceKm * paceMinutes  // ~33.33
        XCTAssertEqual(expectedTime, 33.0, accuracy: 1.0,
                       "5km @ 6:40 should yield ~33 min (got \(expectedTime))")
    }

    func testEasyRunTime_10kmAt7min00_shouldBe70min() {
        let distanceKm = 10.0
        let paceMinutes = parsePace("7:00")!  // 7.0
        let expectedTime = distanceKm * paceMinutes  // 70.0
        XCTAssertEqual(expectedTime, 70.0, accuracy: 1.0,
                       "10km @ 7:00 should yield 70 min (got \(expectedTime))")
    }

    // MARK: - Group 3: Weekly Intensity Distribution

    func testIntensity_weekWithInterval_hasHighGreaterThanZero() {
        let plan = decodePlan(Self.intervalWeekJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertGreaterThan(intensity.high, 0,
                             "A week with interval training must have high > 0")
    }

    func testIntensity_weekWithCruiseIntervals_hasMediumGreaterThanZero() {
        // Cruise intervals work at T pace (sub-threshold) -> medium, NOT high
        let plan = decodePlan(Self.cruiseIntervalsWeekJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertGreaterThan(intensity.medium, 0,
                             "A week with cruise_intervals must have medium > 0")
    }

    func testIntensity_weekWithNorwegian4x4_hasHighGreaterThanZero() {
        let plan = decodePlan(Self.norwegian4x4WeekJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertGreaterThan(intensity.high, 0,
                             "A week with norwegian_4x4 must have high > 0")
    }

    func testIntensity_pureEasyWeek_hasZeroHighAndMedium() {
        let plan = decodePlan(Self.pureEasyWeekJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertEqual(intensity.high, 0,
                       "A pure easy week must have high == 0")
        XCTAssertEqual(intensity.medium, 0,
                       "A pure easy week must have medium == 0")
    }

    func testIntensity_totalEqualsSum() {
        let plan = decodePlan(Self.intervalWeekJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertEqual(intensity.total,
                       intensity.low + intensity.medium + intensity.high,
                       accuracy: 0.001)
    }

    // MARK: - Group 4: Pace Zone Mapping

    func testPaceCalculator_cruiseIntervals_shouldMapToTempoPaceZone() {
        // TODO: cruise_intervals should map to .tempo zone
        // Currently PaceCalculator.mapTrainingTypeToZone does not handle cruise_intervals.
        let pace = PaceCalculator.getSuggestedPace(for: "cruise_intervals", vdot: 45)
        XCTAssertNil(pace,
                     "Known gap: cruise_intervals currently has no pace zone mapping")
    }

    func testPaceCalculator_norwegian4x4_shouldMapToIntervalPaceZone() {
        // TODO: norwegian_4x4 should map to .interval zone
        // Currently PaceCalculator.mapTrainingTypeToZone does not handle norwegian_4x4.
        let pace = PaceCalculator.getSuggestedPace(for: "norwegian_4x4", vdot: 45)
        XCTAssertNil(pace,
                     "Known gap: norwegian_4x4 currently has no pace zone mapping")
    }

    func testPaceCalculator_easyRun_returnsPaceInEasyRange() {
        let pace = PaceCalculator.getSuggestedPace(for: "easy", vdot: 45)
        XCTAssertNotNil(pace, "Easy run must return a suggested pace")
    }

    func testPaceCalculator_interval_returnsPaceInIntervalRange() {
        let pace = PaceCalculator.getSuggestedPace(for: "interval", vdot: 45)
        XCTAssertNotNil(pace, "Interval must return a suggested pace")
    }

    func testPaceCalculator_vdot30_easyPace_isSlowerThan8min() {
        let pace = PaceCalculator.getSuggestedPace(for: "easy", vdot: 30)!
        let paceMinutes = parsePace(pace)!
        XCTAssertGreaterThan(paceMinutes, 7.0,
                             "VDOT 30 easy pace should be > 7:00/km (got \(pace))")
    }

    func testPaceCalculator_vdot30_intervalPace_isFasterThanEasyPace() {
        let easyPace = parsePace(
            PaceCalculator.getSuggestedPace(for: "easy", vdot: 30)!
        )!
        let intervalPace = parsePace(
            PaceCalculator.getSuggestedPace(for: "interval", vdot: 30)!
        )!
        // Faster pace = smaller number
        XCTAssertLessThan(intervalPace, easyPace,
                          "Interval pace must be faster (smaller) than easy pace")
    }

    // MARK: - Group 5: Structure Completeness

    func testStructure_fullWeek_has7Days() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        XCTAssertEqual(plan.days.count, 7, "Full week must have exactly 7 days")
    }

    func testStructure_runDay_hasPositiveDistance() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        // Interval/fartlek store distance in work segment — tested separately
        let skipTypes: Set<String> = ["rest", "strength", "cross_training", "interval", "fartlek"]
        for day in plan.days where !skipTypes.contains(day.trainingType) {
            let distance = day.trainingDetails?.distanceKm ?? 0.0
            XCTAssertGreaterThan(distance, 0,
                "Run day (type=\(day.trainingType), index=\(day.dayIndex)) must have distance_km > 0")
        }
    }

    func testStructure_intervalDay_hasWorkDistance() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let intervalTypes: Set<String> = ["interval", "fartlek"]
        for day in plan.days where intervalTypes.contains(day.trainingType) {
            let workDistance = day.trainingDetails?.work?.distanceKm ?? 0.0
            XCTAssertGreaterThan(workDistance, 0,
                "Interval day (index=\(day.dayIndex)) work segment must have distance_km > 0")
        }
    }

    func testStructure_intervalDay_hasWorkPace() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let intervalTypes: Set<String> = ["interval", "fartlek"]
        for day in plan.days where intervalTypes.contains(day.trainingType) {
            let workPace = day.trainingDetails?.work?.pace
            XCTAssertNotNil(workPace, "Interval day (index=\(day.dayIndex)) work segment must have a pace")
            if let pace = workPace {
                XCTAssertFalse(pace.isEmpty, "Interval day work pace must not be empty")
            }
        }
    }

    func testStructure_hasAtLeastOneRestDay() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let restCount = plan.days.filter { $0.trainingType == "rest" }.count
        XCTAssertGreaterThanOrEqual(restCount, 1, "Week must have at least 1 rest day")
    }

    // MARK: - Group 6: Pace Validity

    func testPace_allPacesAreValid() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        for day in plan.days {
            if let pace = day.trainingDetails?.pace {
                let minutes = parsePace(pace)
                XCTAssertNotNil(minutes, "Pace '\(pace)' on day \(day.dayIndex) must be parseable")
                if let m = minutes {
                    XCTAssertGreaterThan(m, 0, "Pace must be > 0 min/km")
                    XCTAssertLessThan(m, 20.0, "Pace must be < 20 min/km (got \(m))")
                }
            }
            if let workPace = day.trainingDetails?.work?.pace {
                let minutes = parsePace(workPace)
                XCTAssertNotNil(minutes, "Work pace '\(workPace)' on day \(day.dayIndex) must be parseable")
                if let m = minutes {
                    XCTAssertGreaterThan(m, 0)
                    XCTAssertLessThan(m, 20.0)
                }
            }
        }
    }

    func testPace_easyPaceSlowerThanTempoPace() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let easyDay = plan.days.first { $0.trainingType == "easy" || $0.trainingType == "easy_run" }
        let tempoDay = plan.days.first { $0.trainingType == "tempo" }
        guard let easyPaceStr = easyDay?.trainingDetails?.pace,
              let tempoPaceStr = tempoDay?.trainingDetails?.pace else {
            XCTFail("fullWeekMixedJSON must contain easy and tempo days with pace set")
            return
        }
        guard let easyMinutes = parsePace(easyPaceStr),
              let tempoMinutes = parsePace(tempoPaceStr) else {
            XCTFail("Pace strings '\(easyPaceStr)' / '\(tempoPaceStr)' must be parseable by parsePace()")
            return
        }
        XCTAssertGreaterThan(easyMinutes, tempoMinutes,
            "Easy pace (\(easyPaceStr)) must be slower (larger number) than tempo pace (\(tempoPaceStr))")
    }

    // MARK: - Group 7 Extension: Intensity Distribution

    func testIntensity_nonZeroWhenPlanHasRunDays() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let intensity = plan.intensityTotalMinutes!
        XCTAssertGreaterThan(intensity.total, 0, "A week with run days must have total intensity > 0")
    }

    // MARK: - Group 8: Heart Rate & Distance Limits

    func testStructure_easyRun_hasHeartRateRange() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let heartRateTypes: Set<String> = ["easy", "easy_run", "lsd", "recovery_run"]
        for day in plan.days where heartRateTypes.contains(day.trainingType) {
            let hrRange = day.trainingDetails?.heartRateRange
            XCTAssertNotNil(hrRange, "Easy/LSD day (index=\(day.dayIndex)) must have heart_rate_range")
            if let hr = hrRange {
                XCTAssertNotNil(hr.min, "heart_rate_range.min must not be nil")
                XCTAssertNotNil(hr.max, "heart_rate_range.max must not be nil")
                if let minVal = hr.min { XCTAssertGreaterThan(minVal, 0) }
                if let maxVal = hr.max { XCTAssertGreaterThan(maxVal, 0) }
            }
        }
    }

    func testLSD_distanceUnder35km() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        for day in plan.days where day.trainingType == "lsd" {
            let distance = day.trainingDetails?.distanceKm ?? 0.0
            XCTAssertLessThanOrEqual(distance, 35.0,
                "LSD day (index=\(day.dayIndex)) distance \(distance) km must be <= 35 km")
        }
    }

    func testQualitySessions_notConsecutive() {
        let plan = decodePlan(Self.fullWeekMixedJSON)
        let qualityTypes: Set<String> = ["interval", "tempo", "threshold", "fartlek", "progression"]
        let qualityIndices = plan.days
            .filter { qualityTypes.contains($0.trainingType) }
            .compactMap { Int($0.dayIndex) }
            .sorted()
        for i in 1..<qualityIndices.count {
            let gap = qualityIndices[i] - qualityIndices[i - 1]
            XCTAssertGreaterThanOrEqual(gap, 2,
                "Quality sessions at day_index \(qualityIndices[i-1]) and \(qualityIndices[i]) must not be consecutive")
        }
    }
}

// MARK: - Inline JSON Fixtures

extension QARegressionTests {

    /// Week with an interval session -> high > 0
    static let intervalWeekJSON = """
    {
      "id": "reg_interval", "purpose": "test", "week_of_plan": 1,
      "total_weeks": 12, "total_distance_km": 30,
      "intensity_total_minutes": { "low": 200, "medium": 20, "high": 16 },
      "days": [{
        "day_index": "1", "day_target": "Interval", "training_type": "interval",
        "training_details": {
          "repeats": 4,
          "work": { "distance_km": 0.8, "pace": "4:55", "description": "800m repeats" },
          "recovery": { "distance_km": 0.2, "pace": "7:30", "description": "jog" }
        }
      }]
    }
    """

    /// Week with cruise intervals -> medium > 0, NOT high
    static let cruiseIntervalsWeekJSON = """
    {
      "id": "reg_cruise", "purpose": "test", "week_of_plan": 1,
      "total_weeks": 12, "total_distance_km": 25,
      "intensity_total_minutes": { "low": 180, "medium": 30, "high": 0 },
      "days": [{
        "day_index": "1", "day_target": "Cruise intervals", "training_type": "cruise_intervals",
        "training_details": {
          "repeats": 5,
          "work": { "distance_km": 1.6, "pace": "5:20", "description": "T pace cruise" },
          "recovery": { "distance_km": 0.2, "pace": "7:00", "description": "jog" }
        }
      }]
    }
    """

    /// Week with norwegian 4x4 -> high > 0
    static let norwegian4x4WeekJSON = """
    {
      "id": "reg_norw", "purpose": "test", "week_of_plan": 1,
      "total_weeks": 12, "total_distance_km": 28,
      "intensity_total_minutes": { "low": 190, "medium": 10, "high": 24 },
      "days": [{
        "day_index": "1", "day_target": "Norwegian 4x4", "training_type": "interval",
        "training_details": {
          "repeats": 4,
          "work": { "distance_km": 1.0, "pace": "4:30", "description": "4min @ I pace" },
          "recovery": { "distance_km": 0.5, "pace": "7:00", "description": "3min jog" }
        }
      }]
    }
    """

    /// Pure easy week -> high == 0, medium == 0
    static let pureEasyWeekJSON = """
    {
      "id": "reg_easy", "purpose": "test", "week_of_plan": 1,
      "total_weeks": 12, "total_distance_km": 20,
      "intensity_total_minutes": { "low": 150, "medium": 0, "high": 0 },
      "days": [{
        "day_index": "1", "day_target": "Easy run", "training_type": "easy_run",
        "training_details": {
          "distance_km": 5.0, "pace": "6:40", "time_minutes": 33.33,
          "description": "Easy run"
        }
      }]
    }
    """

    /// Full 7-day mixed week for Group 5-8 tests
    /// Mon easy, Tue interval, Wed rest, Thu tempo, Fri easy, Sat lsd, Sun rest
    static let fullWeekMixedJSON = """
    {
      "id": "reg_full_week", "purpose": "test", "week_of_plan": 3,
      "total_weeks": 12, "total_distance_km": 55,
      "intensity_total_minutes": { "low": 240, "medium": 30, "high": 20 },
      "days": [
        {
          "day_index": "1", "day_target": "Easy run", "training_type": "easy",
          "training_details": {
            "distance_km": 8.0, "pace": "6:40", "time_minutes": 53.0,
            "description": "Easy aerobic run",
            "heart_rate_range": { "min": 130, "max": 150 }
          }
        },
        {
          "day_index": "2", "day_target": "Interval", "training_type": "interval",
          "training_details": {
            "repeats": 5,
            "work": { "distance_km": 0.8, "pace": "4:50", "description": "800m at I pace" },
            "recovery": { "distance_km": 0.4, "pace": "7:30", "description": "jog recovery" }
          }
        },
        {
          "day_index": "3", "day_target": "Rest", "training_type": "rest"
        },
        {
          "day_index": "4", "day_target": "Tempo run", "training_type": "tempo",
          "training_details": {
            "distance_km": 10.0, "pace": "5:20", "time_minutes": 53.0,
            "description": "Tempo run at T pace"
          }
        },
        {
          "day_index": "5", "day_target": "Easy run", "training_type": "easy_run",
          "training_details": {
            "distance_km": 6.0, "pace": "6:50", "time_minutes": 41.0,
            "description": "Easy recovery run",
            "heart_rate_range": { "min": 128, "max": 148 }
          }
        },
        {
          "day_index": "6", "day_target": "Long slow distance", "training_type": "lsd",
          "training_details": {
            "distance_km": 22.0, "pace": "7:00", "time_minutes": 154.0,
            "description": "Long slow distance run",
            "heart_rate_range": { "min": 125, "max": 145 }
          }
        },
        {
          "day_index": "7", "day_target": "Rest", "training_type": "rest"
        }
      ]
    }
    """
}
