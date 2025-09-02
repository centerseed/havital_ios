import Foundation
import SwiftUI
import Combine

/// Manager for handling app language preferences and localization
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private static let languageKey = "app_language_preference"
    private static let languageChangedNotification = NSNotification.Name("LanguageDidChange")
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            if currentLanguage != oldValue {
                saveLanguagePreference()
                applyLanguage()
                syncWithBackend()
                // 通知 HTTPClient 語言已變更，之後的請求會使用新的 Accept-Language 標頭
                Logger.firebase("Language changed to: \(currentLanguage.apiCode)", level: .info)
            }
        }
    }
    
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
        
        // Apply the language on init
        applyLanguage()
        
        // Debug: Print language initialization info
        Logger.debug("LanguageManager initialized with: \(currentLanguage.rawValue) (API: \(currentLanguage.apiCode))")
    }
    
    /// Save language preference to UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageKey)
        Logger.firebase("Language preference saved: \(currentLanguage.rawValue)", level: .info)
    }
    
    /// Apply the selected language to the app
    private func applyLanguage() {
        // Set the app's language
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: Self.languageChangedNotification,
            object: currentLanguage
        )
        
        Logger.firebase("Language applied: \(currentLanguage.rawValue)", level: .info)
    }
    
    /// Sync language preference with backend
    private func syncWithBackend() {
        Task {
            do {
                try await updateLanguagePreference(currentLanguage.apiCode)
                Logger.firebase("Language synced with backend: \(currentLanguage.apiCode)", level: .info)
            } catch {
                Logger.firebase("Failed to sync language with backend: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    /// Fetch user preferences from backend
    func fetchUserPreferences() async throws {
        let (data, response) = try await URLSession.shared.data(
            from: URL(string: "\(APIConfig.baseURL)/user/preferences")!
        )
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "LanguageManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch user preferences"
            ])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let languageCode = json["language"] as? String,
           let language = SupportedLanguage(apiCode: languageCode) {
            await MainActor.run {
                self.currentLanguage = language
            }
        }
    }
    
    /// Update language preference on backend
    private func updateLanguagePreference(_ languageCode: String) async throws {
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/user/preferences")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            Logger.firebase("Failed to get auth token: \(error.localizedDescription)", level: .warn)
        }
        
        let body = ["language": languageCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "LanguageManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to update language preference"
            ])
        }
    }
    
    /// Change app language with confirmation and automatic restart
    func changeLanguage(to language: SupportedLanguage, completion: @escaping (Bool) -> Void) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: L10n.Language.title.localized,
            message: L10n.Language.changeConfirm.localized,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: L10n.Common.cancel.localized,
            style: .cancel
        ) { _ in
            completion(false)
        })
        
        alert.addAction(UIAlertAction(
            title: L10n.Common.confirm.localized,
            style: .default
        ) { [weak self] _ in
            self?.performLanguageChange(to: language)
            completion(true)
        })
        
        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    /// Perform language change and restart app
    private func performLanguageChange(to language: SupportedLanguage) {
        // Update language
        self.currentLanguage = language
        
        // Schedule app restart after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restartApp()
        }
    }
    
    /// Public method for direct language change with restart (used by settings)
    func performLanguageChangeWithRestart(to language: SupportedLanguage) {
        performLanguageChange(to: language)
    }
    
    /// Restart the application
    private func restartApp() {
        // Method 1: Try to trigger a scene refresh
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Save a flag to indicate language was changed
            UserDefaults.standard.set(true, forKey: "language_changed_restart")
            
            // Request scene refresh
            UIApplication.shared.requestSceneSessionRefresh(windowScene.session)
            
            // Alternative: Force recreation of root view
            for window in windowScene.windows {
                window.rootViewController = nil
                window.makeKeyAndVisible()
            }
            
            Logger.firebase("App restart requested due to language change", level: .info)
        } else {
            // Method 2: Fallback - exit app (user will need to manually restart)
            Logger.firebase("Fallback: Requesting app exit for language change", level: .info)
            exit(0)
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
    
    /// Format distance (currently only metric is supported by backend)
    func formatDistance(_ distanceInKm: Double) -> String {
        return "\(formatNumber(distanceInKm, maximumFractionDigits: 2)) \(L10n.Unit.km.localized)"
    }
    
    /// Format pace (currently only metric is supported by backend)
    func formatPace(_ paceInSeconds: Double) -> String {
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        let formattedPace = String(format: "%d:%02d", minutes, seconds)
        
        return "\(formattedPace) \(L10n.Unit.minPerKm.localized)"
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