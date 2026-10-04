import XCTest
@testable import paceriz_dev

/// 審核／demo 登入沒有 Firebase session：後端換到的 ID token 一小時就過期，
/// App 要用同一次登入拿到的 refresh token 自己續期，否則用超過一小時就全部 401（T-0876）。
final class DemoTokenStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var clock: Date!

    override func setUp() {
        super.setUp()
        suiteName = "DemoTokenStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        clock = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore(
        refresher: @escaping DemoTokenStore.Refresher = { _ in
            XCTFail("refresher should not be called")
            throw URLError(.badServerResponse)
        }
    ) -> DemoTokenStore {
        DemoTokenStore(defaults: defaults, now: { [unowned self] in self.clock }, refresher: refresher)
    }

    func testFreshTokenIsReturnedWithoutRefreshing() async {
        let store = makeStore()
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)

        let token = await store.currentToken()

        XCTAssertEqual(token, "id-1")
    }

    func testTokenNearExpiryIsRefreshedAndPersisted() async {
        var calls: [String] = []
        let store = makeStore { refreshToken in
            calls.append(refreshToken)
            return DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(3600 - 60)

        let token = await store.currentToken()

        XCTAssertEqual(token, "id-2")
        XCTAssertEqual(calls, ["rt-1"])
        let relaunched = makeStore()
        XCTAssertEqual(relaunched.idToken, "id-2", "續期後的 token 要撐過 App 重開")
        let afterRelaunch = await relaunched.currentToken()
        XCTAssertEqual(afterRelaunch, "id-2")
    }

    func testExpiredTokenAfterRelaunchIsRefreshedWithPersistedRefreshToken() async {
        makeStore().set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(7200)
        var calls: [String] = []
        let relaunched = makeStore { refreshToken in
            calls.append(refreshToken)
            return DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }

        let token = await relaunched.currentToken()

        XCTAssertEqual(token, "id-2")
        XCTAssertEqual(calls, ["rt-1"])
    }

    func testForceRefreshUsesRefreshTokenEvenWhenNotNearExpiry() async throws {
        let store = makeStore { _ in
            DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)

        let token = try await store.forceRefresh()

        XCTAssertEqual(token, "id-2")
        XCTAssertEqual(store.idToken, "id-2")
    }

    func testTokenWithoutRefreshTokenIsKeptAsIs() async {
        let store = makeStore()
        store.set(idToken: "local-uid-token", refreshToken: nil, expiresIn: nil)
        clock = clock.addingTimeInterval(86_400)

        let token = await store.currentToken()

        XCTAssertEqual(token, "local-uid-token")
    }

    func testForceRefreshWithoutRefreshTokenThrows() async {
        let store = makeStore()
        store.set(idToken: "local-uid-token", refreshToken: "", expiresIn: 3600)

        do {
            _ = try await store.forceRefresh()
            XCTFail("expected forceRefresh to throw without a refresh token")
        } catch {}
    }

    func testFailedRefreshKeepsExistingToken() async {
        let store = makeStore { _ in throw URLError(.notConnectedToInternet) }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(3600)

        let token = await store.currentToken()

        XCTAssertEqual(token, "id-1")
    }

    /// 續期還沒回來就登出：晚到的結果不得把已清掉的 session 寫回去，也不得交回舊 token。
    func testLateRefreshAfterClearIsDiscarded() async {
        let gate = RefreshGate()
        let store = makeStore { _ in
            await gate.wait()
            return DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(3600)

        let pending = Task { await store.currentToken() }
        await gate.waitUntilEntered()
        store.set(idToken: nil)
        await gate.open()

        let token = await pending.value
        XCTAssertNil(token)
        XCTAssertNil(store.idToken)
        XCTAssertNil(makeStore().idToken)
    }

    /// 續期途中換成另一個 session：晚到的結果不得覆蓋新 session。
    func testLateRefreshAfterReplacementKeepsNewSession() async {
        let gate = RefreshGate()
        let store = makeStore { _ in
            await gate.wait()
            return DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)
        clock = clock.addingTimeInterval(3600)

        let pending = Task { await store.currentToken() }
        await gate.waitUntilEntered()
        store.set(idToken: "other-session", refreshToken: "rt-other", expiresIn: 3600)
        await gate.open()

        let token = await pending.value
        XCTAssertEqual(token, "other-session")
        XCTAssertEqual(store.idToken, "other-session")
    }

    func testForceRefreshAfterClearThrows() async {
        let gate = RefreshGate()
        let store = makeStore { _ in
            await gate.wait()
            return DemoTokenStore.RefreshedToken(idToken: "id-2", refreshToken: "rt-2", expiresIn: 3600)
        }
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)

        let pending = Task { try await store.forceRefresh() }
        await gate.waitUntilEntered()
        store.set(idToken: nil)
        await gate.open()

        do {
            _ = try await pending.value
            XCTFail("expected forceRefresh to fail after the session was cleared")
        } catch {}
        XCTAssertNil(store.idToken)
    }

    func testClearingRemovesTokenAndRefreshState() async {
        let store = makeStore()
        store.set(idToken: "id-1", refreshToken: "rt-1", expiresIn: 3600)

        store.set(idToken: nil)

        XCTAssertNil(store.idToken)
        XCTAssertNil(makeStore().idToken)
        do {
            _ = try await makeStore().forceRefresh()
            XCTFail("expected no refresh token after clearing")
        } catch {}
    }
}

/// 讓 refresher 停在半路，測「續期途中登出／換 session」。
private actor RefreshGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var entered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
