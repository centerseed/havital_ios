//
//  CompleteOnboardingUseCase.swift
//  Havital
//
//  Complete Onboarding Use Case
//  Domain Layer - Orchestrates the final onboarding completion steps
//
//  This use case composes existing repositories (TrainingPlan, TrainingPlanV2, UserProfile)
//  to complete the onboarding flow. Supports both V1 and V2 training flows.
//

import Foundation

// MARK: - Complete Onboarding Use Case
/// Orchestrates the final steps of onboarding completion
/// Domain Layer - Composes existing repositories for the completion flow
/// Supports both V1 (legacy) and V2 (new) training plan APIs
final class CompleteOnboardingUseCase {

    // MARK: - Dependencies

    private let trainingPlanRepository: TrainingPlanRepository
    private let trainingPlanV2Repository: TrainingPlanV2Repository

    // MARK: - Initialization

    init(
        trainingPlanRepository: TrainingPlanRepository,
        trainingPlanV2Repository: TrainingPlanV2Repository
    ) {
        self.trainingPlanRepository = trainingPlanRepository
        self.trainingPlanV2Repository = trainingPlanV2Repository
    }

    // MARK: - Input

    struct Input {
        /// Starting stage for training (optional)
        let startFromStage: String?

        /// Whether this is a beginner 5K plan (V1)
        let isBeginner: Bool

        /// Whether this is a re-onboarding flow
        let isReonboarding: Bool

        // MARK: - V2 Parameters

        /// Target type ID (V2) - e.g., "race_run", "beginner", "maintenance"
        let targetTypeId: String?

        /// Target ID for race_run type (V2)
        let targetId: String?

        /// Methodology ID (V2) - e.g., "paceriz", "norwegian"
        let methodologyId: String?

        /// Training weeks for non-race targets (V2)
        let trainingWeeks: Int?

        /// Available training days per week (V2)
        let availableDays: Int?

        /// Preview overview ID from onboarding UI.
        /// Local fallback previews use `local_preview_*` and need a real overview before weekly generation.
        let previewOverviewId: String?

        /// Intended race distance in km for maintenance/beginner flows where the user picked a target race distance upfront.
        /// Used when the UseCase has to rebuild a real overview (preview was `local_preview_*`).
        let intendedRaceDistanceKm: Int?

        /// Check if this is a V2 flow
        var isV2Flow: Bool {
            return targetTypeId != nil
        }
    }

    // MARK: - Output

    struct Output {
        /// The created weekly plan (V1) - nil for V2 flow
        let weeklyPlan: WeeklyPlan?

        /// The created weekly plan (V2) - nil for V1 flow
        let weeklyPlanV2: WeeklyPlanV2?

        /// Whether re-onboarding mode was active
        let wasReonboarding: Bool

        /// Whether V2 API was used
        let usedV2API: Bool
    }

    // MARK: - Execute

