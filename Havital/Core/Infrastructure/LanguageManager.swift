import Foundation
import SwiftUI
import Combine
import ObjectiveC

/// Manager for handling app language preferences and localization
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let languageKey = "app_language_preference"
    private static let languageChangedNotification = NSNotification.Name("LanguageDidChange")

    /// 語言同步失敗時發布，LanguageSettingsView 監聽後顯示 alert
    @Published var lastSyncError: String?

    @Published private(set) var currentLanguage: SupportedLanguage

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Load saved language preference or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: Self.languageKey),
           let language = SupportedLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Use system's preferred language
            let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "zh-Hant"
            self.currentLanguage = SupportedLanguage(rawValue: preferredLanguage) ?? .traditionalChinese
        }

        // Apply the language on init (but don't sync with backend during init)
        applyLanguageWithoutBackendSync()

        // Initialize AppFont's language cache
        AppFont.updateLanguage(currentLanguage)

        // Debug: Print language initialization info
        Logger.debug("LanguageManager initialized with: \(currentLanguage.rawValue) (API: \(currentLanguage.apiCode))")
    }
    
    // MARK: - Language Change (Single Path)

    /// 唯一的語言切換入口。先同步後端，成功後套用本地並 restart。
    /// 失敗則回滾本地語言並透過 `lastSyncError` 通知 UI。
    func changeLanguageWithBackendSync(to newLanguage: SupportedLanguage) async {
        let previousLanguage = currentLanguage
        guard newLanguage != previousLanguage else { return }

        do {
            try await syncLanguageToBackend(newLanguage.apiCode)
            // 後端成功 → 套用本地
            applyLocalLanguage(newLanguage)
            Logger.firebase("Language changed and synced: \(newLanguage.apiCode)", level: .info)
        } catch {
            if error.isCancellationError {
                Logger.debug("語言同步任務被取消，忽略錯誤")
                return
            }
            // 後端失敗 → 回滾，發布錯誤讓 UI 顯示
            Logger.firebase("Failed to sync language with backend: \(error.localizedDescription)", level: .error)
            lastSyncError = error.localizedDescription
        }
    }

    /// Fetch user preferences from backend and apply language locally
    func fetchUserPreferences() async throws {
        let httpClient = DefaultHTTPClient.shared
        let data = try await httpClient.request(
            path: "/user/preferences",
            method: .GET
        )

        // 後端回傳結構: { "language": "zh-TW", ... } 或巢狀在 "data" 裡
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Logger.firebase("fetchUserPreferences: response is not a JSON object", level: .warn)
            return
        }

        // 嘗試頂層 language，再嘗試 data.language
        let languageCode: String? = {
            if let code = json["language"] as? String { return code }
            if let nested = json["data"] as? [String: Any],
               let code = nested["language"] as? String { return code }
            return nil
        }()

        guard let code = languageCode,
              let language = SupportedLanguage(apiCode: code) else {
            Logger.firebase("fetchUserPreferences: unrecognised language in response", level: .warn)
            return
        }

        applyLocalLanguage(language)
    }

    // MARK: - Apply from External Source

    /// 後端已確認的語言套用到本地（供 Repository / Legacy Manager 呼叫）。
    /// 不觸碰後端，僅更新本地狀態。
    func applyFromBackend(_ language: SupportedLanguage) {
        applyLocalLanguage(language)
    }

    // MARK: - Private Helpers

    /// 套用語言到本地（UserDefaults + Bundle + 通知），不觸碰後端
    private func applyLocalLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        Bundle.setLanguage(language.rawValue)

        NotificationCenter.default.post(
            name: Self.languageChangedNotification,
            object: language
        )

        AppFont.updateLanguage(language)
        Logger.firebase("Language applied locally: \(language.rawValue)", level: .info)
    }

    /// Apply language without backend sync (for initialization)
    private func applyLanguageWithoutBackendSync() {
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        Bundle.setLanguage(currentLanguage.rawValue)
        NotificationCenter.default.post(
            name: Self.languageChangedNotification,
            object: currentLanguage
        )
        Logger.firebase("Language applied on init: \(currentLanguage.rawValue)", level: .info)
    }

    /// PUT /user/preferences with language code
    private func syncLanguageToBackend(_ languageCode: String) async throws {
        let body = ["language": languageCode]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let httpClient = DefaultHTTPClient.shared
        _ = try await APICallTracker.$currentSource.withValue("LanguageManager: syncLanguageToBackend") {
            try await httpClient.request(path: "/user/preferences", method: .PUT, body: bodyData)
        }
    }
    
    /// 唯一公開方法：同步後端 → 套用本地 → restart。
    /// 由 LanguageSettingsView 呼叫。成功回傳 true，失敗回傳 false（已回滾）。
    func performLanguageChangeWithRestart(to language: SupportedLanguage) async -> Bool {
        await changeLanguageWithBackendSync(to: language)

        // 如果有錯誤表示同步失敗，已回滾
        if lastSyncError != nil { return false }

        // 成功 → restart
        restartApp()
        return true
    }
    
    /// Restart the application
    private func restartApp() {
        // Method 1: Try to trigger a scene refresh
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Save a flag to indicate language was changed
            UserDefaults.standard.set(true, forKey: "language_changed_restart")
            
            // Post notification to trigger UI refresh in the main app
            NotificationCenter.default.post(
                name: NSNotification.Name("AppShouldRefreshForLanguageChange"),
                object: currentLanguage
            )
            
            // Force UI refresh by requesting scene session refresh
            UIApplication.shared.requestSceneSessionRefresh(windowScene.session)
            
            Logger.firebase("App restart requested due to language change", level: .info)
        } else {
            // Method 2: Fallback - Show alert to user to manually restart
            Logger.firebase("Fallback: Requesting manual app restart", level: .info)
            
            let alert = UIAlertController(
                title: "Language Changed",
                message: "Please close and reopen the app to apply the language change.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                // Don't force exit, let user restart manually
            })
            
            // Present alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    /// Get localized string for a key
    static func localized(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
    
    /// Debug function to print current language info
    func debugPrintLanguageInfo() {
        Logger.debug("LanguageManager Debug Info:")
        Logger.debug("- Current language: \(currentLanguage.rawValue)")
        Logger.debug("- API code: \(currentLanguage.apiCode)")
        Logger.debug("- Display name: \(currentLanguage.displayName)")
        Logger.debug("- System preferred: \(Bundle.main.preferredLocalizations.first ?? "unknown")")
    }
    
    /// Test function to validate language API communication
    func testLanguageAPIHeaderSupport() async {
        Logger.debug("Testing language API header support...")
        
        // Print current language info
        debugPrintLanguageInfo()
        
        // Test what would be sent in Accept-Language header
        Logger.debug("Accept-Language header will be: \(currentLanguage.apiCode)")
        
        // Validate that API codes match the backend requirements
        let supportedCodes = ["zh-TW", "en-US", "ja-JP"]
        let currentCode = currentLanguage.apiCode
        
        if supportedCodes.contains(currentCode) {
            Logger.debug("✅ Current language (\(currentCode)) is supported by backend")
        } else {
            Logger.error("❌ Current language (\(currentCode)) is not supported by backend")
        }
        
        // Test all supported language mappings
        Logger.debug("Testing all language mappings:")
        for language in SupportedLanguage.allCases {
            Logger.debug("- \(language.rawValue) → \(language.apiCode)")
        }
    }
    
    /// Format date according to current locale
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Format time according to current locale
    func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        formatter.dateStyle = .none
        formatter.timeStyle = style
        return formatter.string(from: date)
    }
    
    /// Format number according to current locale
    func formatNumber(_ number: Double, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    /// Format distance — delegates to UnitManager for unit conversion
    func formatDistance(_ distanceInKm: Double) -> String {
        return UnitManager.shared.formatDistance(distanceInKm)
    }

    /// Format pace — delegates to UnitManager for unit conversion
    func formatPace(_ paceInSeconds: Double) -> String {
        return UnitManager.shared.formatPace(secondsPerKm: paceInSeconds)
    }
}

