import Foundation
import FirebaseCore

/// 審核／demo 登入的 token。這條登入沒有 Firebase session，SDK 不會幫它續期：
/// 後端用 demo 帳密換到的 ID token 一小時就過期，所以同一次登入拿到的 refresh token
/// 也存起來，快到期或後端回 401 時向 Firebase securetoken 換新的（T-0876）。
/// 沒有 refresh token 的 token（本機 dev 的 uid 字串）照舊原樣使用。
final class DemoTokenStore {

    struct RefreshedToken: Equatable {
        let idToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
    }

    typealias Refresher = (_ refreshToken: String) async throws -> RefreshedToken

    enum RefreshError: Error {
        case noRefreshToken
    }

    private enum Keys {
        static let idToken = "auth.demo_id_token"
        static let refreshToken = "auth.demo_refresh_token"
        static let expiresAt = "auth.demo_token_expires_at"
    }

    /// 剩這麼多秒就先換，避免請求送出途中剛好過期。
    static let refreshLeeway: TimeInterval = 300

    private let defaults: UserDefaults
    private let now: () -> Date
    private let refresher: Refresher
    private let lock = NSLock()
    private var inFlight: Task<RefreshedToken, Error>?

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        refresher: @escaping Refresher = FirebaseSecureTokenRefresher.refresh
    ) {
        self.defaults = defaults
        self.now = now
        self.refresher = refresher
    }

    var idToken: String? {
        defaults.string(forKey: Keys.idToken)
    }

    func set(idToken: String?, refreshToken: String? = nil, expiresIn: TimeInterval? = nil) {
        lock.lock()
        defer { lock.unlock() }
        inFlight?.cancel()
        inFlight = nil
        guard let idToken else {
            defaults.removeObject(forKey: Keys.idToken)
            defaults.removeObject(forKey: Keys.refreshToken)
            defaults.removeObject(forKey: Keys.expiresAt)
            return
        }
        defaults.set(idToken, forKey: Keys.idToken)
        if let refreshToken, !refreshToken.isEmpty {
            defaults.set(refreshToken, forKey: Keys.refreshToken)
        } else {
            defaults.removeObject(forKey: Keys.refreshToken)
        }
        if let expiresIn {
            defaults.set(now().addingTimeInterval(expiresIn).timeIntervalSince1970, forKey: Keys.expiresAt)
        } else {
            defaults.removeObject(forKey: Keys.expiresAt)
        }
    }

    /// 目前可用的 token；快到期就先換。換失敗時交回舊的，由後端的 401 → `forceRefresh` 再試一次。
    func currentToken() async -> String? {
        guard let token = idToken else { return nil }
        guard needsRefresh else { return token }
        return (try? await refresh().idToken) ?? token
    }

    /// 後端回 401 時呼叫：不看到期時間，直接用 refresh token 換。
    func forceRefresh() async throws -> String {
        try await refresh().idToken
    }

    private var needsRefresh: Bool {
        guard storedRefreshToken != nil else { return false }
        let expiresAt = defaults.double(forKey: Keys.expiresAt)
        guard expiresAt > 0 else { return true }
        return now().timeIntervalSince1970 >= expiresAt - Self.refreshLeeway
    }

    private var storedRefreshToken: String? {
        guard let token = defaults.string(forKey: Keys.refreshToken), !token.isEmpty else { return nil }
        return token
    }

    private func refresh() async throws -> RefreshedToken {
        let task: Task<RefreshedToken, Error>
        lock.lock()
        if let existing = inFlight {
            task = existing
        } else {
            guard let refreshToken = storedRefreshToken else {
                lock.unlock()
                throw RefreshError.noRefreshToken
            }
            let refresher = self.refresher
            task = Task { try await refresher(refreshToken) }
            inFlight = task
        }
        lock.unlock()

        do {
            let refreshed = try await task.value
            lock.lock()
            if inFlight == task {
                inFlight = nil
                defaults.set(refreshed.idToken, forKey: Keys.idToken)
                defaults.set(refreshed.refreshToken, forKey: Keys.refreshToken)
                defaults.set(
                    now().addingTimeInterval(refreshed.expiresIn).timeIntervalSince1970,
                    forKey: Keys.expiresAt
                )
            }
            lock.unlock()
            return refreshed
        } catch {
            lock.lock()
            if inFlight == task { inFlight = nil }
            lock.unlock()
            throw error
        }
    }
}

/// Firebase securetoken REST：用 refresh token 換新的 ID token。
enum FirebaseSecureTokenRefresher {

    private struct Response: Decodable {
        let idToken: String
        let refreshToken: String
        let expiresIn: String

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    static func refresh(_ refreshToken: String) async throws -> DemoTokenStore.RefreshedToken {
        guard let apiKey = FirebaseApp.app()?.options.apiKey,
              var components = URLComponents(string: "https://securetoken.googleapis.com/v1/token") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return DemoTokenStore.RefreshedToken(
            idToken: decoded.idToken,
            refreshToken: decoded.refreshToken,
            expiresIn: TimeInterval(decoded.expiresIn) ?? 3600
        )
    }
}
