import Foundation

// MARK: - UserPreferencesLocalDataSource Protocol
protocol UserPreferencesLocalDataSourceProtocol: AnyObject {
    func getPreferences() -> UserPreferences?
    func savePreferences(_ preferences: UserPreferences)
    func isPreferencesExpired() -> Bool
    func clearPreferencesCache()
    
    var dataSourcePreference: DataSourceType { get set }
    var maxHeartRate: Int? { get set }
    var restingHeartRate: Int? { get set }
    var doNotShowHeartRatePrompt: Bool { get set }
    var heartRatePromptNextRemindDate: Date? { get set }
    var heartRateZones: Data? { get set }
    
    var email: String { get set }
    var name: String? { get set }
    var photoURL: String? { get set }
    var age: Int? { get set }
    
    var currentPace: String? { get set }
    var currentDistance: String? { get set }
    var preferWeekDays: [String]? { get set }
    var preferWeekDaysLongRun: [String]? { get set }
    var weekOfTraining: Int? { get set }
    
    var languagePreference: String? { get set }
    var timezonePreference: String? { get set }
    
    var currentVDOT: Double? { get set }
    var targetVDOT: Double? { get set }
    
    func clearAll()
}

// MARK: - UserPreferencesLocalDataSource
/// Handles local storage of user preferences
/// Data Layer - Pure storage, no business logic
final class UserPreferencesLocalDataSource: UserPreferencesLocalDataSourceProtocol {

    // MARK: - Constants
    private enum Keys {
        // API-synced preferences cache
        static let preferences = "user_preferences_cache_v3"
        static let timestampSuffix = "_timestamp"

        // Local-only preferences (not synced to API)
        static let dataSource = "data_source_preference"
        static let email = "user_email"
        static let name = "user_name"
        static let age = "age"
        static let maxHeartRate = "max_heart_rate"
        static let restingHeartRate = "resting_heart_rate"
        static let doNotShowHeartRatePrompt = "do_not_show_heart_rate_prompt"
        static let heartRatePromptNextRemindDate = "heart_rate_prompt_next_remind_date"
        static let heartRateZones = "heart_rate_zones"
        static let currentPace = "current_pace"
        static let currentDistance = "current_distance"
        static let preferWeekDays = "prefer_week_days"
        static let preferWeekDaysLongRun = "prefer_week_days_longrun"
        static let weekOfTraining = "week_of_training"
        static let photoURL = "user_photo_url"
        static let languagePreference = "language_preference"
        static let timezonePreference = "timezone_preference"
        static let currentVDOT = "current_vdot"
        static let targetVDOT = "target_vdot"
    }

    private enum TTL {
        static let preferences: TimeInterval = 3600  // 1 hour
    }

    // MARK: - Dependencies
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - API Preferences Cache

    /// Get cached preferences
    func getPreferences() -> UserPreferences? {
        guard let data = defaults.data(forKey: Keys.preferences) else {
            return nil
        }

        do {
            return try decoder.decode(UserPreferences.self, from: data)
        } catch {
            Logger.debug("[UserPreferencesLocalDS] Failed to decode preferences, clearing cache")
            clearPreferencesCache()
            return nil
        }
    }

    /// Save preferences to cache
    func savePreferences(_ preferences: UserPreferences) {
        do {
            let data = try encoder.encode(preferences)
            defaults.set(data, forKey: Keys.preferences)
            defaults.set(Date(), forKey: Keys.preferences + Keys.timestampSuffix)
            Logger.debug("[UserPreferencesLocalDS] Preferences saved to cache")
        } catch {
            Logger.error("[UserPreferencesLocalDS] Failed to encode preferences: \(error)")
        }
    }

