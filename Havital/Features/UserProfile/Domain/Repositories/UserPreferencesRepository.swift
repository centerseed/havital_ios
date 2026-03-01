import Foundation

// MARK: - UserPreferences Repository Protocol
/// Defines user preferences data access interface
/// Domain Layer - only defines interface, no implementation details
protocol UserPreferencesRepository {

    // MARK: - Preferences Access

    /// Get user preferences (with cache support)
    /// - Returns: User preferences
    func getPreferences() async throws -> UserPreferences

    /// Force refresh preferences from API
    /// - Returns: Latest preferences
    func refreshPreferences() async throws -> UserPreferences

    /// Update language or timezone settings
    /// - Parameters:
    ///   - language: Language code (e.g., "zh-TW", "ja", "en")
    ///   - timezone: IANA timezone (e.g., "Asia/Taipei")
    func updatePreferences(language: String?, timezone: String?) async throws

    // MARK: - Data Source Preference

    /// Get current data source preference
    var dataSourcePreference: DataSourceType { get }

    /// Update data source preference (local only, synced via User API)
    /// - Parameter dataSource: Selected data source
    func updateDataSource(_ dataSource: DataSourceType) async

    // MARK: - Heart Rate Prompt Settings

    /// Get whether heart rate prompt should be shown
    var doNotShowHeartRatePrompt: Bool { get }

    /// Get next remind date for heart rate prompt
    var heartRatePromptNextRemindDate: Date? { get }

    /// Update heart rate prompt settings (local only)
    /// - Parameters:
    ///   - doNotShow: Whether to suppress prompt
    ///   - nextRemindDate: Next reminder date (optional)
    func updateHeartRatePromptSettings(doNotShow: Bool, nextRemindDate: Date?) async

    // MARK: - Heart Rate Data (Local)

    /// Get max heart rate from local preferences
    var maxHeartRate: Int? { get }

    /// Get resting heart rate from local preferences
    var restingHeartRate: Int? { get }

    /// Check if user has complete heart rate data
    func hasHeartRateData() -> Bool

    /// Update heart rate data and calculate zones
    /// - Parameters:
    ///   - maxHR: Maximum heart rate
    ///   - restingHR: Resting heart rate
    func updateHeartRateData(maxHR: Int, restingHR: Int)

    /// Sync heart rate data from User model
    /// - Parameter user: User model containing HR data
    func syncHeartRateData(from user: User?)

    // MARK: - VDOT Data

    /// Get stored VDOT data
    func getVDOTData() -> (currentVDOT: Double?, targetVDOT: Double?)?

    /// Save VDOT data (local only)
    /// - Parameters:
    ///   - currentVDOT: Current VDOT value
    ///   - targetVDOT: Target VDOT value
    func saveVDOTData(currentVDOT: Double, targetVDOT: Double)

    // MARK: - Language Preference

    /// Get current language preference
    var languagePreference: SupportedLanguage { get }

    /// Update language preference
    /// - Parameter language: New language setting
    func updateLanguagePreference(_ language: SupportedLanguage) async

    // MARK: - Timezone

    /// Get current timezone preference
    var timezonePreference: String? { get }

    /// Check if timezone needs initialization
    func needsTimezoneInitialization() -> Bool

    /// Initialize timezone from device
    func initializeTimezoneFromDevice()

    // MARK: - User Info (Local Cache)

    /// Get user email from local preferences
    var email: String { get }

    /// Get user name from local preferences
    var name: String? { get }

    /// Get user photo URL from local preferences
    var photoURL: String? { get }

    // MARK: - Cache Management

    /// Clear all preferences (including local cache)
    func clearPreferences() async

    /// Check if preferences cache is expired
    func isCacheExpired() -> Bool
}
