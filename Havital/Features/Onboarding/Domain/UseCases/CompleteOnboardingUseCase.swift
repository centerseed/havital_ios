//
//  CompleteOnboardingUseCase.swift
//  Havital
//
//  Complete Onboarding Use Case
//  Domain Layer - Orchestrates the final onboarding completion steps
//
//  This use case composes existing repositories (TrainingPlan, UserProfile)
//  to complete the onboarding flow. It does NOT create new repository abstractions,
//  following the principle of reusing existing Clean Architecture components.
//

import Foundation

// MARK: - Complete Onboarding Use Case
/// Orchestrates the final steps of onboarding completion
/// Domain Layer - Composes existing repositories for the completion flow
final class CompleteOnboardingUseCase {

    // MARK: - Dependencies

    private let trainingPlanRepository: TrainingPlanRepository

    // MARK: - Initialization

    init(trainingPlanRepository: TrainingPlanRepository) {
        self.trainingPlanRepository = trainingPlanRepository
    }

    // MARK: - Input

    struct Input {
        /// Starting stage for training (optional)
        let startFromStage: String?

        /// Whether this is a beginner 5K plan
        let isBeginner: Bool

        /// Whether this is a re-onboarding flow
        let isReonboarding: Bool
    }

    // MARK: - Output

    struct Output {
        /// The created weekly plan
        let weeklyPlan: WeeklyPlan

        /// Whether re-onboarding mode was active
        let wasReonboarding: Bool
    }

    // MARK: - Execute

    /// Execute the onboarding completion flow
    /// - Parameter input: Completion parameters
    /// - Returns: Output with created weekly plan
    /// - Throws: OnboardingError if any step fails
    func execute(input: Input) async throws -> Output {
        Logger.debug("[CompleteOnboardingUseCase] Starting completion flow")
        Logger.debug("[CompleteOnboardingUseCase] - startFromStage: \(input.startFromStage ?? "nil")")
        Logger.debug("[CompleteOnboardingUseCase] - isBeginner: \(input.isBeginner)")
        Logger.debug("[CompleteOnboardingUseCase] - isReonboarding: \(input.isReonboarding)")

        do {
            // Step 1: Create first week's training plan
            let weeklyPlan = try await createFirstWeekPlan(
                startFromStage: input.startFromStage,
                isBeginner: input.isBeginner
            )

            Logger.debug("[CompleteOnboardingUseCase] Successfully created weekly plan: \(weeklyPlan.id)")

            // Step 2: Update completion flags
            await updateCompletionFlags(isReonboarding: input.isReonboarding)

            // Step 3: Publish completion event via CacheEventBus
            await publishCompletionEvent()

            Logger.debug("[CompleteOnboardingUseCase] Onboarding completion flow finished successfully")

            return Output(
                weeklyPlan: weeklyPlan,
                wasReonboarding: input.isReonboarding
            )

        } catch let error as OnboardingError {
            Logger.error("[CompleteOnboardingUseCase] Failed with OnboardingError: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[CompleteOnboardingUseCase] Failed with unexpected error: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Create the first week's training plan
    private func createFirstWeekPlan(startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        Logger.debug("[CompleteOnboardingUseCase] Creating first week plan...")

        do {
            let weeklyPlan = try await trainingPlanRepository.createWeeklyPlan(
                week: nil, // First week
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            Logger.debug("[CompleteOnboardingUseCase] First week plan created: \(weeklyPlan.id)")
            return weeklyPlan

        } catch {
            Logger.error("[CompleteOnboardingUseCase] Failed to create weekly plan: \(error.localizedDescription)")
            throw OnboardingError.weeklyPlanCreationFailed(error.localizedDescription)
        }
    }

    /// Update completion flags based on onboarding mode
    private func updateCompletionFlags(isReonboarding: Bool) async {
        await MainActor.run {
            if isReonboarding {
                // Re-onboarding: Just close the mode
                // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                AuthenticationViewModel.shared.isReonboardingMode = false
                Logger.debug("[CompleteOnboardingUseCase] Re-onboarding mode closed")
            } else {
                // New user onboarding: Set global completion flags
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                AuthenticationViewModel.shared.hasCompletedOnboarding = true
                Logger.debug("[CompleteOnboardingUseCase] New user onboarding completion flags set")
            }
        }
    }

    /// Publish completion event to trigger cache clearing and UI refresh
    private func publishCompletionEvent() async {
        await MainActor.run {
            CacheEventBus.shared.publish(.onboardingCompleted)
            Logger.debug("[CompleteOnboardingUseCase] Published onboardingCompleted event via CacheEventBus")
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

        let trainingPlanRepository: TrainingPlanRepository = resolve()

        return CompleteOnboardingUseCase(
            trainingPlanRepository: trainingPlanRepository
        )
    }
}
