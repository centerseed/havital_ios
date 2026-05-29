import XCTest

/// AC test stubs for StoreKit Test isolation (P0-21).
///
/// Spec source: cloud/api_service/docs/01-specs/SPEC-iap-subscription.md
/// Each test corresponds to one AC under "P0-21 StoreKit Test 隔離（2026-04-28 新增，iOS）".
///
/// AC-IAP-21-04 (CI lint guard) is implemented as a separate shell script:
/// `apps/ios/Havital/scripts/check_no_storekit_in_main_target.sh`
///
/// Developer must fill each body and confirm it PASSES.
final class StoreKitIsolationTests: XCTestCase {

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

    /// AC-IAP-21-01:
    /// Given iOS 專案結構，
    /// Then `apps/ios/Havital/Havital/` 目錄下不得存在 `*.storekit` file。
    ///
    /// NOTE: This test verifies the file-system constraint at test runtime
    /// by scanning the Havital source directory for .storekit files.
    func testAC_IAP_21_01_noStoreKitFileInMainTarget() throws {
        // Scan the main app source directory (Havital/) for *.storekit files.
        // StoreKit configuration files belong only in HavitalUITests/.
        let mainTargetDir = try projectRoot.appendingPathComponent("Havital")

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: mainTargetDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            XCTFail("Unable to enumerate \(mainTargetDir.path)")
            return
        }

        var storekitFilesFound: [String] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "storekit" {
                let relativePath = fileURL.path.replacingOccurrences(of: mainTargetDir.path + "/", with: "Havital/")
                storekitFilesFound.append(relativePath)
            }
        }

        XCTAssertTrue(
            storekitFilesFound.isEmpty,
            "AC-IAP-21-01 FAIL: Found *.storekit files in main app target Havital/: \(storekitFilesFound). " +
            "StoreKit configuration files must only exist in HavitalUITests/ (never in the main target)."
        )
    }

    /// AC-IAP-21-02:
    /// Given Xcode `*.xcscheme` files（含 user-specific `xcuserdata/`），
    /// Then 不得在 `Run > Options > StoreKit Configuration` 引用任何 `*.storekit` file。
    ///
    /// NOTE: This test reads xcscheme XML files and asserts no
    /// StoreKitConfiguration key references a .storekit path.
    func testAC_IAP_21_02_noSchemeReferencesStoreKitConfig() throws {
        // Scan all *.xcscheme files in the project (including xcuserdata).
        // Assert none of them contain a StoreKitConfiguration reference.
        let xcprojDir = try projectRoot.appendingPathComponent("Havital.xcodeproj")

        guard FileManager.default.fileExists(atPath: xcprojDir.path) else {
            throw XCTSkip("Havital.xcodeproj not found at expected path — skipping scheme scan")
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: xcprojDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("Unable to enumerate \(xcprojDir.path)")
            return
        }

        var schemesWithStoreKit: [(scheme: String, line: String)] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "xcscheme" {
            let content: String
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                // Skip unreadable schemes
                continue
            }

            // Look for StoreKitConfiguration XML attribute referencing a .storekit file.
            // Xcode scheme XML contains: StoreKitConfiguration = "relative/path/file.storekit"
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if (trimmed.contains("StoreKitConfiguration") || trimmed.lowercased().contains("storekit"))
                    && trimmed.contains(".storekit") {
                    let relativeSchemePath = fileURL.path
                        .replacingOccurrences(of: xcprojDir.path + "/", with: "Havital.xcodeproj/")
                    schemesWithStoreKit.append((scheme: relativeSchemePath, line: trimmed))
                }
            }
        }

        XCTAssertTrue(
            schemesWithStoreKit.isEmpty,
            "AC-IAP-21-02 FAIL: xcscheme files reference StoreKit configuration. " +
            "Schemes with StoreKit references: \(schemesWithStoreKit.map { "\($0.scheme): \($0.line)" }.joined(separator: "; "))"
        )
    }

    /// AC-IAP-21-03:
    /// Given `HavitalUITests/PacerizUITests.storekit` 保留作為 UI test 專用，
    /// When UI test 跑 `SKTestSession`，
    /// Then 必須在 `tearDown` 呼叫 `clearTransactions()` + `resetToDefaultState()` 並驗證。
    ///
    /// NOTE: Inspect HavitalUITests source to confirm tearDown contract is implemented.
    func testAC_IAP_21_03_uitestTearDownClearsTransactions() throws {
        // Scan HavitalUITests/ for any file that uses SKTestSession.
        // For each such file, verify tearDown (or tearDownWithError) calls:
        //   - clearTransactions()
        //   - resetToDefaultState()
        let uitestDir = try projectRoot.appendingPathComponent("HavitalUITests")

        guard FileManager.default.fileExists(atPath: uitestDir.path) else {
            throw XCTSkip("HavitalUITests directory not found — skipping tearDown contract check")
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: uitestDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("Unable to enumerate \(uitestDir.path)")
            return
        }

        // Collect SKTestSession files once, caching content to avoid a second read pass.
        var skSessionFiles: [(url: URL, content: String)] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                  content.contains("SKTestSession") else { continue }
            skSessionFiles.append((url: fileURL, content: content))
        }

        // At least one UITest file must use SKTestSession (PacerizUITests.storekit is preserved for this).
        XCTAssertFalse(
            skSessionFiles.isEmpty,
            "AC-IAP-21-03: Expected at least one HavitalUITests file to use SKTestSession. " +
            "No SKTestSession usage found in HavitalUITests/."
        )

        // The authoritative check: clearTransactions() and resetToDefaultState() must appear
        // inside the tearDown body (not just anywhere in the file). A broad whole-file presence
        // check would pass even when the calls are only in setUp, which does not satisfy the AC.
        for (fileURL, content) in skSessionFiles {
            let relativePath = fileURL.path
                .replacingOccurrences(of: uitestDir.path + "/", with: "HavitalUITests/")

            let hasTearDown = content.contains("override func tearDown") ||
                content.contains("override func tearDownWithError")
            guard hasTearDown else {
                XCTFail("AC-IAP-21-03: \(relativePath) uses SKTestSession but has no tearDown method.")
                continue
            }

            let tearDownBody = contextAfterTearDown(in: content)
            XCTAssertTrue(
                tearDownBody.contains("clearTransactions"),
                "AC-IAP-21-03: \(relativePath) — tearDown must call clearTransactions() " +
                "to reset StoreKit state between tests."
            )
            XCTAssertTrue(
                tearDownBody.contains("resetToDefaultState"),
                "AC-IAP-21-03: \(relativePath) — tearDown must call resetToDefaultState() " +
                "to reset StoreKit state between tests."
            )
        }
    }

    // MARK: - Helpers

    /// Returns the text starting from the first tearDown declaration in `source`,
    /// up to 1500 characters — enough to cover a typical tearDown body.
    private func contextAfterTearDown(in source: String) -> String {
        let markers = ["override func tearDownWithError", "override func tearDown"]
        for marker in markers {
            if let range = source.range(of: marker) {
                return String(source[range.lowerBound...].prefix(1500))
            }
        }
        return ""
    }
}
