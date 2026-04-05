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

    /// 轉換距離數字（不帶單位字串）
    func convertedDistance(_ km: Double) -> Double {
        switch currentUnitSystem {
        case .metric: return km
        case .imperial: return km * 0.621371
        }
    }

    /// 格式化配速（輸入：秒/km，輸出：含單位的配速字串如 "5:30 /km" 或 "8:51 /mi"）
    func formatPace(secondsPerKm: Double) -> String {
        let converted: Double
        switch currentUnitSystem {
        case .metric: converted = secondsPerKm
        case .imperial: converted = secondsPerKm * 1.60934
        }
        let minutes = Int(converted) / 60
        let seconds = Int(converted) % 60
        return String(format: "%d:%02d %@", minutes, seconds, currentUnitSystem.paceSuffix)
    }

    /// 格式化配速（輸入："mm:ss" 字串，輸出：含單位如 "5:30/km"）
    func formatPaceString(_ pace: String?) -> String {
        guard let pace = pace else {
            return "--:--/\(currentUnitSystem.distanceSuffix)"
        }
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return pace }
        let totalSeconds = Double(components[0] * 60 + components[1])
        return formatPace(secondsPerKm: totalSeconds)
    }

    func saveToDefaults() {
        UserDefaults.standard.set(currentUnitSystem.rawValue, forKey: Self.defaultsKey)
    }
}
