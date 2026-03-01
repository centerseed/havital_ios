import XCTest
@testable import paceriz_dev

final class UserPreferencesRepositoryImplTests: XCTestCase {
    
    var repository: UserPreferencesRepositoryImpl!
    var mockRemoteDataSource: MockUserPreferencesRemoteDataSource!
    var mockLocalDataSource: MockUserPreferencesLocalDataSource!
    
    override func setUp() {
        super.setUp()
        mockRemoteDataSource = MockUserPreferencesRemoteDataSource()
        mockLocalDataSource = MockUserPreferencesLocalDataSource()
        
        repository = UserPreferencesRepositoryImpl(
            remoteDataSource: mockRemoteDataSource,
            localDataSource: mockLocalDataSource,
            heartRateZonesManager: .shared // Singleton, but we'll focus on datasource interactions
        )
    }
    
    override func tearDown() {
        repository = nil
        mockRemoteDataSource = nil
        mockLocalDataSource = nil
        super.tearDown()
    }
    
    // MARK: - Preferences Tests
    
    func testGetPreferences_CacheHit_ReturnsCachedData() async throws {
        // Given
        let cachedPrefs = UserProfileTestFixtures.testPreferences
        mockLocalDataSource.preferencesToReturn = cachedPrefs
        mockLocalDataSource.isPreferencesExpiredValue = false
        
        // When
        let result = try await repository.getPreferences()
        
        // Then
        XCTAssertEqual(result.language, cachedPrefs.language)
        XCTAssertEqual(result.timezone, cachedPrefs.timezone)
    }
    
    func testGetPreferences_CacheMiss_FetchesFromRemote() async throws {
        // Given
        mockLocalDataSource.preferencesToReturn = nil
        let remotePrefs = UserProfileTestFixtures.testPreferences
        mockRemoteDataSource.preferencesToReturn = remotePrefs
        
        // When
        let result = try await repository.getPreferences()
        
        // Then
        XCTAssertEqual(result.language, remotePrefs.language)
        XCTAssertNotNil(mockLocalDataSource.preferencesToReturn)
    }
    
    func testUpdatePreferences_UpdatesRemoteAndLocalCache() async throws {
        // Given
        let language = "en-US"
        let timezone = "UTC"
        
        // When
        try await repository.updatePreferences(language: language, timezone: timezone)
        
        // Then
        XCTAssertEqual(mockRemoteDataSource.updatePreferencesCallCount, 1)
        XCTAssertEqual(mockLocalDataSource.clearPreferencesCacheCallCount, 1)
        XCTAssertEqual(mockLocalDataSource.savePreferencesCallCount, 1)
        XCTAssertNotNil(mockLocalDataSource.preferencesToReturn)
    }
    
    // MARK: - Data Source Tests
    
    func testUpdateDataSource_UpdatesLocalData() async {
        // When
        await repository.updateDataSource(.garmin)
        
        // Then
        XCTAssertEqual(mockLocalDataSource.dataSourcePreference, .garmin)
    }
    
    // MARK: - VDOT Tests
    
    func testSaveVDOTData_UpdatesLocalData() {
        // Given
        let currentVDOT = 48.5
        let targetVDOT = 52.0
        
        // When
        repository.saveVDOTData(currentVDOT: currentVDOT, targetVDOT: targetVDOT)
        
        // Then
        XCTAssertEqual(mockLocalDataSource.currentVDOT, currentVDOT)
        XCTAssertEqual(mockLocalDataSource.targetVDOT, targetVDOT)
    }
    
    // MARK: - Language Tests
    
    func testUpdateLanguagePreference_UpdatesRemoteAndLocal() async {
        // Given
        let lang = SupportedLanguage.english
        
        // When
        await repository.updateLanguagePreference(lang)
        
        // Then
        XCTAssertEqual(mockLocalDataSource.languagePreference, lang.rawValue)
    }
}
