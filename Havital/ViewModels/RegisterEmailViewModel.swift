import Foundation
import Combine
import Havital
import SwiftUI

@MainActor
class RegisterEmailViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func register() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        do {
            let data = try await EmailAuthService.shared.register(email: email, password: password)
            successMessage = data.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
