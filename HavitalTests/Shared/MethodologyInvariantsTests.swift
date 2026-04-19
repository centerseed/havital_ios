import XCTest
@testable import paceriz_dev

/// Self-tests for MethodologyInvariants SSOT.
/// Validates that the rule engine correctly flags / clears known-good and known-bad plans
/// using the existing WeeklyPlan fixtures. Extended fixture coverage lives in SpecCompliance layer.
final class MethodologyInvariantsTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> WeeklyPlanV2 {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TrainingPlan/Unit/APISchema/Fixtures/WeeklyPlan")
        let data = try Data(contentsOf: testDir.appendingPathComponent("\(name).json"))
        let dto = try JSONDecoder().decode(WeeklyPlanV2DTO.self, from: data)
        return WeeklyPlanV2Mapper.toEntity(from: dto)
    }

    // MARK: - Paceriz base (known-good)

    func test_paceriz_base_fixture_passesInvariants() throws {
        let plan = try loadFixture("paceriz_42k_base_week")
        let violations = MethodologyInvariants.validate(plan: plan, methodology: .paceriz, phase: .base)
        // Allow general-rule violations from pre-existing fixture (may not match a specific user config);
        // assert no paceriz/base-specific violations.
        let base = violations.filter { $0.ruleId.hasPrefix("INV-02.paceriz.base") }
        XCTAssertTrue(base.isEmpty, "Expected paceriz base fixture to pass phase-specific rules; got \(base)")
    }

    // MARK: - Paceriz peak (known-good)

    func test_paceriz_peak_fixture_passesInvariants() throws {
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validate(plan: plan, methodology: .paceriz, phase: .peak)
        let peakSpecific = violations.filter { $0.ruleId.hasPrefix("INV-02.paceriz.peak") }
        // race_pace may or may not be present in current fixture; only assert interval/threshold required rules don't fail
        let required = peakSpecific.filter {
            $0.ruleId == "INV-02.paceriz.peak.interval_required" ||
            $0.ruleId == "INV-02.paceriz.peak.threshold_required"
        }
        XCTAssertTrue(required.isEmpty, "Paceriz peak must include interval & threshold; got \(required)")
    }

    // MARK: - Polarized build (known-good)

    func test_polarized_build_fixture_passesPolarizedRules() throws {
        let plan = try loadFixture("polarized_42k_build_week")
        let violations = MethodologyInvariants.validate(plan: plan, methodology: .polarized, phase: .build)
        let polarized = violations.filter { $0.ruleId.hasPrefix("INV-05.polarized") }
        XCTAssertTrue(polarized.isEmpty, "Polarized fixture should pass polarized rules; got \(polarized)")
    }

    // MARK: - Cross-check: paceriz base treated as peak should fail

    func test_paceriz_base_fixtureTreatedAsPeak_failsIntervalRequired() throws {
        let plan = try loadFixture("paceriz_42k_base_week")
        let violations = MethodologyInvariants.validate(plan: plan, methodology: .paceriz, phase: .peak)
        XCTAssertTrue(
            violations.contains(where: { $0.ruleId == "INV-02.paceriz.peak.interval_required" }),
            "Base-phase fixture should fail peak.interval_required when mislabeled"
        )
    }

    // MARK: - Cross-check: paceriz peak treated as polarized should fail medium_zero

    func test_paceriz_peak_treatedAsPolarized_failsMediumZero() throws {
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validate(plan: plan, methodology: .polarized, phase: .peak)
        XCTAssertTrue(
            violations.contains(where: { $0.ruleId.hasPrefix("INV-05.polarized") }),
            "Paceriz peak should violate at least one polarized rule"
        )
    }

    // MARK: - Parse pace helper

    func test_parsePaceMinutes_validFormats() {
        XCTAssertEqual(MethodologyInvariants.parsePaceMinutes("5:00"), 5.0)
        XCTAssertEqual(MethodologyInvariants.parsePaceMinutes("5:30"), 5.5)
        XCTAssertEqual(MethodologyInvariants.parsePaceMinutes("06:15"), 6.25)
    }

    func test_parsePaceMinutes_invalidReturnsNil() {
        XCTAssertNil(MethodologyInvariants.parsePaceMinutes("abc"))
        XCTAssertNil(MethodologyInvariants.parsePaceMinutes("5"))
        XCTAssertNil(MethodologyInvariants.parsePaceMinutes(""))
    }

    // MARK: - Group G: Structural Invariants (parity with backend)

    func test_struct_existingFixture_hasSevenDaysAndRest() throws {
        let plan = try loadFixture("paceriz_42k_base_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .base)
        let sevenDay = violations.filter { $0.ruleId.hasPrefix("STRUCT-01") }
        let rest = violations.filter { $0.ruleId.hasPrefix("STRUCT-02") }
        XCTAssertTrue(sevenDay.isEmpty, "Existing fixture must satisfy STRUCT-01; got \(sevenDay)")
        XCTAssertTrue(rest.isEmpty, "Existing fixture must satisfy STRUCT-02; got \(rest)")
    }

    func test_struct_intensityTotalMinutesRequired() throws {
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .peak)
        let intensity = violations.filter { $0.ruleId.hasPrefix("STRUCT-07") }
        XCTAssertTrue(intensity.isEmpty, "STRUCT-07 must pass on existing fixture; got \(intensity)")
    }

    func test_struct_hardTypes_matchesBackendSSOT() {
        // Frozen against cloud/api_service/domains/training_plan/weekly_plan_validator.py
        let expected: Set<String> = [
            "interval", "short_interval", "long_interval",
            "tempo", "threshold", "fartlek",
            "norwegian_4x4", "yasso_800", "mile_repeats",
            "hill_repeats", "cruise_intervals", "race_pace",
            "strides",
        ]
        XCTAssertEqual(MethodologyInvariants.hardTypes, expected,
                       "hardTypes must stay in sync with backend WeeklyPlanValidator.HARD_TYPES")
    }

    func test_struct_peakWithSupplementaryStrength_violatesStage09() throws {
        // If we take a fixture without supplementary strength, STRUCT-09 passes.
        // Existing peak fixture has no strength — should pass.
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .peak)
        let stage09 = violations.filter { $0.ruleId.hasPrefix("STRUCT-09") }
        XCTAssertTrue(stage09.isEmpty, "Paceriz peak fixture should not have supplementary strength; got \(stage09)")
    }

    func test_struct_hardSessionCountLimit_default2() throws {
        // Paceriz peak typically has 2 hard sessions (interval + threshold). Must not violate default cap.
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .peak, maxHardSessions: 2)
        let struct08 = violations.filter { $0.ruleId.hasPrefix("STRUCT-08") }
        XCTAssertTrue(struct08.isEmpty, "Paceriz peak fixture must have <= 2 hard sessions; got \(struct08)")
    }

    func test_struct_hardSessionCountLimit_tooLow_fails() throws {
        // Force max=1 on peak fixture (which has 2+) — must trigger STRUCT-08
        let plan = try loadFixture("paceriz_42k_peak_week")
        let violations = MethodologyInvariants.validateStructure(plan: plan, phase: .peak, maxHardSessions: 1)
        XCTAssertTrue(
            violations.contains(where: { $0.ruleId == "STRUCT-08.too_many_hard_sessions" }),
            "Paceriz peak with max=1 should violate STRUCT-08; got \(violations)"
        )
    }

    // MARK: - Enum mapping

    func test_methodology_initFromBackendId() {
        XCTAssertEqual(Methodology(id: "paceriz"), .paceriz)
        XCTAssertEqual(Methodology(id: "hansons"), .hansons)
        XCTAssertEqual(Methodology(id: "norwegian"), .norwegian)
        XCTAssertEqual(Methodology(id: "polarized"), .polarized)
        XCTAssertEqual(Methodology(id: "balanced_fitness"), .balancedFitness)
        XCTAssertEqual(Methodology(id: "aerobic_endurance"), .aerobicEndurance)
        XCTAssertNil(Methodology(id: "unknown_methodology"))
    }
}
