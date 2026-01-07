import Foundation

// MARK: - Apple Authentication Credential
/// Domain abstraction for Apple Sign-In credential
/// Does NOT depend on ASAuthorization SDK types (Clean Architecture principle)
/// Mapper in Data Layer converts ASAuthorizationAppleIDCredential → AppleAuthCredential
struct AppleAuthCredential: Equatable {
    // MARK: - Core Properties

    /// Apple identity token (JWT)
    let identityToken: Data

    /// Apple authorization code
    let authorizationCode: Data

    // MARK: - User Info (Optional - only provided on first sign-in)

    /// User's full name components
    let fullName: PersonNameComponents?

    /// User's email address
    let email: String?

    // MARK: - Initialization

    init(
        identityToken: Data,
        authorizationCode: Data,
        fullName: PersonNameComponents? = nil,
        email: String? = nil
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.fullName = fullName
        self.email = email
    }
}

// MARK: - Convenience Properties
extension AppleAuthCredential {
    /// Extract identity token as string
    var identityTokenString: String? {
        String(data: identityToken, encoding: .utf8)
    }

    /// Extract authorization code as string
    var authorizationCodeString: String? {
        String(data: authorizationCode, encoding: .utf8)
    }

    /// Check if user info is available (first sign-in)
    var hasUserInfo: Bool {
        fullName != nil || email != nil
    }
}
