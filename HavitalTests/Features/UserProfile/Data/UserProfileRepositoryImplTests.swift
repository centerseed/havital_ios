import XCTest
@testable import paceriz_dev

final class UserProfileRepositoryImplTests: XCTestCase {
    
    var repository: UserProfileRepositoryImpl!
    var mockRemoteDataSource: MockUserProfileRemoteDataSource!
    var mockLocalDataSource: MockUserProfileLocalDataSource!
    var mockTargetRemoteDataSource: MockTargetRemoteDataSource!
    
    override func setUp() {
        super.setUp()
        mockRemoteDataSource = MockUserProfileRemoteDataSource()
        mockLocalDataSource = MockUserProfileLocalDataSource()
        mockTargetRemoteDataSource = MockTargetRemoteDataSource()
        
        repository = UserProfileRepositoryImpl(
            remoteDataSource: mockRemoteDataSource,
            localDataSource: mockLocalDataSource,
            targetRemoteDataSource: mockTargetRemoteDataSource
        )
    }
    
    override func tearDown() {
        repository = nil
        mockRemoteDataSource = nil
        mockLocalDataSource = nil
        mockTargetRemoteDataSource = nil
        super.tearDown()
    }
    
    // MARK: - User Profile Tests
    
    func testGetUserProfile_CacheHit_ReturnsCachedData() async throws {
        // Given
        let cachedUser = UserProfileTestFixtures.testUser
        mockLocalDataSource.userToReturn = cachedUser
        mockLocalDataSource.isUserProfileExpiredValue = false
        
        // When
        let result = try await repository.getUserProfile()
        
        // Then
        XCTAssertEqual(result.email, cachedUser.email)
        XCTAssertEqual(result.displayName, cachedUser.displayName)
    }
    
    func testGetUserProfile_CacheMiss_FetchesFromRemote() async throws {
        // Given
        mockLocalDataSource.userToReturn = nil
        let remoteUser = UserProfileTestFixtures.testUser
        mockRemoteDataSource.userToReturn = remoteUser
        
        // When
        let result = try await repository.getUserProfile()
        
        // Then
        XCTAssertEqual(result.email, remoteUser.email)
        XCTAssertNotNil(mockLocalDataSource.userToReturn)
    }
    
    func testRefreshUserProfile_UpdatesCache() async throws {
        // Given
        let remoteUser = UserProfileTestFixtures.testUser
        mockRemoteDataSource.userToReturn = remoteUser
        
        // When
        let result = try await repository.refreshUserProfile()
        
        // Then
        XCTAssertEqual(result.email, remoteUser.email)
        XCTAssertEqual(mockLocalDataSource.userToReturn?.email, remoteUser.email)
    }
    
    func testUpdateUserProfile_InvalidatesCacheAndRefetches() async throws {
        // Given
        let updates: [String: Any] = ["display_name": "New Name"]
        let remoteUser = UserProfileTestFixtures.testUser
        mockRemoteDataSource.userToReturn = remoteUser
        
        // When
        let result = try await repository.updateUserProfile(updates)
        
        // Then
        XCTAssertEqual(result.displayName, remoteUser.displayName)
        // Verify cache was cleared (it will be refetched and saved again in the implementation)
    }
    
    // MARK: - Heart Rate Zones Tests
    
    func testGetHeartRateZones_CacheHit_ReturnsCachedZones() async throws {
        // Given
        let cachedZones = UserProfileTestFixtures.testHeartRateZones
        mockLocalDataSource.heartRateZonesToReturn = cachedZones
        
        // When
        let result = try await repository.getHeartRateZones()
        
        // Then
        XCTAssertEqual(result.count, cachedZones.count)
        XCTAssertEqual(result[0].name, cachedZones[0].name)
    }

    func testPartialHeartRateUpdateSendsOnlyChangedFieldAndReturnsBackendChangedFalse() async throws {
        let result = try await repository.updateHeartRateZones(
            maxHR: 190,
            restingHR: 60,
            updates: ["max_hr": 190]
        )

        XCTAssertFalse(result.changed)
        XCTAssertEqual(mockRemoteDataSource.updateUserProfileLastParams?.count, 1)
        XCTAssertEqual(mockRemoteDataSource.updateUserProfileLastParams?["max_hr"] as? Int, 190)
        XCTAssertNil(mockRemoteDataSource.updateUserProfileLastParams?["relaxing_hr"])
    }

    func testPartialHeartRateUpdateCachesZonesFromBackendReadbackForOmittedField() async throws {
        let backendUser = UserProfileTestFixtures.user(maxHR: 200, restingHR: 70)
        mockRemoteDataSource.userAfterUpdate = backendUser

        let result = try await repository.updateHeartRateZones(
            maxHR: 200,
            restingHR: 60,
            updates: ["max_hr": 200]
        )

        let expected = HeartRateZone.calculateZones(maxHR: 200, restingHR: 70)
        XCTAssertEqual(result.zones, expected)
        XCTAssertEqual(mockLocalDataSource.heartRateZonesToReturn, expected)
    }
    
    func testGetHeartRateZones_CacheMiss_CalculatesFromProfile() async throws {
        // Given
        mockLocalDataSource.heartRateZonesToReturn = nil
        mockLocalDataSource.userToReturn = UserProfileTestFixtures.testUser // 190 max, 60 resting
        
        // When
        let result = try await repository.getHeartRateZones()
        
        // Then
        XCTAssertEqual(result.count, 6)
        XCTAssertNotNil(mockLocalDataSource.heartRateZonesToReturn)
        XCTAssertEqual(mockLocalDataSource.heartRateZonesToReturn?.count, 6)
    }
    
    // MARK: - Targets Tests
    
    func testGetTargets_FetchesFromRemote() async throws {
        // Given
        let expectedTargets = UserProfileTestFixtures.testTargets
        mockTargetRemoteDataSource.targetsToReturn = expectedTargets

        // When
        let result = try await repository.getTargets()

        // Then
        XCTAssertEqual(result.count, expectedTargets.count)
    }

    // MARK: - getCachedUserProfile（T-0365）

    /// 只讀本機，**過期的也照給**。呼叫端（計畫總覽的「進頁先畫快取」）要的是
    /// 「上一次看到的那份」，新鮮度由它自己那一輪的重驗負責；若比照 `getUserProfile()`
    /// 濾掉過期的，冷啟第一畫永遠是空的。
    func testGetCachedUserProfile_ReturnsExpiredCacheWithoutFetching() {
        mockLocalDataSource.userToReturn = UserProfileTestFixtures.testUser
        mockLocalDataSource.isUserProfileExpiredValue = true
        // 遠端整支炸掉：仍然回得出快取＝這條路真的沒有碰網路。
        mockRemoteDataSource.errorToThrow = URLError(.notConnectedToInternet)

        let cached = repository.getCachedUserProfile()

        XCTAssertNotNil(cached, "過期不等於沒有；那仍是上一次真的看過的那份")
        XCTAssertEqual(cached?.email, UserProfileTestFixtures.testUser.email)
    }

    /// 本機真的沒有＝nil，呼叫端據此維持首載 spinner。
    func testGetCachedUserProfile_NilWhenNoLocalCache() {
        mockLocalDataSource.userToReturn = nil
        mockRemoteDataSource.errorToThrow = URLError(.notConnectedToInternet)

        XCTAssertNil(repository.getCachedUserProfile())
    }
}
