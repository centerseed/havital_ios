import XCTest

final class APIClientRemovalACTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var sourceRoot: URL {
        repoRoot.appendingPathComponent("Havital")
    }

    func test_ac_apiref_01_api_client_removed() throws {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent("Services/APIClient.swift").path),
            "Havital/Services/APIClient.swift must be deleted."
        )

        let matches = try swiftSourceMatches(pattern: #"APIClient\b"#)
        XCTAssertTrue(matches.isEmpty, matches.joined(separator: "\n"))
    }

    func test_ac_apiref_02_call_sites_use_httpclient_or_repository() throws {
        let forbiddenCallSites = [
            "APIClient.shared",
            "EmailAuthService.shared"
        ]

        for forbidden in forbiddenCallSites {
            let matches = try swiftSourceMatches(pattern: NSRegularExpression.escapedPattern(for: forbidden))
            XCTAssertTrue(matches.isEmpty, "\(forbidden) remains:\n\(matches.joined(separator: "\n"))")
        }

        XCTAssertFileContains("Services/Core/FirebaseLoggingService.swift", "HTTPClient")
        XCTAssertFileContains("Features/TrainingPlan/Infrastructure/TrainingLoadDataManager.swift", "HealthDailyRepository")
        XCTAssertFileContains("Views/Settings/ClimateSettingsView.swift", "ClimateSettingsRepository")
        XCTAssertFileContains("Views/Settings/ClimateSettingsView.swift", "func resolveCurrentUid() async throws -> String")
        XCTAssertFileContains("Views/Settings/ClimateSettingsView.swift", "try await authSessionRepository.fetchCurrentUser()")
        XCTAssertFileContains("Features/Authentication/Data/Repositories/AuthSessionRepositoryImpl.swift", "getPersistedDemoUser()")
        XCTAssertFileContains("Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift", "authSessionRepository.setDemoUser(authUser)")
        XCTAssertFileContains("Features/Authentication/Data/DataSources/BackendAuthDataSource.swift", "/login/email")
    }

    func test_ac_apiref_03_workout_upload_contract_preserved() throws {
        let uploadService = try read("Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift")
        let remoteDataSource = try read("Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift")
        let repository = try read("Features/Workout/Domain/Repositories/WorkoutRepository.swift")

        XCTAssertTrue(uploadService.contains("WorkoutRepository"), "AppleHealth upload must use WorkoutRepository.")
        XCTAssertFalse(uploadService.contains("APIClient"), "AppleHealth upload must not reference APIClient.")
        XCTAssertTrue(remoteDataSource.contains(#""/v2/workouts""#), "Workout upload endpoint must remain /v2/workouts.")
        XCTAssertTrue(remoteDataSource.contains(#""/workout/summary/""#))
        XCTAssertTrue(repository.contains("uploadWorkout"))
        XCTAssertTrue(repository.contains("fetchWorkoutSummary"))
        XCTAssertTrue(uploadService.contains("isCancellationError") || uploadService.contains("HTTPError.cancelled"))
    }

    func test_ac_apiref_04_legacy_auth_and_errors_removed() throws {
        let patterns = [
            #"EmailAuthService\b"#,
            #"APINetworkError\b"#,
            #"APIErrorResponse\b"#,
            #"domain:\s*"APIClient""#
        ]

        for pattern in patterns {
            let matches = try swiftSourceMatches(pattern: pattern)
            XCTAssertTrue(matches.isEmpty, "Pattern \(pattern) remains:\n\(matches.joined(separator: "\n"))")
        }
    }

    func test_ac_apiref_05_build_and_smoke_evidence_recorded() throws {
        let plan = try String(contentsOf: repoRoot.appendingPathComponent("Docs/plans/PLAN-remove-apiclient-shared.md"))
        XCTAssertTrue(plan.contains("Resume Point"))
        XCTAssertTrue(plan.contains("xcodebuild build") || plan.contains("xcodebuild clean build"))
        XCTAssertTrue(plan.contains("workout upload"))
    }

    private func swiftSourceMatches(pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let files = try swiftFiles(under: sourceRoot)
        return try files.flatMap { file -> [String] in
            let text = try String(contentsOf: file)
            return text.enumeratedLines().compactMap { lineNumber, line in
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard regex.firstMatch(in: line, range: range) != nil else {
                    return nil
                }
                return "\(file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")):\(lineNumber): \(line)"
            }
        }
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL, url.pathExtension == "swift" else {
                return nil
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceRoot.appendingPathComponent(relativePath))
    }

    private func XCTAssertFileContains(
        _ relativePath: String,
        _ needle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let text = try read(relativePath)
            XCTAssertTrue(text.contains(needle), "\(relativePath) does not contain \(needle)", file: file, line: line)
        } catch {
            XCTFail("Failed to read \(relativePath): \(error)", file: file, line: line)
        }
    }
}

private extension String {
    func enumeratedLines() -> [(Int, String)] {
        split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { ($0.offset + 1, String($0.element)) }
    }
}
