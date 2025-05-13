import Foundation

@MainActor
class VerifyEmailViewModel: ObservableObject {
    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func verify() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        do {
            let data = try await EmailAuthService.shared.verify(oobCode: code)
            successMessage = data.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
