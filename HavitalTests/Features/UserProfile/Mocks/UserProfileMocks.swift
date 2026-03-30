import Foundation
import Combine
@testable import paceriz_dev

// MARK: - Mock UserProfileRepository
final class MockUserProfileRepository: UserProfileRepository {
    var userToReturn: User = UserProfileTestFixtures.testUser
    var heartRateZonesToReturn: [HeartRateZone] = UserProfileTestFixtures.testHeartRateZones
    var targetsToReturn: [Target] = UserProfileTestFixtures.testTargets
    var errorToThrow: Error?

    var getUserProfileCallCount = 0
    var refreshUserProfileCallCount = 0
    var updateUserProfileCallCount = 0
    var updateUserProfileLastParams: [String: Any]?
    var deleteAccountCallCount = 0
    var updateDataSourceCallCount = 0
    var updateDataSourceLastParams: String?
    var getHeartRateZonesCallCount = 0
    var updateHeartRateZonesCallCount = 0
    var syncHeartRateDataCallCount = 0
    var getTargetsCallCount = 0
    var createTargetCallCount = 0
    var calculateStatisticsCallCount = 0
    var updatePersonalBestCallCount = 0
    var detectPersonalBestUpdatesCallCount = 0
    var clearCacheCallCount = 0

    func getUserProfile() async throws -> User {
        getUserProfileCallCount += 1
        if let error = errorToThrow { throw error }
        return userToReturn
    }

    func refreshUserProfile() async throws -> User {
        refreshUserProfileCallCount += 1
        if let error = errorToThrow { throw error }
        return userToReturn
    }

    func updateUserProfile(_ updates: [String: Any]) async throws -> User {
        updateUserProfileCallCount += 1
        updateUserProfileLastParams = updates
        if let error = errorToThrow { throw error }
        return userToReturn
    }

