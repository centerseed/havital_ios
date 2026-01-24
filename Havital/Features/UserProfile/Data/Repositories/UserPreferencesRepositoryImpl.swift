import Foundation

// MARK: - UserPreferencesRepositoryImpl
/// Implementation of UserPreferencesRepository protocol
/// Uses dual-track caching for API preferences, direct storage for local preferences
final class UserPreferencesRepositoryImpl: UserPreferencesRepository {

    // MARK: - Dependencies
    private let remoteDataSource: UserPreferencesRemoteDataSourceProtocol
    private let localDataSource: UserPreferencesLocalDataSourceProtocol
    private let heartRateZonesManager: HeartRateZonesManager

    // MARK: - Initialization
    init(
        remoteDataSource: UserPreferencesRemoteDataSourceProtocol = UserPreferencesRemoteDataSource(),
        localDataSource: UserPreferencesLocalDataSourceProtocol = UserPreferencesLocalDataSource(),
        heartRateZonesManager: HeartRateZonesManager = .shared
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.heartRateZonesManager = heartRateZonesManager
    }

    // MARK: - Preferences Access

    func getPreferences() async throws -> UserPreferences {
        Logger.debug("[UserPreferencesRepo] getPreferences")

        // Track A: Check local cache
        if let cached = localDataSource.getPreferences(),
           !localDataSource.isPreferencesExpired() {
            Logger.debug("[UserPreferencesRepo] Cache hit")

            // Track B: Background refresh
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshInBackground()
            }

            return cached
        }

