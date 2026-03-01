import XCTest
import Combine
@testable import paceriz_dev

@MainActor
final class UserProfileFeatureViewModelTests: XCTestCase {
    
    var viewModel: UserProfileFeatureViewModel!
    var mockUserRepository: MockUserProfileRepository!
    var mockPrefsRepository: MockUserPreferencesRepository!
    var mockAuthService: MockAuthenticationService!
    
    // UseCases
    var getUserProfileUseCase: GetUserProfileUseCase!
    var updateUserProfileUseCase: UpdateUserProfileUseCase!
    var getHeartRateZonesUseCase: GetHeartRateZonesUseCase!
    var updateHeartRateZonesUseCase: UpdateHeartRateZonesUseCase!
    var getUserTargetsUseCase: GetUserTargetsUseCase!
    var createTargetUseCase: CreateTargetUseCase!
    var syncUserPreferencesUseCase: SyncUserPreferencesUseCase!
    var calculateUserStatsUseCase: CalculateUserStatsUseCase!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockUserRepository = MockUserProfileRepository()
        mockPrefsRepository = MockUserPreferencesRepository()
        mockAuthService = MockAuthenticationService()
        
        // Initialize real use cases with mock repositories
        getUserProfileUseCase = GetUserProfileUseCase(repository: mockUserRepository)
        updateUserProfileUseCase = UpdateUserProfileUseCase(repository: mockUserRepository)
        getHeartRateZonesUseCase = GetHeartRateZonesUseCase(repository: mockUserRepository)
        updateHeartRateZonesUseCase = UpdateHeartRateZonesUseCase(repository: mockUserRepository)
        getUserTargetsUseCase = GetUserTargetsUseCase(repository: mockUserRepository)
        createTargetUseCase = CreateTargetUseCase(repository: mockUserRepository)
        syncUserPreferencesUseCase = SyncUserPreferencesUseCase(preferencesRepository: mockPrefsRepository)
        calculateUserStatsUseCase = CalculateUserStatsUseCase(repository: mockUserRepository)
        
        viewModel = UserProfileFeatureViewModel(
            getUserProfileUseCase: getUserProfileUseCase,
            updateUserProfileUseCase: updateUserProfileUseCase,
            getHeartRateZonesUseCase: getHeartRateZonesUseCase,
            updateHeartRateZonesUseCase: updateHeartRateZonesUseCase,
            getUserTargetsUseCase: getUserTargetsUseCase,
            createTargetUseCase: createTargetUseCase,
            syncUserPreferencesUseCase: syncUserPreferencesUseCase,
            calculateUserStatsUseCase: calculateUserStatsUseCase,
            preferencesRepository: mockPrefsRepository,
            userRepository: mockUserRepository,
            authService: mockAuthService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockUserRepository = nil
        mockPrefsRepository = nil
        mockAuthService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialize_Authenticated_LoadsData() async {
        // Given
        mockAuthService.isAuthenticated = true
        
        // When
        await viewModel.initialize()
        
        // Then
        XCTAssertEqual(mockUserRepository.getUserProfileCallCount, 2) // 1 from loadUserProfile, 1 from getHeartRateZones
        XCTAssertEqual(mockUserRepository.getHeartRateZonesCallCount, 1)
        XCTAssertEqual(mockUserRepository.getTargetsCallCount, 1)
    }
    
    func testInitialize_Unauthenticated_DoesNotLoadData() async {
        // Given
        mockAuthService.isAuthenticated = false
        
        // When
        await viewModel.initialize()
        
        // Then
        XCTAssertEqual(mockUserRepository.getUserProfileCallCount, 0)
    }
    
    // MARK: - Profile Tests
    
    func testLoadUserProfile_Success_UpdatesState() async {
        // Given
        mockAuthService.isAuthenticated = true
        let expectedUser = UserProfileTestFixtures.testUser
        mockUserRepository.userToReturn = expectedUser
        
        // When
        await viewModel.loadUserProfile()
        
        // Then
        if case .loaded(let user) = viewModel.profileState {
            XCTAssertEqual(user.email, expectedUser.email)
        } else {
            XCTFail("State should be .loaded")
        }
    }
    
    func testLoadUserProfile_Failure_UpdatesErrorState() async {
        // Given
        mockAuthService.isAuthenticated = true
        mockUserRepository.errorToThrow = NSError(domain: "test", code: -1, userInfo: nil)
        
        // When
        await viewModel.loadUserProfile()
        
        // Then
        if case .error = viewModel.profileState {
            // Success
        } else {
            XCTFail("State should be .error")
        }
    }
    
    // MARK: - Heart Rate Zones Tests
    
    func testLoadHeartRateZones_UpdatesPublishedZones() async {
        // Given
        let expectedZones = UserProfileTestFixtures.testHeartRateZones
        mockUserRepository.heartRateZonesToReturn = expectedZones
        
        // When
        await viewModel.loadHeartRateZones()
        
        // Then
        XCTAssertEqual(viewModel.heartRateZones.count, expectedZones.count)
    }
    
    // MARK: - Targets Tests
    
    func testLoadTargets_UpdatesPublishedTargets() async {
        // Given
        let expectedTargets = UserProfileTestFixtures.testTargets
        mockUserRepository.targetsToReturn = expectedTargets
        
        // When
        await viewModel.loadTargets()
        
        // Then
        XCTAssertEqual(viewModel.targets.count, expectedTargets.count)
    }
}
