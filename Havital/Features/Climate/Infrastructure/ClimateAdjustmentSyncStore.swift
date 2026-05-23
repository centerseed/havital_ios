import Foundation

enum ClimateAdjustmentSyncStore {
    static let key = "climateAdjustmentEnabled"

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: key)
    }
}
