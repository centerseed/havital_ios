import XCTest
@testable import paceriz_dev

/// demo session 冷啟動時，存著的 token 可能早已過期：`/auth/sync` body 的 id_token
/// 必須是續期後的那張，不然後端拒收、整個 session 恢復失敗（T-0876 外審 D02）。
final class AuthSessionRepositoryDemoSyncTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AuthSessionRepositoryDemoSyncTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testExpiredDemoSessionSyncsWithRefreshedToken() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let tokens = DemoTokenStore(
            defaults: defaults,
            now: { clock },
            refresher: { _ in
                DemoTokenStore.RefreshedToken(idToken: "fresh-token", refreshToken: "rt-2", expiresIn: 3600)
            }
        )
        tokens.set(idToken: "expired-token", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(7200)

        let httpClient = MockHTTPClient()
        let cache = MockAuthCache()
        cache.saveUser(AuthUser(
            uid: "demo-uid",
            email: "demo@paceriz.app",
            displayName: "Demo",
            photoURL: nil,
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            onboardingMode: .none
        ))
        let repository = AuthSessionRepositoryImpl(
            firebaseAuth: FirebaseAuthDataSource(),
            backendAuth: BackendAuthDataSource(httpClient: httpClient),
            authCache: cache,
            demoTokens: tokens
        )

        _ = try? await repository.fetchCurrentUser()

        let sync = try XCTUnwrap(
            httpClient.requestHistory.first { $0.path == "/auth/sync" },
            "demo session 恢復時要呼叫 /auth/sync"
        )
        let body = try XCTUnwrap(sync.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["id_token"] as? String, "fresh-token")
    }
}
