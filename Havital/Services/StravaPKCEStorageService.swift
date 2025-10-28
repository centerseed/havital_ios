import Foundation

/// Strava PKCE 存儲服務
/// 負責在 OAuth 流程開始前將 PKCE 參數保存到後端
class StravaPKCEStorageService {
    static let shared = StravaPKCEStorageService()

    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Unified API Call Method

    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }

    // MARK: - API Methods

    /// 保存 Strava PKCE 參數到後端
    /// - Parameters:
    ///   - codeVerifier: PKCE code verifier (128 字符)
    ///   - state: OAuth state 參數
    ///   - forceReplace: 是否強制替換現有連接
    /// - Throws: APIError 如果請求失敗
    func storePKCEParameters(codeVerifier: String, state: String, forceReplace: Bool = false) async throws {
        let requestBody: [String: Any] = [
            "code_verifier": codeVerifier,
            "state": state,
            "force_replace": forceReplace
        ]

        let body = try JSONSerialization.data(withJSONObject: requestBody)

        print("🔐 [StravaPKCEStorageService] 開始保存 PKCE 參數到後端")
        print("  - Code Verifier 長度: \(codeVerifier.count)")
        print("  - State: \(state.prefix(20))...")
        print("  - Force Replace: \(forceReplace)")

        do {
            _ = try await httpClient.request(
                path: "/connect/strava/store-pkce",
                method: .POST,
                body: body
            )

            print("✅ [StravaPKCEStorageService] PKCE 參數已成功保存到後端")

            Logger.debug("Strava PKCE 參數已保存")

        } catch {
            print("❌ [StravaPKCEStorageService] 保存 PKCE 參數失敗: \(error.localizedDescription)")

            Logger.error("Strava PKCE 保存失敗: \(error.localizedDescription)")

            throw error
        }
    }
}

// MARK: - Response Models (如果需要)

/// PKCE 存儲回應
struct StravaPKCEStorageResponse: Codable {
    let success: Bool
    let message: String
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case success, message
        case sessionId = "session_id"
    }
}
