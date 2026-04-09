import XCTest
@testable import paceriz_dev

/// Tests WeeklySummaryV2Mapper DTO-to-Entity conversion.
/// Validates deeply nested structure mapping.
final class WeeklySummaryV2MapperTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklySummary/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodeAndMap(from fixtureName: String) throws -> WeeklySummaryV2 {
        let data = try loadFixture(fixtureName)
        let dto = try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: data)
        return WeeklySummaryV2Mapper.toEntity(from: dto)
    }

    // MARK: - Full Summary Mapping

    func test_mapper_coreFieldMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertEqual(entity.id, "summary_001")
        XCTAssertEqual(entity.uid, "user_123")
        XCTAssertEqual(entity.weeklyPlanId, "plan_001")
        XCTAssertEqual(entity.trainingOverviewId, "overview_001")
        XCTAssertEqual(entity.weekOfTraining, 3)
        XCTAssertNotNil(entity.createdAt)
    }

    func test_mapper_planContextMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertNotNil(entity.planContext)
        XCTAssertEqual(entity.planContext?.targetType, "race_run")
        XCTAssertEqual(entity.planContext?.methodologyName, "Paceriz")
        XCTAssertEqual(entity.planContext?.currentPhase, "base")
        XCTAssertEqual(entity.planContext?.weeksRemaining, 13)

        XCTAssertNotNil(entity.planContext?.upcomingMilestone)
        XCTAssertEqual(entity.planContext?.upcomingMilestone?.targetWeek, 4)
    }

    func test_mapper_trainingCompletionMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertEqual(entity.trainingCompletion.percentage, 0.85, accuracy: 0.01)
        XCTAssertEqual(entity.trainingCompletion.plannedKm, 45.0, accuracy: 0.01)
        XCTAssertEqual(entity.trainingCompletion.completedKm, 38.25, accuracy: 0.01)
    }

    func test_mapper_readinessSummaryMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertNotNil(entity.readinessSummary)
        XCTAssertEqual(entity.readinessSummary?.overallReadinessScore, 73.0)

        // Speed with trend data
        XCTAssertEqual(entity.readinessSummary?.speed?.score, 72.0)
        XCTAssertEqual(entity.readinessSummary?.speed?.trendData.count, 2)
        XCTAssertEqual(entity.readinessSummary?.speed?.trendData[0].date, "2026-02-03")
        XCTAssertEqual(entity.readinessSummary?.speed?.trendData[0].value, 68.0)

        // Race fitness
        XCTAssertEqual(entity.readinessSummary?.raceFitness?.currentVdot, 48.5)
        XCTAssertEqual(entity.readinessSummary?.raceFitness?.targetVdot, 52.0)

        // Flags
        XCTAssertEqual(entity.readinessSummary?.flags.count, 1)
        XCTAssertEqual(entity.readinessSummary?.flags[0].level, "info")
        XCTAssertEqual(entity.readinessSummary?.flags[0].metric, "mileage")
    }

    func test_mapper_nextWeekAdjustmentsMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertEqual(entity.nextWeekAdjustments.items.count, 1)
        XCTAssertEqual(entity.nextWeekAdjustments.items[0].category, "volume")
        XCTAssertEqual(entity.nextWeekAdjustments.items[0].apply, true)
        XCTAssertEqual(entity.nextWeekAdjustments.methodologyConstraintsConsidered, true)
    }

    func test_mapper_restWeekRecommendationMapping() throws {
        let entity = try decodeAndMap(from: "full_summary")

        XCTAssertNotNil(entity.restWeekRecommendation)
        XCTAssertEqual(entity.restWeekRecommendation?.recommended, false)
        XCTAssertEqual(entity.restWeekRecommendation?.fatigueIndicators.count, 0)
    }

    // MARK: - Minimal Summary Mapping

    func test_mapper_minimalSummary_nilFieldsDefaultCorrectly() throws {
        let entity = try decodeAndMap(from: "minimal_summary")

        XCTAssertEqual(entity.id, "summary_minimal")
        XCTAssertEqual(entity.uid, "")  // nil defaults to ""
        XCTAssertEqual(entity.weeklyPlanId, "")
        XCTAssertEqual(entity.trainingOverviewId, "")
        XCTAssertNil(entity.planContext)
        XCTAssertNil(entity.readinessSummary)
        XCTAssertNil(entity.capabilityProgression)
        XCTAssertNil(entity.restWeekRecommendation)
    }
}
