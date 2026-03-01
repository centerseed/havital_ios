import Foundation

// MARK: - Onboarding Repository Protocol
/// Defines onboarding state management operations
/// Domain Layer - only defines interface, no implementation details
/// Responsible for managing user onboarding flow and state
/// Separated from AuthRepository for Single Responsibility Principle
protocol OnboardingRepository {

    // MARK: - Onboarding State Operations

    /// Get current onboarding status for user
    /// - Returns: Current onboarding mode and completion state
    /// - Throws: AuthenticationError if status cannot be retrieved
    func getOnboardingStatus() async throws -> OnboardingMode

    /// Mark onboarding as completed
    /// Called after user finishes initial setup or re-onboarding
    /// Updates backend and local cache
    /// - Throws: AuthenticationError if completion fails
    func completeOnboarding() async throws

    /// Start re-onboarding flow
    /// Allows existing users to update their profile
    /// Sets onboardingMode to .reonboarding
    /// - Throws: AuthenticationError if reonboarding cannot be started
    func startReonboarding() async throws

    /// Reset onboarding state (admin/debug use)
    /// Clears onboarding completion status
    /// Forces user back to onboarding flow
    /// - Throws: AuthenticationError if reset fails
    func resetOnboarding() async throws
}
