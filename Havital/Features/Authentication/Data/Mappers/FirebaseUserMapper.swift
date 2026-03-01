import Foundation
import FirebaseAuth

// MARK: - Firebase User Mapper
/// Maps Firebase User + Backend DTOs to AuthUser Entity (Domain)
/// Combines data from Firebase Auth and Backend API
struct FirebaseUserMapper {

    // MARK: - Legacy Migration Constants

    /// UserDefaults key for legacy onboarding completion status
    /// Used for migration from old AuthenticationService
    private static let legacyOnboardingKey = "hasCompletedOnboarding"

    // MARK: - Mapping from Firebase User + UserSyncResponse

    /// Convert Firebase User + Backend response to AuthUser Entity
    /// - Parameters:
    ///   - firebaseUser: Firebase Auth user object
    ///   - syncResponse: Backend user sync response with onboarding data
    /// - Returns: AuthUser entity with combined data
    static func toDomain(
        firebaseUser: FirebaseUser,
        syncResponse: UserSyncResponse
    ) -> AuthUser {
        // Extract photo URL from Firebase or Backend
        let photoURL: URL? = {
            if let firebasePhotoURL = firebaseUser.photoURL {
                return firebasePhotoURL
            }
            if let photoUrlString = syncResponse.user.photoUrl,
               let url = URL(string: photoUrlString) {
                return url
            }
            return nil
        }()

        // Determine onboarding mode from backend
        let onboardingMode = syncResponse.onboardingStatus.toOnboardingMode()

        // Determine onboarding completion with legacy fallback
        let hasCompletedOnboarding = resolveOnboardingStatus(
            backendCompleted: syncResponse.onboardingStatus.isCompleted,
            uid: firebaseUser.uid
        )

        // Create AuthUser entity
        return AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? syncResponse.user.email,
            displayName: firebaseUser.displayName ?? syncResponse.user.displayName,
            photoURL: photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: hasCompletedOnboarding ? .none : onboardingMode
        )
    }

    // MARK: - Onboarding Status Resolution

    /// Resolve onboarding completion status with legacy UserDefaults fallback
    /// Handles migration from old AuthenticationService which stored status in UserDefaults
    /// - Parameters:
    ///   - backendCompleted: Backend API's is_completed status
    ///   - uid: User's Firebase UID for logging
    /// - Returns: Final onboarding completion status
    private static func resolveOnboardingStatus(backendCompleted: Bool, uid: String) -> Bool {
        // If backend says completed, trust it
        if backendCompleted {
            Logger.debug("[FirebaseUserMapper] Backend says onboarding completed for \(uid)")
            return true
        }

        // Backend says NOT completed - check legacy UserDefaults fallback
        let legacyCompleted = UserDefaults.standard.bool(forKey: legacyOnboardingKey)

        if legacyCompleted {
            // Legacy data says completed but backend says not
            // Trust legacy for migration, but log the discrepancy
            Logger.debug("[FirebaseUserMapper] ⚠️ Onboarding status mismatch for \(uid)")
            Logger.debug("[FirebaseUserMapper]   Backend: false, Legacy UserDefaults: true")
            Logger.debug("[FirebaseUserMapper]   Using legacy status (migration scenario)")
            return true
        }

        // Both backend and legacy say not completed
        Logger.debug("[FirebaseUserMapper] Onboarding not completed for \(uid)")
        return false
    }

    // MARK: - Mapping from Firebase User Only (Fallback)

    /// Convert Firebase User to AuthUser Entity (without backend data)
    /// Used as fallback when backend sync fails
    /// - Parameter firebaseUser: Firebase Auth user object
    /// - Returns: AuthUser entity with Firebase data only
    static func toDomain(firebaseUser: FirebaseUser) -> AuthUser {
        // Check legacy UserDefaults even without backend data
        let hasCompletedOnboarding = resolveOnboardingStatus(
            backendCompleted: false,
            uid: firebaseUser.uid
        )

        return AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: hasCompletedOnboarding ? .none : .initial
        )
    }

    // MARK: - Mapping from UserSyncResponse Only

    /// Convert backend UserSyncResponse to AuthUser Entity (without Firebase user)
    /// Used when Firebase user is not directly available but sync response is
    /// - Parameter syncResponse: Backend user sync response
    /// - Returns: AuthUser entity with backend data
    static func toDomain(syncResponse: UserSyncResponse) -> AuthUser {
        // Extract photo URL from backend
        let photoURL: URL? = {
            if let photoUrlString = syncResponse.user.photoUrl {
                return URL(string: photoUrlString)
            }
            return nil
        }()

        // Determine onboarding mode from backend
        let onboardingMode = syncResponse.onboardingStatus.toOnboardingMode()

        // Determine onboarding completion with legacy fallback
        let hasCompletedOnboarding = resolveOnboardingStatus(
            backendCompleted: syncResponse.onboardingStatus.isCompleted,
            uid: syncResponse.user.uid
        )

        // Create AuthUser entity
        return AuthUser(
            uid: syncResponse.user.uid,
            email: syncResponse.user.email,
            displayName: syncResponse.user.displayName,
            photoURL: photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: hasCompletedOnboarding ? .none : onboardingMode
        )
    }
}
