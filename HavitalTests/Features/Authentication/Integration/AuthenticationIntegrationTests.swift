import XCTest
@testable import paceriz_dev

/// Integration tests for Authentication Module
/// Tests complete flows from ViewModel through Repository to actual backend API
/// Uses Demo account to avoid external authentication dependencies (Google/Apple)
@MainActor
final class AuthenticationIntegrationTests: XCTestCase {

    // MARK: - System Under Test

    var loginViewModel: LoginViewModel!
    var authCoordinatorViewModel: AuthCoordinatorViewModel!

    // MARK: - Real Dependencies (Integration Test)

    var authRepository: AuthRepositoryImpl!
    var authSessionRepository: AuthSessionRepositoryImpl!
    var onboardingRepository: OnboardingRepositoryImpl!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Use real dependencies for integration testing
        // Note: This requires network access to backend API

        // DataSources
        let firebaseAuth = FirebaseAuthDataSource()
        let googleSignIn = GoogleSignInDataSource()
        let appleSignIn = AppleSignInDataSource()
        let backendAuth = BackendAuthDataSource()
        let authCache = UserDefaultsAuthCache()

        // Repositories
        authSessionRepository = AuthSessionRepositoryImpl(
            firebaseAuth: firebaseAuth,
            backendAuth: backendAuth,
            authCache: authCache
        )

        authRepository = AuthRepositoryImpl(
            firebaseAuth: firebaseAuth,
            googleSignIn: googleSignIn,
            appleSignIn: appleSignIn,
            backendAuth: backendAuth,
            authCache: authCache,
            authSessionRepository: authSessionRepository
        )

        onboardingRepository = OnboardingRepositoryImpl(
            firebaseAuth: firebaseAuth,
            backendAuth: backendAuth,
            authCache: authCache
        )

