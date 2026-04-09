import XCTest
@testable import paceriz_dev

/// Tests that WeeklyPreviewResponseDTO correctly decodes real API JSON responses.
final class WeeklyPreviewV2DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklyPreview/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodePreview(from fixtureName: String) throws -> WeeklyPreviewResponseDTO {
        let data = try loadFixture(fixtureName)
        return try JSONDecoder().decode(WeeklyPreviewResponseDTO.self, from: data)
    }

    // MARK: - Paceriz 12 Weeks

    func test_decode_paceriz12Weeks_topLevelFields() throws {
        let dto = try decodePreview(from: "paceriz_12_weeks")

        XCTAssertEqual(dto.planId, "overview_001")
        XCTAssertEqual(dto.methodologyId, "paceriz")
        XCTAssertEqual(dto.totalWeeks, 12)
        XCTAssertEqual(dto.weeks.count, 12)
        XCTAssertNotNil(dto.createdAt)
        XCTAssertNotNil(dto.updatedAt)
    }

    func test_decode_paceriz12Weeks_weekDetails() throws {
        let dto = try decodePreview(from: "paceriz_12_weeks")

        // Week 1: base phase
        let week1 = dto.weeks[0]
        XCTAssertEqual(week1.week, 1)
        XCTAssertEqual(week1.stageId, "base")
        XCTAssertEqual(week1.targetKm, 35.0, accuracy: 0.01)
        XCTAssertEqual(week1.isRecovery, false)
        XCTAssertEqual(week1.weekInPhase, 1)
        XCTAssertEqual(week1.totalPhaseWeeks, 4)

        // Quality options
        XCTAssertEqual(week1.qualityOptions?.count, 1)
        XCTAssertEqual(week1.qualityOptions?[0].category, "threshold")
        XCTAssertEqual(week1.qualityOptions?[0].trainingType, "tempo")

        // Long run
        XCTAssertNotNil(week1.longRun)
        XCTAssertEqual(week1.longRun?.maxKm, 14.0)
        XCTAssertEqual(week1.longRun?.trainingType, "lsd")

        // Intensity ratio
        XCTAssertNotNil(week1.intensityRatio)
        XCTAssertEqual(week1.intensityRatio?.low ?? 0, 0.80, accuracy: 0.01)
    }

    func test_decode_paceriz12Weeks_recoveryWeek() throws {
        let dto = try decodePreview(from: "paceriz_12_weeks")

        // Week 4: recovery week with milestone
        let week4 = dto.weeks[3]
        XCTAssertEqual(week4.isRecovery, true)
        XCTAssertEqual(week4.milestoneRef, "base_complete")
        XCTAssertEqual(week4.targetKm, 30.0, accuracy: 0.01)
        XCTAssertNil(week4.qualityOptions)
    }

    func test_decode_paceriz12Weeks_peakPhaseMultipleQualityOptions() throws {
        let dto = try decodePreview(from: "paceriz_12_weeks")

        // Week 5: build phase with 2 quality options
        let week5 = dto.weeks[4]
        XCTAssertEqual(week5.stageId, "build")
        XCTAssertEqual(week5.qualityOptions?.count, 2)
        XCTAssertEqual(week5.qualityOptions?[0].trainingType, "threshold")
        XCTAssertEqual(week5.qualityOptions?[1].trainingType, "interval")
    }

    func test_decode_paceriz12Weeks_allStagesPresent() throws {
        let dto = try decodePreview(from: "paceriz_12_weeks")

        let stageIds = Set(dto.weeks.map { $0.stageId })
        XCTAssertTrue(stageIds.contains("base"))
        XCTAssertTrue(stageIds.contains("build"))
        XCTAssertTrue(stageIds.contains("peak"))
        XCTAssertTrue(stageIds.contains("taper"))
    }
}
