import XCTest
@testable import paceriz_dev

final class StrengthCompletionTests: XCTestCase {

    func test_exerciseDTO_decodes_series_id() throws {
        let json = """
        {"exercise_id":"plank","series_id":"plank_series","name":"棒式","sets":3,"duration_seconds":45}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ExerciseDTO.self, from: json)
        XCTAssertEqual(dto.seriesId, "plank_series")
    }

    func test_mapper_carries_series_id_to_entity() {
        let dto = ExerciseDTO(
            exerciseId: "plank", name: "棒式", sets: 3, reps: nil, repsRange: nil,
            durationSeconds: 45, weightKg: nil, restSeconds: nil, description: nil,
            seriesId: "plank_series"
        )
        let entity = TrainingSessionMapper.toEntity(from: dto)
        XCTAssertEqual(entity.seriesId, "plank_series")
    }

    func test_exercise_without_series_id_decodes_nil() throws {
        let json = """
        {"exercise_id":"plank","name":"棒式","sets":3}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ExerciseDTO.self, from: json)
        XCTAssertNil(dto.seriesId)
    }

    func test_requestDTO_encodes_snake_case() throws {
        let req = StrengthCompletionRequestDTO(
            dayDate: "2026-06-12",
            strengthType: "core_stability",
            exercises: [
                StrengthExerciseStatusDTO(exerciseId: "plank", seriesId: "plank_series", status: "completed"),
                StrengthExerciseStatusDTO(exerciseId: "dead_bug", seriesId: "dead_bug_series", status: "skipped")
            ],
            overallRpe: 4,
            durationMinutes: 15,
            weeklyPlanId: "wp_1"
        )
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["day_date"] as? String, "2026-06-12")
        XCTAssertEqual(obj["strength_type"] as? String, "core_stability")
        XCTAssertEqual(obj["overall_rpe"] as? Int, 4)
        XCTAssertEqual(obj["weekly_plan_id"] as? String, "wp_1")
        let exs = obj["exercises"] as! [[String: Any]]
        XCTAssertEqual(exs[0]["exercise_id"] as? String, "plank")
        XCTAssertEqual(exs[0]["series_id"] as? String, "plank_series")
        XCTAssertEqual(exs[1]["status"] as? String, "skipped")
        XCTAssertNil(exs[0]["actual_sets"])
    }

    func test_responseDTO_maps_to_result_with_reason() throws {
        let json = """
        {"progress_updates":[{"series_id":"plank_series","previous_level":1,"new_level":2,"reason":"rpe_upgrade"}]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StrengthCompletionResponseDTO.self, from: json)
        let result = StrengthCompletionMapper.toEntity(from: dto)
        XCTAssertEqual(result.progressUpdates.count, 1)
        let u = result.progressUpdates[0]
        XCTAssertEqual(u.seriesId, "plank_series")
        XCTAssertEqual(u.previousLevel, 1)
        XCTAssertEqual(u.newLevel, 2)
        XCTAssertEqual(u.reason, .upgrade)
    }

    func test_empty_progress_updates_maps_to_empty() throws {
        let json = #"{"progress_updates":[]}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StrengthCompletionResponseDTO.self, from: json)
        let result = StrengthCompletionMapper.toEntity(from: dto)
        XCTAssertTrue(result.progressUpdates.isEmpty)
    }
}
