import Foundation
import FirebaseAuth

// MARK: - Firebase User Mapper
/// Maps Firebase User + Backend DTOs to AuthUser Entity (Domain)
/// Combines data from Firebase Auth and Backend API
struct FirebaseUserMapper {

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

        // Create AuthUser entity
        return AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? syncResponse.user.email,
            displayName: firebaseUser.displayName ?? syncResponse.user.displayName,
            photoURL: photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: syncResponse.onboardingStatus.isCompleted,
            onboardingMode: onboardingMode
        )
    }

    // MARK: - Mapping from Firebase User Only (Fallback)

    /// Convert Firebase User to AuthUser Entity (without backend data)
    /// Used as fallback when backend sync fails
    /// - Parameter firebaseUser: Firebase Auth user object
    /// - Returns: AuthUser entity with Firebase data only
    static func toDomain(firebaseUser: FirebaseUser) -> AuthUser {
        return AuthUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: false, // Assume not completed if backend unavailable
            onboardingMode: .initial // Default to initial onboarding
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

        // Create AuthUser entity
        return AuthUser(
            uid: syncResponse.user.uid,
            email: syncResponse.user.email,
            displayName: syncResponse.user.displayName,
            photoURL: photoURL,
            isAuthenticated: true,
            hasCompletedOnboarding: syncResponse.onboardingStatus.isCompleted,
            onboardingMode: onboardingMode
        )
    }
}
