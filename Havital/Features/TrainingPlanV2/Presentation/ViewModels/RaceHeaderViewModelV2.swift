import Foundation
import Combine
import Observation
import SwiftUI

// MARK: - RaceHeaderViewModelV2
/// Composite ViewModel for the Race Header (B2).
/// Aggregates data from WeeklyPlanLoader (planOverview) and
/// TrainingReadinessViewModel (readiness score, estimated time, week delta).
///
/// Depends on:
///   - WeeklyPlanLoader  (plan overview, race date, target time)
///   - TrainingReadinessViewModel  (overallScore, raceFitnessMetric, trendData)
///
/// All published properties are nil-safe; missing data hides the corresponding
/// sub-section rather than crashing.
@MainActor
final class RaceHeaderViewModelV2: ObservableObject {

    // MARK: - Published State

    /// Calendar days remaining until race (nil when race date unavailable)
    @Published private(set) var daysLeft: Int?

    /// Race / event name from planOverview.targetName
    @Published private(set) var raceTitle: String?

    /// Estimated finish time string from raceFitnessMetric.estimatedRaceTime (e.g. "2:01:32")
    @Published private(set) var estimatedFinish: String?

    /// Target finish time formatted from planOverview.targetTime (seconds) or targetPace
    @Published private(set) var targetFinish: String?

    /// Gap chip text — "達標範圍" when within 60 s, else "差 m:ss"
    @Published private(set) var gapText: String?

    /// Whether estimated time is within 60 s of target (controls chip colour)
    @Published private(set) var isOnTrack: Bool = false

    /// Readiness overall score as integer (nil when no data)
    @Published private(set) var readinessScore: Int?

    /// Week-over-week delta for display. Tuple of (symbol, magnitude, color).
    /// Returns nil when data is insufficient, anomalous, or too small to show.
    @Published private(set) var weekDeltaDisplay: (symbol: String, magnitude: Int, color: Color)?

    // MARK: - Dependencies

    private let loader: WeeklyPlanLoader
    private let readinessVM: TrainingReadinessViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(loader: WeeklyPlanLoader, readinessVM: TrainingReadinessViewModel) {
        self.loader = loader
        self.readinessVM = readinessVM
        setupObservers()
        refresh()
    }

    // MARK: - Observation

    /// Called once per ViewModel instance to wire reactive updates.
    private func setupObservers() {
        // Observe readiness data changes (ObservableObject → Combine bridge)
        readinessVM.$readinessData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    // MARK: - Derived State Computation

    /// Recompute all derived properties from current loader + readiness state.
    func refresh() {
        let overview = loader.planOverview

        // -- days left --
        if let raceDate = overview?.raceDateValue {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let raceDay = calendar.startOfDay(for: raceDate)
            let diff = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
            daysLeft = max(0, diff)
        } else {
            daysLeft = nil
        }

        // -- race title --
        raceTitle = overview?.targetName

        // -- estimated finish (from readiness) --
        estimatedFinish = readinessVM.estimatedRaceTime

        // -- target finish (from planOverview.targetTime in seconds) --
        if let seconds = overview?.targetTime, seconds > 0 {
            targetFinish = Self.formatSeconds(seconds)
        } else {
            targetFinish = nil
        }

        // -- gap chip --
        updateGapChip()

        // -- readiness score --
        if let score = readinessVM.overallScore {
            readinessScore = Int(score.rounded())
        } else {
            readinessScore = nil
        }

        // -- week delta --
        weekDeltaDisplay = computeWeekDeltaDisplay()
    }

    // MARK: - Gap Calculation

    private func updateGapChip() {
        guard let estimated = estimatedFinish, let target = targetFinish else {
            gapText = nil
            isOnTrack = false
            return
        }
        let estSec = Self.parseTimeString(estimated)
        let tgtSec = Self.parseTimeString(target)
        guard estSec > 0, tgtSec > 0 else {
            gapText = nil
            isOnTrack = false
            return
        }
        let diffSec = estSec - tgtSec
        if diffSec <= 60 {
            gapText = NSLocalizedString("training_plan.race_gap_within_target", comment: "")
            isOnTrack = true
        } else {
            let absMin = abs(diffSec) / 60
            let absSec = abs(diffSec) % 60
            let formatted = String(format: "%d:%02d", absMin, absSec)
            gapText = String(format: NSLocalizedString("training_plan.race_gap_diff", comment: ""), formatted)
            isOnTrack = false
        }
    }

    // MARK: - Week Delta Calculation

    /// Compute display delta using the most recent 2 trendData points.
    /// Uses raceFitness.trendData first; falls back to speed.trendData.
    ///
    /// Rules:
    /// - Uses last 2 values (not -8), so delta reflects the most recent step only.
    /// - Hides delta when magnitude == 0 or >= 50 (anomaly / no real signal).
    /// - If trendData.direction is present, uses it to resolve sign ambiguity.
    private func computeWeekDeltaDisplay() -> (symbol: String, magnitude: Int, color: Color)? {
        guard let trendData = readinessVM.raceFitnessMetric?.trendData
                           ?? readinessVM.speedMetric?.trendData else { return nil }

        guard let values = Optional(trendData.values), values.count >= 2 else { return nil }

        let latest = values[values.count - 1]
        let prev = values[values.count - 2]
        let delta = latest - prev
        let magnitude = Int(round(abs(delta)))

        // Hide: no meaningful change or anomaly
        if magnitude == 0 || magnitude > 50 { return nil }

        // Determine direction: prefer trendData.direction when available
        let goingUp: Bool
        let dir = trendData.directionType
        if dir == .up {
            goingUp = true
        } else if dir == .down {
            goingUp = false
        } else {
            // stable or ambiguous — use raw delta sign
            goingUp = delta > 0
        }

        let symbol: String = goingUp ? "↗" : "↘"
        let color: Color = goingUp
            ? Color(red: 0.651, green: 0.851, blue: 0.722)  // #A6D9B8
            : Color(red: 1.0, green: 0.690, blue: 0.533)    // #FFB088
        return (symbol, magnitude, color)
    }

    // MARK: - Time Formatting Helpers

    /// Parse "H:MM:SS" or "M:SS" strings into total seconds.
    private static func parseTimeString(_ s: String) -> Int {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return 0
        }
    }

    /// Format total seconds into "H:MM:SS" (or "M:SS" when under 1 hour).
    static func formatSeconds(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - DependencyContainer Factory

extension DependencyContainer {
    @MainActor
    func makeRaceHeaderViewModelV2(
        loader: WeeklyPlanLoader,
        readinessVM: TrainingReadinessViewModel
    ) -> RaceHeaderViewModelV2 {
        RaceHeaderViewModelV2(loader: loader, readinessVM: readinessVM)
    }
}
