import Foundation
import FirebaseAuth
import CryptoKit

// MARK: - Type Alias
/// Avoid naming conflict with FirebaseAuth.User
typealias FirebaseUser = FirebaseAuth.User

// MARK: - Firebase Auth Data Source
/// Handles Firebase Authentication SDK operations
/// Responsible for OAuth authentication, token management, and auth state listening
final class FirebaseAuthDataSource {

    // MARK: - Dependencies

    private let auth: Auth

    // MARK: - Initialization

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    // MARK: - Sign-In Operations

    /// Sign in with Google OAuth tokens
    /// - Parameters:
    ///   - idToken: Google ID Token
    ///   - accessToken: Google Access Token
    /// - Returns: Authenticated Firebase User
    /// - Throws: AuthenticationError.firebaseAuthFailed if sign-in fails
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> FirebaseUser {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )

        do {
            let authResult = try await auth.signIn(with: credential)
            Logger.debug("Firebase Google sign-in succeeded: \(authResult.user.uid)")
            return authResult.user
        } catch {
            Logger.error("Firebase Google sign-in failed: \(error.localizedDescription)")
            throw AuthenticationError.firebaseAuthFailed("Google sign-in failed: \(error.localizedDescription)")
        }
    }

    /// Sign in with Apple OAuth
    /// - Parameters:
    ///   - identityToken: Apple identity token (Data)
    ///   - rawNonce: Raw nonce string used for security
    /// - Returns: Authenticated Firebase User
    /// - Throws: AuthenticationError.firebaseAuthFailed if sign-in fails
    func signInWithApple(identityToken: Data, rawNonce: String) async throws -> FirebaseUser {
        // Convert identity token Data to String
        guard let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthenticationError.appleSignInFailed("Failed to decode identity token")
        }

        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: rawNonce
        )

        do {
            let authResult = try await auth.signIn(with: credential)
            Logger.debug("Firebase Apple sign-in succeeded: \(authResult.user.uid)")
            return authResult.user
        } catch {
            Logger.error("Firebase Apple sign-in failed: \(error.localizedDescription)")
            throw AuthenticationError.firebaseAuthFailed("Apple sign-in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - User State Operations

    /// Get currently signed-in Firebase user (synchronous)
    /// - Returns: Current user if signed in, nil otherwise
    func getCurrentUser() -> FirebaseUser? {
        return auth.currentUser
    }

    /// Check if user is currently authenticated
    /// - Returns: True if user has active Firebase session
    func isAuthenticated() -> Bool {
        return auth.currentUser != nil
    }

    // MARK: - Token Management

    /// Get Firebase ID Token with automatic refresh
    /// Token is fetched fresh every time for security
    /// - Returns: Valid Firebase ID Token
    /// - Throws: AuthenticationError.tokenExpired if token cannot be retrieved
    func getIdToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthenticationError.tokenExpired
        }

        do {
            // Force refresh to ensure token is valid
            let token = try await user.getIDToken()
            return token
        } catch {
            Logger.error("Failed to get Firebase ID token: \(error.localizedDescription)")
            throw AuthenticationError.tokenExpired
        }
    }

    /// Force refresh Firebase ID Token
    /// Explicitly requests new token from Firebase
    /// - Returns: Fresh Firebase ID Token
    /// - Throws: AuthenticationError.tokenExpired if refresh fails
    func refreshIdToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthenticationError.tokenExpired
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(true) { token, error in
                if let error = error {
                    Logger.error("Failed to refresh Firebase ID token: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthenticationError.tokenExpired)
                } else if let token = token {
                    Logger.debug("Firebase ID token refreshed successfully")
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: AuthenticationError.tokenExpired)
                }
            }
        }
    }

    // MARK: - Auth State Listening

    /// Add Firebase Auth State Listener
    /// Listener should be registered once at application startup
    /// - Parameter handler: Callback invoked when auth state changes
    /// - Returns: Listener handle (use to remove listener)
    func addAuthStateListener(handler: @escaping (Auth, FirebaseUser?) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener(handler)
    }

    /// Remove Firebase Auth State Listener
    /// - Parameter handle: Listener handle from addAuthStateListener
    func removeAuthStateListener(handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }

    // MARK: - Sign-Out Operations

    /// Sign out current user from Firebase
    /// - Throws: AuthenticationError.firebaseAuthFailed if sign-out fails
    func signOut() async throws {
        do {
            try auth.signOut()
            Logger.debug("Firebase sign-out succeeded")
        } catch {
            Logger.error("Firebase sign-out failed: \(error.localizedDescription)")
            throw AuthenticationError.firebaseAuthFailed("Sign-out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Sign-In Nonce Generation

    /// Generate random nonce string for Apple Sign-In security
    /// Uses CryptoKit to generate cryptographically secure random nonce
    /// - Parameter length: Nonce length (default: 32)
    /// - Returns: Random nonce string
    static func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            Logger.firebase("Nonce 生成失敗 OSStatus: \(errorCode)", level: .error, labels: [
                "module": "FirebaseAuthDataSource",
                "action": "generateNonce"
            ])
            // Fallback: 使用 UUID 作為替代 nonce
            let fallback = (0..<length).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
            return String(fallback.prefix(length))
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// Generate SHA256 hash of nonce for Apple Sign-In
    /// - Parameter input: Input string to hash
    /// - Returns: SHA256 hash as hex string
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
