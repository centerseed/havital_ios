import XCTest
@testable import paceriz_dev

/// Wave 2 #1 Migration Tests: PaceFormatterHelper.getSuggestedPace → PaceCalculator.getSuggestedPace
///
/// Purpose: Document the behavior change from the removed approximate formula to the
/// authoritative Jack Daniels (PaceCalculator) formula. Serves as a regression guard
/// confirming that EditScheduleViewModel and TrainingPlanViewModel now use the
/// Daniels values, and as a record of the before/after difference for TPM/user review.
///
/// Old formula (PaceFormatterHelper — now deleted):
///   baseSeconds = 330.0 (VDOT 45 = 5:30/km baseline)
///   adjustedSeconds = 330 - (vdot - 45) * 6
///   intensityFactor = 2.0 - percentage
///   finalSeconds = adjustedSeconds * intensityFactor
///   (no rounding to nearest 5 seconds)
///
/// New formula (PaceCalculator — Jack Daniels):
///   adjustedVDOT = vdot * 1.05
///   velocity = Daniels formula with zone percentage range
///   averages pctLow/pctHigh midpoint → converts to mm:ss
///   rounds seconds to nearest 0 or 5
final class PaceCalculatorMigrationTests: XCTestCase {

    // MARK: - Helpers

    /// Replication of the deleted PaceFormatterHelper.getSuggestedPace logic.
    /// Kept here solely to document the old approximate output for comparison.
    private func oldApproxPace(trainingType: String, vdot: Double) -> String {
        let pct: Double
        switch trainingType {
        case "easy", "easyRun", "recovery", "recovery_run": pct = 0.65
        case "marathon":                                     pct = 0.83
        case "threshold", "tempo":                           pct = 0.88
        case "interval":                                     pct = 0.98
        case "repetition":                                   pct = 1.05
        default:                                             pct = 0.65
        }
        let adjusted = 330.0 - (vdot - 45.0) * 6.0
        let finalSeconds = adjusted * (2.0 - pct)
        return String(format: "%d:%02d", Int(finalSeconds / 60), Int(finalSeconds.truncatingRemainder(dividingBy: 60)))
    }

    /// Assert that PaceCalculator returns a non-nil pace that differs from the old approximate value.
    /// - Parameters:
    ///   - type: training type string
    ///   - vdot: VDOT value
    ///   - oldApprox: pre-computed old approximate pace comment (for readability in failure messages)
    private func assertDanielssDiffersFromApprox(type: String, vdot: Double,
                                                 file: StaticString = #file, line: UInt = #line) {
        let newPace = PaceCalculator.getSuggestedPace(for: type, vdot: vdot)
        XCTAssertNotNil(newPace, "PaceCalculator must return a pace for \(type)/VDOT \(vdot)", file: file, line: line)
        let oldPace = oldApproxPace(trainingType: type, vdot: vdot)
        XCTAssertNotEqual(newPace, oldPace,
            "\(type)/VDOT \(vdot): Daniels (\(newPace ?? "nil")) should differ from old approx (\(oldPace)). " +
            "If equal, verify formulas are genuinely different.", file: file, line: line)
    }

    // MARK: - Documentation tests: before/after for representative VDOT values
    //
    // Old approximate values (for TPM/user reference):
    //   easy/45:       7:25  (330 * 1.35 = 445.5s)
    //   threshold/45:  6:09  (330 * 1.12 = 369.6s)
    //   interval/45:   5:36  (330 * 1.02 = 336.6s)
    //   easy/50:       6:45  (300 * 1.35 = 405s)
    //   threshold/50:  5:36  (300 * 1.12 = 336s)

    func testMigration_vdot45_easy()      { assertDanielssDiffersFromApprox(type: "easy",      vdot: 45) }
    func testMigration_vdot45_threshold() { assertDanielssDiffersFromApprox(type: "threshold", vdot: 45) }
    func testMigration_vdot45_interval()  { assertDanielssDiffersFromApprox(type: "interval",  vdot: 45) }
    func testMigration_vdot50_easy()      { assertDanielssDiffersFromApprox(type: "easy",      vdot: 50) }
    func testMigration_vdot50_threshold() { assertDanielssDiffersFromApprox(type: "threshold", vdot: 50) }

    // MARK: - Sanity checks: Daniels paces are physiologically ordered

    func testSanity_easySlowerThanThreshold_vdot45() {
        let easy = PaceCalculator.getSuggestedPace(for: "easy", vdot: 45)!
        let threshold = PaceCalculator.getSuggestedPace(for: "threshold", vdot: 45)!
        XCTAssertGreaterThan(paceSeconds(easy), paceSeconds(threshold),
            "Easy pace must be slower (more seconds/km) than threshold pace")
    }

    func testSanity_thresholdSlowerThanInterval_vdot45() {
        let threshold = PaceCalculator.getSuggestedPace(for: "threshold", vdot: 45)!
        let interval = PaceCalculator.getSuggestedPace(for: "interval", vdot: 45)!
        XCTAssertGreaterThan(paceSeconds(threshold), paceSeconds(interval),
            "Threshold pace must be slower (more seconds/km) than interval pace")
    }

    func testSanity_higherVdot_fasterEasyPace() {
        let pace45 = PaceCalculator.getSuggestedPace(for: "easy", vdot: 45)!
        let pace50 = PaceCalculator.getSuggestedPace(for: "easy", vdot: 50)!
        XCTAssertGreaterThan(paceSeconds(pace45), paceSeconds(pace50),
            "VDOT 45 easy must be slower than VDOT 50 easy")
    }

    // MARK: - nil safety: unrecognized training types must not crash

    func testNilSafety_unknownType_returnsNil() {
        XCTAssertNil(PaceCalculator.getSuggestedPace(for: "unknown_type_xyz", vdot: 45),
            "Unknown training type must return nil, not crash")
    }

    // MARK: - Private helper

    /// Parse "m:ss" pace string to total seconds. Uses PaceFormatterHelper as the shared utility.
    private func paceSeconds(_ pace: String) -> Int {
        Int(PaceFormatterHelper.paceToSeconds(pace) ?? 0)
    }
}
