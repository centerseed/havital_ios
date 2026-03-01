import Foundation

// MARK: - Target Repository Protocol
/// Defines target data access interface
/// Domain Layer - only defines interface, no implementation details
protocol TargetRepository {

    // MARK: - Read Operations

    /// Get all user race targets
    /// Uses dual-track caching: returns cached data immediately, refreshes in background
    /// - Returns: Array of targets
    func getTargets() async throws -> [Target]

    /// Get single target by ID
    /// - Parameter id: Target ID
    /// - Returns: Target if found
    func getTarget(id: String) async throws -> Target

    /// Get main race target
    /// - Returns: Main race target if available
    func getMainTarget() async -> Target?

    /// Get supporting race targets (non-main races)
    /// - Returns: Array of supporting targets
    func getSupportingTargets() async -> [Target]

    // MARK: - Write Operations

    /// Create new race target
    /// - Parameter target: Target to create
    /// - Returns: Created target with ID
    func createTarget(_ target: Target) async throws -> Target

    /// Update existing target
    /// - Parameters:
    ///   - id: Target ID to update
    ///   - target: Updated target data
    /// - Returns: Updated target
    func updateTarget(id: String, target: Target) async throws -> Target

    /// Delete target
    /// - Parameter id: Target ID to delete
    func deleteTarget(id: String) async throws

    // MARK: - Refresh Operations

    /// Force refresh all targets from API (skip cache)
    /// - Returns: Latest targets from API
    func forceRefresh() async throws -> [Target]

    // MARK: - Cache Management

    /// Clear all cached target data
    func clearCache()

    /// Check if target cache exists
    /// - Returns: True if targets are cached
    func hasCache() -> Bool
}
