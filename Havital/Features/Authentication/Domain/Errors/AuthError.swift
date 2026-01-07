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
        }
    }
}

// MARK: - Localized Description
extension AuthenticationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .appleSignInFailed(let message):
            return "Apple Sign-In failed: \(message)"
        case .firebaseAuthFailed(let message):
            return "Firebase authentication failed: \(message)"
        case .backendSyncFailed(let message):
            return "Backend sync failed: \(message)"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .networkFailure:
            return "Network connection failed"
        case .tokenExpired:
            return "Authentication token has expired"
        case .userNotFound:
            return "User not found"
        case .onboardingRequired:
            return "Onboarding must be completed"
        }
    }
}
