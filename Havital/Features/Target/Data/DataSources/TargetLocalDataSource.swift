import Foundation

// MARK: - TargetLocalDataSource Protocol
protocol TargetLocalDataSourceProtocol {
    func getTargets() -> [Target]
    func getTarget(id: String) -> Target?
    func getMainTarget() -> Target?
    func getSupportingTargets() -> [Target]
    func saveTargets(_ targets: [Target])
    func saveTarget(_ target: Target)
    func removeTarget(id: String)
    func isExpired() -> Bool
    func hasTargets() -> Bool
    func clearAll()
    func getCacheSize() -> Int
}

// MARK: - TargetLocalDataSource
/// Handles local caching of target data
/// Data Layer - Pure cache management, no business logic
final class TargetLocalDataSource: TargetLocalDataSourceProtocol {

    // MARK: - Constants
    private enum Keys {
        static let targets = "target_cache_v3"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let targets: TimeInterval = 3600  // 1 hour
    }

    // MARK: - Dependencies
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Targets Cache

    /// Get all cached targets
    func getTargets() -> [Target] {
        guard let data = defaults.data(forKey: Keys.targets) else {
            return []
        }

        do {
            return try decoder.decode([Target].self, from: data)
        } catch {
            Logger.debug("[TargetLocalDS] Failed to decode targets, clearing cache")
            clearAll()
            return []
        }
    }

    /// Get single target by ID
    func getTarget(id: String) -> Target? {
        return getTargets().first { $0.id == id }
    }

    /// Get main race target
    func getMainTarget() -> Target? {
        return getTargets().first { $0.isMainRace }
    }

    /// Get supporting targets (non-main races)
    func getSupportingTargets() -> [Target] {
        return getTargets().filter { !$0.isMainRace }
    }

    /// Save targets to cache
    func saveTargets(_ targets: [Target]) {
        do {
            let data = try encoder.encode(targets)
            defaults.set(data, forKey: Keys.targets)
            defaults.set(Date(), forKey: Keys.targets + Keys.timestampSuffix)
            Logger.debug("[TargetLocalDS] Targets saved to cache: \(targets.count)")
        } catch {
            Logger.error("[TargetLocalDS] Failed to encode targets: \(error)")
        }
    }

    /// Save single target (merge with existing)
    func saveTarget(_ target: Target) {
        var targets = getTargets()

        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            targets[index] = target
        } else {
            targets.append(target)
        }

        saveTargets(targets)
    }

    /// Remove target from cache
    func removeTarget(id: String) {
        var targets = getTargets()
        targets.removeAll { $0.id == id }
        saveTargets(targets)
    }

    /// Check if cache is expired
    func isExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.targets + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.targets
    }

    /// Check if targets exist in cache
    func hasTargets() -> Bool {
        return !getTargets().isEmpty
    }

    /// Clear all cached data
    func clearAll() {
        defaults.removeObject(forKey: Keys.targets)
        defaults.removeObject(forKey: Keys.targets + Keys.timestampSuffix)
        Logger.debug("[TargetLocalDS] All caches cleared")
    }

    /// Get cache size in bytes (approximate)
    func getCacheSize() -> Int {
        if let data = defaults.data(forKey: Keys.targets) {
            return data.count
        }
        return 0
    }
}
