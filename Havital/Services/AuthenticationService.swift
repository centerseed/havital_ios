import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Combine

class AuthenticationService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var appUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    static let shared = AuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            
            if user != nil {
                // If user is authenticated with Firebase, fetch their profile from backend
                self?.fetchUserProfile()
            } else {
                self?.appUser = nil
            }
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
            let user = try await loginWithGoogle(idToken: idToken)
            self.appUser = user
            userService.syncUserPreferences(with: user)
        } catch {
            print("Failed to sync with backend: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func loginWithGoogle(idToken: String) async throws -> User {
        return try await UserService.shared.loginWithGoogle(idToken: idToken)
    }
    
    func fetchUserProfile() {
        isLoading = true
        
        UserService.shared.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Failed to fetch user profile: \(error)")
                }
            } receiveValue: { [weak self] user in
                self?.appUser = user
                UserService.shared.syncUserPreferences(with: user)
            }
            .store(in: &cancellables)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()
        appUser = nil
        UserPreferenceManager.shared.clearUserData()
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
