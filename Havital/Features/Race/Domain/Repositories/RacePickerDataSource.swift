//
//  RacePickerDataSource.swift
//  Havital
//
//  Protocol for ViewModels that supply data to RaceEventListView.
//  Domain Layer — no import of Data or Presentation.
//
//  Conforming types:
//    - OnboardingFeatureViewModel (onboarding flow)
//    - TargetEditRacePickerViewModel (target edit flow)
//

import Foundation

enum RacePickerDefaults {
    static func defaultRegion(timeZoneIdentifier: String?, localeIdentifier: String?) -> String {
        let timeZone = timeZoneIdentifier ?? ""
        let locale = (localeIdentifier ?? "").replacingOccurrences(of: "_", with: "-").lowercased()
        if timeZone == "Asia/Tokyo" || locale == "ja" || locale.hasPrefix("ja-") {
            return "jp"
        }
        return "tw"
    }

    @MainActor
    static var currentRegion: String {
        defaultRegion(
            timeZoneIdentifier: UserPreferencesManager.shared.timezonePreference ?? TimeZone.current.identifier,
            localeIdentifier: LanguageManager.shared.currentLanguage.apiCode
        )
    }
}

// MARK: - RacePickerDataSource

/// Abstraction layer that decouples RaceEventListView from
/// any specific ViewModel implementation.
@MainActor
protocol RacePickerDataSource: ObservableObject {
    /// Current loaded race events for display.
    var raceEvents: [RaceEvent] { get }

    /// Loading state flag — drives skeleton UI.
    var isLoadingRaces: Bool { get }

    /// Selected region ("tw" or "jp") — bound to the segmented picker.
    var selectedRegion: String { get set }

    /// Whether the race API responded successfully.
    /// false drives the degraded / error UI.
    var isRaceAPIAvailable: Bool { get }

    /// Optional race ID to preselect when the picker opens.
    /// OnboardingFeatureViewModel returns nil (no preselection needed).
    /// TargetEditRacePickerViewModel returns the initial raceId.
    var preselectedRaceId: String? { get }

    /// Fetch curated races for the current selectedRegion.
    func loadCuratedRaces() async

    /// Called when the user confirms a race + distance selection.
    func selectRaceEvent(_ event: RaceEvent, distance: RaceDistance)
}
