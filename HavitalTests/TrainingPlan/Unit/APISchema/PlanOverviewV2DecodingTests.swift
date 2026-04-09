import XCTest
@testable import paceriz_dev

/// Tests that PlanOverviewV2DTO correctly decodes real API JSON responses.
final class PlanOverviewV2DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/PlanOverview/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodePlanOverview(from fixtureName: String) throws -> PlanOverviewV2DTO {
        let data = try loadFixture(fixtureName)
        return try JSONDecoder().decode(PlanOverviewV2DTO.self, from: data)
    }

    // MARK: - Race Run Paceriz (Full)

    func test_decode_raceRunPaceriz_allFieldsPopulated() throws {
        let dto = try decodePlanOverview(from: "race_run_paceriz")

        XCTAssertEqual(dto.id, "overview_001")
        XCTAssertEqual(dto.targetId, "target_race_42k")
        XCTAssertEqual(dto.targetType, "race_run")
        XCTAssertEqual(dto.targetDescription, "Berlin Marathon 2026")
        XCTAssertEqual(dto.methodologyId, "paceriz")
        XCTAssertEqual(dto.totalWeeks, 16)
        XCTAssertEqual(dto.startFromStage, "base")
        XCTAssertEqual(dto.raceDate, 1790352000)
        XCTAssertEqual(dto.distanceKm ?? 0, 42.195, accuracy: 0.001)
        XCTAssertEqual(dto.distanceKmDisplay ?? 0, 26.22, accuracy: 0.01)
        XCTAssertEqual(dto.distanceUnit, "miles")
        XCTAssertEqual(dto.targetPace, "5:00")
        XCTAssertEqual(dto.targetTime, 12660)
        XCTAssertEqual(dto.isMainRace, true)
        XCTAssertEqual(dto.targetName, "Berlin Marathon")
        XCTAssertEqual(dto.targetEvaluate, "Achievable goal based on current fitness")
        XCTAssertNotNil(dto.approachSummary)
        XCTAssertEqual(dto.methodologyVersion, "3.0")
        XCTAssertEqual(dto.milestoneBasis, "intended_race_distance")
    }

    func test_decode_raceRunPaceriz_methodologyOverview() throws {
        let dto = try decodePlanOverview(from: "race_run_paceriz")

        XCTAssertNotNil(dto.methodologyOverview)
        XCTAssertEqual(dto.methodologyOverview?.name, "Paceriz")
        XCTAssertEqual(dto.methodologyOverview?.intensityStyle, "balanced")
        XCTAssertNotNil(dto.methodologyOverview?.philosophy)
        XCTAssertNotNil(dto.methodologyOverview?.intensityDescription)
    }

    func test_decode_raceRunPaceriz_trainingStages() throws {
        let dto = try decodePlanOverview(from: "race_run_paceriz")

        XCTAssertEqual(dto.trainingStages?.count, 4)

        let baseStage = dto.trainingStages?[0]
        XCTAssertEqual(baseStage?.stageId, "base")
        XCTAssertEqual(baseStage?.stageName, "Base Building")
        XCTAssertEqual(baseStage?.weekStart, 1)
        XCTAssertEqual(baseStage?.weekEnd, 4)
        XCTAssertEqual(baseStage?.targetWeeklyKmRange.low, 35.0)
        XCTAssertEqual(baseStage?.targetWeeklyKmRange.high, 45.0)
        XCTAssertNotNil(baseStage?.intensityRatio)
        XCTAssertEqual(baseStage?.intensityRatio?.low ?? 0, 0.80, accuracy: 0.01)
        XCTAssertNotNil(baseStage?.keyWorkouts)

        // Imperial display range
        XCTAssertNotNil(baseStage?.targetWeeklyKmRangeDisplay)
        XCTAssertEqual(baseStage?.targetWeeklyKmRangeDisplay?.distanceUnit, "miles")
    }

    func test_decode_raceRunPaceriz_milestones() throws {
        let dto = try decodePlanOverview(from: "race_run_paceriz")

        XCTAssertEqual(dto.milestones?.count, 3)

        let raceDayMilestone = dto.milestones?[2]
        XCTAssertEqual(raceDayMilestone?.week, 16)
        XCTAssertEqual(raceDayMilestone?.milestoneType, "race")
        XCTAssertEqual(raceDayMilestone?.title, "Race Day")
        XCTAssertEqual(raceDayMilestone?.isKeyMilestone, true)
    }

    // MARK: - Beginner 10K

    func test_decode_beginner10k_noRaceFields() throws {
        let dto = try decodePlanOverview(from: "beginner_10k")

        XCTAssertEqual(dto.targetType, "beginner")
        XCTAssertEqual(dto.methodologyId, "complete_10k")
        XCTAssertEqual(dto.totalWeeks, 12)
        XCTAssertNil(dto.raceDate)
        XCTAssertNil(dto.distanceKm)
        XCTAssertNil(dto.targetPace)
        XCTAssertNil(dto.targetTime)
        XCTAssertNil(dto.isMainRace)
        XCTAssertNil(dto.targetId)
        XCTAssertEqual(dto.startFromStage, "conversion")
    }

    // MARK: - Maintenance

    func test_decode_maintenanceAerobic_minimalStages() throws {
        let dto = try decodePlanOverview(from: "maintenance_aerobic")

        XCTAssertEqual(dto.targetType, "maintenance")
        XCTAssertEqual(dto.totalWeeks, 8)
        XCTAssertEqual(dto.trainingStages?.count, 1)
        XCTAssertEqual(dto.milestones?.count, 0)
    }

    // MARK: - Minimal Fields

    func test_decode_minimalFields_onlyRequiredPresent() throws {
        let dto = try decodePlanOverview(from: "minimal_fields")

        XCTAssertEqual(dto.id, "overview_minimal")
        XCTAssertEqual(dto.targetType, "race_run")
        XCTAssertEqual(dto.totalWeeks, 10)

        // All optional fields should be nil
        XCTAssertNil(dto.targetId)
        XCTAssertNil(dto.targetDescription)
        XCTAssertNil(dto.methodologyId)
        XCTAssertNil(dto.startFromStage)
        XCTAssertNil(dto.raceDate)
        XCTAssertNil(dto.distanceKm)
        XCTAssertNil(dto.methodologyOverview)
        XCTAssertNil(dto.targetEvaluate)
        XCTAssertNil(dto.approachSummary)
        XCTAssertNil(dto.trainingStages)
        XCTAssertNil(dto.milestones)
        XCTAssertNil(dto.createdAt)
    }
}
