import XCTest

final class LocalizationCoverageTests: XCTestCase {
    private var projectRoot: URL {
        get throws { try findProjectRoot() }
    }

    func test_all_nslocalizedstring_literal_keys_exist_in_supported_locales() throws {
        let projectRoot = try projectRoot
        let swiftRoot = projectRoot.appendingPathComponent("Havital")
        let locales = ["en", "ja", "zh-Hant"]
        let usedKeys = try collectNSLocalizedStringLiteralKeys(under: swiftRoot)

        XCTAssertFalse(usedKeys.isEmpty, "Localization coverage test found no NSLocalizedString keys")

        for locale in locales {
            let stringsURL = projectRoot
                .appendingPathComponent("Havital/Resources")
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Localizable.strings")
            let definedKeys = try collectDefinedLocalizationKeys(from: stringsURL)
            let missing = usedKeys.subtracting(definedKeys).sorted()

            XCTAssertTrue(
                missing.isEmpty,
                "\(locale) Localizable.strings is missing \(missing.count) keys: \(missing.joined(separator: ", "))"
            )
        }
    }

    func test_all_l10n_static_string_keys_exist_and_are_non_empty_in_supported_locales() throws {
        let projectRoot = try projectRoot
        let localizationKeys = try String(contentsOf: projectRoot.appendingPathComponent("Havital/Utils/LocalizationKeys.swift"), encoding: .utf8)
        let l10nKeys = try collectAllL10nStringConstants(in: localizationKeys)

        XCTAssertGreaterThan(l10nKeys.count, 100, "L10n coverage should include all static string constants, not just one enum")

        for locale in ["en", "ja", "zh-Hant"] {
            let stringsURL = projectRoot
                .appendingPathComponent("Havital/Resources")
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Localizable.strings")
            let table = try collectLocalizationTable(from: stringsURL)
            let missing = l10nKeys.subtracting(Set(table.keys)).sorted()
            let empty = l10nKeys
                .filter { (table[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted()

            XCTAssertTrue(
                missing.isEmpty,
                "\(locale) Localizable.strings is missing L10n keys: \(missing.joined(separator: ", "))"
            )
            XCTAssertTrue(
                empty.isEmpty,
                "\(locale) Localizable.strings has empty L10n values: \(empty.joined(separator: ", "))"
            )
        }
    }

    func test_localized_values_do_not_fall_back_to_key_names() throws {
        let projectRoot = try projectRoot

        for locale in ["en", "ja", "zh-Hant"] {
            let stringsURL = projectRoot
                .appendingPathComponent("Havital/Resources")
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Localizable.strings")
            let table = try collectLocalizationTable(from: stringsURL)
            let fallbackValues = table
                .filter { key, value in value.trimmingCharacters(in: .whitespacesAndNewlines) == key }
                .map(\.key)
                .sorted()

            XCTAssertTrue(
                fallbackValues.isEmpty,
                "\(locale) Localizable.strings has values that would render raw key names: \(fallbackValues.joined(separator: ", "))"
            )
        }
    }

    func test_user_facing_swiftui_strings_are_not_hardcoded_traditional_chinese() throws {
        let swiftRoot = try projectRoot.appendingPathComponent("Havital")
        let violations = try collectHardcodedCJKUserFacingSwiftUIStrings(under: swiftRoot)

        XCTAssertTrue(
            violations.isEmpty,
            "User-facing SwiftUI strings must use localization, not hardcoded Traditional Chinese:\n\(violations.joined(separator: "\n"))"
        )
    }

    func test_typography_audit_harness_covers_release_gate_screens() throws {
        let app = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/HavitalApp.swift"), encoding: .utf8)
        let requiredScreens = [
            "case login",
            "case tabEntry = \"tab_entry\"",
            "case performance",
            "case profile",
            "case trainingHome = \"training_home\"",
            "case weekTimeline = \"week_timeline\""
        ]

        for screen in requiredScreens {
            XCTAssertTrue(app.contains(screen), "Typography audit harness must expose \(screen)")
        }

        XCTAssertTrue(app.contains("ProfileIdentityDisplay.emailText("), "Profile typography smoke must render the same private relay email display logic as UserProfileView.")
        XCTAssertTrue(app.contains("runner@privaterelay.appleid.com"), "Profile typography smoke must include an Apple private relay email fixture.")
        XCTAssertTrue(app.contains("LoginView()"), "Login typography smoke must render the pre-auth language selector.")
    }

    func test_typography_audit_harness_can_skip_notification_prompt_for_clean_screenshots() throws {
        let app = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/HavitalApp.swift"), encoding: .utf8)
        let appDelegate = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/AppDelegate.swift"), encoding: .utf8)
        let script = try String(contentsOf: try projectRoot.appendingPathComponent("Scripts/run_typography_i18n_smoke.sh"), encoding: .utf8)

        XCTAssertTrue(app.contains("-ui_testing_skip_notification_authorization"), "Typography smoke must be able to skip notification permission prompts.")
        XCTAssertTrue(appDelegate.contains("-ui_testing_skip_notification_authorization"), "Typography smoke must skip AppDelegate notification permission prompts.")
        XCTAssertTrue(script.contains("-ui_testing_skip_notification_authorization"), "Screenshot smoke script must launch with the notification prompt skip flag.")
    }

    func test_achievement_tab_entry_hidden_for_current_release() throws {
        let contentView = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/Views/ContentView.swift"), encoding: .utf8)

        XCTAssertTrue(contentView.contains("MyAchievementView()"), "Performance data tab must remain visible because it carries PB/performance metrics.")
        XCTAssertFalse(contentView.contains("PersonalAchievementsView()"), "Awards tab must remain hidden for this release.")
        XCTAssertFalse(contentView.contains("L10n.Tab.achievement.localized"), "Awards tab label must not be wired into ContentView for this release.")
    }

    func test_login_screen_exposes_pre_auth_language_picker() throws {
        let loginView = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Views/LoginView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(loginView.contains("Picker(L10n.Login.language.localized"), "Login screen must expose a language picker before authentication.")
        XCTAssertTrue(loginView.contains("SupportedLanguage.allCases"), "Login language picker must list every supported language.")
        XCTAssertTrue(loginView.contains("applyPreLoginLanguage"), "Login language changes must apply locally before backend sync.")
        XCTAssertTrue(loginView.contains("Login_LanguagePicker"), "Login language picker needs a stable accessibility identifier for UI smoke tests.")
    }

    func test_auth_sync_sends_selected_app_language_as_account_preference() throws {
        let syncRequest = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Features/Authentication/Data/DTOs/UserSyncRequest.swift"),
            encoding: .utf8
        )
        let authRepository = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift"),
            encoding: .utf8
        )
        let authSessionRepository = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Features/Authentication/Data/Repositories/AuthSessionRepositoryImpl.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(syncRequest.contains("let language: String?"), "Auth sync request must carry an explicit account language preference.")
        XCTAssertTrue(authRepository.contains("LanguageManager.shared.currentLanguage.apiCode"), "Auth sign-in sync must send the selected app language.")
        XCTAssertTrue(authSessionRepository.contains("LanguageManager.shared.currentLanguage.apiCode"), "Auth session refresh must send the selected app language.")
        XCTAssertTrue(authRepository.contains("language: appLanguageCode"), "Auth sign-in sync must persist the selected app language as account language.")
        XCTAssertTrue(authSessionRepository.contains("language: appLanguageCode"), "Auth session refresh must persist the selected app language as account language.")
        XCTAssertTrue(authRepository.contains("locale: Locale.current.identifier"), "Device info locale must remain device metadata, not account language.")
        XCTAssertTrue(authSessionRepository.contains("locale: Locale.current.identifier"), "Session refresh device locale must remain device metadata, not account language.")
    }

    func test_performance_data_page_keeps_personal_best_section() throws {
        let performanceView = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/Views/MyAchievementView.swift"), encoding: .utf8)

        XCTAssertTrue(performanceView.contains("PersonalBestCardView("), "Performance data page must keep Personal Best visible while Awards tab is hidden.")
        XCTAssertTrue(performanceView.contains("cachedPersonalBestData"), "Performance data PB section must use cached user personal_best_v2 data.")
    }

    private func findProjectRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            let candidate = current.deletingLastPathComponent()
            let resources = candidate.appendingPathComponent("Havital/Resources/en.lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: resources.path) {
                return candidate
            }
            current = candidate
        }
        throw XCTSkip("Unable to locate project root from #filePath")
    }

    private func collectNSLocalizedStringLiteralKeys(under root: URL) throws -> Set<String> {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var keys = Set<String>()
        let pattern = #"NSLocalizedString\(\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            regex.enumerateMatches(in: content, range: range) { match, _, _ in
                guard let match,
                      let keyRange = Range(match.range(at: 1), in: content) else { return }
                keys.insert(String(content[keyRange]))
            }
        }

        return keys
    }

    private func collectAllL10nStringConstants(in content: String) throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: #"static\s+let\s+\w+\s*=\s*"([^"]+)""#)
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        var keys = Set<String>()

        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let keyRange = Range(match.range(at: 1), in: content) else { return }
            keys.insert(String(content[keyRange]))
        }

        return keys
    }

    private func collectDefinedLocalizationKeys(from stringsURL: URL) throws -> Set<String> {
        Set(try collectLocalizationTable(from: stringsURL).keys)
    }

    private func collectLocalizationTable(from stringsURL: URL) throws -> [String: String] {
        let content = try String(contentsOf: stringsURL, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^\s*"((?:\\"|[^"])*)"\s*=\s*"((?:\\"|[^"])*)"\s*;"#, options: [.anchorsMatchLines])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        var table: [String: String] = [:]

        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let keyRange = Range(match.range(at: 1), in: content),
                  let valueRange = Range(match.range(at: 2), in: content) else { return }
            table[String(content[keyRange])] = String(content[valueRange])
        }

        return table
    }

    private func collectHardcodedCJKUserFacingSwiftUIStrings(under root: URL) throws -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let userFacingAPIPattern = #"(Text|Button|Label|Section|navigationTitle|alert|TextField|SecureField|Picker|Toggle|confirmationDialog|ToolbarButtonLabel|ProgressView|SharePreview)\("#
        let userFacingAPIRegex = try NSRegularExpression(pattern: userFacingAPIPattern)
        let cjkRegex = try NSRegularExpression(pattern: #""(?:\\"|[^"])*\p{Han}(?:\\"|[^"])*""#)
        var violations: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let path = fileURL.path
            if path.contains("/Debug/")
                || path.contains("/Deprecated/")
                || path.contains("/PreviewHelpers/")
                || path.contains("/GeneratedAssetSymbols.swift") {
                continue
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            var debugDepth = 0
            var previewDepth = 0
            var pendingPreview = false

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("#if DEBUG") {
                    debugDepth += 1
                }

                if trimmed.hasPrefix("#Preview") {
                    pendingPreview = true
                }

                if pendingPreview, line.contains("{") {
                    previewDepth += braceDelta(in: line)
                    pendingPreview = false
                } else if previewDepth > 0 {
                    previewDepth += braceDelta(in: line)
                }

                defer {
                    if trimmed.hasPrefix("#endif"), debugDepth > 0 {
                        debugDepth -= 1
                    }
                }

                guard debugDepth == 0, previewDepth == 0 else { continue }
                guard !trimmed.hasPrefix("//") else { continue }
                guard !line.contains("NSLocalizedString(") else { continue }

                let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
                guard userFacingAPIRegex.firstMatch(in: line, range: lineRange) != nil,
                      cjkRegex.firstMatch(in: line, range: lineRange) != nil else {
                    continue
                }

                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "Havital/")
                violations.append("\(relativePath):\(index + 1): \(trimmed)")
            }
        }

        return violations.sorted()
    }

    private func braceDelta(in line: String) -> Int {
        line.reduce(0) { count, character in
            switch character {
            case "{": return count + 1
            case "}": return count - 1
            default: return count
            }
        }
    }
}
