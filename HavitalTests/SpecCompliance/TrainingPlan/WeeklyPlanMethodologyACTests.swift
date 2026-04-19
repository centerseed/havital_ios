import XCTest
@testable import paceriz_dev

final class WeeklyPlanMethodologyACTests: XCTestCase {
    func test_ac_ios_testparity_inv_02_paceriz_base_fixture_satisfies_methodology_specific_rules() throws {
        let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: "paceriz_42k_base_week")
        let violations = MethodologyInvariants.validatePaceriz(plan: plan, phase: .base)
        XCTAssertTrue(violations.isEmpty, "Paceriz base fixture should satisfy methodology-specific rules, got \(violations)")
    }

    func test_ac_ios_testparity_inv_02_paceriz_peak_fixture_surfaces_missing_race_pace_session() throws {
        let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: "paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validatePaceriz(plan: plan, phase: .peak)

        XCTAssertEqual(
            violations.map(\.ruleId),
            ["INV-02.paceriz.peak.race_pace_required"],
            "Current peak fixture should only fail the race-pace requirement until S02 regenerates it"
        )
    }

    func test_ac_ios_testparity_inv_05_polarized_existing_fixture_passes_methodology_rules() throws {
        let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: "polarized_42k_build_week")
        let violations = MethodologyInvariants.validatePolarized(plan: plan)
        XCTAssertTrue(violations.isEmpty, "Polarized build fixture should satisfy methodology-specific rules, got \(violations)")
    }

    func test_ac_ios_testparity_inv_06_current_weekly_fixtures_match_training_days_and_long_run_day() throws {
        let fixtures: [(String, Methodology, TrainingPhase)] = [
            ("paceriz_42k_base_week", .paceriz, .base),
            ("paceriz_42k_peak_week", .paceriz, .peak),
            ("polarized_42k_build_week", .polarized, .build),
            ("complete_10k_conversion_week", .complete10k, .conversion),
        ]

        for (fixture, methodology, phase) in fixtures {
            let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: fixture)
            let config = inferredConfig(for: plan, methodology: methodology)
            let violations = MethodologyInvariants.validateGeneral(plan: plan, config: config)

            XCTAssertFalse(
                violations.contains(where: { $0.ruleId.hasPrefix("INV-06.training_days_match") || $0.ruleId.hasPrefix("INV-06.long_run_day") }),
                "Fixture \(fixture) should satisfy general schedule alignment rules in phase \(phase.rawValue), got \(violations)"
            )
        }
    }

    func test_ac_ios_testparity_struct_05_legacy_race_run_fixtures_flag_missing_heart_rate_ranges() throws {
        let fixtures: [(name: String, phase: TrainingPhase, expectedDays: [Int])] = [
            ("paceriz_42k_base_week", .base, [4, 6]),
            ("paceriz_42k_peak_week", .peak, [1, 3, 6, 7]),
            ("polarized_42k_build_week", .build, [1, 3, 5, 6, 7]),
        ]

        for fixture in fixtures {
            let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: fixture.name)
            let violations = MethodologyInvariants.validateStructure(plan: plan, phase: fixture.phase)
            let hrRuleIds = violations
                .filter { $0.ruleId == "STRUCT-05.hr_range_required" }
                .map(\.message)

            for day in fixture.expectedDays {
                XCTAssertTrue(
                    hrRuleIds.contains(where: { $0.contains("Day \(day)") }),
                    "Fixture \(fixture.name) should flag missing heartRateRange on day \(day), got \(violations)"
                )
            }
        }
    }

    func test_ac_ios_testparity_struct_07_beginner_conversion_fixture_flags_missing_intensity_totals() throws {
        let plan = try FixtureLoader.decodeEntity(category: "WeeklyPlan", name: "complete_10k_conversion_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .conversion)

        XCTAssertTrue(
            violations.contains(where: { $0.ruleId == "STRUCT-07.intensity_required" }),
            "Beginner conversion fixture should currently expose missing intensity totals, got \(violations)"
        )
    }

    private func inferredConfig(for plan: WeeklyPlanV2, methodology: Methodology) -> UserPlanConfig {
        let trainingDays = Set(plan.days.filter { $0.session != nil }.map(\.dayIndex))
        let longRunDay = plan.days.first {
            guard case let .run(activity)? = $0.session?.primary else { return false }
            let type = activity.runType.lowercased()
            return type == "long_run" || type == "lsd"
        }?.dayIndex

        return UserPlanConfig(
            trainingDays: trainingDays,
            longRunDay: longRunDay,
            maxHardSessions: methodology == .norwegian ? 3 : 2
        )
    }
}

private enum FixtureLoader {
    static func decodeEntity(category: String, name: String) throws -> WeeklyPlanV2 {
        let data = try Data(contentsOf: url(category: category, name: name))
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    private static func url(category: String, name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TrainingPlan/Unit/APISchema/Fixtures/\(category)/\(name).json")
    }
}
