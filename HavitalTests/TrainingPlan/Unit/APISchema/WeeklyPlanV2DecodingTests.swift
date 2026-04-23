import XCTest
@testable import paceriz_dev

/// Tests that WeeklyPlanV2DTO correctly decodes real API JSON responses.
/// Validates every CodingKey mapping and field type.
final class WeeklyPlanV2DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/WeeklyPlan") else {
            // Fallback: try loading from file path relative to test target
            let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklyPlan/\(name).json")
            return try Data(contentsOf: fixtureURL)
        }
        return try Data(contentsOf: url)
    }

    private func decodeWeeklyPlan(from fixtureName: String) throws -> WeeklyPlanV2DTO {
        let data = try loadFixture(fixtureName)
        return try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: data)
    }

    // MARK: - Paceriz 42K Base Week

    func test_decode_paceriz42kBaseWeek_allFieldsPopulated() throws {
        let dto = try decodeWeeklyPlan(from: "paceriz_42k_base_week")

        XCTAssertEqual(dto.planId, "overview_001_3")
        XCTAssertEqual(dto.overviewId, "overview_001")
        XCTAssertEqual(dto.weekOfTraining, 3)
        XCTAssertEqual(dto.id, "plan_legacy_id")
        XCTAssertEqual(dto.purpose, "Build aerobic base with progressive mileage increase")
        XCTAssertEqual(dto.weekOfPlan, 3)
        XCTAssertEqual(dto.totalWeeks, 16)
        XCTAssertEqual(dto.totalDistance, 45.0, accuracy: 0.01)
        XCTAssertNil(dto.totalDistanceDisplay)
        XCTAssertNil(dto.totalDistanceUnit)
        XCTAssertNotNil(dto.totalDistanceReason)
        XCTAssertEqual(dto.designReason?.count, 2)
        XCTAssertEqual(dto.days.count, 7)
        XCTAssertEqual(dto.methodologyId, "paceriz")
        XCTAssertEqual(dto.stageId, "base")
        XCTAssertEqual(dto.apiVersion, "2.0")
        XCTAssertNotNil(dto.createdAt)
        XCTAssertNotNil(dto.updatedAt)
    }

    func test_decode_paceriz42kBaseWeek_dayDetailsCorrect() throws {
        let dto = try decodeWeeklyPlan(from: "paceriz_42k_base_week")

        // Day 1: easy run
        let day1 = dto.days[0]
        XCTAssertEqual(day1.dayIndex, 1)
        XCTAssertEqual(day1.dayTarget, "Easy recovery run")
        XCTAssertEqual(day1.category, "run")

        if case .run(let runActivity) = day1.primary {
            XCTAssertEqual(runActivity.runType, "easy")
            XCTAssertEqual(runActivity.distanceKm, 6.0)
            XCTAssertEqual(runActivity.durationMinutes, 36)
            XCTAssertEqual(runActivity.pace, "6:00")
            XCTAssertEqual(runActivity.heartRateRange?.min, 130)
            XCTAssertEqual(runActivity.heartRateRange?.max, 145)
            XCTAssertEqual(runActivity.targetIntensity, "low")
        } else {
            XCTFail("Day 1 primary should be .run")
        }

        // Day 2: rest
        let day2 = dto.days[1]
        XCTAssertEqual(day2.dayIndex, 2)
        XCTAssertNil(day2.primary)

        // Day 3: tempo with warmup/cooldown
        let day3 = dto.days[2]
        XCTAssertNotNil(day3.warmup)
        XCTAssertNotNil(day3.cooldown)
        XCTAssertEqual(day3.warmup?.distanceKm, 2.0)
        XCTAssertEqual(day3.cooldown?.distanceKm, 1.5)

        // Day 5: strength
        let day5 = dto.days[4]
        if case .strength(let strengthActivity) = day5.primary {
            XCTAssertEqual(strengthActivity.strengthType, "runner_specific")
            XCTAssertEqual(strengthActivity.exercises.count, 2)
            XCTAssertEqual(strengthActivity.durationMinutes, 45)

            // Exercise with reps (Int)
            let squat = strengthActivity.exercises[0]
            XCTAssertEqual(squat.name, "Barbell Squat")
            XCTAssertEqual(squat.reps, 10)
            XCTAssertEqual(squat.weightKg, 40.0)

            // Exercise with repsRange (String)
            let lunges = strengthActivity.exercises[1]
            XCTAssertEqual(lunges.name, "Walking Lunges")
            XCTAssertEqual(lunges.repsRange, "8-12")
            XCTAssertNil(lunges.reps)
        } else {
            XCTFail("Day 5 primary should be .strength")
        }
    }

    func test_decode_paceriz42kBaseWeek_intensityTotalMinutes() throws {
        let dto = try decodeWeeklyPlan(from: "paceriz_42k_base_week")

        XCTAssertNotNil(dto.intensityTotalMinutes)
        XCTAssertEqual(dto.intensityTotalMinutes?.low, 180)
        XCTAssertEqual(dto.intensityTotalMinutes?.medium, 40)
        XCTAssertEqual(dto.intensityTotalMinutes?.high, 0)
    }

    // MARK: - Peak Week (Intervals + Segments)

    func test_decode_peakWeek_intervalBlock() throws {
        let dto = try decodeWeeklyPlan(from: "paceriz_42k_peak_week")

        XCTAssertEqual(dto.totalDistance, 70.0, accuracy: 0.01)
        XCTAssertEqual(dto.weekOfTraining, 12)

        // Day 2: interval session
        let day2 = dto.days[1]
        if case .run(let runActivity) = day2.primary {
            XCTAssertEqual(runActivity.runType, "interval")
            XCTAssertNotNil(runActivity.interval)
            XCTAssertEqual(runActivity.interval?.repeats, 5)
            XCTAssertEqual(runActivity.interval?.workDistanceKm, 1.0)
            XCTAssertEqual(runActivity.interval?.workPace, "4:10")
            XCTAssertEqual(runActivity.interval?.recoveryDistanceKm, 0.4)
            XCTAssertEqual(runActivity.interval?.recoveryDurationMinutes, 2)
        } else {
            XCTFail("Day 2 primary should be .run with interval")
        }
    }

    func test_decode_peakWeek_progressionSegments() throws {
        let dto = try decodeWeeklyPlan(from: "paceriz_42k_peak_week")

        // Day 7: progression with segments
        let day7 = dto.days[6]
        if case .run(let runActivity) = day7.primary {
            XCTAssertEqual(runActivity.runType, "progression")
            XCTAssertNotNil(runActivity.segments)
            XCTAssertEqual(runActivity.segments?.count, 3)
            XCTAssertEqual(runActivity.segments?[0].distanceKm, 15.0)
            XCTAssertEqual(runActivity.segments?[0].pace, "6:00")
            XCTAssertEqual(runActivity.segments?[2].distanceKm, 5.0)
            XCTAssertEqual(runActivity.segments?[2].pace, "4:50")
        } else {
            XCTFail("Day 7 primary should be .run with segments")
        }
    }

    func test_decode_climateAdjustedWeek_climateFieldsDecodeCorrectly() throws {
        let dto = try decodeWeeklyPlan(from: "climate_adjusted_week")

        let day1 = dto.days[0]
        XCTAssertEqual(day1.climateMeta?.heatPressureLevel, "high")
        XCTAssertEqual(day1.climateMeta?.feelsLikeTempC ?? 0, 33.5, accuracy: 0.01)
        XCTAssertEqual(day1.climateMeta?.paceAdjustmentPct ?? 0, 6.0, accuracy: 0.01)
        XCTAssertEqual(day1.climateMeta?.longRunReductionPct ?? 0, 25.0, accuracy: 0.01)

        if case .run(let runActivity) = day1.primary {
            XCTAssertEqual(runActivity.basePace, "5:00")
            XCTAssertEqual(runActivity.climateAdjustedPace, "5:18")
            XCTAssertEqual(runActivity.climateMeta?.reasonText, "High heat stress, slow the pace and shorten recovery.")
            XCTAssertEqual(runActivity.segments?.count, 2)
            XCTAssertEqual(runActivity.segments?.first?.basePace, "4:55")
            XCTAssertEqual(runActivity.segments?.first?.climateAdjustedPace, "5:13")
            XCTAssertEqual(runActivity.segments?.first?.climateMeta?.heatPressureLevel, "high")
        } else {
            XCTFail("Day 1 primary should be .run")
        }
    }

    // MARK: - Polarized (Imperial Units)

    func test_decode_polarizedBuildWeek_imperialUnits() throws {
        let dto = try decodeWeeklyPlan(from: "polarized_42k_build_week")

        XCTAssertEqual(dto.totalDistanceDisplay ?? 0, 34.18, accuracy: 0.01)
        XCTAssertEqual(dto.totalDistanceUnit, "miles")

        // Check day-level distance display
        let day1 = dto.days[0]
        if case .run(let runActivity) = day1.primary {
            XCTAssertEqual(runActivity.distanceDisplay ?? 0, 4.97, accuracy: 0.01)
            XCTAssertEqual(runActivity.distanceUnit, "miles")
        } else {
            XCTFail("Day 1 should be run")
        }

        // Check interval work distance display
        let day2 = dto.days[1]
        if case .run(let runActivity) = day2.primary {
            XCTAssertEqual(runActivity.interval?.workDistanceDisplay ?? 0, 0.5, accuracy: 0.01)
            XCTAssertEqual(runActivity.interval?.workDistanceUnit, "miles")
        } else {
            XCTFail("Day 2 should be run with interval")
        }
    }

    // MARK: - Minimal Data

    func test_decode_minimalRestDayOnly_succeeds() throws {
        let dto = try decodeWeeklyPlan(from: "minimal_rest_day_only")

        XCTAssertEqual(dto.purpose, "Complete rest week")
        XCTAssertEqual(dto.totalDistance, 0.0, accuracy: 0.01)
        XCTAssertEqual(dto.days.count, 7)
        XCTAssertNil(dto.planId)
        XCTAssertNil(dto.overviewId)
        XCTAssertNil(dto.weekOfTraining)
        XCTAssertNil(dto.weekOfPlan)
        XCTAssertNil(dto.totalWeeks)
        XCTAssertNil(dto.intensityTotalMinutes)
        XCTAssertNil(dto.apiVersion)

        // All days should have no primary activity
        for day in dto.days {
            XCTAssertNil(day.primary, "Day \(day.dayIndex) should have no primary")
        }
    }

    func test_decode_missingOptionalFields_succeeds() throws {
        let dto = try decodeWeeklyPlan(from: "missing_optional_fields")

        XCTAssertEqual(dto.totalDistance, 25.0, accuracy: 0.01)
        XCTAssertNil(dto.planId)
        XCTAssertNil(dto.designReason)
        XCTAssertNil(dto.totalDistanceReason)
        XCTAssertNil(dto.intensityTotalMinutes)

        // Day 1 has category, Day 3 does not have category
        XCTAssertEqual(dto.days[0].category, "run")

        // Day 3 has no tips, no category
        let day3 = dto.days[2]
        XCTAssertNil(day3.tips)
        XCTAssertNil(day3.category)
    }

    // MARK: - Session Wrapper Format

    func test_decode_sessionWrapperFormat_extractsPrimaryFromSession() throws {
        let dto = try decodeWeeklyPlan(from: "session_wrapper_format")

        // Day 1: session wrapper format with supplementary
        let day1 = dto.days[0]
        XCTAssertNotNil(day1.primary, "Primary should be extracted from session wrapper")

        if case .run(let runActivity) = day1.primary {
            XCTAssertEqual(runActivity.runType, "easy")
            XCTAssertEqual(runActivity.distanceKm, 6.0)
        } else {
            XCTFail("Day 1 primary from session wrapper should be .run")
        }

        // Warmup/cooldown at day level, not in session
        XCTAssertNotNil(day1.warmup)
        XCTAssertNotNil(day1.cooldown)

        // Supplementary from session wrapper
        XCTAssertNotNil(day1.supplementary)
        XCTAssertEqual(day1.supplementary?.count, 1)
        if case .strength(let strengthActivity) = day1.supplementary?[0] {
            XCTAssertEqual(strengthActivity.strengthType, "core")
        } else {
            XCTFail("Supplementary should be strength")
        }
    }

    func test_decode_sessionWrapperFormat_flatAndWrappedCoexist() throws {
        let dto = try decodeWeeklyPlan(from: "session_wrapper_format")

        // Day 3: flat primary format
        let day3 = dto.days[2]
        XCTAssertNotNil(day3.primary)
        if case .run(let runActivity) = day3.primary {
            XCTAssertEqual(runActivity.runType, "interval")
        } else {
            XCTFail("Day 3 flat primary should be .run")
        }

        // Day 3: supplementary at flat level (cross/yoga)
        XCTAssertNotNil(day3.supplementary)
        if case .cross(let crossActivity) = day3.supplementary?[0] {
            XCTAssertEqual(crossActivity.crossType, "yoga")
        } else {
            XCTFail("Day 3 supplementary should be .cross (yoga)")
        }

        // Day 7: session wrapper without supplementary
        let day7 = dto.days[6]
        XCTAssertNotNil(day7.primary)
        if case .run(let runActivity) = day7.primary {
            XCTAssertEqual(runActivity.runType, "long_run")
        } else {
            XCTFail("Day 7 primary from session should be .run")
        }
    }
}
