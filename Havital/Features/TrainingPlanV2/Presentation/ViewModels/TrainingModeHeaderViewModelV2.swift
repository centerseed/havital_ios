import Foundation
import Combine
import Observation

// MARK: - TrainingMode
/// Represents the two non-race training modes.
enum TrainingMode {
    case starter    // beginner target type
    case maintain   // maintenance target type
}

// MARK: - TrainingModeHeaderViewModelV2
/// Composite ViewModel for the Starter / Maintenance Mode Header (B3).
///
/// Depends on:
///   - WeeklyPlanLoader  (mode determination, current week)
///   - MonthlyStatsRepository  (streak days, monthly km)
///   - TrainingReadinessViewModel  (readiness score)
///
/// All published properties are nil-safe — missing data hides the corresponding
/// section rather than crashing.
@MainActor
final class TrainingModeHeaderViewModelV2: ObservableObject {

    // MARK: - Published State

    /// The training mode (starter or maintain) — drives chip colour + tagline
    @Published private(set) var mode: TrainingMode = .starter

    /// Current training week number
    @Published private(set) var currentWeek: Int?

    /// Consecutive days with a workout up to today
    @Published private(set) var streakDays: Int?

    /// Sum of DailyStat.totalDistanceKm for the current calendar month
    @Published private(set) var monthlyKm: Double?

    /// Overall readiness score (nil when no data)
    @Published private(set) var readinessScore: Int?

    /// Readiness score as a progress value [0, 1]
    var readinessProgress: Double {
        guard let score = readinessScore else { return 0 }
        return min(max(Double(score) / 100.0, 0), 1)
    }

    // MARK: - Dependencies

    private let loader: WeeklyPlanLoader
    private let monthlyStatsRepository: MonthlyStatsRepository
    private let readinessVM: TrainingReadinessViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        loader: WeeklyPlanLoader,
        monthlyStatsRepository: MonthlyStatsRepository,
        readinessVM: TrainingReadinessViewModel
    ) {
        self.loader = loader
        self.monthlyStatsRepository = monthlyStatsRepository
        self.readinessVM = readinessVM
        setupObservers()
        refresh()
    }

    // MARK: - Observation

    private func setupObservers() {
        readinessVM.$readinessData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    // MARK: - Public Refresh

    /// Recompute synchronous derived state, then kick off async stats fetch.
    func refresh() {
        updateSyncState()
        Task { await fetchMonthlyStats() }
    }

    // MARK: - Synchronous Derivation

    private func updateSyncState() {
        // mode
        let overview = loader.planOverview
        mode = (overview?.isBeginnerTarget == true) ? .starter : .maintain

        // current week
        if case .ready(let plan) = loader.planStatus {
            currentWeek = plan.effectiveWeek
        } else {
            currentWeek = loader.currentWeek
        }

        // readiness
        if let score = readinessVM.overallScore {
            readinessScore = Int(score.rounded())
        } else {
            readinessScore = nil
        }
    }

    // MARK: - Async Monthly Stats

    private func fetchMonthlyStats() async {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            let stats = try await tracked("TrainingModeHeaderViewModelV2: loadMonthlyStats") {
                try await monthlyStatsRepository.getMonthlyStats(year: year, month: month)
            }

            // Monthly km — sum of all DailyStat.totalDistanceKm in this month
            let totalKm = stats.reduce(0.0) { $0 + $1.totalDistanceKm }
            monthlyKm = totalKm > 0 ? (totalKm * 10).rounded() / 10 : 0

            // Streak — count consecutive days backwards from today that have a workout
            streakDays = computeStreak(from: stats, referenceDate: now)
        } catch {
            Logger.error("[TrainingModeHeaderViewModelV2] Failed to fetch monthly stats: \(error.localizedDescription)")
            monthlyKm = nil
            streakDays = nil
        }
    }

    // MARK: - Streak Algorithm

    /// Walk backwards from `referenceDate` counting consecutive days with
    /// `hasWorkout == true`.  If today has no workout yet, the streak counts
    /// from yesterday (i.e. current-day absence does NOT break a streak that
    /// was active through yesterday).
    private func computeStreak(from stats: [DailyStat], referenceDate: Date) -> Int {
        guard !stats.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        // Build a Set of dates that have a workout for O(1) lookups
        var workoutDates = Set<Date>()
        for stat in stats where stat.hasWorkout {
            if let date = stat.dateValue {
                workoutDates.insert(calendar.startOfDay(for: date))
            }
        }

        // If today has no workout, start counting from yesterday
        let startDay: Date = workoutDates.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var streak = 0
        var checkDay = startDay

        while workoutDates.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }

        return streak
    }
}

// MARK: - DependencyContainer Factory

extension DependencyContainer {
    @MainActor
    func makeTrainingModeHeaderViewModelV2(
        loader: WeeklyPlanLoader,
        readinessVM: TrainingReadinessViewModel
    ) -> TrainingModeHeaderViewModelV2 {
        let monthlyStatsRepo: MonthlyStatsRepository = resolve()
        return TrainingModeHeaderViewModelV2(
            loader: loader,
            monthlyStatsRepository: monthlyStatsRepo,
            readinessVM: readinessVM
        )
    }
}