    /// Execute the onboarding completion flow
    /// - Parameter input: Completion parameters
    /// - Returns: Output with created weekly plan
    /// - Throws: OnboardingError if any step fails
    func execute(input: Input) async throws -> Output {
        Logger.debug("[CompleteOnboardingUseCase] Starting completion flow")
        Logger.debug("[CompleteOnboardingUseCase] - isV2Flow: \(input.isV2Flow)")
        Logger.debug("[CompleteOnboardingUseCase] - targetTypeId: \(input.targetTypeId ?? "nil")")
        Logger.debug("[CompleteOnboardingUseCase] - methodologyId: \(input.methodologyId ?? "nil")")
        Logger.debug("[CompleteOnboardingUseCase] - startFromStage: \(input.startFromStage ?? "nil")")
        Logger.debug("[CompleteOnboardingUseCase] - isBeginner: \(input.isBeginner)")
        Logger.debug("[CompleteOnboardingUseCase] - isReonboarding: \(input.isReonboarding)")

        do {
            let output: Output

            if input.isV2Flow {
                // V2 Flow: Use V2 API
                output = try await executeV2Flow(input: input)
            } else {
                // V1 Flow: Use legacy API
                output = try await executeV1Flow(input: input)
            }

            // Step 2: Update completion flags
            await updateCompletionFlags(isReonboarding: input.isReonboarding)

            Logger.debug("[CompleteOnboardingUseCase] Onboarding completion flow finished successfully")

            return output

        } catch let error as OnboardingError {
            Logger.error("[CompleteOnboardingUseCase] Failed with OnboardingError: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[CompleteOnboardingUseCase] Failed with unexpected error: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - V1 Flow (Legacy)

    private func executeV1Flow(input: Input) async throws -> Output {
        Logger.debug("[CompleteOnboardingUseCase] Executing V1 (legacy) flow...")

        let weeklyPlan = try await createFirstWeekPlanV1(
            startFromStage: input.startFromStage,
            isBeginner: input.isBeginner
        )

        Logger.debug("[CompleteOnboardingUseCase] V1 weekly plan created: \(weeklyPlan.id)")

        return Output(
            weeklyPlan: weeklyPlan,
            weeklyPlanV2: nil,
            wasReonboarding: input.isReonboarding,
            usedV2API: false
        )
    }

    // MARK: - V2 Flow

    private func executeV2Flow(input: Input) async throws -> Output {
        Logger.debug("[CompleteOnboardingUseCase] Executing V2 flow...")

        guard let targetTypeId = input.targetTypeId else {
            throw OnboardingError.weeklyPlanCreationFailed("Missing targetTypeId for V2 flow")
        }

        let needsRealOverview = input.previewOverviewId?.hasPrefix("local_preview_") ?? true
        let overview: PlanOverviewV2

        if needsRealOverview {
            Logger.debug("[CompleteOnboardingUseCase] Creating real V2 overview before weekly generation...")
            overview = try await createOverviewV2(input: input, targetTypeId: targetTypeId)
        } else {
            Logger.debug("[CompleteOnboardingUseCase] Reusing existing V2 overview: \(input.previewOverviewId ?? "nil")")
            overview = try await trainingPlanV2Repository.getOverview()
        }

        // Generate first week's plan
        let weeklyPlan = try await createFirstWeekPlanV2(methodologyId: input.methodologyId, overview: overview)
        Logger.debug("[CompleteOnboardingUseCase] V2 weekly plan created: \(weeklyPlan.id)")

        return Output(
            weeklyPlan: nil,
            weeklyPlanV2: weeklyPlan,
            wasReonboarding: input.isReonboarding,
            usedV2API: true
        )
    }

    // MARK: - Private Methods - V1

    /// Create the first week's training plan (V1)
    private func createFirstWeekPlanV1(startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        Logger.debug("[CompleteOnboardingUseCase] Creating V1 first week plan...")

        do {
            let weeklyPlan = try await trainingPlanRepository.createWeeklyPlan(
                week: nil, // First week
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            Logger.debug("[CompleteOnboardingUseCase] V1 First week plan created: \(weeklyPlan.id)")
            return weeklyPlan

        } catch {
            Logger.error("[CompleteOnboardingUseCase] Failed to create V1 weekly plan: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods - V2

    /// Create V2 Overview based on target type
    private func createOverviewV2(input: Input, targetTypeId: String) async throws -> PlanOverviewV2 {
        Logger.debug("[CompleteOnboardingUseCase] Creating V2 overview for targetType: \(targetTypeId)")

        do {
            if targetTypeId == "race_run" {
                // Race mode: requires targetId
                guard let targetId = input.targetId else {
                    throw OnboardingError.weeklyPlanCreationFailed("Missing targetId for race_run target type")
                }

                Logger.debug("[CompleteOnboardingUseCase] Creating race_run overview with targetId: \(targetId)")
                return try await trainingPlanV2Repository.createOverviewForRace(
                    targetId: targetId,
                    startFromStage: input.startFromStage,
                    methodologyId: input.methodologyId
                )
            } else {
                // Non-race mode: beginner or maintenance
                guard let trainingWeeks = input.trainingWeeks else {
                    throw OnboardingError.weeklyPlanCreationFailed("Missing trainingWeeks for non-race target type")
                }

                Logger.debug("[CompleteOnboardingUseCase] Creating \(targetTypeId) overview with \(trainingWeeks) weeks, methodology: \(input.methodologyId ?? "default"), intendedRaceDistanceKm: \(input.intendedRaceDistanceKm.map(String.init) ?? "nil")")
                return try await trainingPlanV2Repository.createOverviewForNonRace(
                    targetType: targetTypeId,
                    trainingWeeks: trainingWeeks,
                    availableDays: input.availableDays,
                    methodologyId: input.methodologyId,
                    startFromStage: input.startFromStage,
                    intendedRaceDistanceKm: input.intendedRaceDistanceKm
                )
            }
        } catch {
            Logger.error("[CompleteOnboardingUseCase] Failed to create V2 overview: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed("V2 Overview creation failed: \(error.localizedDescription)")
        }
    }

    /// Create the first week's training plan (V2)
    private func createFirstWeekPlanV2(methodologyId: String?, overview: PlanOverviewV2) async throws -> WeeklyPlanV2 {
        Logger.debug("[CompleteOnboardingUseCase] Creating V2 first week plan...")

        do {
            // Week 1 (1-based)
            let weeklyPlan = try await trainingPlanV2Repository.generateWeeklyPlan(
                weekOfTraining: 1,
                forceGenerate: false,
                promptVersion: nil,
                methodology: methodologyId
            )

            Logger.debug("[CompleteOnboardingUseCase] V2 First week plan created: \(weeklyPlan.id)")
            return weeklyPlan

        } catch {
            if shouldRetryWeeklyGenerationWithFallback(error: error, overview: overview) {
                Logger.warn("[CompleteOnboardingUseCase] Weekly generation failed with PlanExpander. Retrying fallback stages...")

                let fallbackStages = fallbackStartStages(for: overview)
                let fallbackMethodologyId = overview.methodologyId ?? methodologyId
                let originalStage = overview.startFromStage
                var lastRetryError: Error = error

                for fallbackStage in fallbackStages {
                    do {
                        Logger.warn("[CompleteOnboardingUseCase] Retrying weekly generation with start stage: \(fallbackStage)")
                        let updatedOverview = try await trainingPlanV2Repository.updateOverview(
                            overviewId: overview.id,
                            startFromStage: fallbackStage,
                            methodologyId: fallbackMethodologyId
                        )

                        let weeklyPlan = try await trainingPlanV2Repository.generateWeeklyPlan(
                            weekOfTraining: 1,
                            forceGenerate: false,
                            promptVersion: nil,
                            methodology: fallbackMethodologyId
                        )

                        Logger.warn(
                            "[CompleteOnboardingUseCase] Weekly generation recovered by switching start stage from \(overview.startFromStage ?? "nil") to \(updatedOverview.startFromStage ?? fallbackStage)"
                        )
                        return weeklyPlan
                    } catch {
                        lastRetryError = error
                        Logger.warn("[CompleteOnboardingUseCase] Retry with stage \(fallbackStage) failed: \(error.localizedDescription)")
                    }
                }

                Logger.error("[CompleteOnboardingUseCase] All fallback stages failed for overview \(overview.id). Attempting to revert startFromStage to original: \(originalStage ?? "nil")")
                // Best-effort revert: fallback 迴圈每次 updateOverview 都改寫了後端 overview。
                // 全部失敗時，若不還原，使用者下次回來後端 startFromStage 會卡在最後一次嘗試的值，
                // 不再反映他原本選擇。失敗不阻斷 error propagation。
                do {
                    _ = try await trainingPlanV2Repository.updateOverview(
                        overviewId: overview.id,
                        startFromStage: originalStage,
                        methodologyId: fallbackMethodologyId
                    )
                    Logger.warn("[CompleteOnboardingUseCase] Overview stage reverted to original: \(originalStage ?? "nil")")
                } catch {
                    Logger.error("[CompleteOnboardingUseCase] Failed to revert overview stage: \(error.localizedDescription). Overview \(overview.id) left at last attempted stage.")
                }
                throw OnboardingError.weeklyPlanCreationFailed("V2 Weekly plan creation failed: \(lastRetryError.localizedDescription)")
            }

            Logger.error("[CompleteOnboardingUseCase] Failed to create V2 weekly plan: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed("V2 Weekly plan creation failed: \(error.localizedDescription)")
        }
    }

    private func shouldRetryWeeklyGenerationWithFallback(error: Error, overview: PlanOverviewV2) -> Bool {
        guard overview.isRaceRunTarget else { return false }
        return error.localizedDescription.lowercased().contains("planexpander")
    }

    private func fallbackStartStages(for overview: PlanOverviewV2) -> [String] {
        let weeksRemaining = max(overview.totalWeeks, 1)
        let currentStage = overview.startFromStage

        let orderedStages: [TrainingStagePhase]
        if weeksRemaining <= 5 {
            orderedStages = [.peak, .build, .base]
        } else if weeksRemaining < 12 {
            orderedStages = [.build, .peak, .base]
        } else {
            orderedStages = [.base, .build, .peak]
        }

        return orderedStages
            .filter { TrainingPlanCalculator.isStageAvailable($0, weeksRemaining: weeksRemaining) }
            .map(\.apiIdentifier)
            .filter { $0 != currentStage }
    }

    // MARK: - Common Methods

    /// Update completion flags based on onboarding mode
    /// Note: This does NOT set isReonboardingMode
    /// OnboardingCoordinator is responsible for managing isReonboardingMode
    private func updateCompletionFlags(isReonboarding: Bool) async {
        if isReonboarding {
            // Re-onboarding: No need to update backend flags
            // OnboardingCoordinator will handle UI state (isReonboardingMode)
            Logger.debug("[CompleteOnboardingUseCase] Re-onboarding completion - no flags to update")
        } else {
            // New user onboarding: Set global completion flags
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                AuthenticationViewModel.shared.hasCompletedOnboarding = true
                Logger.debug("[CompleteOnboardingUseCase] New user onboarding completion flags set")
            }
        }
    }

}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// Create CompleteOnboardingUseCase with dependencies resolved from container
    func makeCompleteOnboardingUseCase() -> CompleteOnboardingUseCase {
        // Ensure TrainingPlan module is registered
        if !isRegistered(TrainingPlanRepository.self) {
            registerTrainingPlanModule()
        }

        // Ensure TrainingPlanV2 module is registered
        if !isRegistered(TrainingPlanV2Repository.self) {
            registerTrainingPlanV2Module()
        }

        let trainingPlanRepository: TrainingPlanRepository = resolve()
        let trainingPlanV2Repository: TrainingPlanV2Repository = resolve()

        return CompleteOnboardingUseCase(
            trainingPlanRepository: trainingPlanRepository,
            trainingPlanV2Repository: trainingPlanV2Repository
        )
    }
}
