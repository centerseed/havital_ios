import XCTest

/// AC tests for TD-garmin-initial-backfill-guard, iOS client side (S02 tasks).
///
/// AC-GARMIN-BF-01: OAuth callback must NOT directly call raw `/garmin/backfill`.
/// AC-GARMIN-BF-02: OAuth callback must call the ensure-initial guard endpoint instead.
/// AC-GARMIN-BF-03: Non-started decisions (already_requested, already_has_data, in_progress) must not block the UI.
///
/// S02 已實作（T-0463）：callback 改呼叫 `BackfillService.ensureInitialGarminBackfill`，
/// raw `/garmin/backfill` 路徑已從 App 端移除。
/// 這些測試鎖的是 TD 要求的原始碼層契約；decision 的行為驗證在 `BackfillServiceTests`。
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
        let manager = try readSource(at: "Havital/Core/Infrastructure/GarminManager.swift")
        XCTAssertFalse(
            sourceContains(manager, withinFunction: "handleCallback", callTo: "triggerOnboardingBackfill"),
            "AC-GARMIN-BF-01: handleCallback must not use triggerOnboardingBackfill (raw /garmin/backfill)"
        )

        // 掃整個 App 原始碼，而不是只看 BackfillService —— raw caller 曾經也存在於
        // Havital/Services/Integrations/Garmin/GarminService.swift（已於本次移除）。
        let offenders = try swiftSourcesContaining("path: \"/garmin/backfill\"")
        XCTAssertTrue(
            offenders.isEmpty,
            "AC-GARMIN-BF-01: the app must not call raw POST /garmin/backfill; offenders: \(offenders)"
        )
    }

    // MARK: - AC-GARMIN-BF-02: OAuth callback must call the ensure-initial guard

    func test_ac_garmin_bf_02_callback_calls_ensure_initial() throws {
        let manager = try readSource(at: "Havital/Core/Infrastructure/GarminManager.swift")
        XCTAssertTrue(
            sourceContains(manager, withinFunction: "handleCallback", callTo: "ensureInitialGarminBackfill"),
            "AC-GARMIN-BF-02: handleCallback must call ensureInitialGarminBackfill"
        )

        let service = try readSource(at: "Havital/Features/Workout/Infrastructure/BackfillService.swift")
        XCTAssertTrue(
            service.contains("path: \"/garmin/backfill/ensure-initial\""),
            "AC-GARMIN-BF-02: BackfillService must call the guard endpoint"
        )
    }

    // MARK: - AC-GARMIN-BF-03: Non-started decisions must be non-blocking

    func test_ac_garmin_bf_03_non_started_decision_is_non_blocking() throws {
        let service = try readSource(at: "Havital/Features/Workout/Infrastructure/BackfillService.swift")

        // callback 端呼叫的入口不得是 throwing 的：任何 decision 都不能往上拋去阻斷 OAuth 流程。
        // 只鎖「這個宣告沒有 throws」，不綁完整簽名字面，簽名調整不該讓這條假紅。
        let declaration = try XCTUnwrap(
            service
                .split(separator: "\n", omittingEmptySubsequences: false)
                .first { $0.contains("func ensureInitialGarminBackfill(") },
            "AC-GARMIN-BF-03: ensureInitialGarminBackfill must exist"
        )
        XCTAssertFalse(
            declaration.contains("throws"),
            "AC-GARMIN-BF-03: ensureInitialGarminBackfill must be a non-throwing background entry point, got: \(declaration)"
        )
    }

    // MARK: - Source Analysis Helpers

    /// 掃 `Havital/` 底下所有 Swift 檔，回傳含有 `needle` 的相對路徑。
    private func swiftSourcesContaining(_ needle: String) throws -> [String] {
        let root = try projectRoot.appendingPathComponent("Havital")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Unable to enumerate Havital sources")
        }
        var hits: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains(needle) {
                hits.append(url.lastPathComponent)
            }
        }
        return hits.sorted()
    }

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
