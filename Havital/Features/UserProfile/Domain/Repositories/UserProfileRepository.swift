import Foundation

// MARK: - UserProfile Repository Protocol
/// Defines user profile data access interface
/// Domain Layer - only defines interface, no implementation details
protocol UserProfileRepository {

    // MARK: - User Profile

    /// Get user profile (with cache support)
    /// Uses dual-track caching: returns cached data immediately, refreshes in background
    /// - Returns: User profile entity
    func getUserProfile() async throws -> User

    /// Force refresh user profile (skip cache)
    /// - Returns: Latest user profile from API
    func refreshUserProfile() async throws -> User

    /// Update user profile data
    /// - Parameter updates: Dictionary of fields to update
    /// - Returns: Updated user profile
    func updateUserProfile(_ updates: [String: Any]) async throws -> User

    /// Delete user account
    /// - Parameter userId: User ID to delete
    func deleteAccount(userId: String) async throws

    // MARK: - Data Source

    /// Update user's data source preference
    /// - Parameter dataSource: The data source to set (apple_health, garmin, strava, unbound)
    func updateDataSource(_ dataSource: String) async throws

    // MARK: - Heart Rate Zones

    /// Get calculated heart rate zones based on user's maxHR and restingHR
    /// - Returns: Array of 5 heart rate zones
    func getHeartRateZones() async throws -> [HeartRateZonesManager.HeartRateZone]

    /// Update heart rate parameters and recalculate zones
    /// - Parameters:
    ///   - maxHR: Maximum heart rate
    ///   - restingHR: Resting heart rate
    /// - Returns: Recalculated zones
    func updateHeartRateZones(maxHR: Int, restingHR: Int) async throws -> [HeartRateZonesManager.HeartRateZone]

    /// Sync heart rate data from User model to local storage
    /// - Parameter user: User model containing HR data
    func syncHeartRateData(from user: User) async

    // MARK: - Targets

    /// Get all user race targets
    func getTargets() async throws -> [Target]

    /// Create new race target
    /// - Parameter target: Target to create
    /// - Returns: Created target
    func createTarget(_ target: Target) async throws

    // MARK: - Statistics

    /// Calculate and return user statistics
    /// - Returns: Aggregated user statistics
    func calculateStatistics() async -> UserStatistics?

    // MARK: - Personal Best

    /// Detect and track personal best updates
    /// - Parameters:
    ///   - oldData: Previous personal best data
    ///   - newData: New personal best data
    func detectPersonalBestUpdates(
        oldData: [String: [PersonalBestRecordV2]]?,
        newData: [String: [PersonalBestRecordV2]]?
    ) async

    /// Get pending celebration update (if any PB was detected)
    func getPendingCelebrationUpdate() -> PersonalBestUpdate?

    /// Mark celebration as shown
    func markCelebrationAsShown()

    // MARK: - Cache Management

    /// Clear all cached user data
    func clearCache() async

    /// Check if cache is expired
    func isCacheExpired() -> Bool
}