        // Cache miss - fetch from API
        Logger.debug("[UserPreferencesRepo] Cache miss, fetching from API")
        return try await fetchAndCachePreferences()
    }

    func refreshPreferences() async throws -> UserPreferences {
        Logger.debug("[UserPreferencesRepo] Force refresh")
        return try await fetchAndCachePreferences()
    }

    func updatePreferences(language: String?, timezone: String?) async throws {
        Logger.debug("[UserPreferencesRepo] Updating preferences")

        try await remoteDataSource.updatePreferences(language: language, timezone: timezone)

        // Update local language manager if language changed
        if let language = language,
           let supportedLanguage = SupportedLanguage(rawValue: language) {
            await MainActor.run {
                LanguageManager.shared.currentLanguage = supportedLanguage
            }
        }

        // Update local timezone if changed
        if let timezone = timezone {
            localDataSource.timezonePreference = timezone
        }

        // Invalidate cache and refresh
        localDataSource.clearPreferencesCache()
        _ = try await fetchAndCachePreferences()
    }

    // MARK: - Data Source Preference

    var dataSourcePreference: DataSourceType {
        localDataSource.dataSourcePreference
    }

    func updateDataSource(_ dataSource: DataSourceType) async {
        Logger.debug("[UserPreferencesRepo] Updating data source: \(dataSource.displayName)")

        localDataSource.dataSourcePreference = dataSource

        // Send notifications for backward compatibility
        NotificationCenter.default.post(
            name: NSNotification.Name("DataSourceDidChange"),
            object: dataSource.rawValue
        )
        NotificationCenter.default.post(
            name: .dataSourceChanged,
            object: dataSource
        )
    }

    // MARK: - Heart Rate Prompt Settings

    var doNotShowHeartRatePrompt: Bool {
        localDataSource.doNotShowHeartRatePrompt
    }

    var heartRatePromptNextRemindDate: Date? {
        localDataSource.heartRatePromptNextRemindDate
    }

    func updateHeartRatePromptSettings(doNotShow: Bool, nextRemindDate: Date?) async {
        Logger.debug("[UserPreferencesRepo] Updating HR prompt settings")

        localDataSource.doNotShowHeartRatePrompt = doNotShow
        localDataSource.heartRatePromptNextRemindDate = nextRemindDate
    }

    // MARK: - Heart Rate Data

    var maxHeartRate: Int? {
        localDataSource.maxHeartRate
    }

    var restingHeartRate: Int? {
        localDataSource.restingHeartRate
    }

    func hasHeartRateData() -> Bool {
        guard let maxHR = maxHeartRate,
              let restingHR = restingHeartRate else {
            return false
        }
        return maxHR > restingHR && maxHR > 0 && restingHR > 0
    }

    func updateHeartRateData(maxHR: Int, restingHR: Int) {
        Logger.debug("[UserPreferencesRepo] Updating HR data")

        guard maxHR > 0 && restingHR > 0 && maxHR > restingHR else {
            Logger.debug("[UserPreferencesRepo] Invalid HR data, skipping")
            return
        }

        localDataSource.maxHeartRate = maxHR
        localDataSource.restingHeartRate = restingHR

        // Calculate and save heart rate zones
        heartRateZonesManager.calculateAndSaveHeartRateZones(maxHR: maxHR, restingHR: restingHR)
    }

    func syncHeartRateData(from user: User?) {
        Logger.debug("[UserPreferencesRepo] Syncing HR data from user")

        guard let user = user else { return }

        // Only update if values are valid
        if let maxHR = user.maxHr, maxHR > 0 {
            localDataSource.maxHeartRate = maxHR
        }

        if let restingHR = user.relaxingHr, restingHR > 0 {
            localDataSource.restingHeartRate = restingHR
        }

        // Calculate zones if we have complete data
        if hasHeartRateData(),
           let maxHR = maxHeartRate,
           let restingHR = restingHeartRate {
            heartRateZonesManager.calculateAndSaveHeartRateZones(
                maxHR: maxHR,
                restingHR: restingHR
            )
        }
    }

    // MARK: - VDOT Data

    func getVDOTData() -> (currentVDOT: Double?, targetVDOT: Double?)? {
        let current = localDataSource.currentVDOT
        let target = localDataSource.targetVDOT

        guard current != nil || target != nil else {
            return nil
        }

        return (currentVDOT: current, targetVDOT: target)
    }

    func saveVDOTData(currentVDOT: Double, targetVDOT: Double) {
        Logger.debug("[UserPreferencesRepo] Saving VDOT data")

        localDataSource.currentVDOT = currentVDOT
        localDataSource.targetVDOT = targetVDOT
    }

    // MARK: - Language Preference

    var languagePreference: SupportedLanguage {
        if let langString = localDataSource.languagePreference,
           let language = SupportedLanguage(rawValue: langString) {
            return language
        }
        return SupportedLanguage.current
    }

    func updateLanguagePreference(_ language: SupportedLanguage) async {
        Logger.debug("[UserPreferencesRepo] Updating language: \(language.rawValue)")

        do {
            try await remoteDataSource.updateLanguage(language.rawValue)
            localDataSource.languagePreference = language.rawValue
            await MainActor.run {
                LanguageManager.shared.currentLanguage = language
            }
        } catch {
            Logger.error("[UserPreferencesRepo] Failed to update language: \(error)")
        }
    }

    // MARK: - Timezone

    var timezonePreference: String? {
        localDataSource.timezonePreference
    }

    func needsTimezoneInitialization() -> Bool {
        return timezonePreference == nil
    }

    func initializeTimezoneFromDevice() {
        let deviceTimezone = TimeZone.current.identifier
        localDataSource.timezonePreference = deviceTimezone
        Logger.firebase("Timezone initialized from device: \(deviceTimezone)", level: .info)
    }

    // MARK: - User Info

    var email: String {
        localDataSource.email
    }

    var name: String? {
        localDataSource.name
    }

    var photoURL: String? {
        localDataSource.photoURL
    }

    // MARK: - Cache Management

    func clearPreferences() async {
        Logger.debug("[UserPreferencesRepo] Clearing all preferences")

        localDataSource.clearAll()

        // Also clear related caches for backward compatibility
        TrainingPlanStorage.shared.clearAll()
        WorkoutUploadTracker.shared.clearUploadedWorkouts()
    }

    func isCacheExpired() -> Bool {
        return localDataSource.isPreferencesExpired()
    }

    // MARK: - Private Methods

    private func fetchAndCachePreferences() async throws -> UserPreferences {
        let preferences = try await remoteDataSource.getPreferences()
        localDataSource.savePreferences(preferences)
        return preferences
    }

    private func refreshInBackground() async {
        do {
            let preferences = try await remoteDataSource.getPreferences()
            localDataSource.savePreferences(preferences)
            Logger.debug("[UserPreferencesRepo] Background refresh success")
        } catch {
            Logger.debug("[UserPreferencesRepo] Background refresh failed (non-critical): \(error.localizedDescription)")
        }
    }
}
