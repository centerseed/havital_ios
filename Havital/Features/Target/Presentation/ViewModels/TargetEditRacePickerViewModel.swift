//
//  TargetEditRacePickerViewModel.swift
//  Havital
//
//  ViewModel for the race picker in the target edit flow.
//  Conforms to RacePickerDataSource so RaceEventListView can be reused.
//
//  Architecture:
//    - @MainActor, ObservableObject
//    - Depends on RaceRepository protocol (never RepositoryImpl)
//    - Dependencies resolved via DependencyContainer
//    - TaskManageable for safe async task lifecycle
//

import Foundation
import SwiftUI

// MARK: - TargetEditRacePickerViewModel

@MainActor
final class TargetEditRacePickerViewModel: ObservableObject, RacePickerDataSource, TaskManageable {

    // MARK: - TaskManageable

    let taskRegistry = TaskRegistry()

    deinit {
        cancelAllTasks()
    }

    // MARK: - RacePickerDataSource state

    @Published var raceEvents: [RaceEvent] = []
    @Published var isLoadingRaces: Bool = false
    @Published var selectedRegion: String = "tw"
    @Published var isRaceAPIAvailable: Bool = true

    // MARK: - Preselection

    /// The race_id of the target being edited.
    /// Used to highlight the matching card when the picker opens.
    let preselectedRaceId: String?

    // MARK: - Private

    private let raceRepository: RaceRepository
    private let onRaceSelected: (RaceEvent, RaceDistance) -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - initialRaceId: The race_id from the target being edited, or nil if target has none.
    ///   - raceRepository: Injected repository (defaults to DependencyContainer resolution).
    ///   - onRaceSelected: Callback fired when the user confirms a race + distance.
    init(
        initialRaceId: String?,
        raceRepository: RaceRepository = DependencyContainer.shared.resolve(),
        onRaceSelected: @escaping (RaceEvent, RaceDistance) -> Void
    ) {
        self.preselectedRaceId = initialRaceId
        self.raceRepository = raceRepository
        self.onRaceSelected = onRaceSelected
    }

    // MARK: - RacePickerDataSource methods

    /// Fetch curated races for the current region.
    /// After loading, if initialRaceId is set, the matching race will be
    /// identified via preselectedRaceId for UI highlighting.
    func loadCuratedRaces() async {
        guard !isLoadingRaces else { return }
        isLoadingRaces = true
        do {
            let events = try await raceRepository.getRaces(
                region: selectedRegion,
                distanceMin: nil,
                distanceMax: nil,
                dateFrom: nil,
                dateTo: nil,
                query: nil,
                curatedOnly: true,
                limit: 50,
                offset: nil
            )
            raceEvents = events
            isRaceAPIAvailable = true
            Logger.info("[TargetEditRacePickerVM] Loaded \(events.count) races, region=\(selectedRegion)")
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            // Intentional cancellation — do not update UI state
            Logger.debug("[TargetEditRacePickerVM] loadCuratedRaces cancelled")
        } catch {
            isRaceAPIAvailable = false
            raceEvents = []
            Logger.warn("[TargetEditRacePickerVM] Race API unavailable: \(error.localizedDescription)")
        }
        isLoadingRaces = false
    }

    /// Called when the user confirms a race + distance selection.
    /// Fires the callback so EditTargetViewModel can apply the selection.
    func selectRaceEvent(_ event: RaceEvent, distance: RaceDistance) {
        Logger.info("[TargetEditRacePickerVM] Selected: \(event.name), distance: \(distance.name)")
        onRaceSelected(event, distance)
    }
}
