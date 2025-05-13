import Foundation
import FirebaseAuth

@MainActor
class EmailLoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let authService = AuthenticationService.shared

    func login() async {
        errorMessage = nil
        isLoading = true
        do {
            // 使用 Firebase 電子郵件登入
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            // 取得 Firebase ID Token
            let idToken = try await authResult.user.getIDToken()
            // 與後端同步用戶資料
            try await authService.syncUserWithBackend(idToken: idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
