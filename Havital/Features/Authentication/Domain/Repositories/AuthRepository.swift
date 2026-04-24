import Foundation

// MARK: - Auth Repository Protocol
/// Defines core authentication operations
/// Domain Layer - only defines interface, no implementation details
/// Responsible for sign-in/sign-out operations only
/// Token management is handled by AuthSessionRepository
protocol AuthRepository {

    // MARK: - Sign-In Operations

    /// Sign in with Google account
    /// - Returns: Authenticated user with business properties
    /// - Throws: AuthenticationError if sign-in fails
    func signInWithGoogle() async throws -> AuthUser

    /// Sign in with Apple ID (full async flow)
    /// Handles ASAuthorizationController internally
    /// - Returns: Authenticated user with business properties
    /// - Throws: AuthenticationError if sign-in fails
    func signInWithApple() async throws -> AuthUser

    /// Sign in with Apple ID (with pre-obtained credential)
    /// - Parameter credential: Apple authentication credential (domain abstraction, not SDK type)
    /// - Returns: Authenticated user with business properties
    /// - Throws: AuthenticationError if sign-in fails
    func signInWithApple(credential: AppleAuthCredential) async throws -> AuthUser

    /// Sign in with email and password (if supported)
    /// - Parameters:
    ///   - email: User email address
    ///   - password: User password
    /// - Returns: Authenticated user with business properties
    /// - Throws: AuthenticationError if sign-in fails
    func signInWithEmail(email: String, password: String) async throws -> AuthUser

    func registerEmail(email: String, password: String) async throws -> RegisterData

    func verifyEmail(oobCode: String) async throws -> VerifyData

    func resendEmailVerification(email: String, password: String) async throws -> ResendData

    /// Demo login for development/testing
    /// - Parameter reviewerPasscode: Reviewer access passcode collected from the hidden login gate
    /// - Returns: Demo user with pre-configured data
    /// - Throws: AuthenticationError if demo mode is not available
    func demoLogin(reviewerPasscode: String) async throws -> AuthUser

    // MARK: - Sign-Out Operations

    /// Sign out current user
    /// Clears Firebase session, cache, and all authentication state
    /// - Throws: AuthenticationError if sign-out fails
    func signOut() async throws
}

extension AuthRepository {
    func registerEmail(email: String, password: String) async throws -> RegisterData {
        throw AuthenticationError.invalidCredentials
    }

    func verifyEmail(oobCode: String) async throws -> VerifyData {
        throw AuthenticationError.invalidCredentials
    }

    func resendEmailVerification(email: String, password: String) async throws -> ResendData {
        throw AuthenticationError.invalidCredentials
    }
}
