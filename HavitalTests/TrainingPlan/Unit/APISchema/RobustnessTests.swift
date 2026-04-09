import XCTest
@testable import paceriz_dev

/// Tests forward compatibility and robustness of DTO decoding.
/// Validates the system handles edge cases gracefully:
/// - Extra unknown fields (forward compatibility)
/// - Missing optional fields
/// - Empty arrays
/// - PrimaryActivityDTO type discrimination
final class RobustnessTests: XCTestCase {

    // MARK: - Extra Unknown Fields (Forward Compatibility)

    func test_extraUnknownFields_decodingSucceeds() throws {
        // JSON with extra fields that don't exist in the DTO
        let json = """
        {
            "purpose": "Test forward compatibility",
            "total_distance_km": 30.0,
            "some_future_field": "should be ignored",
            "another_new_field": 42,
            "nested_future": { "key": "value" },
            "days": [
                {
                    "day_index": 1,
                    "day_target": "Easy run",
                    "reason": "Test",
                    "future_day_field": true,
                    "primary": {
                        "run_type": "easy",
                        "distance_km": 5.0,
                        "duration_minutes": 30,
                        "pace": "6:00",
                        "future_run_field": "ignored"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: json)
        XCTAssertEqual(dto.purpose, "Test forward compatibility")
        XCTAssertEqual(dto.totalDistance, 30.0)
        XCTAssertEqual(dto.days.count, 1)
    }

    // MARK: - Empty Arrays

    func test_emptyDaysArray_decodingSucceeds() throws {
        let json = """
        {
            "purpose": "Empty days test",
            "total_distance_km": 0.0,
            "days": []
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: json)
        XCTAssertEqual(dto.days.count, 0)
    }

