import Foundation

// MARK: - Google Authentication Credential
/// Domain abstraction for Google Sign-In credential
/// Does NOT depend on GoogleSignIn SDK types (Clean Architecture principle)
/// Mapper in Data Layer converts GIDGoogleUser → GoogleAuthCredential
struct GoogleAuthCredential: Equatable {
    // MARK: - Core Properties

    /// Google ID Token (JWT)
    let idToken: String

    /// Google Access Token
    let accessToken: String

    // MARK: - Initialization

    init(
        idToken: String,
        accessToken: String
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
    }
}

// MARK: - Validation
extension GoogleAuthCredential {
    /// Validate that credential has required tokens
    var isValid: Bool {
        !idToken.isEmpty && !accessToken.isEmpty
    }
}
