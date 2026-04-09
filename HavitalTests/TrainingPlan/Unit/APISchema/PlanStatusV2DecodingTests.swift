import XCTest
@testable import paceriz_dev

/// Tests that PlanStatusV2Response correctly decodes real API JSON responses.
final class PlanStatusV2DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/PlanStatus/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodePlanStatus(from fixtureName: String) throws -> PlanStatusV2Response {
        let data = try loadFixture(fixtureName)
        return try JSONDecoder().decode(PlanStatusV2Response.self, from: data)
    }

    // MARK: - View Plan

    func test_decode_viewPlan_allFieldsPopulated() throws {
        let dto = try decodePlanStatus(from: "view_plan")

        XCTAssertEqual(dto.currentWeek, 3)
        XCTAssertEqual(dto.totalWeeks, 16)
        XCTAssertEqual(dto.nextAction, "view_plan")
        XCTAssertEqual(dto.canGenerateNextWeek, false)
        XCTAssertEqual(dto.currentWeekPlanId, "overview_001_3")
        XCTAssertEqual(dto.previousWeekSummaryId, "summary_002")
        XCTAssertEqual(dto.targetType, "race_run")
        XCTAssertEqual(dto.methodologyId, "paceriz")
    }

    func test_decode_viewPlan_nextWeekInfo() throws {
        let dto = try decodePlanStatus(from: "view_plan")

        XCTAssertNotNil(dto.nextWeekInfo)
        XCTAssertEqual(dto.nextWeekInfo?.weekNumber, 4)
        XCTAssertEqual(dto.nextWeekInfo?.hasPlan, false)
        XCTAssertEqual(dto.nextWeekInfo?.canGenerate, false)
        XCTAssertEqual(dto.nextWeekInfo?.requiresCurrentWeekSummary, true)
        XCTAssertEqual(dto.nextWeekInfo?.nextAction, "create_summary")
    }

    func test_decode_viewPlan_metadata() throws {
        let dto = try decodePlanStatus(from: "view_plan")

        XCTAssertNotNil(dto.metadata)
        XCTAssertNotNil(dto.metadata?.trainingStartDate)
        XCTAssertNotNil(dto.metadata?.currentWeekStartDate)
        XCTAssertNotNil(dto.metadata?.currentWeekEndDate)
        XCTAssertEqual(dto.metadata?.userTimezone, "Asia/Taipei")
        XCTAssertNotNil(dto.metadata?.serverTime)
    }

    // MARK: - Create Summary

    func test_decode_createSummary_actionAndOptionalFields() throws {
        let dto = try decodePlanStatus(from: "create_summary")

        XCTAssertEqual(dto.currentWeek, 5)
        XCTAssertEqual(dto.nextAction, "create_summary")
        XCTAssertEqual(dto.canGenerateNextWeek, true)
        XCTAssertNil(dto.previousWeekSummaryId)
        XCTAssertNil(dto.metadata)

        XCTAssertEqual(dto.nextWeekInfo?.weekNumber, 6)
        XCTAssertEqual(dto.nextWeekInfo?.canGenerate, true)
    }
}
