import Foundation

// MARK: - UserProfileLocalDataSource
/// Handles local caching of user profile data
/// Data Layer - Pure cache management, no business logic
final class UserProfileLocalDataSource {

    // MARK: - Constants
    private enum Keys {
        static let userProfile = "user_profile_cache_v3"
        static let targets = "user_targets_cache_v3"
        static let heartRateZones = "heart_rate_zones_cache_v3"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let userProfile: TimeInterval = 3600      // 1 hour
        static let targets: TimeInterval = 3600          // 1 hour
        static let heartRateZones: TimeInterval = 86400  // 24 hours
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

    // MARK: - User Profile Cache

    /// Get cached user profile
    func getUserProfile() -> User? {
        guard let data = defaults.data(forKey: Keys.userProfile) else {
            return nil
        }

        do {
            return try decoder.decode(User.self, from: data)
        } catch {
            Logger.debug("[UserProfileLocalDS] Failed to decode user profile, clearing cache")
            clearUserProfile()
            return nil
        }
    }

    /// Save user profile to cache
    func saveUserProfile(_ profile: User) {
        do {
            let data = try encoder.encode(profile)
            defaults.set(data, forKey: Keys.userProfile)
            defaults.set(Date(), forKey: Keys.userProfile + Keys.timestampSuffix)
            Logger.debug("[UserProfileLocalDS] User profile saved to cache")
        } catch {
            Logger.error("[UserProfileLocalDS] Failed to encode user profile: \(error)")
        }
    }

    /// Check if user profile cache is expired
    func isUserProfileExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.userProfile + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.userProfile
    }

    /// Clear user profile cache
    func clearUserProfile() {
        defaults.removeObject(forKey: Keys.userProfile)
        defaults.removeObject(forKey: Keys.userProfile + Keys.timestampSuffix)
        Logger.debug("[UserProfileLocalDS] User profile cache cleared")
    }

    // MARK: - Targets Cache

    /// Get cached targets
    func getTargets() -> [Target]? {
        guard let data = defaults.data(forKey: Keys.targets) else {
            return nil
        }

        do {
            return try decoder.decode([Target].self, from: data)
        } catch {
            Logger.debug("[UserProfileLocalDS] Failed to decode targets, clearing cache")
            clearTargets()
            return nil
        }
    }

    /// Save targets to cache
    func saveTargets(_ targets: [Target]) {
        do {
            let data = try encoder.encode(targets)
            defaults.set(data, forKey: Keys.targets)
            defaults.set(Date(), forKey: Keys.targets + Keys.timestampSuffix)
            Logger.debug("[UserProfileLocalDS] Targets saved to cache")
        } catch {
            Logger.error("[UserProfileLocalDS] Failed to encode targets: \(error)")
        }
    }

    /// Check if targets cache is expired
    func isTargetsExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.targets + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.targets
    }

    /// Clear targets cache
    func clearTargets() {
        defaults.removeObject(forKey: Keys.targets)
        defaults.removeObject(forKey: Keys.targets + Keys.timestampSuffix)
        Logger.debug("[UserProfileLocalDS] Targets cache cleared")
    }

    // MARK: - Heart Rate Zones Cache

    /// Get cached heart rate zones
    func getHeartRateZones() -> [HeartRateZonesManager.HeartRateZone]? {
        guard let data = defaults.data(forKey: Keys.heartRateZones) else {
            return nil
        }

        do {
            // Decode zone data (stored as array of dictionaries)
            let zonesData = try decoder.decode([[String: Any]].self, from: data)
            return zonesData.compactMap { dict -> HeartRateZonesManager.HeartRateZone? in
                guard let zone = dict["zone"] as? Int,
                      let name = dict["name"] as? String,
                      let minHR = dict["minHR"] as? Double,
                      let maxHR = dict["maxHR"] as? Double,
                      let description = dict["description"] as? String else {
                    return nil
                }
                return HeartRateZonesManager.HeartRateZone(
                    zone: zone,
                    name: name,
                    range: minHR...maxHR,
                    description: description,
                    benefit: dict["benefit"] as? String ?? ""
                )
            }
        } catch {
            Logger.debug("[UserProfileLocalDS] Failed to decode HR zones, returning nil")
            return nil
        }
    }

    /// Save heart rate zones to cache
    func saveHeartRateZones(_ zones: [HeartRateZonesManager.HeartRateZone]) {
        let zonesData = zones.map { zone -> [String: Any] in
            [
                "zone": zone.zone,
                "name": zone.name,
                "minHR": zone.range.lowerBound,
                "maxHR": zone.range.upperBound,
                "description": zone.description,
                "benefit": zone.benefit
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: zonesData)
            defaults.set(data, forKey: Keys.heartRateZones)
            defaults.set(Date(), forKey: Keys.heartRateZones + Keys.timestampSuffix)
            Logger.debug("[UserProfileLocalDS] Heart rate zones saved to cache")
        } catch {
            Logger.error("[UserProfileLocalDS] Failed to encode HR zones: \(error)")
        }
    }

    /// Check if heart rate zones cache is expired
    func isHeartRateZonesExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.heartRateZones + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.heartRateZones
    }

    /// Clear heart rate zones cache
    func clearHeartRateZones() {
        defaults.removeObject(forKey: Keys.heartRateZones)
        defaults.removeObject(forKey: Keys.heartRateZones + Keys.timestampSuffix)
        Logger.debug("[UserProfileLocalDS] Heart rate zones cache cleared")
    }

    // MARK: - Clear All

    /// Clear all cached data
    func clearAll() {
        clearUserProfile()
        clearTargets()
        clearHeartRateZones()
        Logger.debug("[UserProfileLocalDS] All caches cleared")
    }

    // MARK: - Cache Size

    /// Get total cache size in bytes (approximate)
    func getCacheSize() -> Int {
        var size = 0
        if let data = defaults.data(forKey: Keys.userProfile) {
            size += data.count
        }
        if let data = defaults.data(forKey: Keys.targets) {
            size += data.count
        }
        if let data = defaults.data(forKey: Keys.heartRateZones) {
            size += data.count
        }
        return size
    }
}

// MARK: - Helper Extension for JSONDecoder
private extension JSONDecoder {
    func decode(_ type: [[String: Any]].Type, from data: Data) throws -> [[String: Any]] {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw DecodingError.typeMismatch(
                [[String: Any]].self,
                DecodingError.Context(codingPath: [], debugDescription: "Expected array of dictionaries")
            )
        }
        return array
    }
}
