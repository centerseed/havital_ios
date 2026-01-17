import Foundation

// MARK: - TargetRepositoryImpl
/// Repository implementation with dual-track caching strategy
/// Data Layer - Coordinates between remote and local data sources
final class TargetRepositoryImpl: TargetRepository {

    // MARK: - Dependencies
    private let remoteDataSource: TargetRemoteDataSourceProtocol
    private let localDataSource: TargetLocalDataSourceProtocol

    // MARK: - Initialization
    init(
        remoteDataSource: TargetRemoteDataSourceProtocol = TargetRemoteDataSource(),
        localDataSource: TargetLocalDataSourceProtocol = TargetLocalDataSource()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - Read Operations

    /// Get all targets with dual-track caching
    /// Track A: Return cached data immediately
    /// Track B: Refresh from API in background
    func getTargets() async throws -> [Target] {
        // Use DualTrackCacheHelper for consistent caching behavior
        return try await DualTrackCacheHelper.executeForCollection(
            cacheKey: "targets",
            getCached: { localDataSource.getTargets() },
            fetchFromAPI: { [remoteDataSource] in try await remoteDataSource.getTargets() },
            saveToCache: { [localDataSource] in localDataSource.saveTargets($0) }
        )
    }

    /// Get single target with dual-track caching
    func getTarget(id: String) async throws -> Target {
        // Use DualTrackCacheHelper for consistent caching behavior
        return try await DualTrackCacheHelper.executeSimple(
            cacheKey: "target_\(id)",
            getCached: { [localDataSource] in localDataSource.getTarget(id: id) },
            fetchFromAPI: { [remoteDataSource] in try await remoteDataSource.getTarget(id: id) },
            saveToCache: { [localDataSource] in localDataSource.saveTarget($0) }
        )
    }

    /// Get main race target from cache
    func getMainTarget() async -> Target? {
        return localDataSource.getMainTarget()
    }

    /// Get supporting targets from cache
    func getSupportingTargets() async -> [Target] {
        return localDataSource.getSupportingTargets()
    }

    // MARK: - Write Operations

    /// Create new target
    func createTarget(_ target: Target) async throws -> Target {
        Logger.debug("[TargetRepo] Creating target: \(target.name)")

        let createdTarget = try await remoteDataSource.createTarget(target)

        // Update local cache
        localDataSource.saveTarget(createdTarget)
        Logger.debug("[TargetRepo] Target created and cached")

        // Post notification for backward compatibility
        await notifyTargetUpdated()

        return createdTarget
    }

    /// Update existing target
    func updateTarget(id: String, target: Target) async throws -> Target {
        Logger.debug("[TargetRepo] Updating target: \(id)")

        let updatedTarget = try await remoteDataSource.updateTarget(id: id, target: target)

        // Update local cache
        localDataSource.saveTarget(updatedTarget)
        Logger.debug("[TargetRepo] Target updated and cached")

        // Post notification for backward compatibility
        await notifyTargetUpdated()

        return updatedTarget
    }

    /// Delete target
    func deleteTarget(id: String) async throws {
        Logger.debug("[TargetRepo] Deleting target: \(id)")

        try await remoteDataSource.deleteTarget(id: id)

        // Remove from local cache
        localDataSource.removeTarget(id: id)
        Logger.debug("[TargetRepo] Target deleted from cache")

        // Post notification for backward compatibility
        await notifyTargetUpdated()
    }

    // MARK: - Refresh Operations

    /// Force refresh all targets from API (skip cache)
    func forceRefresh() async throws -> [Target] {
        // Use DualTrackCacheHelper for consistent refresh behavior
        return try await DualTrackCacheHelper.forceRefresh(
            cacheKey: "targets",
            fetchFromAPI: { [remoteDataSource] in try await remoteDataSource.getTargets() },
            saveToCache: { [localDataSource] in localDataSource.saveTargets($0) }
        )
    }

    // MARK: - Cache Management

    /// Clear all cached target data
    func clearCache() {
        localDataSource.clearAll()
        Logger.debug("[TargetRepo] Cache cleared")
    }

    /// Check if target cache exists
    func hasCache() -> Bool {
        return localDataSource.hasTargets()
    }

    // MARK: - Private Methods

    /// Post notification for backward compatibility with existing views
    @MainActor
    private func notifyTargetUpdated() {
        NotificationCenter.default.post(name: .targetUpdated, object: nil)
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {
    /// Register Target module dependencies
    func registerTargetModule() {
        // Register DataSources
        let localDS = TargetLocalDataSource()
        register(localDS, forProtocol: TargetLocalDataSourceProtocol.self)

        let remoteDS = TargetRemoteDataSource()
        register(remoteDS, forProtocol: TargetRemoteDataSourceProtocol.self)

        // Register Repository
        let repository = TargetRepositoryImpl(
            remoteDataSource: resolve() as TargetRemoteDataSourceProtocol,
            localDataSource: resolve() as TargetLocalDataSourceProtocol
        )
        register(repository as TargetRepository, forProtocol: TargetRepository.self)

        Logger.debug("[DI] Target module dependencies registered")
    }
}
