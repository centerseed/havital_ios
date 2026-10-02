import XCTest
@testable import paceriz_dev

private actor RepositoryLanguageHTTPClient: HTTPClient {
    struct Request {
        let path: String
        let method: HTTPMethod
        let body: Data?
    }

    private(set) var requests: [Request] = []

    func request(
        path: String,
        method: HTTPMethod,
        body: Data?,
        customHeaders: [String: String]?,
        timeout: TimeInterval?
    ) async throws -> Data {
        requests.append(Request(path: path, method: method, body: body))
        return Data(#"{"success":true}"#.utf8)
    }

    func stream(
        path: String,
        method: HTTPMethod,
        body: Data?,
        customHeaders: [String: String]?
    ) async throws -> HTTPByteStreamResponse {
        let data = try await request(
            path: path,
            method: method,
            body: body,
            customHeaders: customHeaders,
            timeout: nil
        )
        return HTTPByteStreamResponse(
            contentType: "application/json",
            bytes: AsyncThrowingStream { continuation in
                data.forEach { continuation.yield($0) }
                continuation.finish()
            }
        )
    }
}

@MainActor
final class UserPreferencesRepositoryImplTests: XCTestCase {
    
    var repository: UserPreferencesRepositoryImpl!
    var mockRemoteDataSource: MockUserPreferencesRemoteDataSource!
    var mockLocalDataSource: MockUserPreferencesLocalDataSource!
    private var languageHTTPClient: RepositoryLanguageHTTPClient!
    private var languageManager: LanguageManager!
    
    override func setUp() {
        super.setUp()
        mockRemoteDataSource = MockUserPreferencesRemoteDataSource()
        mockLocalDataSource = MockUserPreferencesLocalDataSource()
        languageHTTPClient = RepositoryLanguageHTTPClient()
        languageManager = LanguageManager(httpClient: languageHTTPClient)
        languageManager.applyPreLoginLanguage(.english)
        
        repository = UserPreferencesRepositoryImpl(
            remoteDataSource: mockRemoteDataSource,
            localDataSource: mockLocalDataSource,
            heartRateZonesManager: .shared,
            languageManager: languageManager
        )
    }
    
    override func tearDown() {
        repository = nil
        mockRemoteDataSource = nil
        mockLocalDataSource = nil
        languageHTTPClient = nil
        languageManager = nil
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

    func testUpdatePreferences_LanguageUsesInjectedOwnerTransport() async throws {
        mockRemoteDataSource.preferencesToReturn = UserProfileTestFixtures.testPreferences

        try await repository.updatePreferences(language: SupportedLanguage.japanese.apiCode, timezone: nil)

        let requests = await languageHTTPClient.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.path, "/user/preferences")
        XCTAssertEqual(requests.first?.method, .PUT)
        let body = try XCTUnwrap(requests.first?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["language"], SupportedLanguage.japanese.apiCode)
    }
}
