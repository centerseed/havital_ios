import Foundation
import Combine

/// Service for Email Registration, Login, and Verification
actor EmailAuthService {
    static let shared = EmailAuthService()
    private init() {}

    /// 註冊帳號
    func register(email: String, password: String) async throws -> RegisterData {
        let path = "/auth/register/email"
        guard let url = URL(string: APIConfig.baseURL + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "EmailAuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<RegisterData>.self, from: data)
        return apiResponse.data
    }

    /// Email 登入
    func login(email: String, password: String) async throws -> LoginData {
        let path = "/auth/login/email"
        guard let url = URL(string: APIConfig.baseURL + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "EmailAuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<LoginData>.self, from: data)
        return apiResponse.data
    }

    /// 驗證 Email
    func verify(oobCode: String) async throws -> VerifyData {
        let path = "/auth/verify/email"
        guard let url = URL(string: APIConfig.baseURL + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["oobCode": oobCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "EmailAuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<VerifyData>.self, from: data)
        return apiResponse.data
    }
}