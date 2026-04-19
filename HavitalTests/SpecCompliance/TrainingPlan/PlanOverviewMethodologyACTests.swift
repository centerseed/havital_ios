import XCTest
@testable import paceriz_dev

final class PlanOverviewMethodologyACTests: XCTestCase {
    func test_ac_ios_testparity_fixt_01_current_plan_overview_fixtures_decode_successfully() throws {
        let fixtures = [
            "race_run_paceriz",
            "beginner_10k",
            "maintenance_aerobic",
        ]

        for fixture in fixtures {
            let dto = try FixtureLoader.decode(PlanOverviewV2DTO.self, category: "PlanOverview", name: fixture)
            XCTAssertFalse(dto.id.isEmpty, "Fixture \(fixture) should decode an overview id")
            XCTAssertFalse((dto.methodologyId ?? "").isEmpty, "Fixture \(fixture) should decode a methodology id")
            XCTAssertGreaterThan(dto.trainingStages?.count ?? 0, 0, "Fixture \(fixture) should contain training stages")
        }
    }

    func test_ac_ios_testparity_inv_01_overview_fixtures_resolve_known_methodology_and_phase_ids() throws {
        let fixtures = [
            "race_run_paceriz",
            "beginner_10k",
            "maintenance_aerobic",
        ]

        for fixture in fixtures {
            let dto = try FixtureLoader.decode(PlanOverviewV2DTO.self, category: "PlanOverview", name: fixture)
            let methodologyId = try XCTUnwrap(dto.methodologyId, "Fixture \(fixture) should provide methodologyId")
            XCTAssertNotNil(Methodology(id: methodologyId), "Unknown methodology in fixture \(fixture): \(methodologyId)")

            for stage in try XCTUnwrap(dto.trainingStages, "Fixture \(fixture) should provide training stages") {
                XCTAssertNotNil(TrainingPhase(stageId: stage.stageId), "Unknown stage in fixture \(fixture): \(stage.stageId)")
            }
        }
    }
}

private enum FixtureLoader {
    static func decode<T: Decodable>(_ type: T.Type, category: String, name: String) throws -> T {
        let data = try Data(contentsOf: url(category: category, name: name))
        return try JSONDecoder().decode(type, from: data)
    }

    private static func url(category: String, name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TrainingPlan/Unit/APISchema/Fixtures/\(category)/\(name).json")
    }
}
