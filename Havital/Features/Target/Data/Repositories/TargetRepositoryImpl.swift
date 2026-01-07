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
        Logger.debug("[TargetRepo] Getting targets (dual-track)")

        // Track A: Return cached data if available
        let cachedTargets = localDataSource.getTargets()
        if !cachedTargets.isEmpty {
            Logger.debug("[TargetRepo] Returning cached targets: \(cachedTargets.count)")

            // Track B: Refresh in background
            Task.detached { [weak self] in
                await self?.refreshInBackground()
            }

            return cachedTargets
        }

        // No cache - fetch from API
        Logger.debug("[TargetRepo] No cache, fetching from API")
        let targets = try await remoteDataSource.getTargets()
        localDataSource.saveTargets(targets)
        return targets
    }

    /// Get single target with dual-track caching
    func getTarget(id: String) async throws -> Target {
        Logger.debug("[TargetRepo] Getting target: \(id)")

        // Track A: Return cached target if available
        if let cachedTarget = localDataSource.getTarget(id: id) {
            Logger.debug("[TargetRepo] Returning cached target: \(cachedTarget.name)")

            // Track B: Refresh in background
            Task.detached { [weak self] in
                await self?.refreshTargetInBackground(id: id)
            }

            return cachedTarget
        }

        // No cache - fetch from API
        Logger.debug("[TargetRepo] No cache for target, fetching from API")
        let target = try await remoteDataSource.getTarget(id: id)
        localDataSource.saveTarget(target)
        return target
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
        Logger.debug("[TargetRepo] Force refreshing targets")

        let targets = try await remoteDataSource.getTargets()
        localDataSource.saveTargets(targets)
        Logger.debug("[TargetRepo] Force refresh complete: \(targets.count) targets")

        return targets
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

    /// Background refresh for dual-track strategy
    private func refreshInBackground() async {
        do {
            Logger.debug("[TargetRepo] Background refresh started")
            let targets = try await remoteDataSource.getTargets()
            localDataSource.saveTargets(targets)
            Logger.debug("[TargetRepo] Background refresh complete")
        } catch {
            Logger.debug("[TargetRepo] Background refresh failed: \(error.localizedDescription)")
        }
    }

    /// Background refresh for single target
    private func refreshTargetInBackground(id: String) async {
        do {
            Logger.debug("[TargetRepo] Background refresh target: \(id)")
            let target = try await remoteDataSource.getTarget(id: id)
            localDataSource.saveTarget(target)
            Logger.debug("[TargetRepo] Background refresh target complete")
        } catch {
            Logger.debug("[TargetRepo] Background refresh target failed: \(error.localizedDescription)")
        }
    }

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
