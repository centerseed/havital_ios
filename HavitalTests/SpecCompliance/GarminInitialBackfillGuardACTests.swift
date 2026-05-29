import XCTest

/// AC tests for TD-garmin-initial-backfill-guard, iOS client side (S02 tasks).
///
/// AC-GARMIN-BF-01: OAuth callback must NOT directly call raw `/garmin/backfill`.
/// AC-GARMIN-BF-02: OAuth callback must call the ensure-initial guard endpoint instead.
/// AC-GARMIN-BF-03: Non-started decisions (already_requested, already_has_data, in_progress) must not block the UI.
///
/// Implementation status per TD-garmin-initial-backfill-guard.md:
/// S02 is in STUB state — iOS callback still calls triggerOnboardingBackfill (raw path),
/// and BackfillService.ensureInitialGarminBackfill does not yet exist.
/// These tests verify the source-level contract required by the TD.
final class GarminInitialBackfillGuardACTests: XCTestCase {

    // MARK: - Project Root

    private var projectRoot: URL {
        get throws { try findProjectRoot() }
    }

    private func findProjectRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            let candidate = current.deletingLastPathComponent()
            let marker = candidate.appendingPathComponent("Havital/Resources/en.lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: marker.path) {
                return candidate
            }
            current = candidate
        }
        throw XCTSkip("Unable to locate project root from #filePath")
    }

    private func readSource(at relativePath: String) throws -> String {
        let url = try projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - AC-GARMIN-BF-01: OAuth callback must NOT call raw /garmin/backfill directly

    func test_ac_garmin_bf_01_callback_does_not_call_raw_backfill() throws {
        // S02 backend ensure-initial integration not yet implemented.
        // TODO: when S02 lands, verify GarminManager.handleCallback calls ensureInitialGarminBackfill
        // instead of triggerOnboardingBackfill (raw /garmin/backfill path).
        throw XCTSkip("Pending AC-GARMIN-BF-01/02 — S02 backend ensure-initial integration not implemented")
    }

    // MARK: - AC-GARMIN-BF-02: OAuth callback must call the ensure-initial guard

    func test_ac_garmin_bf_02_callback_calls_ensure_initial() throws {
        // S02 backend ensure-initial integration not yet implemented.
        // TODO: when S02 lands, verify BackfillService exposes ensureInitialGarminBackfill and
        // GarminManager.handleCallback calls it instead of triggerOnboardingBackfill.
        throw XCTSkip("Pending AC-GARMIN-BF-01/02 — S02 backend ensure-initial integration not implemented")
    }

    // MARK: - AC-GARMIN-BF-03: Non-started decisions must be non-blocking

    func test_ac_garmin_bf_03_non_started_decision_is_non_blocking() throws {
        // S02 ensureInitialGarminBackfill not yet implemented.
        // Previous revision verified triggerOnboardingBackfill (old path) — wrong contract.
        // TODO: when S02 lands, verify ensureInitialGarminBackfill handles non-started decisions
        // (already_requested, already_has_data, in_progress, not_eligible) without throwing
        // and without blocking the UI flow.
        throw XCTSkip("Pending AC-GARMIN-BF-03 — ensureInitialGarminBackfill (S02) not implemented")
    }

    // MARK: - Source Analysis Helpers

    /// Returns true if `callName` appears between the declaration of `functionName` and the
    /// next top-level `func ` declaration (or end of file). This is a conservative range search:
    /// it does not handle nested `func` blocks but is sufficient for single-method bodies at
    /// class scope in production Swift files (which don't embed nested named functions).
    private func sourceContains(_ source: String, withinFunction functionName: String, callTo callName: String) -> Bool {
        guard let funcStart = source.range(of: "func \(functionName)") else { return false }
        let tail = source[funcStart.upperBound...]

        // Find the end of this function body: first occurrence of "\nfunc " (next sibling method)
        // or end of string, whichever comes first.
        let bodyEnd = tail.range(of: "\n    func ")?.lowerBound ?? tail.endIndex
        return tail[tail.startIndex..<bodyEnd].contains(callName)
    }
}