    func deleteAccount(userId: String) async throws {
        deleteAccountCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func updateDataSource(_ dataSource: String) async throws {
        updateDataSourceCallCount += 1
        updateDataSourceLastParams = dataSource
        if let error = errorToThrow { throw error }
    }

    func getHeartRateZones() async throws -> [HeartRateZone] {
        getHeartRateZonesCallCount += 1
        if let error = errorToThrow { throw error }
        return heartRateZonesToReturn
    }

    func updateHeartRateZones(maxHR: Int, restingHR: Int) async throws -> [HeartRateZone] {
        updateHeartRateZonesCallCount += 1
        if let error = errorToThrow { throw error }
        return heartRateZonesToReturn
    }

    func syncHeartRateData(from user: User) async {
        syncHeartRateDataCallCount += 1
    }

    func getTargets() async throws -> [Target] {
        getTargetsCallCount += 1
        if let error = errorToThrow { throw error }
        return targetsToReturn
    }

    func createTarget(_ target: Target) async throws {
        createTargetCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func calculateStatistics() async -> UserStatistics? {
        calculateStatisticsCallCount += 1
        return UserStatistics(userData: userToReturn, targets: targetsToReturn)
    }

    func updatePersonalBest(distanceKm: Double, completeTime: Int) async throws {
        updatePersonalBestCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func detectPersonalBestUpdates(oldData: [String: [PersonalBestRecordV2]]?, newData: [String: [PersonalBestRecordV2]]?) async {
        detectPersonalBestUpdatesCallCount += 1
    }

    var pendingCelebrationToReturn: PersonalBestUpdate?
    func getPendingCelebrationUpdate() -> PersonalBestUpdate? {
        return pendingCelebrationToReturn
    }

    var markCelebrationAsShownCalled = false
    func markCelebrationAsShown() {
        markCelebrationAsShownCalled = true
    }

    func clearCache() async {
        clearCacheCallCount += 1
    }

    var isCacheExpiredValue = false
    func isCacheExpired() -> Bool {
        return isCacheExpiredValue
    }
}

// MARK: - Mock UserPreferencesRepository
final class MockUserPreferencesRepository: UserPreferencesRepository {
    var preferencesToReturn: UserPreferences = UserProfileTestFixtures.testPreferences
    var errorToThrow: Error?

    var getPreferencesCallCount = 0
    var refreshPreferencesCallCount = 0
    var updatePreferencesCallCount = 0
    var updateDataSourceCallCount = 0
    var updateHeartRatePromptSettingsCallCount = 0
    var updateHeartRateDataCallCount = 0
    var syncHeartRateDataCallCount = 0
    var saveVDOTDataCallCount = 0
    var updateLanguagePreferenceCallCount = 0
    var clearPreferencesCallCount = 0

    func getPreferences() async throws -> UserPreferences {
        getPreferencesCallCount += 1
        if let error = errorToThrow { throw error }
        return preferencesToReturn
    }

    func refreshPreferences() async throws -> UserPreferences {
        refreshPreferencesCallCount += 1
        if let error = errorToThrow { throw error }
        return preferencesToReturn
    }

    func updatePreferences(language: String?, timezone: String?) async throws {
        updatePreferencesCallCount += 1
        if let error = errorToThrow { throw error }
    }

    var dataSourcePreference: DataSourceType = .appleHealth
    func updateDataSource(_ dataSource: DataSourceType) async {
        updateDataSourceCallCount += 1
        dataSourcePreference = dataSource
    }

    var doNotShowHeartRatePrompt: Bool = false
    var heartRatePromptNextRemindDate: Date?
    func updateHeartRatePromptSettings(doNotShow: Bool, nextRemindDate: Date?) async {
        updateHeartRatePromptSettingsCallCount += 1
        doNotShowHeartRatePrompt = doNotShow
        heartRatePromptNextRemindDate = nextRemindDate
    }

    var maxHeartRate: Int? = 190
    var restingHeartRate: Int? = 60
    func hasHeartRateData() -> Bool {
        return maxHeartRate != nil && restingHeartRate != nil
    }

    func updateHeartRateData(maxHR: Int, restingHR: Int) {
        updateHeartRateDataCallCount += 1
        maxHeartRate = maxHR
        restingHeartRate = restingHR
    }

    func syncHeartRateData(from user: User?) {
        syncHeartRateDataCallCount += 1
    }

    func getVDOTData() -> (currentVDOT: Double?, targetVDOT: Double?)? {
        return (45.0, 50.0)
    }

    func saveVDOTData(currentVDOT: Double, targetVDOT: Double) {
        saveVDOTDataCallCount += 1
    }

    var unitSystemPreference: UnitSystem = .metric
    var updateUnitSystemCallCount = 0
    func updateUnitSystem(_ unitSystem: UnitSystem) async throws {
        updateUnitSystemCallCount += 1
        unitSystemPreference = unitSystem
    }

    var languagePreference: SupportedLanguage = .traditionalChinese
    func updateLanguagePreference(_ language: SupportedLanguage) async {
        updateLanguagePreferenceCallCount += 1
        languagePreference = language
    }

    var timezonePreference: String? = "Asia/Taipei"
    func needsTimezoneInitialization() -> Bool {
        return timezonePreference == nil
    }

    func initializeTimezoneFromDevice() {
        timezonePreference = "Asia/Taipei"
    }

    var email: String = "test@example.com"
    var name: String? = "Test User"
    var photoURL: String? = nil

    func clearPreferences() async {
        clearPreferencesCallCount += 1
    }

    var isCacheExpiredValue = false
    func isCacheExpired() -> Bool {
        return isCacheExpiredValue
    }
}

// MARK: - Mock Data Sources
final class MockUserProfileRemoteDataSource: UserProfileRemoteDataSourceProtocol {
    var userToReturn: User = UserProfileTestFixtures.testUser
    var errorToThrow: Error?

    func getUserProfile() async throws -> User {
        if let error = errorToThrow { throw error }
        return userToReturn
    }

    func updateUserProfile(_ updates: [String: Any]) async throws {
        if let error = errorToThrow { throw error }
    }

    func updateDataSource(_ dataSource: String) async throws {
        if let error = errorToThrow { throw error }
    }
    
    func updatePersonalBest(_ performanceData: [String: Any]) async throws {
        if let error = errorToThrow { throw error }
    }

    func deleteUser(userId: String) async throws {
        if let error = errorToThrow { throw error }
    }

    func getTargets() async throws -> [Target] {
        if let error = errorToThrow { throw error }
        return []
    }

    func createTarget(_ target: Target) async throws {
        if let error = errorToThrow { throw error }
    }
    
    func recordRatingPrompt(promptCount: Int, lastPromptDate: String) async throws {
        if let error = errorToThrow { throw error }
    }
}

final class MockUserProfileLocalDataSource: UserProfileLocalDataSourceProtocol {
    var userToReturn: User? = UserProfileTestFixtures.testUser
    var isUserProfileExpiredValue = false
    var heartRateZonesToReturn: [HeartRateZone]? = UserProfileTestFixtures.testHeartRateZones
    var targetsToReturn: [Target]? = UserProfileTestFixtures.testTargets

    func getUserProfile() -> User? {
        return userToReturn
    }

    func saveUserProfile(_ user: User) {
        userToReturn = user
    }

    func clearUserProfile() {
        userToReturn = nil
    }

    func isUserProfileExpired() -> Bool {
        return isUserProfileExpiredValue
    }
    
    func getTargets() -> [Target]? {
        return targetsToReturn
    }
    
    func saveTargets(_ targets: [Target]) {
        targetsToReturn = targets
    }
    
    func isTargetsExpired() -> Bool {
        return false
    }
    
    func clearTargets() {
        targetsToReturn = nil
    }

    func getHeartRateZones() -> [HeartRateZone]? {
        return heartRateZonesToReturn
    }

    func saveHeartRateZones(_ zones: [HeartRateZone]) {
        heartRateZonesToReturn = zones
    }
    
    func isHeartRateZonesExpired() -> Bool {
        return false
    }
    
    func clearHeartRateZones() {
        heartRateZonesToReturn = nil
    }

    func clearAll() {
        userToReturn = nil
        heartRateZonesToReturn = nil
    }
    
    func getCacheSize() -> Int {
        return 0
    }
}

final class MockUserPreferencesRemoteDataSource: UserPreferencesRemoteDataSourceProtocol {
    var preferencesToReturn: UserPreferences = UserProfileTestFixtures.testPreferences
    var errorToThrow: Error?

    var getPreferencesCallCount = 0
    var updatePreferencesCallCount = 0
    var updateTimezoneCallCount = 0
    var updateLanguageCallCount = 0

    func getPreferences() async throws -> UserPreferences {
        getPreferencesCallCount += 1
        if let error = errorToThrow { throw error }
        return preferencesToReturn
    }

    func updatePreferences(language: String?, timezone: String?, unitSystem: String?) async throws {
        updatePreferencesCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func updateTimezone(_ timezone: String) async throws {
        updateTimezoneCallCount += 1
        if let error = errorToThrow { throw error }
    }
    
    func updateLanguage(_ language: String) async throws {
        updateLanguageCallCount += 1
        if let error = errorToThrow { throw error }
    }
}

final class MockUserPreferencesLocalDataSource: UserPreferencesLocalDataSourceProtocol {
    var preferencesToReturn: UserPreferences? = UserProfileTestFixtures.testPreferences
    var isPreferencesExpiredValue = false

    func getPreferences() -> UserPreferences? {
        return preferencesToReturn
    }

    func savePreferences(_ preferences: UserPreferences) {
        savePreferencesCallCount += 1
        preferencesToReturn = preferences
    }

    func isPreferencesExpired() -> Bool {
        return isPreferencesExpiredValue
    }
    
    func clearPreferencesCache() {
        clearPreferencesCacheCallCount += 1
        preferencesToReturn = nil
    }

    var dataSourcePreference: DataSourceType = .appleHealth
    var maxHeartRate: Int? = 190
    var restingHeartRate: Int? = 60
    var doNotShowHeartRatePrompt: Bool = false
    var heartRatePromptNextRemindDate: Date? = nil
    var heartRateZones: Data? = nil
    
    var email: String = "test@example.com"
    var name: String? = "Test User"
    var photoURL: String? = nil
    var age: Int? = 30
    
    var currentPace: String? = "5:00"
    var currentDistance: String? = "10.0"
    var preferWeekDays: [String]? = ["Monday", "Wednesday", "Friday"]
    var preferWeekDaysLongRun: [String]? = ["Sunday"]
    var weekOfTraining: Int? = 5
    
    var languagePreference: String? = "zh-TW"
    var timezonePreference: String? = "Asia/Taipei"
    var unitSystemPreference: String? = "metric"
    
    var currentVDOT: Double? = 45.0
    var targetVDOT: Double? = 50.0

    var clearAllCallCount = 0
    var clearPreferencesCacheCallCount = 0
    var savePreferencesCallCount = 0

    func clearAll() {
        clearAllCallCount += 1
        preferencesToReturn = nil
    }
}

// MARK: - Mock AuthenticationService
final class MockAuthenticationService: AuthenticationServiceProtocol {
    var isAuthenticated: Bool = false
    var appUser: User? = nil
    
    var signOutCallCount = 0
    func signOut() async throws {
        signOutCallCount += 1
        isAuthenticated = false
        appUser = nil
    }
}
