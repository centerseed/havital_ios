import XCTest
@testable import paceriz_dev

/// Tests WeeklyPlanV2Mapper and TrainingSessionMapper DTO-to-Entity conversion.
/// Validates that all fields are correctly mapped, especially:
/// - ID resolution logic (planId > id > overviewId_N)
/// - Date parsing (ISO8601 with/without fractional seconds)
/// - Exercise reps/repsRange conversion
/// - DayDetail session extraction
final class WeeklyPlanV2MapperTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklyPlan/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodeAndMap(from fixtureName: String) throws -> WeeklyPlanV2 {
        let data = try loadFixture(fixtureName)
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private func decodeAndMap(json: String) throws -> WeeklyPlanV2 {
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: Data(json.utf8))
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    // MARK: - ID Resolution

    func test_mapper_idResolution_planIdTakesPrecedence() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        // planId exists -> should be used as both planId and id
        XCTAssertEqual(entity.planId, "overview_001_3")
        XCTAssertEqual(entity.id, "overview_001_3")
    }

    func test_mapper_idResolution_fallbackToId() throws {
        let entity = try decodeAndMap(from: "missing_optional_fields")

        // No planId -> should use id field (which also doesn't exist, so overviewId_N fallback)
        // In this fixture, neither planId nor id nor overviewId exist -> UUID
        XCTAssertFalse(entity.id.isEmpty)
    }

    // MARK: - Core Field Mapping

    func test_mapper_coreFields() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        XCTAssertEqual(entity.purpose, "Build aerobic base with progressive mileage increase")
        XCTAssertEqual(entity.weekOfTraining, 3)
        XCTAssertEqual(entity.weekOfPlan, 3)
        XCTAssertEqual(entity.totalWeeks, 16)
        XCTAssertEqual(entity.totalDistance ?? -1, 45.5, accuracy: 0.01)
        XCTAssertEqual(entity.designReason?.count, 2)
        XCTAssertEqual(entity.apiVersion, "2.0")
    }

    // MARK: - Date Parsing

    func test_mapper_dateParsingWithFractionalSeconds() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        // "2026-01-21T15:24:26.194000+00:00" should parse correctly
        XCTAssertNotNil(entity.createdAt)
        XCTAssertNotNil(entity.updatedAt)
    }

    func test_mapper_dateParsingStandardISO8601() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_peak_week")

        // "2026-03-15T10:00:00Z" should parse correctly
        XCTAssertNotNil(entity.createdAt)
    }

    // MARK: - DayDetail Mapping

    func test_mapper_dayDetailMapping_runDay() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        let day1 = entity.days[0]
        XCTAssertEqual(day1.dayIndex, 1)
        XCTAssertEqual(day1.dayTarget, "Easy recovery run")
        XCTAssertEqual(day1.tips, "Keep heart rate in Zone 2")
        XCTAssertEqual(day1.category, .run)

        // Session should be created from flat primary
        XCTAssertNotNil(day1.session)
        if case .run(let runActivity) = day1.session?.primary {
            XCTAssertEqual(runActivity.runType, "easy")
            XCTAssertEqual(runActivity.distanceKm, 6.0)
        } else {
            XCTFail("Day 1 session primary should be .run")
        }
    }

    func test_mapper_dayDetailMapping_restDay() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        let day2 = entity.days[1]
        XCTAssertEqual(day2.dayIndex, 2)
        XCTAssertNil(day2.session)
        // category can be nil for rest days without explicit category
        // OR .rest if category was specified
    }

    func test_mapper_dayDetailMapping_warmupCooldown() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        let day3 = entity.days[2]
        XCTAssertNotNil(day3.session?.warmup)
        XCTAssertNotNil(day3.session?.cooldown)
        XCTAssertEqual(day3.session?.warmup?.distanceKm, 2.0)
        XCTAssertEqual(day3.session?.cooldown?.distanceKm, 1.5)
    }

    func test_mapper_completeDailyDistances_sumToWeeklyMileage() throws {
        let entity = try decodeAndMap(json: """
        {
          "purpose": "interval week",
          "total_distance_km": 99.0,
          "days": [
            {
              "day_index": 1,
              "day_target": "interval",
              "reason": "quality",
              "distance_km": 6.0,
              "primary": {"run_type": "interval", "distance_km": 2.84},
              "warmup": {"distance_km": 1.58},
              "cooldown": {"distance_km": 1.58}
            },
            {
              "day_index": 2,
              "day_target": "rest",
              "reason": "recovery",
              "distance_km": 0.0,
              "category": "rest"
            },
            {
              "day_index": 3,
              "day_target": "easy",
              "reason": "aerobic",
              "distance_km": 2.0,
              "primary": {"run_type": "easy", "distance_km": 2.0}
            }
          ]
        }
        """)

        XCTAssertEqual(entity.days[0].distanceKm ?? -1.0, 6.0, accuracy: 0.001)
        XCTAssertEqual(entity.days[1].distanceKm ?? -1.0, 0.0, accuracy: 0.001)
        XCTAssertEqual(entity.days[2].distanceKm ?? -1.0, 2.0, accuracy: 0.001)
        XCTAssertEqual(entity.totalDistance ?? -1.0, 8.0, accuracy: 0.001)
    }

    func test_mapper_runDayMissingDailyDistance_makesWeeklyMileageUnknown() throws {
        let entity = try decodeAndMap(json: """
        {
          "purpose": "incomplete interval week",
          "total_distance_km": 99.0,
          "days": [
            {
              "day_index": 1,
              "day_target": "interval",
              "reason": "quality",
              "distance_km": 6.0,
              "primary": {"run_type": "interval", "distance_km": 2.84}
            },
            {
              "day_index": 2,
              "day_target": "easy",
              "reason": "aerobic",
              "distance_km": 2.0,
              "primary": {"run_type": "easy", "distance_km": 2.0}
            },
            {
              "day_index": 3,
              "day_target": "missing",
              "reason": "missing day distance",
              "category": "run",
              "primary": {"run_type": "easy", "distance_km": 8.0}
            }
          ]
        }
        """)

        XCTAssertNil(entity.days[2].distanceKm)
        XCTAssertNil(entity.totalDistance, "部分日量不得冒充完整週量或退回 top-level total_distance_km")
    }

    func test_mapper_restDayZero_isKnownWeeklyMileageInput() throws {
        let entity = try decodeAndMap(json: """
        {
          "purpose": "rest week",
          "total_distance_km": 99.0,
          "days": [
            {
              "day_index": 1,
              "day_target": "rest",
              "reason": "recovery",
              "distance_km": 0.0,
              "category": "rest"
            },
            {
              "day_index": 2,
              "day_target": "easy",
              "reason": "aerobic",
              "distance_km": 5.0,
              "primary": {"run_type": "easy", "distance_km": 5.0}
            }
          ]
        }
        """)

        XCTAssertEqual(entity.days[0].distanceKm, 0.0)
        XCTAssertEqual(entity.totalDistance ?? -1.0, 5.0, accuracy: 0.001)
    }

    // MARK: - Exercise Reps Conversion

    func test_mapper_exerciseRepsConversion_intToString() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        // Day 5: strength with exercises
        let day5 = entity.days[4]
        guard let session = day5.session,
              case .strength(let strengthActivity) = session.primary else {
            XCTFail("Day 5 should have strength session")
            return
        }

        // DTO reps=10 -> Entity reps="10"
        let squat = strengthActivity.exercises[0]
        XCTAssertEqual(squat.reps, "10")
        XCTAssertEqual(squat.weightKg, 40.0)

        // DTO repsRange="8-12" -> Entity reps="8-12" (repsRange takes precedence)
        let lunges = strengthActivity.exercises[1]
        XCTAssertEqual(lunges.reps, "8-12")
    }

    // MARK: - Interval Block Mapping

    func test_mapper_intervalBlockMapping() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_peak_week")

        let day2 = entity.days[1]
        guard let session = day2.session,
              case .run(let runActivity) = session.primary else {
            XCTFail("Day 2 should have run session")
            return
        }

        XCTAssertNotNil(runActivity.interval)
        XCTAssertEqual(runActivity.interval?.repeats, 5)
        XCTAssertEqual(runActivity.interval?.workDistanceKm, 1.0)
        XCTAssertEqual(runActivity.interval?.workPace, "4:10")
        XCTAssertEqual(runActivity.interval?.recoveryDistanceKm, 0.4)
    }

    func test_mapper_climateFieldsPreservedAndEffectivePacePrefersAdjusted() throws {
        let entity = try decodeAndMap(from: "climate_adjusted_week")

        let day1 = entity.days[0]
        XCTAssertEqual(day1.climateMeta?.heatPressureLevel, "high")
        XCTAssertEqual(day1.effectiveClimateMeta?.reasonText, "High heat stress, slow the pace and shorten recovery.")

        guard let session = day1.session,
              case .run(let runActivity) = session.primary else {
            XCTFail("Day 1 should have run session")
            return
        }

        // commit 45c8838: effectivePace = raw basePace (heat adjustment only applies on temperature card,
        // not baked into effectivePace). climateAdjustedPace field is still mapped and preserved.
        XCTAssertEqual(runActivity.basePace, "5:00")
        XCTAssertEqual(runActivity.climateAdjustedPace, "5:18", "climateAdjustedPace must still be mapped from DTO")
        XCTAssertEqual(runActivity.effectivePace, "5:00", "effectivePace equals raw basePace (commit 45c8838)")
        XCTAssertEqual(runActivity.climateMeta?.longRunReductionPct ?? 0, 25.0, accuracy: 0.01)
        XCTAssertEqual(runActivity.segments?.first?.effectivePace, "4:55", "segment effectivePace equals segment basePace")
    }

    // MARK: - Imperial Units Preserved

    func test_mapper_imperialUnitsPreserved() throws {
        let entity = try decodeAndMap(from: "polarized_42k_build_week")

        XCTAssertEqual(entity.totalDistanceDisplay ?? 0, 34.18, accuracy: 0.01)
        XCTAssertEqual(entity.totalDistanceUnit, "miles")
    }

    // MARK: - Computed Properties

    func test_entity_effectiveWeek() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        XCTAssertEqual(entity.effectiveWeek, 3)
    }

    func test_entity_effectivePlanId() throws {
        let entity = try decodeAndMap(from: "paceriz_42k_base_week")

        XCTAssertEqual(entity.effectivePlanId, "overview_001_3")
    }
}
