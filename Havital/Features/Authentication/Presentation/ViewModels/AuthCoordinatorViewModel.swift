import Foundation

// MARK: - Auth State Enum
/// Represents application-level authentication state
/// Determines which screen to display
enum AuthState: Equatable {
    case loading                      // Initializing, checking auth status
    case unauthenticated              // Not logged in, show login screen
    case authenticated(AuthUser)      // Logged in and completed onboarding
    case onboarding(AuthUser)         // Logged in but needs onboarding
    case error(String)                // Authentication error

    // Equatable conformance
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser == rhsUser
        case (.onboarding(let lhsUser), .onboarding(let rhsUser)):
            return lhsUser == rhsUser
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Auth Coordinator ViewModel
/// Manages application-level authentication state
/// Responsible for:
/// - Managing global authentication state
/// - Coordinating authentication and onboarding flows
/// - Subscribing to authentication events
/// - Determining which screen to display (login, onboarding, main)
@MainActor
final class AuthCoordinatorViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Global authentication state
    @Published var authState: AuthState = .loading

    // MARK: - Dependencies

    private let authSessionRepository: AuthSessionRepository
    private let authRepository: AuthRepository
    private let onboardingRepository: OnboardingRepository

    // MARK: - Event Subscription

    private let subscriberId = "AuthCoordinatorViewModel"

    // MARK: - Initialization

    /// Main initializer with dependency injection
    /// - Parameters:
    ///   - authSessionRepository: Session management repository
    ///   - authRepository: Core authentication repository
    ///   - onboardingRepository: Onboarding state repository
    init(
        authSessionRepository: AuthSessionRepository,
        authRepository: AuthRepository,
        onboardingRepository: OnboardingRepository
    ) {
        self.authSessionRepository = authSessionRepository
        self.authRepository = authRepository
        self.onboardingRepository = onboardingRepository

        Logger.debug("[AuthCoordinator] Initialized")

        // Subscribe to authentication events
        subscribeToAuthEvents()
    }

    /// Convenience initializer using DependencyContainer
    convenience init() {
        let container = DependencyContainer.shared
        let sessionRepo: AuthSessionRepository = container.resolve()
        let authRepo: AuthRepository = container.resolve()
        let onboardingRepo: OnboardingRepository = container.resolve()

        self.init(
            authSessionRepository: sessionRepo,
            authRepository: authRepo,
            onboardingRepository: onboardingRepo
        )
    }

    // MARK: - Lifecycle

    deinit {
        // Unsubscribe from events
        CacheEventBus.shared.unsubscribe(forIdentifier: subscriberId)
        Logger.debug("[AuthCoordinator] Deinitialized")
    }

    // MARK: - State Initialization

    /// Initialize authentication state on app launch
    /// Checks Firebase session and backend onboarding status
    func initializeAuthState() async {
        authState = .loading

        Logger.debug("[AuthCoordinator] Initializing auth state")

        do {
            // Check if Firebase session exists
            guard authSessionRepository.isAuthenticated() else {
                Logger.debug("[AuthCoordinator] No Firebase session, switching to unauthenticated")
                authState = .unauthenticated
                return
            }

            // Fetch current user from backend
            let authUser = try await authSessionRepository.fetchCurrentUser()

            // Determine state based on onboarding status
            if authUser.hasCompletedOnboarding {
                authState = .authenticated(authUser)
                Logger.debug("[AuthCoordinator] User authenticated and completed onboarding")
            } else {
                authState = .onboarding(authUser)
                Logger.debug("[AuthCoordinator] User authenticated but needs onboarding")
            }

        } catch {
            Logger.error("[AuthCoordinator] Failed to initialize auth state: \(error.localizedDescription)")
            authState = .error("Failed to load user session")
        }
    }

    // MARK: - Sign-Out Operation

