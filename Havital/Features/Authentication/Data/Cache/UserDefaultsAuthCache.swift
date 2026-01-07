import Foundation

// MARK: - UserDefaults-based Auth Cache Implementation
/// Concrete implementation of AuthCache using UserDefaults
/// Stores business data only (no tokens for security)
/// Cache expires after 5 minutes
final class UserDefaultsAuthCache: AuthCache {

    // MARK: - Constants

    private enum Keys {
        static let authUser = "auth_cache_user"
        static let expirationDate = "auth_cache_expiration"
    }

    /// Cache validity duration: 5 minutes
    private let cacheDuration: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Save Operations

    func saveUser(_ user: AuthUser) {
        // Encode AuthUser to JSON
        guard let encoded = try? JSONEncoder().encode(user) else {
            Logger.error("Failed to encode AuthUser for caching")
            return
        }

        // Calculate expiration date
        let expirationDate = Date().addingTimeInterval(cacheDuration)

        // Save to UserDefaults
        userDefaults.set(encoded, forKey: Keys.authUser)
        userDefaults.set(expirationDate, forKey: Keys.expirationDate)

        Logger.debug("AuthUser cached until \(expirationDate)")
    }

    // MARK: - Read Operations

    func getCurrentUser() -> AuthUser? {
        // Check if cache is expired
        guard isValid() else {
            Logger.debug("Auth cache expired or not found")
            clearCache() // Auto-cleanup expired cache
            return nil
        }

        // Retrieve and decode cached user
        guard let data = userDefaults.data(forKey: Keys.authUser),
              let user = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            Logger.debug("Failed to decode cached AuthUser")
            clearCache()
            return nil
        }

        Logger.debug("Returning cached AuthUser: \(user.uid)")
        return user
    }

    // MARK: - Validation Operations

    func isValid() -> Bool {
        guard let expirationDate = getExpirationDate() else {
            return false
        }

        let isValid = Date() < expirationDate
        if !isValid {
            Logger.debug("Auth cache expired at \(expirationDate)")
        }
        return isValid
    }

    func getExpirationDate() -> Date? {
        return userDefaults.object(forKey: Keys.expirationDate) as? Date
    }

    // MARK: - Clear Operations

    func clearCache() {
        userDefaults.removeObject(forKey: Keys.authUser)
        userDefaults.removeObject(forKey: Keys.expirationDate)
        Logger.debug("Auth cache cleared")
    }
}
