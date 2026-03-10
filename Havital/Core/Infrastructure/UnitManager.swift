import Foundation
import SwiftUI

// MARK: - UnitSystem

enum UnitSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

    var displayName: String {
        switch self {
        case .metric:
            return L10n.Unit.metric.localized
        case .imperial:
            return L10n.Unit.imperial.localized
        }
    }

    var apiValue: String { rawValue }

    var distanceSuffix: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    var paceSuffix: String {
        switch self {
        case .metric: return "min/km"
        case .imperial: return "min/mi"
        }
    }
}

// MARK: - UnitManager

@MainActor
class UnitManager: ObservableObject {
    static let shared = UnitManager()

    private static let defaultsKey = "unit_system_preference"

    @Published var currentUnitSystem: UnitSystem {
        didSet {
            saveToDefaults()
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let system = UnitSystem(rawValue: saved) {
            self.currentUnitSystem = system
        } else {
            self.currentUnitSystem = .metric
        }
    }

    /// Format a distance value (in km) to a display string with unit suffix
    func formatDistance(_ km: Double) -> String {
        switch currentUnitSystem {
        case .metric:
            return String(format: "%.1f km", km)
        case .imperial:
            let miles = km * 0.621371
            return String(format: "%.1f mi", miles)
        }
    }

    func saveToDefaults() {
        UserDefaults.standard.set(currentUnitSystem.rawValue, forKey: Self.defaultsKey)
    }
}