    func test_emptyDesignReason_decodingSucceeds() throws {
        let json = """
        {
            "purpose": "Empty design reason",
            "total_distance_km": 20.0,
            "design_reason": [],
            "days": [
                {
                    "day_index": 1,
                    "day_target": "Rest",
                    "reason": "Recovery"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: json)
        XCTAssertEqual(dto.designReason?.count, 0)
    }

    func test_emptyExercisesArray_decodingSucceeds() throws {
        let json = """
        {
            "purpose": "Empty exercises",
            "total_distance_km": 0.0,
            "days": [
                {
                    "day_index": 1,
                    "day_target": "Strength",
                    "reason": "Test",
                    "category": "strength",
                    "primary": {
                        "strength_type": "core",
                        "exercises": [],
                        "duration_minutes": 20
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: json)
        if case .strength(let activity) = dto.days[0].primary {
            XCTAssertEqual(activity.exercises.count, 0)
        } else {
            XCTFail("Primary should be strength")
        }
    }

    // MARK: - Missing Optional Fields

    func test_allOptionalsNil_decodingSucceeds() throws {
        let json = """
        {
            "purpose": "Bare minimum",
            "total_distance_km": 0.0,
            "days": [
                {
                    "day_index": 1,
                    "day_target": "Rest",
                    "reason": "Recovery"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: json)

        XCTAssertNil(dto.planId)
        XCTAssertNil(dto.overviewId)
        XCTAssertNil(dto.weekOfTraining)
        XCTAssertNil(dto.id)
        XCTAssertNil(dto.weekOfPlan)
        XCTAssertNil(dto.totalWeeks)
        XCTAssertNil(dto.totalDistanceDisplay)
        XCTAssertNil(dto.totalDistanceUnit)
        XCTAssertNil(dto.totalDistanceReason)
        XCTAssertNil(dto.designReason)
        XCTAssertNil(dto.intensityTotalMinutes)
        XCTAssertNil(dto.createdAt)
        XCTAssertNil(dto.updatedAt)
        XCTAssertNil(dto.trainingLoadAnalysis)
        XCTAssertNil(dto.personalizedRecommendations)
        XCTAssertNil(dto.realTimeAdjustments)
        XCTAssertNil(dto.stageId)
        XCTAssertNil(dto.methodologyId)
        XCTAssertNil(dto.dataVersion)
        XCTAssertNil(dto.apiVersion)
    }

    // MARK: - PrimaryActivityDTO Type Discrimination

    func test_primaryActivity_runTypeDiscrimination() throws {
        let json = """
        {
            "run_type": "easy",
            "distance_km": 5.0,
            "duration_minutes": 30,
            "pace": "6:00"
        }
        """.data(using: .utf8)!

        let activity = try JSONDecoder().decode(PrimaryActivityDTO.self, from: json)
        if case .run(let runActivity) = activity {
            XCTAssertEqual(runActivity.runType, "easy")
            XCTAssertEqual(runActivity.distanceKm, 5.0)
        } else {
            XCTFail("Should decode as .run")
        }
    }

    func test_primaryActivity_strengthTypeDiscrimination() throws {
        let json = """
        {
            "strength_type": "runner_specific",
            "exercises": [
                { "name": "Squat", "sets": 3, "reps": 10 }
            ],
            "duration_minutes": 30
        }
        """.data(using: .utf8)!

        let activity = try JSONDecoder().decode(PrimaryActivityDTO.self, from: json)
        if case .strength(let strengthActivity) = activity {
            XCTAssertEqual(strengthActivity.strengthType, "runner_specific")
            XCTAssertEqual(strengthActivity.exercises.count, 1)
        } else {
            XCTFail("Should decode as .strength")
        }
    }

    func test_primaryActivity_crossTypeDiscrimination() throws {
        let json = """
        {
            "cross_type": "cycling",
            "duration_minutes": 45,
            "intensity": "low"
        }
        """.data(using: .utf8)!

        let activity = try JSONDecoder().decode(PrimaryActivityDTO.self, from: json)
        if case .cross(let crossActivity) = activity {
            XCTAssertEqual(crossActivity.crossType, "cycling")
            XCTAssertEqual(crossActivity.durationMinutes, 45)
        } else {
            XCTFail("Should decode as .cross")
        }
    }

    // MARK: - PlanOverviewV2DTO createdAt Multi-Type

    func test_planOverview_createdAtAsString() throws {
        let json = """
        {
            "id": "test_1",
            "target_type": "race_run",
            "total_weeks": 10,
            "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: json)
        XCTAssertEqual(dto.createdAt, "2026-01-01T00:00:00Z")
    }

    func test_planOverview_createdAtAsInt_decodesSuccessfully() throws {
        let json = """
        {
            "id": "test_2",
            "target_type": "race_run",
            "total_weeks": 10,
            "created_at": 1704067200
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: json)
        XCTAssertEqual(dto.createdAt, "1704067200")
    }

    // MARK: - PlanStatus Forward Compatibility

    func test_planStatus_extraFields_ignored() throws {
        let json = """
        {
            "current_week": 1,
            "total_weeks": 12,
            "next_action": "view_plan",
            "can_generate_next_week": false,
            "future_status_field": "ignored",
            "new_section": { "data": 123 }
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PlanStatusV2Response.self, from: json)
        XCTAssertEqual(dto.currentWeek, 1)
        XCTAssertEqual(dto.nextAction, "view_plan")
    }

    // MARK: - WeeklyPreview Forward Compatibility

    func test_weekPreview_minimalWeek_decodesSuccessfully() throws {
        let json = """
        {
            "plan_id": "test",
            "methodology_id": "paceriz",
            "weeks": [
                {
                    "week": 1,
                    "stage_id": "base",
                    "target_km": 30.0
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(WeeklyPreviewResponseDTO.self, from: json)
        XCTAssertEqual(dto.weeks.count, 1)
        XCTAssertEqual(dto.weeks[0].week, 1)
        XCTAssertNil(dto.weeks[0].isRecovery)
        XCTAssertNil(dto.weeks[0].qualityOptions)
        XCTAssertNil(dto.weeks[0].longRun)
        XCTAssertNil(dto.weeks[0].intensityRatio)
    }
}
