import Foundation
import GoogleSignIn

// MARK: - Google Sign-In Data Source
/// Handles Google Sign-In SDK operations
/// Responsible for displaying Google sign-in UI and extracting tokens
final class GoogleSignInDataSource {

    // MARK: - Initialization

    init() {}

    // MARK: - Sign-In Operations

    /// Perform Google Sign-In flow
    /// Displays Google sign-in UI and returns authenticated user
    /// - Returns: GIDGoogleUser with tokens
    /// - Throws: AuthenticationError.googleSignInFailed if sign-in fails
    func performSignIn() async throws -> GIDGoogleUser {
        // Get presenting view controller
        guard let presentingViewController = await getRootViewController() else {
            throw AuthenticationError.googleSignInFailed("No presenting view controller available")
        }

        do {
            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )

            Logger.debug("Google Sign-In succeeded: \(result.user.userID ?? "unknown")")
            return result.user
        } catch let error as NSError {
            // Handle user cancellation gracefully
            if error.code == -5 { // GIDSignInErrorCode.canceled
                Logger.debug("User cancelled Google Sign-In")
                throw AuthenticationError.googleSignInFailed("User cancelled sign-in")
            }

            Logger.error("Google Sign-In failed: \(error.localizedDescription)")
            throw AuthenticationError.googleSignInFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Get root view controller for presenting Google Sign-In UI
    /// - Returns: Root view controller if available
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}
