import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

class AuthenticationService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    
    static let shared = AuthenticationService()
    
    private init() {
        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
        }
    }
    
    func signInWithGoogle() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientId
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw AuthError.presentationError
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        // After getting the credential, sync with our backend
        do {
            try await syncUserWithBackend(idToken: idToken)
        } catch {
            print("Failed to sync user with backend: \(error)")
            // Still return the credential even if backend sync fails
            // The user can still use the app with Firebase auth
        }
        
        return credential
    }
    
    private func syncUserWithBackend(idToken: String) async throws {
        let userService = UserService.shared
        
        do {
            // Try to get existing user
            let user = try await userService.getCurrentUser()
            userService.syncUserPreferences(with: user)
        } catch {
            // If user doesn't exist, create new user with Google login
            let user = try await userService.loginWithGoogle(idToken: idToken)
            userService.syncUserPreferences(with: user)
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()
    }
    
    // Get the current ID token
    func getIdToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        return try await user.getIDToken()
    }
}

enum AuthError: Error {
    case missingClientId
    case presentationError
    case missingToken
    case notAuthenticated
    
    var localizedDescription: String {
        switch self {
        case .missingClientId:
            return "Firebase client ID is missing"
        case .presentationError:
            return "Cannot present sign in screen"
        case .missingToken:
            return "Authentication token is missing"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}
