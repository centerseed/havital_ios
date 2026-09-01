import Combine
import SwiftUI

/// SPEC-app-appearance §4.2／R1：本機外觀偏好。不進 backend。
enum App2AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` = 跟隨系統（不覆寫 `preferredColorScheme`）。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return L10n.App2.Settings.appearanceSystem.localized
        case .light: return L10n.App2.Settings.appearanceLight.localized
        case .dark: return L10n.App2.Settings.appearanceDark.localized
        }
    }
}

@MainActor
final class App2AppearanceStore: ObservableObject {
    static let shared = App2AppearanceStore()
    static let defaultsKey = "app2.appearance.preference"

    @Published var preference: App2AppearancePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.defaultsKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        preference = App2AppearancePreference(rawValue: raw) ?? .system
    }
}
