import XCTest
@testable import paceriz_dev

/// Unit tests for AuthCoordinatorViewModel
/// Tests application-level authentication state management and event handling
@MainActor
final class AuthCoordinatorViewModelTests: XCTestCase {

    // System Under Test
    var sut: AuthCoordinatorViewModel!

    // Mock Dependencies
    var mockAuthSessionRepository: MockAuthSessionRepository!
    var mockAuthRepository: MockAuthRepository!
    var mockOnboardingRepository: MockOnboardingRepository!

    override func setUp() {
        super.setUp()
        mockAuthSessionRepository = MockAuthSessionRepository()
        mockAuthRepository = MockAuthRepository()
        mockOnboardingRepository = MockOnboardingRepository()

        sut = AuthCoordinatorViewModel(
            authSessionRepository: mockAuthSessionRepository,
            authRepository: mockAuthRepository,
            onboardingRepository: mockOnboardingRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockAuthSessionRepository = nil
        mockAuthRepository = nil
        mockOnboardingRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Then
        XCTAssertEqual(sut.authState, .loading)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertFalse(sut.needsOnboarding)
        XCTAssertNil(sut.currentUser)
    }

    // MARK: - Initialize Auth State Tests

    func testInitializeAuthState_WhenNotAuthenticated() async {
        // Given
        mockAuthSessionRepository.isAuthenticatedValue = false

        // When
        await sut.initializeAuthState()

        // Then
        XCTAssertTrue(mockAuthSessionRepository.isAuthenticatedCalled)
        XCTAssertEqual(sut.authState, .unauthenticated)
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testInitializeAuthState_WhenAuthenticatedAndOnboardingCompleted() async {
        // Given
        let authenticatedUser = AuthUserFactory.makeAuthenticatedUser()
        mockAuthSessionRepository.isAuthenticatedValue = true
        mockAuthSessionRepository.fetchCurrentUserResult = .success(authenticatedUser)

        // When
        await sut.initializeAuthState()

        // Then
        XCTAssertTrue(mockAuthSessionRepository.isAuthenticatedCalled)
        XCTAssertTrue(mockAuthSessionRepository.fetchCurrentUserCalled)

        if case .authenticated(let user) = sut.authState {
            XCTAssertEqual(user, authenticatedUser)
            XCTAssertTrue(user.hasCompletedOnboarding)
        } else {
            XCTFail("Expected .authenticated state, got \(sut.authState)")
        }

        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertFalse(sut.needsOnboarding)
    }

    func testInitializeAuthState_WhenAuthenticatedButNeedsOnboarding() async {
        // Given
        let newUser = AuthUserFactory.makeNewUser()
        mockAuthSessionRepository.isAuthenticatedValue = true
        mockAuthSessionRepository.fetchCurrentUserResult = .success(newUser)

        // When
        await sut.initializeAuthState()

        // Then
        if case .onboarding(let user) = sut.authState {
            XCTAssertEqual(user, newUser)
            XCTAssertFalse(user.hasCompletedOnboarding)
        } else {
            XCTFail("Expected .onboarding state, got \(sut.authState)")
        }

        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertTrue(sut.needsOnboarding)
    }

    func testInitializeAuthState_WhenFetchUserFails() async {
        // Given
        mockAuthSessionRepository.isAuthenticatedValue = true
        mockAuthSessionRepository.fetchCurrentUserResult = .failure(.userNotFound)

        // When
        await sut.initializeAuthState()

        // Then
        if case .error(let message) = sut.authState {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected .error state, got \(sut.authState)")
        }
    }

    // MARK: - Sign Out Tests

    func testSignOut_Success() async {
        // Given - Set initial authenticated state
        let authenticatedUser = AuthUserFactory.makeAuthenticatedUser()
        sut.authState = .authenticated(authenticatedUser)
        mockAuthRepository.signOutResult = .success(())

        // When
        await sut.signOut()

        // Then
        XCTAssertTrue(mockAuthRepository.signOutCalled)
        XCTAssertEqual(sut.authState, .unauthenticated)
        XCTAssertNil(sut.currentUser)
    }

    func testSignOut_Failure() async {
        // Given
        let authenticatedUser = AuthUserFactory.makeAuthenticatedUser()
        sut.authState = .authenticated(authenticatedUser)
        mockAuthRepository.signOutResult = .failure(.firebaseAuthFailed("Sign out failed"))

        // When
        await sut.signOut()

        // Then
        XCTAssertTrue(mockAuthRepository.signOutCalled)

        if case .error(let message) = sut.authState {
            XCTAssertTrue(message.contains("Sign-out failed"))
        } else {
            XCTFail("Expected .error state after sign out failure")
        }
    }

    // MARK: - Handle Onboarding Complete Tests

    func testHandleOnboardingComplete_Success() async {
        // Given - User in onboarding state
        let newUser = AuthUserFactory.makeNewUser()
        sut.authState = .onboarding(newUser)
        mockOnboardingRepository.completeOnboardingResult = .success(())

        // When
        await sut.handleOnboardingComplete()

        // Then
        XCTAssertTrue(mockOnboardingRepository.completeOnboardingCalled)

        if case .authenticated(let user) = sut.authState {
            XCTAssertEqual(user.uid, newUser.uid)
            XCTAssertTrue(user.hasCompletedOnboarding)
            XCTAssertEqual(user.onboardingMode, .none)
        } else {
            XCTFail("Expected .authenticated state after onboarding completion")
        }
    }

    func testHandleOnboardingComplete_Failure() async {
        // Given
        let newUser = AuthUserFactory.makeNewUser()
        sut.authState = .onboarding(newUser)
        mockOnboardingRepository.completeOnboardingResult = .failure(.backendSyncFailed("Failed"))

        // When
        await sut.handleOnboardingComplete()

        // Then
        XCTAssertTrue(mockOnboardingRepository.completeOnboardingCalled)

        if case .error(let message) = sut.authState {
            XCTAssertTrue(message.contains("complete onboarding"))
        } else {
            XCTFail("Expected .error state after onboarding failure")
        }
    }

    func testHandleOnboardingComplete_WhenNotInOnboardingState() async {
        // Given - User already authenticated
        let authenticatedUser = AuthUserFactory.makeAuthenticatedUser()
        sut.authState = .authenticated(authenticatedUser)

        // When
        await sut.handleOnboardingComplete()

        // Then
        XCTAssertFalse(mockOnboardingRepository.completeOnboardingCalled)
        // State should remain unchanged
        if case .authenticated(let user) = sut.authState {
            XCTAssertEqual(user, authenticatedUser)
        } else {
            XCTFail("State should not change")
        }
    }

    // MARK: - State Query Helper Tests

    func testIsAuthenticated_WhenInAuthenticatedState() {
        // Given
        sut.authState = .authenticated(AuthUserFactory.makeAuthenticatedUser())

        // Then
        XCTAssertTrue(sut.isAuthenticated)
    }

    func testIsAuthenticated_WhenInOtherStates() {
        // Test loading
        sut.authState = .loading
        XCTAssertFalse(sut.isAuthenticated)

        // Test unauthenticated
        sut.authState = .unauthenticated
        XCTAssertFalse(sut.isAuthenticated)

        // Test onboarding
        sut.authState = .onboarding(AuthUserFactory.makeNewUser())
        XCTAssertFalse(sut.isAuthenticated)

        // Test error
        sut.authState = .error("Error")
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testNeedsOnboarding_WhenInOnboardingState() {
        // Given
        sut.authState = .onboarding(AuthUserFactory.makeNewUser())

        // Then
        XCTAssertTrue(sut.needsOnboarding)
    }

    func testNeedsOnboarding_WhenInOtherStates() {
        // Test authenticated
        sut.authState = .authenticated(AuthUserFactory.makeAuthenticatedUser())
        XCTAssertFalse(sut.needsOnboarding)

        // Test unauthenticated
        sut.authState = .unauthenticated
        XCTAssertFalse(sut.needsOnboarding)
    }

    func testCurrentUser_WhenInAuthenticatedOrOnboardingState() {
        // Test authenticated
        let authenticatedUser = AuthUserFactory.makeAuthenticatedUser()
        sut.authState = .authenticated(authenticatedUser)
        XCTAssertEqual(sut.currentUser, authenticatedUser)

        // Test onboarding
        let newUser = AuthUserFactory.makeNewUser()
        sut.authState = .onboarding(newUser)
        XCTAssertEqual(sut.currentUser, newUser)
    }

    func testCurrentUser_WhenInOtherStates() {
        // Test unauthenticated
        sut.authState = .unauthenticated
        XCTAssertNil(sut.currentUser)

        // Test loading
        sut.authState = .loading
        XCTAssertNil(sut.currentUser)

        // Test error
        sut.authState = .error("Error")
        XCTAssertNil(sut.currentUser)
    }

    // MARK: - State Transition Tests

    func testStateTransition_LoginFlow() async {
        // 1. Initial loading state
        XCTAssertEqual(sut.authState, .loading)

        // 2. Initialize as unauthenticated
        mockAuthSessionRepository.isAuthenticatedValue = false
        await sut.initializeAuthState()
        XCTAssertEqual(sut.authState, .unauthenticated)

        // 3. User signs in, needs onboarding
        let newUser = AuthUserFactory.makeNewUser()
        mockAuthSessionRepository.isAuthenticatedValue = true
        mockAuthSessionRepository.fetchCurrentUserResult = .success(newUser)
        await sut.initializeAuthState()

        if case .onboarding(let user) = sut.authState {
            XCTAssertEqual(user, newUser)
        } else {
            XCTFail("Expected .onboarding state")
        }

        // 4. Complete onboarding
        mockOnboardingRepository.completeOnboardingResult = .success(())
        await sut.handleOnboardingComplete()

        if case .authenticated(let user) = sut.authState {
            XCTAssertTrue(user.hasCompletedOnboarding)
        } else {
            XCTFail("Expected .authenticated state")
        }

        // 5. Sign out
        mockAuthRepository.signOutResult = .success(())
        await sut.signOut()
        XCTAssertEqual(sut.authState, .unauthenticated)
    }

    // MARK: - AuthUser Extension Tests

    func testAuthUserExtension_WithCompletedOnboarding() {
        // Given
        let newUser = AuthUserFactory.makeNewUser()

        // When
        let completedUser = newUser.withCompletedOnboarding

        // Then
        XCTAssertEqual(completedUser.uid, newUser.uid)
        XCTAssertEqual(completedUser.email, newUser.email)
        XCTAssertEqual(completedUser.displayName, newUser.displayName)
        XCTAssertTrue(completedUser.hasCompletedOnboarding)
        XCTAssertEqual(completedUser.onboardingMode, .none)
    }

    // MARK: - AuthState Equatable Tests

    func testAuthStateEquatable_Loading() {
        XCTAssertEqual(AuthState.loading, AuthState.loading)
    }

    func testAuthStateEquatable_Unauthenticated() {
        XCTAssertEqual(AuthState.unauthenticated, AuthState.unauthenticated)
    }

    func testAuthStateEquatable_Authenticated() {
        let user = AuthUserFactory.makeAuthenticatedUser()
        XCTAssertEqual(AuthState.authenticated(user), AuthState.authenticated(user))

        let differentUser = AuthUserFactory.makeAuthenticatedUser(uid: "different_123")
        XCTAssertNotEqual(AuthState.authenticated(user), AuthState.authenticated(differentUser))
    }

    func testAuthStateEquatable_Onboarding() {
        let user = AuthUserFactory.makeNewUser()
        XCTAssertEqual(AuthState.onboarding(user), AuthState.onboarding(user))

        let differentUser = AuthUserFactory.makeNewUser(uid: "different_123")
        XCTAssertNotEqual(AuthState.onboarding(user), AuthState.onboarding(differentUser))
    }

    func testAuthStateEquatable_Error() {
        XCTAssertEqual(AuthState.error("message"), AuthState.error("message"))
        XCTAssertNotEqual(AuthState.error("message1"), AuthState.error("message2"))
    }

    func testAuthStateEquatable_DifferentStates() {
        XCTAssertNotEqual(AuthState.loading, AuthState.unauthenticated)
        XCTAssertNotEqual(AuthState.loading, AuthState.error("error"))

        let user = AuthUserFactory.makeAuthenticatedUser()
        XCTAssertNotEqual(AuthState.authenticated(user), AuthState.onboarding(user))
    }
}