    /// Check if preferences cache is expired
    func isPreferencesExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.preferences + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.preferences
    }

    /// Clear preferences cache
    func clearPreferencesCache() {
        defaults.removeObject(forKey: Keys.preferences)
        defaults.removeObject(forKey: Keys.preferences + Keys.timestampSuffix)
        Logger.debug("[UserPreferencesLocalDS] Preferences cache cleared")
    }

    // MARK: - Data Source Preference

    var dataSourcePreference: DataSourceType {
        get {
            let rawValue = defaults.string(forKey: Keys.dataSource) ?? "unbound"
            return DataSourceType(rawValue: rawValue) ?? .unbound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.dataSource)
        }
    }

    // MARK: - Heart Rate Data

    var maxHeartRate: Int? {
        get { defaults.object(forKey: Keys.maxHeartRate) as? Int }
        set { defaults.set(newValue, forKey: Keys.maxHeartRate) }
    }

    var restingHeartRate: Int? {
        get { defaults.object(forKey: Keys.restingHeartRate) as? Int }
        set { defaults.set(newValue, forKey: Keys.restingHeartRate) }
    }

    var doNotShowHeartRatePrompt: Bool {
        get { defaults.bool(forKey: Keys.doNotShowHeartRatePrompt) }
        set { defaults.set(newValue, forKey: Keys.doNotShowHeartRatePrompt) }
    }

    var heartRatePromptNextRemindDate: Date? {
        get {
            if let timestamp = defaults.object(forKey: Keys.heartRatePromptNextRemindDate) as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: Keys.heartRatePromptNextRemindDate)
            } else {
                defaults.removeObject(forKey: Keys.heartRatePromptNextRemindDate)
            }
        }
    }

    var heartRateZones: Data? {
        get { defaults.data(forKey: Keys.heartRateZones) }
        set { defaults.set(newValue, forKey: Keys.heartRateZones) }
    }

    // MARK: - User Info

    var email: String {
        get { defaults.string(forKey: Keys.email) ?? "" }
        set { defaults.set(newValue, forKey: Keys.email) }
    }

    var name: String? {
        get { defaults.string(forKey: Keys.name) }
        set { defaults.set(newValue, forKey: Keys.name) }
    }

    var photoURL: String? {
        get { defaults.string(forKey: Keys.photoURL) }
        set { defaults.set(newValue, forKey: Keys.photoURL) }
    }

    var age: Int? {
        get { defaults.object(forKey: Keys.age) as? Int }
        set { defaults.set(newValue, forKey: Keys.age) }
    }

    // MARK: - Training Preferences

    var currentPace: String? {
        get { defaults.string(forKey: Keys.currentPace) }
        set { defaults.set(newValue, forKey: Keys.currentPace) }
    }

    var currentDistance: String? {
        get { defaults.string(forKey: Keys.currentDistance) }
        set { defaults.set(newValue, forKey: Keys.currentDistance) }
    }

    var preferWeekDays: [String]? {
        get { defaults.array(forKey: Keys.preferWeekDays) as? [String] }
        set { defaults.set(newValue, forKey: Keys.preferWeekDays) }
    }

    var preferWeekDaysLongRun: [String]? {
        get { defaults.array(forKey: Keys.preferWeekDaysLongRun) as? [String] }
        set { defaults.set(newValue, forKey: Keys.preferWeekDaysLongRun) }
    }

    var weekOfTraining: Int? {
        get { defaults.object(forKey: Keys.weekOfTraining) as? Int }
        set { defaults.set(newValue, forKey: Keys.weekOfTraining) }
    }

    // MARK: - Language and Timezone

    var languagePreference: String? {
        get { defaults.string(forKey: Keys.languagePreference) }
        set { defaults.set(newValue, forKey: Keys.languagePreference) }
    }

    var timezonePreference: String? {
        get { defaults.string(forKey: Keys.timezonePreference) }
        set { defaults.set(newValue, forKey: Keys.timezonePreference) }
    }

    // MARK: - VDOT Data

    var currentVDOT: Double? {
        get { defaults.object(forKey: Keys.currentVDOT) as? Double }
        set { defaults.set(newValue, forKey: Keys.currentVDOT) }
    }

    var targetVDOT: Double? {
        get { defaults.object(forKey: Keys.targetVDOT) as? Double }
        set { defaults.set(newValue, forKey: Keys.targetVDOT) }
    }

    // MARK: - Clear All

    /// Clear all local preferences
    func clearAll() {
        let keysToRemove = [
            Keys.preferences, Keys.preferences + Keys.timestampSuffix,
            Keys.dataSource, Keys.email, Keys.name, Keys.age,
            Keys.maxHeartRate, Keys.restingHeartRate,
            Keys.doNotShowHeartRatePrompt, Keys.heartRatePromptNextRemindDate,
            Keys.heartRateZones, Keys.currentPace, Keys.currentDistance,
            Keys.preferWeekDays, Keys.preferWeekDaysLongRun, Keys.weekOfTraining,
            Keys.photoURL, Keys.languagePreference, Keys.timezonePreference,
            Keys.currentVDOT, Keys.targetVDOT
        ]

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        Logger.debug("[UserPreferencesLocalDS] All preferences cleared")
    }
}
