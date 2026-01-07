import Foundation

// MARK: - Auth Cache Protocol
/// Defines authentication cache interface for Data Layer
/// Abstracts storage mechanism to enable different implementations (UserDefaults, Keychain, etc.)
/// Cache stores ONLY business data (AuthUser), NOT tokens (security consideration)
protocol AuthCache {

    // MARK: - Save Operations

    /// Save authenticated user to cache
    /// Cache expires after 5 minutes
    /// - Parameter user: AuthUser entity to cache (business data only, no tokens)
    func saveUser(_ user: AuthUser)

    // MARK: - Read Operations

    /// Get cached user (with expiration check)
    /// Returns nil if cache is expired or not found
    /// - Returns: Cached AuthUser if valid, nil otherwise
    func getCurrentUser() -> AuthUser?

    // MARK: - Validation Operations

    /// Check if cache is still valid (not expired)
    /// - Returns: True if cache exists and not expired
    func isValid() -> Bool

    /// Get cache expiration timestamp
    /// - Returns: Date when cache expires, nil if no cache
    func getExpirationDate() -> Date?

    // MARK: - Clear Operations

    /// Clear all cached authentication data
    /// Called during sign-out or cache invalidation
    func clearCache()
}
