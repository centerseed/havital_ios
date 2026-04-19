import XCTest
@testable import paceriz_dev

// MARK: - TargetTypeV2MapperTests

final class TargetTypeV2MapperTests: XCTestCase {

    // MARK: - toEntity Tests

    func test_toEntity_copiesAllFields() {
        // Given
        let dto = TargetTypeV2DTO(
            id: "race_run",
            name: "Race Run",
            description: "Training for a specific race event",
            defaultMethodology: "paceriz",
            availableMethodologies: ["paceriz", "polarized", "hansons", "norwegian"]
        )

        // When
        let entity = TargetTypeV2Mapper.toEntity(dto)

        // Then
        XCTAssertEqual(entity.id, "race_run")
        XCTAssertEqual(entity.name, "Race Run")
        XCTAssertEqual(entity.description, "Training for a specific race event")
        XCTAssertEqual(entity.defaultMethodology, "paceriz")
        XCTAssertEqual(entity.availableMethodologies, ["paceriz", "polarized", "hansons", "norwegian"])
    }

    func test_toEntity_emptyAvailableMethodologies_handledCorrectly() {
        // Given
        let dto = TargetTypeV2DTO(
            id: "maintenance",
            name: "Maintenance",
            description: "Maintain current fitness level",
            defaultMethodology: "balanced_fitness",
            availableMethodologies: []
        )

        // When
        let entity = TargetTypeV2Mapper.toEntity(dto)

        // Then
        XCTAssertEqual(entity.id, "maintenance")
        XCTAssertEqual(entity.defaultMethodology, "balanced_fitness")
        XCTAssertTrue(entity.availableMethodologies.isEmpty, "Empty availableMethodologies should be preserved")
    }

    func test_toEntity_computedPropertiesReflectId() {
        // Given
        let raceDto = makeDTO(id: "race_run")
        let beginnerDto = makeDTO(id: "beginner")
        let maintenanceDto = makeDTO(id: "maintenance")

        // When
        let raceEntity = TargetTypeV2Mapper.toEntity(raceDto)
        let beginnerEntity = TargetTypeV2Mapper.toEntity(beginnerDto)
        let maintenanceEntity = TargetTypeV2Mapper.toEntity(maintenanceDto)

        // Then
        XCTAssertTrue(raceEntity.isRaceRunTarget)
        XCTAssertFalse(raceEntity.isBeginnerTarget)
        XCTAssertTrue(beginnerEntity.isBeginnerTarget)
        XCTAssertFalse(beginnerEntity.isRaceRunTarget)
        XCTAssertTrue(maintenanceEntity.isMaintenanceTarget)
    }

    // MARK: - toEntities Tests

    func test_toEntities_preservesOrder() {
        // Given
        let dtos: [TargetTypeV2DTO] = [
            makeDTO(id: "race_run"),
            makeDTO(id: "beginner"),
            makeDTO(id: "maintenance")
        ]
        let response = TargetTypesResponseV2DTO(targetTypes: dtos)

        // When
        let entities = TargetTypeV2Mapper.toEntities(response)

        // Then
        XCTAssertEqual(entities.count, 3)
        XCTAssertEqual(entities[0].id, "race_run")
        XCTAssertEqual(entities[1].id, "beginner")
        XCTAssertEqual(entities[2].id, "maintenance")
    }

    func test_toEntities_emptyResponse_returnsEmpty() {
        // Given
        let response = TargetTypesResponseV2DTO(targetTypes: [])

        // When
        let entities = TargetTypeV2Mapper.toEntities(response)

        // Then
        XCTAssertTrue(entities.isEmpty, "Empty DTO list should produce empty entity list")
    }
}

// MARK: - Test Fixtures

private extension TargetTypeV2MapperTests {

    func makeDTO(
        id: String = "race_run",
        name: String = "Race",
        description: String = "Race description",
        defaultMethodology: String = "paceriz",
        availableMethodologies: [String] = ["paceriz", "polarized"]
    ) -> TargetTypeV2DTO {
        TargetTypeV2DTO(
            id: id,
            name: name,
            description: description,
            defaultMethodology: defaultMethodology,
            availableMethodologies: availableMethodologies
        )
    }
}
