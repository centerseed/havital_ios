import Foundation

// MARK: - Onboarding Repository Implementation
/// Implements onboarding state management operations
/// Responsible for managing user onboarding flow and state
/// Wraps Backend API calls for onboarding operations
final class OnboardingRepositoryImpl: OnboardingRepository {

    // MARK: - Dependencies

    private let firebaseAuth: FirebaseAuthDataSource
    private let backendAuth: BackendAuthDataSource
    private let authCache: AuthCache

    // MARK: - Initialization

    init(
        firebaseAuth: FirebaseAuthDataSource,
        backendAuth: BackendAuthDataSource,
        authCache: AuthCache
    ) {
        self.firebaseAuth = firebaseAuth
        self.backendAuth = backendAuth
        self.authCache = authCache
    }

    // MARK: - Onboarding State Operations

    /// Get current onboarding status for user
    /// Fetches from backend API
    func getOnboardingStatus() async throws -> OnboardingMode {
        do {
            // Get current user UID
            guard let firebaseUser = firebaseAuth.getCurrentUser() else {
                Logger.error("[Onboarding] No Firebase user session found")
                throw AuthenticationError.userNotFound
            }

            Logger.debug("[Onboarding] Fetching onboarding status for: \(firebaseUser.uid)")

            // Fetch onboarding status from backend
            let statusDTO = try await backendAuth.getOnboardingStatus(uid: firebaseUser.uid)

            // Convert DTO to Domain OnboardingMode
            let onboardingMode = statusDTO.toOnboardingMode()

            Logger.debug("[Onboarding] Status fetched: \(onboardingMode)")
            return onboardingMode

        } catch let error as AuthenticationError {
            Logger.error("[Onboarding] Failed to get status: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[Onboarding] Unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    /// Mark onboarding as completed
    /// Updates backend and clears cache to force refresh
    func completeOnboarding() async throws {
        do {
            // Get current user UID
            guard let firebaseUser = firebaseAuth.getCurrentUser() else {
                Logger.error("[Onboarding] No Firebase user session found")
                throw AuthenticationError.userNotFound
            }

            Logger.debug("[Onboarding] Completing onboarding for: \(firebaseUser.uid)")

            // Mark as completed in backend
            try await backendAuth.completeOnboarding(uid: firebaseUser.uid, data: nil)

            // Clear cache to force fresh fetch on next getCurrentUser()
            authCache.clearCache()

            Logger.debug("[Onboarding] Onboarding completed successfully")

        } catch let error as AuthenticationError {
            Logger.error("[Onboarding] Failed to complete: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[Onboarding] Unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    /// Start re-onboarding flow
    /// Allows existing users to update their profile
    func startReonboarding() async throws {
        do {
            // Get current user UID
            guard let firebaseUser = firebaseAuth.getCurrentUser() else {
                Logger.error("[Onboarding] No Firebase user session found")
                throw AuthenticationError.userNotFound
            }

            Logger.debug("[Onboarding] Starting re-onboarding for: \(firebaseUser.uid)")

            // TODO: Call backend API to set reonboarding mode
            // For now, just clear cache to force refresh
            authCache.clearCache()

            Logger.debug("[Onboarding] Re-onboarding started")

        } catch let error as AuthenticationError {
            Logger.error("[Onboarding] Failed to start re-onboarding: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[Onboarding] Unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    /// Reset onboarding state (admin/debug use)
    /// Forces user back to onboarding flow
    func resetOnboarding() async throws {
        do {
            // Get current user UID
            guard let firebaseUser = firebaseAuth.getCurrentUser() else {
                Logger.error("[Onboarding] No Firebase user session found")
                throw AuthenticationError.userNotFound
            }

            Logger.debug("[Onboarding] Resetting onboarding for: \(firebaseUser.uid)")

            // Reset in backend
            try await backendAuth.resetOnboarding(uid: firebaseUser.uid)

            // Clear cache to force fresh fetch
            authCache.clearCache()

            Logger.debug("[Onboarding] Onboarding reset successfully")

        } catch let error as AuthenticationError {
            Logger.error("[Onboarding] Failed to reset: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[Onboarding] Unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }
}
