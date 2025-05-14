import Foundation
import Combine

/// Service for Email Registration, Login, and Verification
actor EmailAuthService {
    static let shared = EmailAuthService()
    private init() {}

    /// 註冊帳號
    func register(email: String, password: String) async throws -> RegisterData {
        let body = ["email": email, "password": password]
        let bodyData = try JSONEncoder().encode(body)
        return try await APIClient.shared.request(RegisterData.self,
                                                  path: "/register/email",
                                                  method: "POST",
                                                  body: bodyData)
    }

    /// Email 登入
    func login(email: String, password: String) async throws -> LoginData {
        let body = ["email": email, "password": password]
        let bodyData = try JSONEncoder().encode(body)
        do {
            return try await APIClient.shared.request(LoginData.self,
                                                      path: "/login/email",
                                                      method: "POST",
                                                      body: bodyData)
        } catch let error as NSError where error.code == 401 {
            // 未驗證
            throw AuthError.emailNotVerified
        }
    }

    /// 驗證 Email
    func verify(oobCode: String) async throws -> VerifyData {
        let body = ["oobCode": oobCode]
        let bodyData = try JSONEncoder().encode(body)
        return try await APIClient.shared.request(VerifyData.self,
                                                  path: "/verify/email",
                                                  method: "POST",
                                                  body: bodyData)
    }

    /// 重新發送驗證信
    func resendVerification(email: String, password: String) async throws -> ResendData {
        let body = ["email": email, "password": password]
        let bodyData = try JSONEncoder().encode(body)
        return try await APIClient.shared.request(ResendData.self,
                                                 path: "/resend/email",
                                                 method: "POST",
                                                 body: bodyData)
    }
}
