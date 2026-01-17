//
//  OnboardingFeatureViewModel.swift
//  Havital
//
//  Onboarding Feature ViewModel
//  Presentation Layer - Handles all onboarding step operations using Clean Architecture
//
//  This ViewModel orchestrates the entire onboarding flow by composing
//  existing repositories (UserProfile, Target, TrainingPlan).
//

import SwiftUI
import Combine

// MARK: - Onboarding Feature ViewModel
/// Unified ViewModel for the entire onboarding flow
/// Uses Clean Architecture principles with Repository dependencies
@MainActor
final class OnboardingFeatureViewModel: ObservableObject {

    // MARK: - Dependencies

    private let userProfileRepository: UserProfileRepository
    private let targetRepository: TargetRepository
    private let trainingPlanRepository: TrainingPlanRepository

    // MARK: - Shared State (across all steps)

    /// Target race distance in km
    @Published var targetDistance: Double = 21.0975

    /// Whether this is a beginner 5K plan
    @Published var isBeginner: Bool = false

    // MARK: - Personal Best State

    @Published var personalBestHours: Int = 0
    @Published var personalBestMinutes: Int = 0
    @Published var personalBestSeconds: Int = 0
    @Published var selectedPBDistance: String = "5"
    @Published var hasPersonalBest: Bool = true
    @Published var availablePersonalBests: [String: [PersonalBestRecordV2]] = [:]
    @Published var selectedPersonalBestKey: String?

    /// Computed pace based on personal best time and distance
    var currentPace: String {
        guard hasPersonalBest else { return "" }
        let totalSeconds = personalBestHours * 3600 + personalBestMinutes * 60 + personalBestSeconds
        guard totalSeconds > 0 else { return "" }

        let distanceKm = Double(selectedPBDistance) ?? 5.0
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }

    // MARK: - Weekly Distance State

    @Published var weeklyDistance: Double = 10.0
    @Published var isLoadingWeeklyHistory: Bool = false

    // MARK: - Goal Type State

    @Published var selectedGoalType: GoalType?

    // MARK: - Training Days State

    @Published var selectedWeekdays: Set<Int> = []
    @Published var selectedLongRunDay: Int = 6

    // MARK: - Training Overview State

    @Published var trainingOverview: TrainingPlanOverview?

    // MARK: - UI State

    @Published var isLoading: Bool = false
    @Published var isLoadingPreferences: Bool = false  // Separate state for loading preferences (no fullScreenCover)
    @Published var error: String?

    // MARK: - Available Distances for Personal Best

    let availablePBDistances: [String: String] = [
        "3": NSLocalizedString("distance.3k", comment: "3K"),
        "5": NSLocalizedString("distance.5k", comment: "5K"),
        "10": NSLocalizedString("distance.10k", comment: "10K"),
        "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
        "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
    ]

    // MARK: - Initialization

    init(
        userProfileRepository: UserProfileRepository,
        targetRepository: TargetRepository,
        trainingPlanRepository: TrainingPlanRepository
    ) {
        self.userProfileRepository = userProfileRepository
        self.targetRepository = targetRepository
        self.trainingPlanRepository = trainingPlanRepository

        Logger.debug("[OnboardingFeatureVM] Initialized with repositories")
    }

    /// Convenience initializer for DI
    convenience init() {
        let container = DependencyContainer.shared
        self.init(
            userProfileRepository: container.resolve(),
            targetRepository: container.resolve(),
            trainingPlanRepository: container.resolve()
        )
    }

    // MARK: - Personal Best Methods

    /// Load existing personal bests from user profile
    func loadPersonalBests() async {
        Logger.debug("[OnboardingFeatureVM] Loading personal bests")

        do {
            let user = try await userProfileRepository.getUserProfile()

            if let personalBestV2 = user.personalBestV2,
               let raceRunData = personalBestV2["race_run"] {
                self.availablePersonalBests = raceRunData
                Logger.debug("[OnboardingFeatureVM] Loaded \(raceRunData.count) PB distances")
            }
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load PBs: \(error.localizedDescription)")
            // Don't show error - new users may not have PBs
        }
    }

    /// Select an existing personal best
    func selectPersonalBest(distanceKey: String) {
        guard let records = availablePersonalBests[distanceKey],
              let bestRecord = records.first else { return }

        let normalizedDistance = normalizeDistanceKey(distanceKey)
        selectedPBDistance = normalizedDistance
        selectedPersonalBestKey = distanceKey

        let totalSeconds = bestRecord.completeTime
        personalBestHours = totalSeconds / 3600
        personalBestMinutes = (totalSeconds % 3600) / 60
        personalBestSeconds = totalSeconds % 60

        Logger.debug("[OnboardingFeatureVM] Selected PB: \(distanceKey)km, time: \(bestRecord.formattedTime())")
    }

