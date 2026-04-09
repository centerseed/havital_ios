import XCTest
@testable import paceriz_dev

/// Tests that WeeklySummaryV2DTO correctly decodes real API JSON responses.
final class WeeklySummaryV2DecodingTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklySummary/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    private func decodeSummary(from fixtureName: String) throws -> WeeklySummaryV2DTO {
        let data = try loadFixture(fixtureName)
        return try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: data)
    }

    // MARK: - Full Summary

    func test_decode_fullSummary_coreFields() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertEqual(dto.id, "summary_001")
        XCTAssertEqual(dto.uid, "user_123")
        XCTAssertEqual(dto.weeklyPlanId, "plan_001")
        XCTAssertEqual(dto.trainingOverviewId, "overview_001")
        XCTAssertEqual(dto.weekOfTraining, 3)
        XCTAssertNotNil(dto.createdAt)
    }

    func test_decode_fullSummary_planContext() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertNotNil(dto.planContext)
        XCTAssertEqual(dto.planContext?.targetType, "race_run")
        XCTAssertEqual(dto.planContext?.methodologyId, "paceriz")
        XCTAssertEqual(dto.planContext?.currentPhase, "base")
        XCTAssertEqual(dto.planContext?.phaseWeek, 3)
        XCTAssertEqual(dto.planContext?.phaseTotalWeeks, 4)
        XCTAssertEqual(dto.planContext?.totalWeeks, 16)
        XCTAssertEqual(dto.planContext?.weeksRemaining, 13)

        // Upcoming milestone
        XCTAssertNotNil(dto.planContext?.upcomingMilestone)
        XCTAssertEqual(dto.planContext?.upcomingMilestone?.targetWeek, 4)
    }

    func test_decode_fullSummary_trainingCompletion() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertEqual(dto.trainingCompletion.percentage, 0.85, accuracy: 0.01)
        XCTAssertEqual(dto.trainingCompletion.plannedKm, 45.0, accuracy: 0.01)
        XCTAssertEqual(dto.trainingCompletion.completedKm, 38.25, accuracy: 0.01)
        XCTAssertEqual(dto.trainingCompletion.plannedSessions, 5)
        XCTAssertEqual(dto.trainingCompletion.completedSessions, 4)
    }

    func test_decode_fullSummary_trainingAnalysis() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertNotNil(dto.trainingAnalysis.heartRate)
        XCTAssertEqual(dto.trainingAnalysis.heartRate?.average, 142.0)
        XCTAssertNotNil(dto.trainingAnalysis.heartRate?.zonesDistribution)

        XCTAssertNotNil(dto.trainingAnalysis.pace)
        XCTAssertEqual(dto.trainingAnalysis.pace?.average, "5:45")
        XCTAssertEqual(dto.trainingAnalysis.pace?.trend, "improving")

        XCTAssertNotNil(dto.trainingAnalysis.distance)
        XCTAssertEqual(dto.trainingAnalysis.distance?.total ?? 0, 38.25, accuracy: 0.01)
        XCTAssertEqual(dto.trainingAnalysis.distance?.longRunCompleted, true)

        XCTAssertNotNil(dto.trainingAnalysis.intensityDistribution)
        XCTAssertEqual(dto.trainingAnalysis.intensityDistribution?.easyPercentage ?? 0, 0.78, accuracy: 0.01)
    }

    func test_decode_fullSummary_readinessSummary() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertNotNil(dto.readinessSummary)
        XCTAssertEqual(dto.readinessSummary?.overallReadinessScore, 73.0)
        XCTAssertEqual(dto.readinessSummary?.overallStatus, "on_track")

        // Speed
        XCTAssertEqual(dto.readinessSummary?.speed?.score, 72.0)
        XCTAssertEqual(dto.readinessSummary?.speed?.trend, "improving")
        XCTAssertEqual(dto.readinessSummary?.speed?.trendData.count, 2)

        // Race fitness
        XCTAssertEqual(dto.readinessSummary?.raceFitness?.currentVdot, 48.5)
        XCTAssertEqual(dto.readinessSummary?.raceFitness?.targetVdot, 52.0)
        XCTAssertEqual(dto.readinessSummary?.raceFitness?.estimatedRaceTime, "3:40:00")

        // Training load
        XCTAssertEqual(dto.readinessSummary?.trainingLoad?.isInOptimalRange, true)

        // Flags
        XCTAssertEqual(dto.readinessSummary?.flags.count, 1)
        XCTAssertEqual(dto.readinessSummary?.flags[0].level, "info")
    }

    func test_decode_fullSummary_nextWeekAdjustments() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertEqual(dto.nextWeekAdjustments.items.count, 1)
        XCTAssertEqual(dto.nextWeekAdjustments.methodologyConstraintsConsidered, true)
        XCTAssertEqual(dto.nextWeekAdjustments.items[0].category, "volume")
        XCTAssertEqual(dto.nextWeekAdjustments.items[0].apply, true)
        XCTAssertEqual(dto.nextWeekAdjustments.items[0].priority, "medium")
    }

    func test_decode_fullSummary_restWeekRecommendation() throws {
        let dto = try decodeSummary(from: "full_summary")

        XCTAssertNotNil(dto.restWeekRecommendation)
        XCTAssertEqual(dto.restWeekRecommendation?.recommended, false)
        XCTAssertEqual(dto.restWeekRecommendation?.fatigueIndicators.count, 0)
    }

    // MARK: - Minimal Summary

    func test_decode_minimalSummary_onlyRequired() throws {
        let dto = try decodeSummary(from: "minimal_summary")

        XCTAssertEqual(dto.id, "summary_minimal")
        XCTAssertEqual(dto.weekOfTraining, 1)
        XCTAssertNil(dto.uid)
        XCTAssertNil(dto.weeklyPlanId)
        XCTAssertNil(dto.trainingOverviewId)
        XCTAssertNil(dto.createdAt)
        XCTAssertNil(dto.planContext)
        XCTAssertNil(dto.readinessSummary)
        XCTAssertNil(dto.capabilityProgression)
        XCTAssertNil(dto.milestoneProgress)
        XCTAssertNil(dto.historicalComparison)
        XCTAssertNil(dto.upcomingRaceEvaluation)
        XCTAssertNil(dto.restWeekRecommendation)
        XCTAssertNil(dto.finalTrainingReview)

        XCTAssertEqual(dto.trainingCompletion.percentage, 0.5, accuracy: 0.01)
        XCTAssertEqual(dto.weeklyHighlights.highlights.count, 1)
        XCTAssertEqual(dto.nextWeekAdjustments.items.count, 0)
    }
}
