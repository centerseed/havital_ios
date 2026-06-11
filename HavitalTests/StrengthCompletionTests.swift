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
}
