import Foundation
import FirebaseAuth

@MainActor
class EmailLoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var canResendVerification = false
    @Published var errorMessage: String?
    @Published var resendSuccessMessage: String?
    private let authService = AuthenticationService.shared

    func login() async {
        errorMessage = nil
        canResendVerification = false
        isLoading = true
        do {
            
            // 呼叫後端 login API (401 會轉為 AuthError.emailNotVerified)
            _ = try await EmailAuthService.shared.login(email: email, password: password)
            // 使用 Firebase 電子郵件登入並取得 Firebase ID Token
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let idToken = try await authResult.user.getIDToken()
            // 驗證通過後，同步用戶資料
            try await authService.syncUserWithBackend(idToken: idToken)
        } catch AuthError.emailNotVerified {
            errorMessage = "請點擊驗證信中的連結完成驗證後再登入。"
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
            try await EmailAuthService.shared.resendVerification(email: email, password: password)
            resendSuccessMessage = "已重新發送驗證信，請至信箱查看。"
        } catch {
            resendSuccessMessage = error.localizedDescription
        }
    }
}
