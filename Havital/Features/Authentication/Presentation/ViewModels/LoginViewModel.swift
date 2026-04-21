import Foundation

// MARK: - Login ViewModel
/// Manages login UI state and authentication operations
/// Responsible for:
/// - Managing login UI states (loading, success, error)
/// - Calling AuthRepository to execute login logic
/// - Publishing authentication events (Repository does NOT publish)
/// - Handling user-friendly error messages
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Unified login state using ViewState pattern
    @Published var state: ViewState<AuthUser> = .empty

    /// Google Sign-In loading state
    @Published var isGoogleSignInLoading: Bool = false

    /// Apple Sign-In loading state
    @Published var isAppleSignInLoading: Bool = false

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let authSessionRepository: AuthSessionRepository

    // MARK: - Initialization

    /// Main initializer with dependency injection
    /// - Parameter authRepository: Authentication repository protocol
    init(
        authRepository: AuthRepository,
        authSessionRepository: AuthSessionRepository
    ) {
        self.authRepository = authRepository
        self.authSessionRepository = authSessionRepository
        Logger.debug("[LoginViewModel] Initialized")
    }

    /// Convenience initializer using DependencyContainer
    convenience init() {
        let container = DependencyContainer.shared
        let authRepo: AuthRepository = container.resolve()
        let authSessionRepo: AuthSessionRepository = container.resolve()
        self.init(authRepository: authRepo, authSessionRepository: authSessionRepo)
    }

    // MARK: - Sign-In Operations

    /// Sign in with Google account
    /// Executes 7-step authentication flow via AuthRepository
    /// Publishes authentication event on success
    func signInWithGoogle() async {
        isGoogleSignInLoading = true
        state = .loading

        Logger.debug("[LoginViewModel] Starting Google Sign-In")
        let previousUserId = authSessionRepository.getCurrentUser()?.uid

        do {
            // Step 1-7: Execute authentication flow via Repository
            let authUser = try await authRepository.signInWithGoogle()

            // Update UI state
            state = .loaded(authUser)
            isGoogleSignInLoading = false

            Logger.debug("[LoginViewModel] Google Sign-In succeeded: \(authUser.uid)")

            // ✅ Publish authentication event (ViewModel responsibility)
            publishAuthenticationEvent(previousUserId: previousUserId, user: authUser)

        } catch let error as AuthenticationError {
            let domainErr = error.toDomainError()
            if case .forceUpdateRequired(let url) = domainErr {
                AuthenticationViewModel.shared.requiresForceUpdate = true
                AuthenticationViewModel.shared.forceUpdateUrl = url
                isGoogleSignInLoading = false
                return
            }
            state = .error(domainErr)
            isGoogleSignInLoading = false

            Logger.error("[LoginViewModel] Google Sign-In failed: \(error.localizedDescription)")

        } catch {
            // Handle unexpected errors
            state = .error(error.toDomainError())
            isGoogleSignInLoading = false

            Logger.error("[LoginViewModel] Google Sign-In unexpected error: \(error.localizedDescription)")
        }
    }

    /// Sign in with Apple ID (full async flow)
    /// Executes 7-step authentication flow via AuthRepository
    /// Publishes authentication event on success
    func signInWithApple() async {
        isAppleSignInLoading = true
        state = .loading

        Logger.debug("[LoginViewModel] Starting Apple Sign-In")
        let previousUserId = authSessionRepository.getCurrentUser()?.uid

        do {
            // Step 1-7: Execute authentication flow via Repository
            let authUser = try await authRepository.signInWithApple()

            // Update UI state
            state = .loaded(authUser)
            isAppleSignInLoading = false

            Logger.debug("[LoginViewModel] Apple Sign-In succeeded: \(authUser.uid)")

            // ✅ Publish authentication event (ViewModel responsibility)
            publishAuthenticationEvent(previousUserId: previousUserId, user: authUser)

        } catch let error as AuthenticationError {
            let domainErr = error.toDomainError()
            if case .forceUpdateRequired(let url) = domainErr {
                AuthenticationViewModel.shared.requiresForceUpdate = true
                AuthenticationViewModel.shared.forceUpdateUrl = url
                isAppleSignInLoading = false
                return
            }

            // Ignore user cancellation - don't show error
            if case .appleSignInFailed(let message) = error, message == "User cancelled sign-in" {
                state = .empty
                isAppleSignInLoading = false
                Logger.debug("[LoginViewModel] Apple Sign-In cancelled by user")
                return
            }

            state = .error(domainErr)
            isAppleSignInLoading = false

            Logger.error("[LoginViewModel] Apple Sign-In failed: \(error.localizedDescription)")

        } catch {
            // Handle unexpected errors
            state = .error(error.toDomainError())
            isAppleSignInLoading = false

            Logger.error("[LoginViewModel] Apple Sign-In unexpected error: \(error.localizedDescription)")
        }
    }

    /// Sign in with Apple ID (with pre-obtained credential)
    /// Executes 7-step authentication flow via AuthRepository
    /// Publishes authentication event on success
    /// - Parameter credential: Apple authentication credential (Domain abstraction)
    func signInWithApple(credential: AppleAuthCredential) async {
        isAppleSignInLoading = true
        state = .loading

        Logger.debug("[LoginViewModel] Starting Apple Sign-In with credential")
        let previousUserId = authSessionRepository.getCurrentUser()?.uid

        do {
            // Step 1-7: Execute authentication flow via Repository
            let authUser = try await authRepository.signInWithApple(credential: credential)

            // Update UI state
            state = .loaded(authUser)
            isAppleSignInLoading = false

            Logger.debug("[LoginViewModel] Apple Sign-In succeeded: \(authUser.uid)")

            // ✅ Publish authentication event (ViewModel responsibility)
            publishAuthenticationEvent(previousUserId: previousUserId, user: authUser)

        } catch let error as AuthenticationError {
            let domainErr = error.toDomainError()
            if case .forceUpdateRequired(let url) = domainErr {
                AuthenticationViewModel.shared.requiresForceUpdate = true
                AuthenticationViewModel.shared.forceUpdateUrl = url
                isAppleSignInLoading = false
                return
            }
            state = .error(domainErr)
            isAppleSignInLoading = false

            Logger.error("[LoginViewModel] Apple Sign-In failed: \(error.localizedDescription)")

        } catch {
            // Handle unexpected errors
            state = .error(error.toDomainError())
            isAppleSignInLoading = false

            Logger.error("[LoginViewModel] Apple Sign-In unexpected error: \(error.localizedDescription)")
        }
    }

    /// Demo login for development and testing
    /// Simplified flow without real authentication
    func demoLogin(passcode: String) async {
        state = .loading

        Logger.debug("[LoginViewModel] Starting Demo Login")
        let previousUserId = authSessionRepository.getCurrentUser()?.uid

        do {
            let authUser = try await authRepository.demoLogin(reviewerPasscode: passcode)

            state = .loaded(authUser)

            Logger.debug("[LoginViewModel] Demo Login succeeded: \(authUser.uid)")

            // ✅ Publish authentication event
            publishAuthenticationEvent(previousUserId: previousUserId, user: authUser)

        } catch let error as AuthenticationError {
            if error == .invalidCredentials {
                state = .error(.validationFailure(NSLocalizedString("login.reviewer_access_failed", comment: "")))
            } else {
                state = .error(error.toDomainError())
            }

            Logger.error("[LoginViewModel] Demo Login failed: \(error.localizedDescription)")

        } catch {
            state = .error(error.toDomainError())

            Logger.error("[LoginViewModel] Demo Login unexpected error: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Publishing

    /// Publish authentication success event
    /// ✅ CORRECT: ViewModel publishes events (Repository does NOT)
    /// - Parameter user: Authenticated user
    private func publishAuthenticationEvent(previousUserId: String?, user: AuthUser) {
        Logger.debug("[LoginViewModel] Publishing user authentication event")

        if let previousUserId, previousUserId != user.uid {
            Logger.debug("[LoginViewModel] Detected user switch: \(previousUserId) -> \(user.uid)")
            CacheEventBus.shared.publish(.userLogout)
        }

        // Publish user data change event
        CacheEventBus.shared.publish(.dataChanged(.user))

        // 登入後拉取訂閱狀態（更新 SubscriptionStateManager）
        Task {
            let subscriptionRepository: SubscriptionRepository = DependencyContainer.shared.resolve()
            _ = try? await subscriptionRepository.refreshStatus()
            Logger.debug("[LoginViewModel] ✅ 訂閱狀態已刷新")
        }

        Logger.debug("[LoginViewModel] Authentication event published for user: \(user.uid)")
    }

    // MARK: - Error Handling Helpers

    /// Get user-friendly error message from ViewState
    /// - Returns: Localized error message or nil
    func getErrorMessage() -> String? {
        if case .error(let domainError) = state {
            return domainError.localizedDescription
        }
        return nil
    }

    /// Check if currently in error state
    var hasError: Bool {
        state.hasError
    }

    /// Check if currently loading
    var isLoading: Bool {
        state.isLoading
    }

    /// Get authenticated user if available
    var authenticatedUser: AuthUser? {
        state.data
    }
}
