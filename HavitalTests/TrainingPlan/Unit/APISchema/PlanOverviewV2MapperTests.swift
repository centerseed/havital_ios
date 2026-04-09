import XCTest
@testable import paceriz_dev

/// Tests PlanOverviewV2Mapper DTO-to-Entity conversion.
/// Validates nested structure mapping: stages, milestones, methodology overview.
final class PlanOverviewV2MapperTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/PlanOverview/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodeAndMap(from fixtureName: String) throws -> PlanOverviewV2 {
        let data = try loadFixture(fixtureName)
        let dto = try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
        return PlanOverviewV2Mapper.toEntity(from: dto)
    }

    // MARK: - Core Fields

    func test_mapper_coreFieldsMapping() throws {
        let entity = try decodeAndMap(from: "race_run_paceriz")

        XCTAssertEqual(entity.id, "overview_001")
        XCTAssertEqual(entity.targetType, "race_run")
        XCTAssertEqual(entity.methodologyId, "paceriz")
        XCTAssertEqual(entity.totalWeeks, 16)
        XCTAssertEqual(entity.distanceKm ?? 0, 42.195, accuracy: 0.001)
        XCTAssertEqual(entity.distanceKmDisplay ?? 0, 26.22, accuracy: 0.01)
        XCTAssertEqual(entity.distanceUnit, "miles")
        XCTAssertEqual(entity.targetPace, "5:00")
        XCTAssertEqual(entity.targetTime, 12660)
        XCTAssertEqual(entity.isMainRace, true)
        XCTAssertEqual(entity.raceDate, 1790352000)
    }

    // MARK: - Computed Properties

    func test_entity_computedProperties() throws {
        let entity = try decodeAndMap(from: "race_run_paceriz")

        XCTAssertTrue(entity.isRaceRunTarget)
        XCTAssertFalse(entity.isBeginnerTarget)
        XCTAssertFalse(entity.isMaintenanceTarget)
        XCTAssertEqual(entity.totalDays, 112) // 16 * 7
        XCTAssertNotNil(entity.raceDateValue)
    }

    // MARK: - Methodology Overview Mapping

    func test_mapper_methodologyOverview() throws {
        let entity = try decodeAndMap(from: "race_run_paceriz")

        XCTAssertNotNil(entity.methodologyOverview)
        XCTAssertEqual(entity.methodologyOverview?.name, "Paceriz")
        XCTAssertEqual(entity.methodologyOverview?.intensityStyle, "balanced")
        XCTAssertNotNil(entity.methodologyOverview?.philosophy)
        XCTAssertNotNil(entity.methodologyOverview?.intensityDescription)
    }

    // MARK: - Training Stages Mapping

    func test_mapper_trainingStages() throws {
        let entity = try decodeAndMap(from: "race_run_paceriz")

        XCTAssertEqual(entity.trainingStages.count, 4)

        let baseStage = entity.trainingStages[0]
        XCTAssertEqual(baseStage.stageId, "base")
        XCTAssertEqual(baseStage.stageName, "Base Building")
        XCTAssertEqual(baseStage.weekStart, 1)
        XCTAssertEqual(baseStage.weekEnd, 4)
        XCTAssertEqual(baseStage.targetWeeklyKmRange.low, 35.0)
        XCTAssertEqual(baseStage.targetWeeklyKmRange.high, 45.0)

        // Computed property
        XCTAssertEqual(baseStage.durationWeeks, 4)
        XCTAssertTrue(baseStage.contains(week: 3))
        XCTAssertFalse(baseStage.contains(week: 5))

        // Imperial display
        XCTAssertNotNil(baseStage.targetWeeklyKmRangeDisplay)
        XCTAssertEqual(baseStage.targetWeeklyKmRangeDisplay?.distanceUnit, "miles")

        // Intensity ratio
        XCTAssertNotNil(baseStage.intensityRatio)
        XCTAssertEqual(baseStage.intensityRatio?.low ?? 0, 0.80, accuracy: 0.01)
        XCTAssertEqual(baseStage.intensityRatio?.medium ?? 0, 0.15, accuracy: 0.01)
    }

    // MARK: - Milestones Mapping

    func test_mapper_milestones() throws {
        let entity = try decodeAndMap(from: "race_run_paceriz")

        XCTAssertEqual(entity.milestones.count, 3)

        let firstMilestone = entity.milestones[0]
        XCTAssertEqual(firstMilestone.week, 4)
        XCTAssertEqual(firstMilestone.milestoneType, "volume")
        XCTAssertEqual(firstMilestone.isKeyMilestone, true)
    }

    // MARK: - Empty Collections

    func test_mapper_emptyMilestones() throws {
        let entity = try decodeAndMap(from: "maintenance_aerobic")

        XCTAssertEqual(entity.milestones.count, 0)
    }

    // MARK: - Minimal Mapping

    func test_mapper_minimalFields() throws {
        let entity = try decodeAndMap(from: "minimal_fields")

        XCTAssertEqual(entity.id, "overview_minimal")
        XCTAssertEqual(entity.totalWeeks, 10)
        // trainingStages defaults to empty array from nil
        XCTAssertEqual(entity.trainingStages.count, 0)
        XCTAssertEqual(entity.milestones.count, 0)
        XCTAssertNil(entity.methodologyOverview)
        XCTAssertNil(entity.createdAt)
    }
}
