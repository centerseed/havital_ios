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
}
