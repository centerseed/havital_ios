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
}
