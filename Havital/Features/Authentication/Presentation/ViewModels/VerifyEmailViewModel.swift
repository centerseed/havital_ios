import Foundation

@MainActor
class VerifyEmailViewModel: ObservableObject, @preconcurrency TaskManageable {
    let taskRegistry = TaskRegistry()

    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let authRepository: AuthRepository

    init(authRepository: AuthRepository = DependencyContainer.shared.resolve()) {
        self.authRepository = authRepository
    }

    func verify() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        do {
            let data = try await authRepository.verifyEmail(oobCode: code)
            successMessage = data.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    deinit {
        cancelAllTasks()
    }
}
