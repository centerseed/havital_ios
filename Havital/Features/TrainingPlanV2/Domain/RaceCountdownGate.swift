import Foundation

// MARK: - Race Countdown Card Visibility

/// How the home race-countdown card decides whether to show.
/// Stored as a raw string in @AppStorage("raceCountdownMode").
enum RaceCountdownDisplayMode: String, CaseIterable {
    /// Show only within `daysBefore` days of the race (default behaviour, 42 days).
    case auto
    /// Always show (as long as there is an upcoming race).
    case always
    /// Never show (user hid it via long-press; restorable in settings).
    case off

    static let `default`: RaceCountdownDisplayMode = .auto

    init(rawValueOrDefault raw: String) {
        self = RaceCountdownDisplayMode(rawValue: raw) ?? .default
    }
}

/// Pure, UI-free decision for whether the race countdown card should be visible.
///
/// `daysLeft` must be recomputed from the CURRENT race date each time (it comes from
/// `RaceHeaderViewModelV2.daysLeft`, which derives from `loader.planOverview.raceDateValue`),
/// so editing the target race date or re-onboarding naturally re-drives this gate.
enum RaceCountdownGate {

    static let defaultDaysBefore = 42

    /// - Parameters:
    ///   - mode: user preference.
    ///   - daysBefore: threshold for `.auto` (days before the race to start showing).
    ///   - daysLeft: calendar days until the race; `nil` when there is no upcoming race date.
    static func shouldShow(mode: RaceCountdownDisplayMode, daysBefore: Int, daysLeft: Int?) -> Bool {
        // No upcoming race (no date, or already in the past with a negative value) → never show.
        guard let daysLeft, daysLeft >= 0 else { return false }
        switch mode {
        case .off:
            return false
        case .always:
            return true
        case .auto:
            return daysLeft <= max(0, daysBefore)
        }
    }
}
