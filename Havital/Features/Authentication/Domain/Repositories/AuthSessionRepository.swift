import Foundation

// MARK: - Auth Session Repository Protocol
/// Defines authentication session and token management operations
/// Domain Layer - only defines interface, no implementation details
/// Responsible for managing user session state and token lifecycle
/// Separated from AuthRepository for Single Responsibility Principle
protocol AuthSessionRepository {

    // MARK: - Session State Operations

    /// Get currently cached user (synchronous)
    /// Returns cached AuthUser without making network calls
    /// Cache expires after 5 minutes (business data only, no tokens)
    /// - Returns: Cached AuthUser if available and valid, nil otherwise
    func getCurrentUser() -> AuthUser?

    /// Fetch current user from Firebase and Backend (asynchronous)
    /// Always fetches fresh data from API, updates cache
    /// - Returns: Current authenticated user with latest data
    /// - Throws: AuthenticationError if user not authenticated or fetch fails
    func fetchCurrentUser() async throws -> AuthUser

    /// Check if user is currently authenticated
    /// Validates Firebase Auth State
    /// - Returns: True if user has valid Firebase session
    func isAuthenticated() -> Bool

    // MARK: - Token Management

    /// Get Firebase ID Token (real-time, not cached)
    /// Token is fetched from Firebase SDK every time for security
    /// Firebase SDK handles automatic refresh internally
    /// - Returns: Valid Firebase ID Token
    /// - Throws: AuthenticationError.tokenExpired if token cannot be retrieved
    func getIdToken() async throws -> String

    /// Force refresh Firebase ID Token
    /// Explicitly requests new token from Firebase
    /// - Returns: Fresh Firebase ID Token
    /// - Throws: AuthenticationError.tokenExpired if refresh fails
    func refreshIdToken() async throws -> String

    // MARK: - Cache Management

    /// Clear all cached authentication data
    /// Used during sign-out or when cache becomes invalid
    func clearCache()

    // MARK: - Demo Support

    /// Set Demo Token for testing/development
    /// - Parameter token: Valid backend ID token
    func setDemoToken(_ token: String?)
}
