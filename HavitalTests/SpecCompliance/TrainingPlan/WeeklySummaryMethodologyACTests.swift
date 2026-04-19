import XCTest
@testable import paceriz_dev

final class WeeklySummaryMethodologyACTests: XCTestCase {
    func test_ac_ios_testparity_fixt_03_boundary_summary_fixtures_decode_successfully() throws {
        let full = try FixtureLoader.decode(WeeklySummaryV2DTO.self, category: "WeeklySummary", name: "full_summary")
        let minimal = try FixtureLoader.decode(WeeklySummaryV2DTO.self, category: "WeeklySummary", name: "minimal_summary")

        XCTAssertEqual(full.weekOfTraining, 3)
        XCTAssertEqual(minimal.weekOfTraining, 1)
    }

    func test_ac_ios_testparity_fixt_03_full_summary_preserves_methodology_context() throws {
        let summary = try FixtureLoader.decodeEntity(category: "WeeklySummary", name: "full_summary")

        XCTAssertEqual(summary.planContext?.methodologyId, "paceriz")
        XCTAssertEqual(summary.planContext?.currentPhase, "base")
        XCTAssertEqual(summary.trainingCompletion.percentage, 0.85, accuracy: 0.001)
    }

    func test_ac_ios_testparity_fixt_03_minimal_summary_allows_optional_blocks_to_be_absent() throws {
        let summary = try FixtureLoader.decodeEntity(category: "WeeklySummary", name: "minimal_summary")

        XCTAssertNil(summary.planContext)
        XCTAssertNil(summary.trainingAnalysis.heartRate)
        XCTAssertNil(summary.trainingAnalysis.pace)
        XCTAssertEqual(summary.trainingCompletion.percentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(summary.nextWeekAdjustments.items.count, 0)
    }
}

private enum FixtureLoader {
    static func decode<T: Decodable>(_ type: T.Type, category: String, name: String) throws -> T {
        let data = try Data(contentsOf: url(category: category, name: name))
        return try JSONDecoder().decode(type, from: data)
    }

    static func decodeEntity(category: String, name: String) throws -> WeeklySummaryV2 {
        let dto = try decode(WeeklySummaryV2DTO.self, category: category, name: name)
        return WeeklySummaryV2Mapper.toEntity(from: dto)
    }

    private static func url(category: String, name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TrainingPlan/Unit/APISchema/Fixtures/\(category)/\(name).json")
    }
}
