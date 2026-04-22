import Foundation
import SwiftUI

@MainActor
class BaseSupportingTargetViewModel: ObservableObject {
    @Published var raceName = "" {
        didSet {
            if !isApplyingRaceSelection {
                clearRaceSelection()
            }
        }
    }
    @Published var raceDate = Date()
    @Published var selectedDistance = "21.0975" { // 預設半馬
        didSet {
            if !isApplyingRaceSelection {
                clearRaceSelection()
            }
        }
    }
    @Published var targetHours = 2
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?

    /// race_id from the race database. nil means the target was manually entered.
    @Published var raceId: String?

    /// Flag to suppress auto-clear during programmatic applyRaceSelection calls.
    var isApplyingRaceSelection = false

    var availableDistances: [String: String] {
        [
            "3": L10n.EditTarget.distance3k.localized,
            "5": L10n.EditTarget.distance5k.localized,
            "10": L10n.EditTarget.distance10k.localized,
            "15": L10n.EditTarget.distance15k.localized,
            "21.0975": L10n.EditTarget.distanceHalf.localized,
            "42.195": L10n.EditTarget.distanceFull.localized
        ]
    }

    var remainingWeeks: Int {
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear],
                                          from: Date(),
                                          to: raceDate).weekOfYear ?? 0
        return max(weeks, 1) // 至少返回1週
    }

    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 21.0975
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }

    // MARK: - Race Database Integration

    /// Apply a race selection from the race picker.
    /// Sets raceId, raceName, raceDate, selectedDistance without triggering auto-clear.
    func applyRaceSelection(_ event: RaceEvent, distance: RaceDistance) {
        isApplyingRaceSelection = true
        defer { isApplyingRaceSelection = false }

        raceId = event.raceId
        raceName = event.name
        raceDate = event.eventDate
        selectedDistance = normalizeDistanceForPicker(distance.distanceKm)

        Logger.info("[BaseSupportingTargetVM] Applied race selection: \(event.name), raceId=\(event.raceId), distance=\(distance.name)")
    }

    /// Clear the race database binding.
    /// Called automatically when raceName or selectedDistance is manually edited.
    func clearRaceSelection() {
        guard raceId != nil else { return }
        raceId = nil
        Logger.debug("[BaseSupportingTargetVM] Cleared raceId (manual edit detected)")
    }

    // MARK: - Target Object Creation

    /// Create the base Target object for persistence, including raceId.
    func createTargetObject(id: String) -> Target {
        return Target(
            id: id,
            type: "race_run",
            name: raceName,
            distanceKm: Int(Double(selectedDistance) ?? 21.0975),
            targetTime: targetHours * 3600 + targetMinutes * 60,
            targetPace: targetPace,
            raceDate: Int(raceDate.timeIntervalSince1970),
            isMainRace: false, // 設為支援賽事
            trainingWeeks: remainingWeeks,
            raceId: raceId   // 帶入 race_id（手動輸入時為 nil）
        )
    }

    // MARK: - Private Helpers

    private func normalizeDistanceForPicker(_ distanceKm: Double) -> String {
        let intKm = Int(distanceKm)
        switch intKm {
        case 3:  return "3"
        case 5:  return "5"
        case 10: return "10"
        case 15: return "15"
        case 21: return "21.0975"
        case 42: return "42.195"
        default: return String(format: "%.4g", distanceKm)
        }
    }
}
