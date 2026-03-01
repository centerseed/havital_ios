import Foundation
import AuthenticationServices
import GoogleSignIn

// MARK: - Authentication Credential Mapper
/// Maps SDK-specific credential types to Domain abstraction types
/// Isolates Domain Layer from external SDK dependencies
struct AuthCredentialMapper {

    // MARK: - Apple Sign-In Mapping

    /// Convert ASAuthorizationAppleIDCredential (SDK) to AppleAuthCredential (Domain)
    /// - Parameter credential: Apple SDK credential from ASAuthorizationController
    /// - Returns: Domain abstraction credential
    /// - Throws: AuthenticationError.appleSignInFailed if required data is missing
    static func toDomain(
        _ credential: ASAuthorizationAppleIDCredential
    ) throws -> AppleAuthCredential {
        // Extract identity token
        guard let identityToken = credential.identityToken else {
            throw AuthenticationError.appleSignInFailed("Missing identity token")
        }

        // Extract authorization code
        guard let authorizationCode = credential.authorizationCode else {
            throw AuthenticationError.appleSignInFailed("Missing authorization code")
        }

        // Convert PersonNameComponents (SDK type is allowed in mapper)
        let fullName = credential.fullName

        // Extract email (only provided on first sign-in)
        let email = credential.email

        return AppleAuthCredential(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName,
            email: email
        )
    }

    // MARK: - Google Sign-In Mapping

    /// Convert GIDGoogleUser (SDK) to GoogleAuthCredential (Domain)
    /// - Parameter user: Google SDK user from GoogleSignIn
    /// - Returns: Domain abstraction credential
    /// - Throws: AuthenticationError.googleSignInFailed if required tokens are missing
    static func toDomain(
        _ user: GIDGoogleUser
    ) throws -> GoogleAuthCredential {
        // Extract ID Token
        guard let idToken = user.idToken?.tokenString else {
            throw AuthenticationError.googleSignInFailed("Missing ID token")
        }

        // Extract Access Token
        let accessToken = user.accessToken.tokenString

        return GoogleAuthCredential(
            idToken: idToken,
            accessToken: accessToken
        )
    }
}
