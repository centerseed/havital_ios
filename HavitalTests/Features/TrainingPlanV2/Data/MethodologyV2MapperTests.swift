import XCTest
@testable import paceriz_dev

// MARK: - MethodologyV2MapperTests

final class MethodologyV2MapperTests: XCTestCase {

    // MARK: - toEntity Tests

    func test_toEntity_copiesAllFields() {
        // Given
        let dto = MethodologyV2DTO(
            id: "paceriz",
            name: "Paceriz Method",
            description: "A balanced training approach",
            targetTypes: ["race_run", "beginner"],
            phases: ["base", "build", "peak", "taper"],
            crossTrainingEnabled: true
        )

        // When
        let entity = MethodologyV2Mapper.toEntity(dto)

        // Then
        XCTAssertEqual(entity.id, "paceriz")
        XCTAssertEqual(entity.name, "Paceriz Method")
        XCTAssertEqual(entity.description, "A balanced training approach")
        XCTAssertEqual(entity.targetTypes, ["race_run", "beginner"])
        XCTAssertEqual(entity.phases, ["base", "build", "peak", "taper"])
        XCTAssertTrue(entity.crossTrainingEnabled)
    }

    func test_toEntity_emptyTargetTypes_handledCorrectly() {
        // Given
        let dto = MethodologyV2DTO(
            id: "polarized",
            name: "Polarized",
            description: "High-low intensity split",
            targetTypes: [],
            phases: ["base"],
            crossTrainingEnabled: false
        )

        // When
        let entity = MethodologyV2Mapper.toEntity(dto)

        // Then
        XCTAssertEqual(entity.id, "polarized")
        XCTAssertTrue(entity.targetTypes.isEmpty, "Empty targetTypes should be preserved")
        XCTAssertFalse(entity.supportsRaceRun, "supportsRaceRun should be false when targetTypes is empty")
        XCTAssertFalse(entity.supportsBeginner, "supportsBeginner should be false when targetTypes is empty")
        XCTAssertFalse(entity.supportsMaintenance, "supportsMaintenance should be false when targetTypes is empty")
    }

    func test_toEntity_crossTrainingDisabled_preservedCorrectly() {
        // Given
        let dto = MethodologyV2DTO(
            id: "hansons",
            name: "Hansons Method",
            description: "Cumulative fatigue training",
            targetTypes: ["race_run"],
            phases: ["base", "speed", "strength", "peak"],
            crossTrainingEnabled: false
        )

        // When
        let entity = MethodologyV2Mapper.toEntity(dto)

        // Then
        XCTAssertFalse(entity.crossTrainingEnabled)
        XCTAssertEqual(entity.phases.count, 4)
    }

    // MARK: - toEntities Tests

    func test_toEntities_preservesOrder() {
        // Given
        let dtos: [MethodologyV2DTO] = [
            makeDTO(id: "first"),
            makeDTO(id: "second"),
            makeDTO(id: "third")
        ]
        let response = MethodologiesResponseV2DTO(methodologies: dtos)

        // When
        let entities = MethodologyV2Mapper.toEntities(response)

        // Then
        XCTAssertEqual(entities.count, 3)
        XCTAssertEqual(entities[0].id, "first")
        XCTAssertEqual(entities[1].id, "second")
        XCTAssertEqual(entities[2].id, "third")
    }

    func test_toEntities_emptyResponse_returnsEmpty() {
        // Given
        let response = MethodologiesResponseV2DTO(methodologies: [])

        // When
        let entities = MethodologyV2Mapper.toEntities(response)

        // Then
        XCTAssertTrue(entities.isEmpty, "Empty DTO list should produce empty entity list")
    }
}

// MARK: - Test Fixtures

private extension MethodologyV2MapperTests {

    func makeDTO(
        id: String = "test_methodology",
        name: String = "Test Methodology",
        description: String = "Test description",
        targetTypes: [String] = ["race_run"],
        phases: [String] = ["base", "build"],
        crossTrainingEnabled: Bool = true
    ) -> MethodologyV2DTO {
        MethodologyV2DTO(
            id: id,
            name: name,
            description: description,
            targetTypes: targetTypes,
            phases: phases,
            crossTrainingEnabled: crossTrainingEnabled
        )
    }
}