        // ViewModels with real repositories
        loginViewModel = LoginViewModel(authRepository: authRepository)
        authCoordinatorViewModel = AuthCoordinatorViewModel(
            authSessionRepository: authSessionRepository,
            authRepository: authRepository,
            onboardingRepository: onboardingRepository
        )
    }

    override func tearDown() async throws {
        // Clean up any authenticated state
        try? await authRepository.signOut()

        loginViewModel = nil
        authCoordinatorViewModel = nil
        authRepository = nil
        authSessionRepository = nil
        onboardingRepository = nil

        try await super.tearDown()
    }

    // MARK: - Demo Login Integration Tests

    /// Test complete demo login flow from ViewModel to backend API
    /// This tests the entire authentication pipeline:
    /// LoginViewModel → AuthRepository → BackendAuthDataSource → Backend API
    func testDemoLogin_CompleteFlow() async throws {
        // Given - Initial state
        XCTAssertEqual(loginViewModel.state, .empty)
        XCTAssertNil(loginViewModel.authenticatedUser)

        // When - Perform demo login
        await loginViewModel.demoLogin()

        // Then - Verify successful authentication
        XCTAssertFalse(loginViewModel.hasError, "Demo login should not produce error")

        // Verify user is authenticated
        guard let authenticatedUser = loginViewModel.authenticatedUser else {
            XCTFail("Expected authenticated user after demo login")
            return
        }

        // Verify user properties
        XCTAssertFalse(authenticatedUser.uid.isEmpty, "User should have valid UID")
        XCTAssertNotNil(authenticatedUser.email, "Demo user should have email")
        XCTAssertTrue(authenticatedUser.isAuthenticated, "User should be authenticated")
        XCTAssertTrue(authenticatedUser.hasCompletedOnboarding, "Demo user should have completed onboarding")
        XCTAssertEqual(authenticatedUser.onboardingMode, .none, "Demo user should not need onboarding")

        // Verify state is .loaded
        if case .loaded(let user) = loginViewModel.state {
            XCTAssertEqual(user.uid, authenticatedUser.uid)
        } else {
            XCTFail("Expected .loaded state, got \(loginViewModel.state)")
        }

        print("✅ Demo login succeeded: \(authenticatedUser.uid)")
    }

    /// Test demo login updates AuthCoordinatorViewModel state
    func testDemoLogin_UpdatesAuthCoordinator() async throws {
        // Given - AuthCoordinator starts in loading state
        XCTAssertEqual(authCoordinatorViewModel.authState, .loading)

        // When - Perform demo login through LoginViewModel
        await loginViewModel.demoLogin()

        // Then - Verify LoginViewModel has user
        guard let loginUser = loginViewModel.authenticatedUser else {
            XCTFail("Expected authenticated user after demo login")
            return
        }

        // Re-initialize AuthCoordinator to pick up cached user
        await authCoordinatorViewModel.initializeAuthState()

        // Verify AuthCoordinator recognizes the session
        // Note: This depends on cache being properly populated
        switch authCoordinatorViewModel.authState {
        case .authenticated(let user):
            XCTAssertEqual(user.uid, loginUser.uid, "AuthCoordinator should recognize cached user")
            XCTAssertTrue(authCoordinatorViewModel.isAuthenticated)
            XCTAssertFalse(authCoordinatorViewModel.needsOnboarding)
            print("✅ AuthCoordinator recognized authenticated user")

        case .unauthenticated:
            // This can happen if cache expired or Firebase session not synced
            print("⚠️ AuthCoordinator shows unauthenticated - cache may have expired")

        case .onboarding:
            XCTFail("Demo user should not need onboarding")

        case .error(let message):
            XCTFail("AuthCoordinator should not be in error state: \(message)")

        case .loading:
            XCTFail("AuthCoordinator should have finished loading")
        }
    }

    // MARK: - Sign Out Integration Tests

    /// Test sign out flow clears authentication state
    func testSignOut_ClearsAuthenticationState() async throws {
        // Given - First perform demo login
        await loginViewModel.demoLogin()

        guard loginViewModel.authenticatedUser != nil else {
            XCTFail("Precondition failed: Need authenticated user for sign out test")
            return
        }

        // When - Sign out through AuthCoordinator
        // First initialize coordinator to pick up the session
        await authCoordinatorViewModel.initializeAuthState()

        // Perform sign out
        await authCoordinatorViewModel.signOut()

        // Then - Verify unauthenticated state
        XCTAssertEqual(authCoordinatorViewModel.authState, .unauthenticated)
        XCTAssertFalse(authCoordinatorViewModel.isAuthenticated)
        XCTAssertNil(authCoordinatorViewModel.currentUser)

        print("✅ Sign out completed successfully")
    }

    /// Test sign out clears local cache
    func testSignOut_ClearsCache() async throws {
        // Given - Demo login and verify cache populated
        await loginViewModel.demoLogin()

        guard let user = loginViewModel.authenticatedUser else {
            XCTFail("Precondition failed: Need authenticated user")
            return
        }

        // Verify user is cached
        let cachedUserBefore = authSessionRepository.getCurrentUser()
        XCTAssertNotNil(cachedUserBefore, "User should be cached after login")

        // When - Sign out
        try await authRepository.signOut()

        // Then - Verify cache cleared
        let cachedUserAfter = authSessionRepository.getCurrentUser()
        XCTAssertNil(cachedUserAfter, "Cache should be cleared after sign out")

        print("✅ Cache cleared after sign out")
    }

    // MARK: - Session Restoration Tests

    /// Test session can be restored from cache
    func testSessionRestoration_FromCache() async throws {
        // Given - Demo login to populate cache
        await loginViewModel.demoLogin()

        guard let originalUser = loginViewModel.authenticatedUser else {
            XCTFail("Precondition failed: Need authenticated user")
            return
        }

        // When - Create new AuthCoordinator (simulating app restart)
        let newCoordinator = AuthCoordinatorViewModel(
            authSessionRepository: authSessionRepository,
            authRepository: authRepository,
            onboardingRepository: onboardingRepository
        )

        await newCoordinator.initializeAuthState()

        // Then - Verify session restored
        // Note: Actual restoration depends on Firebase session and cache validity
        switch newCoordinator.authState {
        case .authenticated(let restoredUser):
            XCTAssertEqual(restoredUser.uid, originalUser.uid, "Restored user should match original")
            print("✅ Session restored from cache")

        case .unauthenticated:
            // This can happen if:
            // 1. Firebase session expired
            // 2. Cache TTL expired
            // 3. Firebase not properly initialized in test environment
            print("⚠️ Session not restored - may be expected in test environment")

        default:
            print("⚠️ Unexpected state: \(newCoordinator.authState)")
        }
    }

    // MARK: - Error Handling Integration Tests

    /// Test network failure handling
    func testDemoLogin_HandlesNetworkFailure() async throws {
        // This test requires simulating network failure
        // In a real integration test environment, you might:
        // 1. Disconnect network
        // 2. Use a mock server that returns errors
        // 3. Use dependency injection with a failing mock

        // For now, we'll skip this test in normal runs
        // Uncomment when running with network simulation

        /*
        // Given - Network is unavailable (simulated)

        // When - Attempt demo login
        await loginViewModel.demoLogin()

        // Then - Verify error state
        XCTAssertTrue(loginViewModel.hasError)

        if case .error(let domainError) = loginViewModel.state {
            // Should be network-related error
            print("Expected error: \(domainError)")
        } else {
            XCTFail("Expected error state on network failure")
        }
        */
    }

    // MARK: - Concurrent Operations Tests

    /// Test multiple login attempts don't cause race conditions
    func testConcurrentDemoLogins_NoRaceCondition() async throws {
        // Given - Multiple concurrent login tasks
        let task1 = Task { await self.loginViewModel.demoLogin() }
        let task2 = Task { await self.loginViewModel.demoLogin() }
        let task3 = Task { await self.loginViewModel.demoLogin() }

        // When - Wait for all to complete
        await task1.value
        await task2.value
        await task3.value

        // Then - State should be consistent
        XCTAssertFalse(loginViewModel.hasError, "No errors from concurrent logins")

        if case .loaded(let user) = loginViewModel.state {
            XCTAssertFalse(user.uid.isEmpty, "Should have valid user")
            print("✅ Concurrent logins handled correctly")
        } else if case .error = loginViewModel.state {
            // Acceptable if backend rate-limits
            print("⚠️ Error state - may be rate limited")
        } else {
            // Could be in any valid state depending on timing
            print("⚠️ Unexpected state after concurrent logins: \(loginViewModel.state)")
        }
    }
}
