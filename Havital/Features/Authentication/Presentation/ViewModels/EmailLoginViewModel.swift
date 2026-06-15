import Foundation

@MainActor
class EmailLoginViewModel: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()

    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var canResendVerification = false
    @Published var errorMessage: String?
    @Published var resendSuccessMessage: String?
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository = DependencyContainer.shared.resolve()) {
        self.authRepository = authRepository
    }

    func login() async {
        errorMessage = nil
        canResendVerification = false
        isLoading = true
        do {
            _ = try await authRepository.signInWithEmail(email: email, password: password)
        } catch AuthError.emailNotVerified {
            errorMessage = NSLocalizedString("auth.email_not_verified_login_message", comment: "Email sign-in blocked until the user verifies their email")
            canResendVerification = true
        } catch {
            errorMessage = error.localizedDescription
            canResendVerification = false
        }
        isLoading = false
    }

    /// 重新發送驗證信
    func resendVerification() async {
        do {
            try await authRepository.resendEmailVerification(email: email, password: password)
            resendSuccessMessage = NSLocalizedString("auth.verification_email_resent", comment: "Verification email resent confirmation")
        } catch {
            resendSuccessMessage = error.localizedDescription
        }
    }

    deinit {
        cancelAllTasks()
    }
}