    /// Update personal best data
    func updatePersonalBest() async -> Bool {
        isLoading = true
        error = nil

        do {
            if hasPersonalBest {
                let totalSeconds = personalBestHours * 3600 + personalBestMinutes * 60 + personalBestSeconds
                guard totalSeconds > 0 else {
                    error = NSLocalizedString("onboarding.enter_valid_time", comment: "Enter Valid Time")
                    isLoading = false
                    return false
                }

                let normalizedDistance = normalizeDistance(selectedPBDistance)
                try await userProfileRepository.updatePersonalBest(
                    distanceKm: normalizedDistance,
                    completeTime: totalSeconds
                )

                Logger.debug("[OnboardingFeatureVM] Personal best updated successfully")
            } else {
                Logger.debug("[OnboardingFeatureVM] User has no PB, skipping update")
            }

            // Save hasPersonalBest state for later navigation logic
            UserDefaults.standard.set(hasPersonalBest, forKey: "onboarding_hasPersonalBest")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Weekly Distance Methods

    /// Load historical weekly distance from summaries
    func loadHistoricalWeeklyDistance() async {
        isLoadingWeeklyHistory = true

        do {
            // Use WeeklySummaryService for now (peripheral service, not user data)
            let summaries = try await WeeklySummaryService.shared.fetchAllWeeklyVolumes(limit: 8)

            if !summaries.isEmpty {
                let recentWeeks = summaries.suffix(4)
                let distances = recentWeeks.compactMap { $0.distanceKm }.filter { $0 > 0 }

                if !distances.isEmpty {
                    let average = distances.reduce(0, +) / Double(distances.count)
                    weeklyDistance = min(max(average, 5.0), 30.0)
                    Logger.debug("[OnboardingFeatureVM] Calculated weekly distance: \(weeklyDistance)km")
                }
            }
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load weekly history: \(error.localizedDescription)")
            // Keep default value on error
        }

        isLoadingWeeklyHistory = false
    }

    /// Save weekly distance to user profile
    func saveWeeklyDistance() async -> Bool {
        isLoading = true
        error = nil

        do {
            let weeklyDistanceInt = Int(weeklyDistance.rounded())
            let updates: [String: Any] = ["current_week_distance": weeklyDistanceInt]

            _ = try await userProfileRepository.updateUserProfile(updates)
            Logger.debug("[OnboardingFeatureVM] Weekly distance saved: \(weeklyDistanceInt)km")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Determine next step after weekly distance based on user data
    func determineNextStepAfterWeeklyDistance() -> OnboardingCoordinator.Step {
        let hasPersonalBest = UserDefaults.standard.bool(forKey: "onboarding_hasPersonalBest")
        let weeklyDistanceInt = Int(weeklyDistance.rounded())

        if !hasPersonalBest && weeklyDistanceInt == 0 {
            return .goalType
        } else {
            return .raceSetup
        }
    }

    // MARK: - Goal Type Methods

    /// Create beginner 5K goal
    func createBeginner5kGoal() async -> Bool {
        isLoading = true
        error = nil

        do {
            let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date()) ?? Date()
            let target = Target(
                id: UUID().uuidString,
                type: "race_run",
                name: NSLocalizedString("onboarding.beginner_5k_goal", comment: "Can run 5km"),
                distanceKm: 5,
                targetTime: 40 * 60,
                targetPace: "8:00",
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: 4
            )

            _ = try await targetRepository.createTarget(target)
            isBeginner = true
            Logger.debug("[OnboardingFeatureVM] Beginner 5K goal created")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Training Days Methods

    /// Load user's training day preferences
    func loadTrainingDayPreferences() async {
        // ✅ Use separate loading state to avoid triggering fullScreenCover
        // This loading is fast (reads from cache) and doesn't need a full-screen loading animation
        isLoadingPreferences = true

        do {
            let user = try await userProfileRepository.getUserProfile()

            if let weekdayPreferences = user.preferWeekDays, !weekdayPreferences.isEmpty {
                selectedWeekdays = Set(weekdayPreferences)
                Logger.debug("[OnboardingFeatureVM] Loaded training days: \(weekdayPreferences)")
            }

            if let longrunDays = user.preferWeekDaysLongrun,
               let longrunDay = longrunDays.first {
                selectedLongRunDay = longrunDay
                Logger.debug("[OnboardingFeatureVM] Loaded long run day: \(longrunDay)")
            } else if !selectedWeekdays.isEmpty {
                selectedLongRunDay = selectedWeekdays.contains(6) ? 6 : (selectedWeekdays.sorted().first ?? 6)
            }
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load training days: \(error.localizedDescription)")
        }

        isLoadingPreferences = false
    }

    /// Save training day preferences and generate overview
    func saveTrainingDaysAndGenerateOverview(startFromStage: String?) async -> Bool {
        guard !selectedWeekdays.isEmpty else {
            error = NSLocalizedString("onboarding.select_at_least_one_day", comment: "Select at least one day")
            return false
        }

        guard selectedWeekdays.contains(selectedLongRunDay) else {
            error = NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")
            return false
        }

        isLoading = true
        error = nil

        do {
            // Update user preferences
            let preferences: [String: Any] = [
                "prefer_week_days": Array(selectedWeekdays),
                "prefer_week_days_longrun": [selectedLongRunDay]
            ]
            _ = try await userProfileRepository.updateUserProfile(preferences)

            // Generate training plan overview
            let overview = try await trainingPlanRepository.createOverview(
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            trainingOverview = overview
            Logger.debug("[OnboardingFeatureVM] Training overview created: \(overview.id)")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Target Management Methods

    /// Update an existing target
    func updateTarget(id: String, target: Target) async throws {
        Logger.debug("[OnboardingFeatureVM] Updating target: \(id)")
        _ = try await targetRepository.updateTarget(id: id, target: target)
    }

    /// Get all targets
    func getTargets() async throws -> [Target] {
        Logger.debug("[OnboardingFeatureVM] Getting all targets")
        return try await targetRepository.getTargets()
    }

    /// Delete a target
    func deleteTarget(id: String) async throws {
        Logger.debug("[OnboardingFeatureVM] Deleting target: \(id)")
        try await targetRepository.deleteTarget(id: id)
    }

    /// Create a new target
    func createTarget(_ target: Target) async throws {
        Logger.debug("[OnboardingFeatureVM] Creating target: \(target.name)")
        _ = try await targetRepository.createTarget(target)
    }

    // MARK: - Training Overview Methods

    /// Load training overview
    func loadTrainingOverview() async {
        isLoading = true
        error = nil

        do {
            let overview = try await trainingPlanRepository.getOverview()
            trainingOverview = overview
            Logger.debug("[OnboardingFeatureVM] Training overview loaded: \(overview.id)")
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load target pace from main race
    func loadTargetPace() async -> String {
        guard let overview = trainingOverview, !overview.mainRaceId.isEmpty else {
            return "6:00"
        }

        do {
            let mainRace = try await targetRepository.getTarget(id: overview.mainRaceId)
            return mainRace.targetPace
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load target pace: \(error.localizedDescription)")
            return "6:00"
        }
    }

    /// Complete onboarding by creating weekly plan
    func completeOnboarding(startFromStage: String?) async -> Bool {
        isLoading = true
        error = nil

        do {
            _ = try await trainingPlanRepository.createWeeklyPlan(
                week: nil,
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            Logger.debug("[OnboardingFeatureVM] Weekly plan created, onboarding complete")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Private Helpers

    private func normalizeDistanceKey(_ key: String) -> String {
        switch key {
        case "21": return "21.0975"
        case "42": return "42.195"
        default: return key
        }
    }

    private func normalizeDistance(_ distanceStr: String) -> Double {
        let distance = Double(distanceStr) ?? 0.0
        if distance == 21 { return 21.0975 }
        if distance == 42 { return 42.195 }
        return distance
    }
}

// MARK: - DependencyContainer Extension
extension DependencyContainer {

    /// Create OnboardingFeatureViewModel with dependencies resolved from container
    @MainActor
    func makeOnboardingFeatureViewModel() -> OnboardingFeatureViewModel {
        // Ensure modules are registered
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        if !isRegistered(TargetRepository.self) {
            registerTargetModule()
        }
        if !isRegistered(TrainingPlanRepository.self) {
            registerTrainingPlanModule()
        }

        return OnboardingFeatureViewModel(
            userProfileRepository: resolve(),
            targetRepository: resolve(),
            trainingPlanRepository: resolve()
        )
    }
}