    /// Sign out current user
    /// Clears all caches and switches to unauthenticated state
    func signOut() async {
        Logger.debug("[AuthCoordinator] Signing out user")

        do {
            // Execute sign-out via Repository
            try await authRepository.signOut()

            // Update state
            authState = .unauthenticated

            Logger.debug("[AuthCoordinator] Sign-out succeeded")

            // ✅ Publish logout event (Coordinator responsibility)
            CacheEventBus.shared.publish(.userLogout)

        } catch {
            Logger.error("[AuthCoordinator] Sign-out failed: \(error.localizedDescription)")
            authState = .error("Sign-out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding Operations

    /// Handle onboarding completion
    /// Transitions from .onboarding to .authenticated state
    func handleOnboardingComplete() async {
        Logger.debug("[AuthCoordinator] Handling onboarding completion")

        guard case .onboarding(let user) = authState else {
            Logger.error("[AuthCoordinator] Invalid state for onboarding completion")
            return
        }

        do {
            // Mark onboarding as completed via Repository
            try await onboardingRepository.completeOnboarding()

            // Create updated user with completed onboarding
            let updatedUser = AuthUser(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
                photoURL: user.photoURL,
                isAuthenticated: user.isAuthenticated,
                hasCompletedOnboarding: true,
                onboardingMode: .none
            )

            // Transition to authenticated state
            authState = .authenticated(updatedUser)

            Logger.debug("[AuthCoordinator] Onboarding completed successfully")

            // ✅ Publish onboarding completion event (Coordinator responsibility)
            CacheEventBus.shared.publish(.onboardingCompleted)

        } catch {
            Logger.error("[AuthCoordinator] Failed to complete onboarding: \(error.localizedDescription)")
            authState = .error("Failed to complete onboarding")
        }
    }

    // MARK: - Event Subscription

    /// Subscribe to authentication-related events
    /// ✅ CORRECT: ViewModel subscribes to events
    private func subscribeToAuthEvents() {
        CacheEventBus.shared.subscribe(forIdentifier: subscriberId) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.handleCacheEvent(event)
            }
        }

        Logger.debug("[AuthCoordinator] Subscribed to authentication events")
    }

    /// Handle cache invalidation events
    /// - Parameter event: Cache invalidation reason
    private func handleCacheEvent(_ event: CacheInvalidationReason) async {
        Logger.debug("[AuthCoordinator] Received event: \(event)")

        switch event {
        case .dataChanged(.user):
            // User authenticated or updated - reload state
            await reloadAuthState()

        case .userLogout:
            // User logged out - switch to unauthenticated
            authState = .unauthenticated

        case .onboardingCompleted:
            // Onboarding completed - reload to ensure latest state
            await reloadAuthState()

        default:
            // Other events not relevant to auth state
            break
        }
    }

    /// Reload authentication state from backend
    /// Used when events indicate state may have changed
    private func reloadAuthState() async {
        Logger.debug("[AuthCoordinator] Reloading auth state")

        do {
            guard authSessionRepository.isAuthenticated() else {
                authState = .unauthenticated
                return
            }

            let authUser = try await authSessionRepository.fetchCurrentUser()

            if authUser.hasCompletedOnboarding {
                authState = .authenticated(authUser)
            } else {
                authState = .onboarding(authUser)
            }

            Logger.debug("[AuthCoordinator] Auth state reloaded successfully")

        } catch {
            Logger.error("[AuthCoordinator] Failed to reload auth state: \(error.localizedDescription)")
            // Don't change state on reload error - keep current state
        }
    }

    // MARK: - State Query Helpers

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    /// Check if user needs onboarding
    var needsOnboarding: Bool {
        if case .onboarding = authState {
            return true
        }
        return false
    }

    /// Get current authenticated user
    var currentUser: AuthUser? {
        switch authState {
        case .authenticated(let user), .onboarding(let user):
            return user
        default:
            return nil
        }
    }
}

// MARK: - AuthUser Extension for Mutation
extension AuthUser {
    /// Create a copy with updated onboarding status
    /// Used by AuthCoordinatorViewModel after onboarding completion
    var withCompletedOnboarding: AuthUser {
        return AuthUser(
            uid: self.uid,
            email: self.email,
            displayName: self.displayName,
            photoURL: self.photoURL,
            isAuthenticated: self.isAuthenticated,
            hasCompletedOnboarding: true,
            onboardingMode: .none
        )
    }
}
