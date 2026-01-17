import Foundation
import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Authentication ViewModel
/// Global authentication state manager
/// Replaces AuthenticationService for state management
/// Responsible for:
/// - Managing global authentication state (isAuthenticated, currentUser)
/// - Listening to Firebase Auth state changes
/// - Managing onboarding status
/// - Providing sign-out functionality
/// - Publishing authentication events
@MainActor
final class AuthenticationViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current authentication status
    @Published var isAuthenticated: Bool = false

    /// Current authenticated user (cached)
    @Published var currentUser: AuthUser?

    /// Onboarding completion status
    @Published var hasCompletedOnboarding: Bool = false

    /// Re-onboarding mode flag
    @Published var isReonboardingMode: Bool = false

    /// Loading state for auth operations
    @Published var isLoading: Bool = false

    /// Authentication error
    @Published var error: DomainError?

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let authSessionRepository: AuthSessionRepository
    private let onboardingRepository: OnboardingRepository

    // Firebase Auth state listener handle
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = AuthenticationViewModel()

    // MARK: - Initialization

    /// Main initializer with dependency injection
    private init(
        authRepository: AuthRepository,
        authSessionRepository: AuthSessionRepository,
        onboardingRepository: OnboardingRepository
    ) {
        self.authRepository = authRepository
        self.authSessionRepository = authSessionRepository
        self.onboardingRepository = onboardingRepository

        Logger.debug("[AuthViewModel] Initialized with repositories")

        // Initialize authentication state
        initializeAuthState()

        // Listen to Firebase Auth state changes
        setupAuthStateListener()

        // Load onboarding status from UserDefaults
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    /// Convenience initializer using DependencyContainer
    convenience init() {
        let container = DependencyContainer.shared
        let authRepo: AuthRepository = container.resolve()
        let sessionRepo: AuthSessionRepository = container.resolve()
        let onboardingRepo: OnboardingRepository = container.resolve()

        self.init(
            authRepository: authRepo,
            authSessionRepository: sessionRepo,
            onboardingRepository: onboardingRepo
        )
    }

    deinit {
        // Remove Firebase Auth listener
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        cancellables.removeAll()
    }

    // MARK: - Initialization Helpers

    /// Initialize authentication state from current session
    private func initializeAuthState() {
        // Check if user is authenticated
        isAuthenticated = authSessionRepository.isAuthenticated()

        // Load cached user if available
        currentUser = authSessionRepository.getCurrentUser()

        Logger.debug("[AuthViewModel] Initial auth state: isAuthenticated=\(isAuthenticated), user=\(currentUser?.uid ?? "nil")")
    }

    /// Setup Firebase Auth state change listener
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }

            Task { @MainActor in
                Logger.debug("[AuthViewModel] Firebase Auth state changed: user=\(firebaseUser?.uid ?? "nil")")

                // Update authentication status using AuthSessionRepository (supports both Firebase and Demo mode)
                self.isAuthenticated = self.authSessionRepository.isAuthenticated()

                // Fetch user data if authenticated
                if firebaseUser != nil {
                    await self.fetchCurrentUserData()
                } else {
                    // For demo mode, check if we have a cached user
                    // Demo mode has no Firebase session but may have a cached user
                    if let cachedUser = self.authSessionRepository.getCurrentUser() {
                        Logger.debug("[AuthViewModel] Demo mode: keeping cached user")
                        self.currentUser = cachedUser
                    } else {
                        // Clear user data if signed out
                        self.currentUser = nil
                    }
                }

                // Publish authentication state change event
                CacheEventBus.shared.publish(.dataChanged(.user))
            }
        }

        // ✅ Subscribe to user data change events (e.g., from LoginViewModel)
        // This ensures AuthenticationViewModel stays in sync when user logs in via Clean Architecture
        CacheEventBus.shared.subscribe(for: "dataChanged.user") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[AuthViewModel] Received dataChanged.user event, refreshing user data")

            // Update authentication status (supports both Firebase and Demo mode)
            await MainActor.run {
                self.isAuthenticated = self.authSessionRepository.isAuthenticated()
                Logger.debug("[AuthViewModel] Updated isAuthenticated: \(self.isAuthenticated)")
            }

            // Fetch latest user data from backend
            await self.fetchCurrentUserData()

            // Update onboarding status from user data
            if let user = self.currentUser {
                await MainActor.run {
                    self.hasCompletedOnboarding = user.hasCompletedOnboarding
                    UserDefaults.standard.set(user.hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
                    Logger.debug("[AuthViewModel] ✅ Onboarding status updated: \(user.hasCompletedOnboarding)")
                }
            }
        }

        // ✅ Subscribe to re-onboarding completed event
        // Clean Architecture: OnboardingCoordinator publishes event, AuthenticationViewModel subscribes
        // This decouples the Coordinator from the ViewModel
        CacheEventBus.shared.subscribe(for: "reonboardingCompleted") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[AuthViewModel] Received reonboardingCompleted event, closing sheet")

            // Close the re-onboarding sheet
            self.isReonboardingMode = false
        }
    }

    // MARK: - User Data Management

    /// Fetch current user data from backend
    func fetchCurrentUserData() async {
        do {
            Logger.debug("[AuthViewModel] Fetching current user data")

            // Fetch fresh user data from backend
            let user = try await authSessionRepository.fetchCurrentUser()

            // Update published property
            currentUser = user

            Logger.debug("[AuthViewModel] User data fetched successfully: \(user.uid)")

        } catch {
            Logger.error("[AuthViewModel] Failed to fetch user data: \(error.localizedDescription)")
            self.error = error.toDomainError()
        }
    }

    /// Get current user synchronously from cache
    func getCachedUser() -> AuthUser? {
        return authSessionRepository.getCurrentUser()
    }

    // MARK: - Sign-Out Operation

    /// Sign out current user
    /// Clears authentication state and cache
    func signOut() async {
        isLoading = true
        error = nil

        Logger.debug("[AuthViewModel] Starting sign out")

        do {
            // Execute sign out via Repository
            try await authRepository.signOut()

            // Clear local state
            isAuthenticated = false
            currentUser = nil
            hasCompletedOnboarding = false
            isReonboardingMode = false
            isLoading = false

            // Clear onboarding status from UserDefaults
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

            Logger.debug("[AuthViewModel] Sign out succeeded")

            // Publish user logout event
            CacheEventBus.shared.publish(.userLogout)

        } catch {
            isLoading = false
            self.error = error.toDomainError()

            Logger.error("[AuthViewModel] Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding Management

    /// Mark onboarding as completed
    func completeOnboarding() async {
        do {
            Logger.debug("[AuthViewModel] Completing onboarding")

            // Update backend
            try await onboardingRepository.completeOnboarding()

            // Update local state
            hasCompletedOnboarding = true
            isReonboardingMode = false

            // Persist to UserDefaults
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

            Logger.debug("[AuthViewModel] Onboarding completed successfully")

            // Publish onboarding completed event
            CacheEventBus.shared.publish(.onboardingCompleted)

        } catch {
            self.error = error.toDomainError()
            Logger.error("[AuthViewModel] Failed to complete onboarding: \(error.localizedDescription)")
        }
    }

    /// Start re-onboarding flow
    func startReonboarding() {
        Logger.debug("[AuthViewModel] Starting re-onboarding")

        isReonboardingMode = true

        // Note: Don't clear hasCompletedOnboarding
        // Re-onboarding allows users to update their profile without full onboarding
    }

    /// Cancel re-onboarding flow
    func cancelReonboarding() {
        Logger.debug("[AuthViewModel] Canceling re-onboarding")

        isReonboardingMode = false
    }

    /// Reset onboarding (admin/debug use)
    func resetOnboarding() async {
        do {
            Logger.debug("[AuthViewModel] Resetting onboarding")

            // Update backend
            try await onboardingRepository.resetOnboarding()

            // Clear local state
            hasCompletedOnboarding = false
            isReonboardingMode = false

            // Clear UserDefaults
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

            Logger.debug("[AuthViewModel] Onboarding reset successfully")

        } catch {
            self.error = error.toDomainError()
            Logger.error("[AuthViewModel] Failed to reset onboarding: \(error.localizedDescription)")
        }
    }

    // MARK: - Token Management

    /// Get Firebase ID Token
    /// - Returns: Valid Firebase ID Token
    /// - Throws: AuthenticationError if token cannot be retrieved
    func getIdToken() async throws -> String {
        return try await authSessionRepository.getIdToken()
    }

    /// Refresh Firebase ID Token
    /// - Returns: Fresh Firebase ID Token
    /// - Throws: AuthenticationError if refresh fails
    func refreshIdToken() async throws -> String {
        return try await authSessionRepository.refreshIdToken()
    }
}
