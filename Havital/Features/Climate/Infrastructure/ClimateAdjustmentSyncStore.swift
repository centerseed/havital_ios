import Foundation

enum ClimateAdjustmentSyncStore {
    static let key = "climateAdjustmentEnabled"

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: key)
    }

    static func read(defaults: UserDefaults = .standard) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    static func remove(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
