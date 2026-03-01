import Foundation
import AuthenticationServices

// MARK: - Apple Sign-In Data Source
/// Handles Apple Sign-In SDK operations
/// Responsible for displaying Apple sign-in UI and handling delegate callbacks
final class AppleSignInDataSource: NSObject {

    // MARK: - Continuation for async/await

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Sign-In Operations

    /// Perform Apple Sign-In flow
    /// Displays Apple sign-in UI and returns credential
    /// - Parameter nonce: SHA256-hashed nonce for security
    /// - Returns: ASAuthorizationAppleIDCredential with tokens
    /// - Throws: AuthenticationError.appleSignInFailed if sign-in fails
    func performSignIn(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Create Apple ID authorization request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce

            // Create and present authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self

            authorizationController.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInDataSource: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = AuthenticationError.appleSignInFailed("Invalid credential type")
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        Logger.debug("Apple Sign-In succeeded: \(appleIDCredential.user)")
        continuation?.resume(returning: appleIDCredential)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let authError = error as NSError

        // Handle user cancellation gracefully
        if authError.code == ASAuthorizationError.canceled.rawValue {
            Logger.debug("User cancelled Apple Sign-In")
            let customError = AuthenticationError.appleSignInFailed("User cancelled sign-in")
            continuation?.resume(throwing: customError)
        } else {
            Logger.error("Apple Sign-In failed: \(error.localizedDescription)")
            let customError = AuthenticationError.appleSignInFailed(error.localizedDescription)
            continuation?.resume(throwing: customError)
        }

        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInDataSource: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            Logger.firebase("Apple Sign-In 無法取得 window", level: .error, labels: [
                "module": "AppleSignInDataSource",
                "action": "presentationAnchor"
            ])
            return UIWindow()
        }
        return window
    }
}