// MARK: - Unit Preference
// Note: Currently only metric units are supported by the backend
// Imperial unit support will be added in the future when backend is ready
enum UnitPreference: String, CaseIterable {
    case metric = "metric"
    // case imperial = "imperial"  // TODO: Enable when backend supports imperial units
    
    var displayName: String {
        switch self {
        case .metric:
            return L10n.Settings.metric.localized
        // case .imperial:
        //     return L10n.Settings.imperial.localized
        }
    }
}

// MARK: - SwiftUI Environment Key
private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue = LanguageManager.shared
}

extension EnvironmentValues {
    var languageManager: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Apply language manager to view hierarchy
    func withLanguageManager() -> some View {
        self.environment(\.languageManager, LanguageManager.shared)
    }
}

// MARK: - Bundle Extension for Dynamic Language Switching
extension Bundle {
    private static var bundleKey: UInt8 = 0
    
    class LanguageBundle: Bundle {
        override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
            return (objc_getAssociatedObject(self, &Bundle.bundleKey) as? Bundle)?
                .localizedString(forKey: key, value: value, table: tableName) ?? 
                super.localizedString(forKey: key, value: value, table: tableName)
        }
    }
    
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            Logger.firebase("Failed to find language bundle for: \(language)", level: .error)
            return
        }
        
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        Logger.firebase("Language bundle set for: \(language)", level: .info)
    }
}