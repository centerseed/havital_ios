import Foundation
@testable import paceriz_dev

// MARK: - Mock Auth Repository
/// Mock implementation of AuthRepository for testing ViewModels
final class MockAuthRepository: AuthRepository {

    // Test control properties
    var signInWithGoogleResult: Result<AuthUser, AuthenticationError> = .failure(.googleSignInFailed("Not configured"))
    var signInWithAppleResult: Result<AuthUser, AuthenticationError> = .failure(.appleSignInFailed("Not configured"))
    var signInWithEmailResult: Result<AuthUser, AuthenticationError> = .failure(.invalidCredentials)
    var demoLoginResult: Result<AuthUser, AuthenticationError> = .failure(.firebaseAuthFailed("Not configured"))
    var signOutResult: Result<Void, AuthenticationError> = .success(())

    // Call tracking
    var signInWithGoogleCalled = false
    var signInWithAppleCalled = false
    var signInWithEmailCalled = false
    var demoLoginCalled = false
    var signOutCalled = false

    func signInWithGoogle() async throws -> AuthUser {
        signInWithGoogleCalled = true
        switch signInWithGoogleResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    func signInWithApple(credential: AppleAuthCredential) async throws -> AuthUser {
        signInWithAppleCalled = true
        switch signInWithAppleResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        signInWithEmailCalled = true
        switch signInWithEmailResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    func demoLogin() async throws -> AuthUser {
        demoLoginCalled = true
        switch demoLoginResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    func signOut() async throws {
        signOutCalled = true
        switch signOutResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Auth Session Repository
/// Mock implementation of AuthSessionRepository for testing
final class MockAuthSessionRepository: AuthSessionRepository {

    // Test control properties
    var currentUser: AuthUser?
    var fetchCurrentUserResult: Result<AuthUser, AuthenticationError> = .failure(.userNotFound)
    var isAuthenticatedValue: Bool = false
    var getIdTokenResult: Result<String, AuthenticationError> = .failure(.tokenExpired)
    var refreshIdTokenResult: Result<String, AuthenticationError> = .failure(.tokenExpired)

    // Call tracking
    var getCurrentUserCalled = false
    var fetchCurrentUserCalled = false
    var isAuthenticatedCalled = false
    var getIdTokenCalled = false
    var refreshIdTokenCalled = false
    var clearCacheCalled = false

    func getCurrentUser() -> AuthUser? {
        getCurrentUserCalled = true
        return currentUser
    }

    func fetchCurrentUser() async throws -> AuthUser {
        fetchCurrentUserCalled = true
        switch fetchCurrentUserResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    func isAuthenticated() -> Bool {
        isAuthenticatedCalled = true
        return isAuthenticatedValue
    }

    func getIdToken() async throws -> String {
        getIdTokenCalled = true
        switch getIdTokenResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    func refreshIdToken() async throws -> String {
        refreshIdTokenCalled = true
        switch refreshIdTokenResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    func clearCache() {
        clearCacheCalled = true
        currentUser = nil
    }

    // MARK: - Demo Support
    var setDemoTokenForTest: String?
    var setDemoTokenCalled = false

    func setDemoToken(_ token: String?) {
        setDemoTokenCalled = true
        setDemoTokenForTest = token
    }
}

// MARK: - Mock Onboarding Repository
/// Mock implementation of OnboardingRepository for testing
final class MockOnboardingRepository: OnboardingRepository {

    // Test control properties
    var getOnboardingStatusResult: Result<OnboardingMode, AuthenticationError> = .success(.none)
    var completeOnboardingResult: Result<Void, AuthenticationError> = .success(())
    var startReonboardingResult: Result<Void, AuthenticationError> = .success(())
    var resetOnboardingResult: Result<Void, AuthenticationError> = .success(())

    // Call tracking
    var getOnboardingStatusCalled = false
    var completeOnboardingCalled = false
    var startReonboardingCalled = false
    var resetOnboardingCalled = false

    func getOnboardingStatus() async throws -> OnboardingMode {
        getOnboardingStatusCalled = true
        switch getOnboardingStatusResult {
        case .success(let mode):
            return mode
        case .failure(let error):
            throw error
        }
    }

    func completeOnboarding() async throws {
        completeOnboardingCalled = true
        switch completeOnboardingResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    func startReonboarding() async throws {
        startReonboardingCalled = true
        switch startReonboardingResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    func resetOnboarding() async throws {
        resetOnboardingCalled = true
        switch resetOnboardingResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Auth Cache
/// Mock implementation of AuthCache for testing RepositoryImpl
final class MockAuthCache: AuthCache {

    // Test data
    var savedUser: AuthUser?
    var isValidValue: Bool = true
    var expirationDate: Date?

    // Call tracking
    var saveUserCalled = false
    var getCurrentUserCalled = false
    var isValidCalled = false
    var getExpirationDateCalled = false
    var clearCacheCalled = false

    func saveUser(_ user: AuthUser) {
        saveUserCalled = true
        savedUser = user
    }

    func getCurrentUser() -> AuthUser? {
        getCurrentUserCalled = true
        return isValidValue ? savedUser : nil
    }

    func isValid() -> Bool {
        isValidCalled = true
        return isValidValue
    }

    func getExpirationDate() -> Date? {
        getExpirationDateCalled = true
        return expirationDate
    }

    func clearCache() {
        clearCacheCalled = true
        savedUser = nil
        expirationDate = nil
    }
}

// MARK: - Test Data Factories
/// Factory for creating test AuthUser instances
struct AuthUserFactory {

    static func makeAuthenticatedUser(
        uid: String = "test_uid_123",
        email: String? = "test@example.com",
        displayName: String? = "Test User",
        hasCompletedOnboarding: Bool = true,
        onboardingMode: OnboardingMode = .none
    ) -> AuthUser {
        return AuthUser(
            uid: uid,
            email: email,
            displayName: displayName,
            photoURL: nil,
            isAuthenticated: true,
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: onboardingMode
        )
    }

    static func makeNewUser(
        uid: String = "new_user_123"
    ) -> AuthUser {
        return AuthUser(
            uid: uid,
            email: "new@example.com",
            displayName: "New User",
            photoURL: nil,
            isAuthenticated: true,
            hasCompletedOnboarding: false,
            onboardingMode: .initial
        )
    }

    static func makeReonboardingUser(
        uid: String = "reonboarding_123"
    ) -> AuthUser {
        return AuthUser(
            uid: uid,
            email: "reonboard@example.com",
            displayName: "Reonboarding User",
            photoURL: nil,
            isAuthenticated: true,
            hasCompletedOnboarding: false,
            onboardingMode: .reonboarding
        )
    }
}

// MARK: - Test Credential Factories
/// Factory for creating test credentials
struct TestCredentialFactory {

    static func makeAppleAuthCredential() -> AppleAuthCredential {
        return AppleAuthCredential(
            identityToken: Data("test_identity_token".utf8),
            authorizationCode: Data("test_auth_code".utf8),
            fullName: nil,
            email: "apple@example.com"
        )
    }

    static func makeGoogleAuthCredential() -> GoogleAuthCredential {
        return GoogleAuthCredential(
            idToken: "test_google_id_token",
            accessToken: "test_google_access_token"
        )
    }
}
