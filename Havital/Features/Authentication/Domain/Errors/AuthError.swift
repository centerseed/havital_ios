import Foundation

// MARK: - Authentication Error Types
/// Domain-specific errors for Authentication feature
/// Pure business layer errors without exposing implementation details
/// Named AuthenticationError to avoid conflict with legacy AuthError in AuthenticationService
enum AuthenticationError: Error, Equatable {
    /// Google Sign-In failed
    case googleSignInFailed(String)

    /// Apple Sign-In failed
    case appleSignInFailed(String)

    /// Firebase authentication failed
    case firebaseAuthFailed(String)

    /// Backend user sync failed
    case backendSyncFailed(String)

    /// Invalid credentials provided
    case invalidCredentials

    /// Network connectivity error
    case networkFailure

    /// Authentication token expired
    case tokenExpired

    /// User not found
    case userNotFound

    /// Onboarding completion required
    case onboardingRequired

    /// App version is too old and must be updated
    case forceUpdateRequired(updateUrl: String?)
}

// MARK: - Conversion to DomainError
extension AuthenticationError {
    func toDomainError() -> DomainError {
        switch self {
        case .googleSignInFailed(let message):
            return .unauthorized
        case .appleSignInFailed(let message):
            return .unauthorized
        case .firebaseAuthFailed(let message):
            return .unauthorized
        case .backendSyncFailed(let message):
            return .serverError(500, message)
        case .invalidCredentials:
            return .validationFailure("Invalid authentication credentials")
        case .networkFailure:
            return .networkFailure("Network connection failed")
        case .tokenExpired:
            return .unauthorized
        case .userNotFound:
            return .notFound("User not found")
        case .onboardingRequired:
            return .validationFailure("Onboarding must be completed")
        case .forceUpdateRequired(let url):
            return .forceUpdateRequired(updateUrl: url)
        }
    }
}

// MARK: - Localized Description
extension AuthenticationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .googleSignInFailed(let message):
            return String(format: NSLocalizedString("authentication.error.google_sign_in_failed_format", comment: "Google sign-in failed"), message)
        case .appleSignInFailed(let message):
            return String(format: NSLocalizedString("authentication.error.apple_sign_in_failed_format", comment: "Apple sign-in failed"), message)
        case .firebaseAuthFailed(let message):
            return String(format: NSLocalizedString("authentication.error.firebase_auth_failed_format", comment: "Firebase authentication failed"), message)
        case .backendSyncFailed(let message):
            return String(format: NSLocalizedString("authentication.error.backend_sync_failed_format", comment: "Backend sync failed"), message)
        case .invalidCredentials:
            return NSLocalizedString("authentication.error.invalid_credentials", comment: "Invalid credentials")
        case .networkFailure:
            return NSLocalizedString("authentication.error.network_failure", comment: "Network connection failed")
        case .tokenExpired:
            return NSLocalizedString("authentication.error.token_expired", comment: "Authentication token expired")
        case .userNotFound:
            return NSLocalizedString("authentication.error.user_not_found", comment: "User not found")
        case .onboardingRequired:
            return NSLocalizedString("authentication.error.onboarding_required", comment: "Onboarding must be completed")
        case .forceUpdateRequired:
            return NSLocalizedString("error.force_update_required", comment: "Force app update required error")
        }
    }
}
