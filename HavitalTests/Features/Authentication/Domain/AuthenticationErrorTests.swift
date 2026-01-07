import XCTest
@testable import paceriz_dev

/// Unit tests for AuthenticationError
/// Tests error mapping and localized descriptions
final class AuthenticationErrorTests: XCTestCase {

    // MARK: - Error Types Tests

    func testGoogleSignInFailed() {
        // Given
        let errorMessage = "Google sign-in cancelled by user"
        let error = AuthenticationError.googleSignInFailed(errorMessage)

        // Then
        XCTAssertEqual(error, .googleSignInFailed(errorMessage))
    }

    func testAppleSignInFailed() {
        // Given
        let errorMessage = "Apple sign-in failed: invalid credentials"
        let error = AuthenticationError.appleSignInFailed(errorMessage)

        // Then
        XCTAssertEqual(error, .appleSignInFailed(errorMessage))
    }

    func testFirebaseAuthFailed() {
        // Given
        let errorMessage = "Firebase authentication error"
        let error = AuthenticationError.firebaseAuthFailed(errorMessage)

        // Then
        XCTAssertEqual(error, .firebaseAuthFailed(errorMessage))
    }

    func testBackendSyncFailed() {
        // Given
        let errorMessage = "Backend sync failed: timeout"
        let error = AuthenticationError.backendSyncFailed(errorMessage)

        // Then
        XCTAssertEqual(error, .backendSyncFailed(errorMessage))
    }

    func testInvalidCredentials() {
        // Given
        let error = AuthenticationError.invalidCredentials

        // Then
        XCTAssertEqual(error, .invalidCredentials)
    }

    func testNetworkFailure() {
        // Given
        let error = AuthenticationError.networkFailure

        // Then
        XCTAssertEqual(error, .networkFailure)
    }

    func testTokenExpired() {
        // Given
        let error = AuthenticationError.tokenExpired

        // Then
        XCTAssertEqual(error, .tokenExpired)
    }

    func testUserNotFound() {
        // Given
        let error = AuthenticationError.userNotFound

        // Then
        XCTAssertEqual(error, .userNotFound)
    }

    func testOnboardingRequired() {
        // Given
        let error = AuthenticationError.onboardingRequired

        // Then
        XCTAssertEqual(error, .onboardingRequired)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameErrorWithMessage() {
        // Given
        let error1 = AuthenticationError.googleSignInFailed("error message")
        let error2 = AuthenticationError.googleSignInFailed("error message")

        // Then
        XCTAssertEqual(error1, error2)
    }

    func testEquatable_DifferentMessages() {
        // Given
        let error1 = AuthenticationError.googleSignInFailed("message 1")
        let error2 = AuthenticationError.googleSignInFailed("message 2")

        // Then
        XCTAssertNotEqual(error1, error2)
    }

    func testEquatable_DifferentErrorTypes() {
        // Given
        let error1 = AuthenticationError.googleSignInFailed("message")
        let error2 = AuthenticationError.appleSignInFailed("message")

        // Then
        XCTAssertNotEqual(error1, error2)
    }

    func testEquatable_SimpleErrors() {
        // Given
        let error1 = AuthenticationError.invalidCredentials
        let error2 = AuthenticationError.invalidCredentials

        // Then
        XCTAssertEqual(error1, error2)
    }

    // MARK: - DomainError Conversion Tests

    func testToDomainError_GoogleSignInFailed() {
        // Given
        let authError = AuthenticationError.googleSignInFailed("Google error")

        // When
        let domainError = authError.toDomainError()

        // Then
        XCTAssertEqual(domainError, .unauthorized)
    }

    func testToDomainError_AppleSignInFailed() {
        // Given
        let authError = AuthenticationError.appleSignInFailed("Apple error")

        // When
        let domainError = authError.toDomainError()

        // Then
        XCTAssertEqual(domainError, .unauthorized)
    }

    func testToDomainError_FirebaseAuthFailed() {
        // Given
        let authError = AuthenticationError.firebaseAuthFailed("Firebase error")

        // When
        let domainError = authError.toDomainError()

        // Then
        XCTAssertEqual(domainError, .unauthorized)
    }

    func testToDomainError_BackendSyncFailed() {
        // Given
        let errorMessage = "Backend sync error"
        let authError = AuthenticationError.backendSyncFailed(errorMessage)

        // When
        let domainError = authError.toDomainError()

        // Then
        if case .serverError(let code, let message) = domainError {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected .serverError, got \(domainError)")
        }
    }

    func testToDomainError_InvalidCredentials() {
        // Given
        let authError = AuthenticationError.invalidCredentials

        // When
        let domainError = authError.toDomainError()

        // Then
        if case .validationFailure(let message) = domainError {
            XCTAssertEqual(message, "Invalid authentication credentials")
        } else {
            XCTFail("Expected .validationFailure, got \(domainError)")
        }
    }

    func testToDomainError_NetworkFailure() {
        // Given
        let authError = AuthenticationError.networkFailure

        // When
        let domainError = authError.toDomainError()

        // Then
        if case .networkFailure(let message) = domainError {
            XCTAssertEqual(message, "Network connection failed")
        } else {
            XCTFail("Expected .networkFailure, got \(domainError)")
        }
    }

    func testToDomainError_TokenExpired() {
        // Given
        let authError = AuthenticationError.tokenExpired

        // When
        let domainError = authError.toDomainError()

        // Then
        XCTAssertEqual(domainError, .unauthorized)
    }

    func testToDomainError_UserNotFound() {
        // Given
        let authError = AuthenticationError.userNotFound

        // When
        let domainError = authError.toDomainError()

        // Then
        if case .notFound(let message) = domainError {
            XCTAssertEqual(message, "User not found")
        } else {
            XCTFail("Expected .notFound, got \(domainError)")
        }
    }

    func testToDomainError_OnboardingRequired() {
        // Given
        let authError = AuthenticationError.onboardingRequired

        // When
        let domainError = authError.toDomainError()

        // Then
        if case .validationFailure(let message) = domainError {
            XCTAssertEqual(message, "Onboarding must be completed")
        } else {
            XCTFail("Expected .validationFailure, got \(domainError)")
        }
    }

    // MARK: - LocalizedError Tests

    func testLocalizedDescription_GoogleSignInFailed() {
        // Given
        let error = AuthenticationError.googleSignInFailed("User cancelled")

        // When
        let description = error.localizedDescription

        // Then
        XCTAssertTrue(description.contains("Google"))
        XCTAssertTrue(description.contains("User cancelled"))
    }

    func testLocalizedDescription_InvalidCredentials() {
        // Given
        let error = AuthenticationError.invalidCredentials

        // When
        let description = error.localizedDescription

        // Then
        XCTAssertFalse(description.isEmpty)
    }

    func testLocalizedDescription_NetworkFailure() {
        // Given
        let error = AuthenticationError.networkFailure

        // When
        let description = error.localizedDescription

        // Then
        XCTAssertFalse(description.isEmpty)
    }
}
