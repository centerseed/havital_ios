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

    func test_first_batch_user_visible_i18n_strings_are_not_hardcoded() throws {
        let projectRoot = try projectRoot
        let filesAndForbiddenSnippets: [String: [String]] = [
            "Havital/Features/Authentication/Presentation/ViewModels/EmailLoginViewModel.swift": [
                "請點擊驗證信中的連結完成驗證後再登入。",
                "已重新發送驗證信，請至信箱查看。"
            ],
            "Havital/Core/Infrastructure/GarminManager.swift": [
                "connectionError = \"Garmin 功能暫時不可用，請稍後再試\"",
                "response.message.isEmpty ? \"Garmin 連接需要重新授權\"",
                "connectionError = \"初始化連接失敗:",
                "connectionError = \"中斷連接失敗:",
                "connectionError = \"無法顯示授權頁面\"",
                "handleConnectionError(\"無效的回調 URL\")",
                "handleConnectionError(\"Garmin 授權失敗:",
                "handleConnectionError(\"安全驗證失敗\")",
                "handleConnectionError(\"Garmin 連接失敗\")",
                "NSLocalizedDescriptionKey: \"中斷連接失敗\"",
                "NSLocalizedDescriptionKey: \"無效的 Garmin 授權 URL\"",
                "NSLocalizedDescriptionKey: \"無法建構授權 URL\"",
                "該 Garmin Connect™ 帳號已經綁定至另一個 Paceriz 帳號。"
            ],
            "Havital/Core/Infrastructure/StravaManager.swift": [
                "connectionError = \"Strava 功能暫時不可用，請稍後再試\"",
                "response.message.isEmpty ? \"Strava 連接需要重新授權\"",
                "connectionError = \"初始化連接失敗:",
                "connectionError = \"中斷連接失敗:",
                "connectionError = \"無法顯示授權頁面\"",
                "handleConnectionError(\"無效的回調 URL\")",
                "handleConnectionError(\"Strava 授權失敗:",
                "handleConnectionError(\"安全驗證失敗\")",
                "handleConnectionError(\"Strava 連接失敗\")",
                "NSLocalizedDescriptionKey: \"Code Verifier 未生成\"",
                "NSLocalizedDescriptionKey: \"中斷連接失敗\"",
                "NSLocalizedDescriptionKey: \"無效的 Strava 授權 URL\"",
                "NSLocalizedDescriptionKey: \"無法建構授權 URL\"",
                "該 Strava 帳號已經綁定至另一個 Paceriz 帳號。"
            ],
            "Havital/Core/Infrastructure/SyncNotificationManager.swift": [
                "開始同步訓練數據",
                "正在同步",
                "訓練數據同步完成",
                "已成功同步"
            ],
            "Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift": [
                "開始同步訓練數據",
                "正在同步",
                "訓練數據同步完成",
                "已成功同步",
                "正在處理歷史訓練數據",
                "系統正在處理您的"
            ],
            "Havital/Core/Infrastructure/CalendarManager.swift": [
                "Paceriz 訓練日",
                "今天是訓練日，記得按照計劃完成訓練！"
            ]
        ]

        var violations: [String] = []
        for (relativePath, snippets) in filesAndForbiddenSnippets {
            let content = try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
            for snippet in snippets where content.contains(snippet) {
                violations.append("\(relativePath): \(snippet)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "First-batch user-visible i18n strings must be localized, not hardcoded:\n\(violations.joined(separator: "\n"))"
        )
    }

    func test_second_batch_user_visible_error_strings_are_not_hardcoded() throws {
        let projectRoot = try projectRoot
        let filesAndForbiddenSnippets: [String: [String]] = [
            "Havital/Services/Authentication/AuthenticationService.swift": [
                "Firebase client ID 不存在",
                "無法顯示登入畫面",
                "缺少 Token",
                "發生未知錯誤，請稍後再試",
                "用戶未登入",
                "郵箱未驗證"
            ],
            "Havital/Features/Announcement/Domain/Errors/AnnouncementError.swift": [
                "公告載入失敗:",
                "標記已讀失敗:"
            ],
            "Havital/Services/Core/HTTPClient.swift": [
                "return \"無效的 URL:",
                "return \"無網路連接\"",
                "return \"請求超時\"",
                "return \"請求已取消\"",
                "return \"請求錯誤:",
                "return \"未授權:",
                "return \"禁止訪問:",
                "return \"需要訂閱才能使用此功能\"",
                "return \"Rizo AI 使用次數已達上限\"",
                "return \"資源不存在:",
                "return \"HTTP 錯誤",
                "return \"伺服器錯誤",
                "return \"網路錯誤:",
                "return \"無效回應:"
            ],
            "Havital/Services/Core/UnifiedAPIResponse.swift": [
                "return \"找不到資源:",
                "return \"未授權:",
                "return \"禁止訪問:",
                "return \"驗證失敗:",
                "return \"業務邏輯錯誤",
                "return \"任務已取消\"",
                "return \"配置錯誤:",
                "return \"存儲錯誤:",
                "return \"未知錯誤:"
            ],
            "Havital/Services/Core/APIParser.swift": [
                "return \"JSON 解析失敗:",
                "return \"容錯解析失敗:",
                "return \"無效數據:"
            ],
            "Havital/Core/Infrastructure/AppStateManager.swift": [
                "return \"初始化中...\"",
                "return \"驗證用戶身份...\"",
                "return \"載入用戶資料...\"",
                "return \"設置服務中...\"",
                "return \"就緒\"",
                "return \"錯誤:",
                "return \"免費版\"",
                "return \"付費版\"",
                "return \"已過期\""
            ],
            "Havital/Storage/TrainingReadinessStorage.swift": [
                "無緩存",
                "剛剛更新",
                "分鐘前更新",
                "小時前更新"
            ],
            "Havital/Features/TrainingPlan/Domain/UseCases/TrainingReadinessManager.swift": [
                "return \"載入中...\"",
                "return \"載入失敗:",
                "return \"暫無訓練準備度數據\"",
                "return \"準備度分析完成\""
            ],
            "Havital/Core/Infrastructure/CalendarManager.swift": [
                "NSLocalizedDescriptionKey: \"No sync preference set\"",
                "NSLocalizedDescriptionKey: \"Calendar access denied\"",
                "NSLocalizedDescriptionKey: \"無法創建事件時間\"",
                "NSLocalizedDescriptionKey: \"No default calendar available\""
            ],
            "Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanGenerator.swift": [
                "無法更新訓練計劃"
            ],
            "Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift": [
                "Health Kit 授權被拒絕"
            ],
            "Havital/Features/TrainingPlanV2/Domain/Entities/PlanOverviewV2.swift": [
                "低強度 / \\(",
                "中強度 / \\(",
                "高強度\""
            ]
        ]

        var violations: [String] = []
        for (relativePath, snippets) in filesAndForbiddenSnippets {
            let content = try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
            for snippet in snippets where content.contains(snippet) {
                violations.append("\(relativePath): \(snippet)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Second-batch user-visible error/display strings must be localized, not hardcoded:\n\(violations.joined(separator: "\n"))"
        )
    }

    func test_performance_chart_user_visible_errors_are_not_hardcoded() throws {
        let projectRoot = try projectRoot
        let filesAndForbiddenSnippets: [String: [String]] = [
            "Havital/Features/UserProfile/Presentation/ViewModels/SleepHeartRateViewModel.swift": [
                "self.error = \"HealthKit 管理器未初始化\"",
                "self.error = \"Strava 不提供靜息心率數據\"",
                "self.error = \"請先選擇數據來源\"",
                "self.error = \"無法載入睡眠心率數據\""
            ],
            "Havital/Features/UserProfile/Presentation/ViewModels/HRVChartViewModel.swift": [
                "self.error = \"無法載入心率變異性數據\"",
                "diagnosticsText = \"讀取授權:",
                "diagnosticsText = \"診斷失敗:",
                "self.error = \"讀取授權檢查失敗:"
            ],
            "Havital/Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModel.swift": [
                "self.error = \"無法載入跑力數據:"
            ]
        ]

        var violations: [String] = []
        for (relativePath, snippets) in filesAndForbiddenSnippets {
            let content = try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
            for snippet in snippets where content.contains(snippet) {
                violations.append("\(relativePath): \(snippet)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Performance chart user-visible errors must be localized, not hardcoded:\n\(violations.joined(separator: "\n"))"
        )
    }

    func test_authentication_domain_errors_are_not_hardcoded() throws {
        let projectRoot = try projectRoot
        let content = try String(
            contentsOf: projectRoot.appendingPathComponent("Havital/Features/Authentication/Domain/Errors/AuthError.swift"),
            encoding: .utf8
        )
        let forbiddenSnippets = [
            "return \"Google Sign-In failed:",
            "return \"Apple Sign-In failed:",
            "return \"Firebase authentication failed:",
            "return \"Backend sync failed:",
            "return \"Invalid credentials provided\"",
            "return \"Network connection failed\"",
            "return \"Authentication token has expired\"",
            "return \"User not found\"",
            "return \"Onboarding must be completed\"",
            "return \"App 版本過舊，請前往 App Store 更新\""
        ]
        let violations = forbiddenSnippets.filter { content.contains($0) }

        XCTAssertTrue(
            violations.isEmpty,
            "Authentication domain LocalizedError messages must be localized, not hardcoded:\n\(violations.joined(separator: "\n"))"
        )
    }

    func test_workout_formatting_user_visible_strings_are_not_hardcoded() throws {
        let projectRoot = try projectRoot
        let filesAndForbiddenSnippets: [String: [String]] = [
            "Havital/Utils/WorkoutUtils.swift": [
                "return \"無法計算\""
            ],
            "Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift": [
                "\\(sets) × \\(reps)次",
                "\\(sets) 組"
            ]
        ]

        var violations: [String] = []
        for (relativePath, snippets) in filesAndForbiddenSnippets {
            let content = try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
            for snippet in snippets where content.contains(snippet) {
                violations.append("\(relativePath): \(snippet)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Workout formatting strings must be localized, not hardcoded:\n\(violations.joined(separator: "\n"))"
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
        // 2.0 cutover（T-0306）：ContentView 掛的是 App2RootView shell，1.x 的
        // tab 建構子（MyAchievementView/PersonalAchievementsView）不再住這裡；
        // 成就面由 App2RootView 內的 PersonalAchievementsViewModel 承接。
        let contentView = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/Views/ContentView.swift"), encoding: .utf8)
        XCTAssertTrue(contentView.contains("App2RootView()"), "2.0 shell must be mounted by ContentView (T-0306 cutover).")

        let rootView = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Features/App2/Presentation/App2RootView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(rootView.contains("PersonalAchievementsViewModel()"), "Achievements surface must stay wired inside the App2 shell.")
    }

    func test_login_screen_exposes_pre_auth_language_picker() throws {
        // commit ffd2cbf: language picker changed from SwiftUI Picker to custom circular switcher.
        // "Picker(L10n.Login.language" no longer exists, but the feature is still present via
        // circular language switcher with accessibilityIdentifier "Login_LanguagePicker".
        let loginView = try String(
            contentsOf: try projectRoot.appendingPathComponent("Havital/Views/LoginView.swift"),
            encoding: .utf8
        )

        // First assertion updated: circular switcher replaces SwiftUI Picker, verify new implementation.
        XCTAssertTrue(loginView.contains("Login_LanguagePicker"), "Login language switcher needs a stable accessibility identifier for UI smoke tests.")
        XCTAssertTrue(loginView.contains("SupportedLanguage.allCases"), "Login language switcher must list every supported language.")
        XCTAssertTrue(loginView.contains("applyPreLoginLanguage"), "Login language changes must apply locally before backend sync.")
    }

    func test_auth_sync_uses_app_display_language_as_authority() throws {
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
        XCTAssertFalse(authRepository.contains("explicitLanguage"), "Auth sign-in sync must not use a stale explicit-language flag.")
        XCTAssertFalse(authSessionRepository.contains("explicitLanguage"), "Auth session refresh must not use a stale explicit-language flag.")
        XCTAssertTrue(authRepository.contains("language: nil"), "Auth sign-in sync must compare then write the App display language.")
        XCTAssertTrue(authSessionRepository.contains("language: nil"), "Auth session refresh must compare then write the App display language.")
        XCTAssertTrue(authRepository.contains("locale: Locale.current.identifier"), "Device info locale must remain device metadata, not account language.")
        XCTAssertTrue(authSessionRepository.contains("locale: Locale.current.identifier"), "Session refresh device locale must remain device metadata, not account language.")
    }

    func test_performance_data_page_keeps_personal_best_section() throws {
        // commit 61a9931: PB deliberately moved to the Achievements tab (PersonalAchievementsView).
        // MyAchievementView no longer contains PersonalBestCardView.
        // Guard updated to reflect current correct state: PB is now in the achievements tab.
        let achievementsView = try String(contentsOf: try projectRoot.appendingPathComponent("Havital/Features/Achievements/Presentation/Views/PersonalAchievementsView.swift"), encoding: .utf8)

        XCTAssertTrue(achievementsView.contains("cachedPersonalBestData"), "Personal Best data must be accessible in the Achievements tab (commit 61a9931).")
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
                let key = String(content[keyRange])
                // Skip interpolated keys (e.g. "benchmark.weekday.\(wd)"): they resolve to
                // dynamic values at runtime and cannot be statically matched against a single
                // strings entry. The concrete variants are covered by their own static keys.
                if key.contains("\\(") { return }
                keys.insert(key)
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
