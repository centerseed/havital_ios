import XCTest
@testable import paceriz_dev

/// 冷啟快照落地層（`App2FileSnapshotStore`）。
///
/// 三件事要守住：讀寫能對得起來、**換帳號讀不到前帳號的快照**、失效路徑真的刪檔。
///
/// 隔離沿用既有慣例（`WorkoutLocalDataSourceTests`／`MonthlyStatsLocalDataSourceTests`
/// 都是每條測試自己一個命名空間）：這裡走 UUID 命名的暫存目錄，tearDown 刪掉。
final class App2SnapshotStoreTests: XCTestCase {

    private struct Payload: Codable, Equatable {
        let headline: String
        let week: Int
    }

    private var directory: URL!
    private var uid: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("App2SnapshotStoreTests-\(UUID().uuidString)", isDirectory: true)
        uid = "uid-A"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func makeStore() -> App2FileSnapshotStore {
        App2FileSnapshotStore(directory: directory, currentUserID: { [weak self] in self?.uid })
    }

    // MARK: - 讀寫

    func testSaveThenLoadRoundTripsPayload() {
        let store = makeStore()
        let payload = Payload(headline: "穩住這一週", week: 6)

        store.save(payload, for: .stateToday)

        XCTAssertEqual(store.load(Payload.self, for: .stateToday)?.value, payload)
    }

    func testLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(makeStore().load(Payload.self, for: .recentWorkouts))
    }

    func testFetchedAtIsStamped() throws {
        let store = makeStore()
        let before = Date().addingTimeInterval(-1)
        store.save(Payload(headline: "H", week: 1), for: .recentWorkouts)

        let fetchedAt = try XCTUnwrap(store.load(Payload.self, for: .recentWorkouts)?.fetchedAt)
        // 目前不做 TTL 淘汰，只確認落地格式帶得動時間戳。
        XCTAssertGreaterThanOrEqual(fetchedAt, before)
        XCTAssertLessThanOrEqual(fetchedAt, Date().addingTimeInterval(1))
    }

    func testKeysDoNotCollide() {
        let store = makeStore()
        store.save(Payload(headline: "狀態", week: 1), for: .stateToday)
        store.save(Payload(headline: "課表", week: 2), for: .homeRecentWorkouts)

        XCTAssertEqual(store.load(Payload.self, for: .stateToday)?.value.headline, "狀態")
        XCTAssertEqual(store.load(Payload.self, for: .homeRecentWorkouts)?.value.headline, "課表")
    }

    // MARK: - uid 隔離

    /// 換帳號後**絕不能**讀到前一個帳號的快照 —— 這是這個 store 存在的第一條約束。
    func testSnapshotFromAnotherAccountIsNotReadable() {
        let store = makeStore()
        store.save(Payload(headline: "A 的狀態", week: 6), for: .stateToday)

        uid = "uid-B"
        XCTAssertNil(store.load(Payload.self, for: .stateToday))
    }

    /// 讀到不屬於自己的快照時就地清掉，換回 A 也不會再看到它。
    func testForeignSnapshotIsDiscardedOnRead() {
        let store = makeStore()
        store.save(Payload(headline: "A 的狀態", week: 6), for: .stateToday)

        uid = "uid-B"
        _ = store.load(Payload.self, for: .stateToday)

        uid = "uid-A"
        XCTAssertNil(store.load(Payload.self, for: .stateToday))
    }

    /// B 寫過之後回到 A：A 讀到的是 nil，不是 B 的資料。
    func testEachAccountOnlySeesItsOwnSnapshot() {
        let store = makeStore()
        uid = "uid-B"
        store.save(Payload(headline: "B 的狀態", week: 2), for: .stateToday)

        uid = "uid-A"
        XCTAssertNil(store.load(Payload.self, for: .stateToday))
    }

    /// 還沒登入（uid 未知）時不讀也不寫 —— 來源不明的快照不進畫面。
    func testNoUserIDMeansNoReadAndNoWrite() {
        let store = makeStore()
        store.save(Payload(headline: "H", week: 1), for: .stateToday)

        uid = nil
        XCTAssertNil(store.load(Payload.self, for: .stateToday))
        store.save(Payload(headline: "不該寫進去", week: 9), for: .recentWorkouts)

        uid = "uid-A"
        XCTAssertNil(store.load(Payload.self, for: .recentWorkouts))
        XCTAssertEqual(store.load(Payload.self, for: .stateToday)?.value.headline, "H")
    }

    // MARK: - 失效

    func testInvalidateRemovesOnlyTheGivenKeys() {
        let store = makeStore()
        store.save(Payload(headline: "狀態", week: 1), for: .stateToday)
        store.save(Payload(headline: "課表", week: 2), for: .homeRecentWorkouts)
        store.save(Payload(headline: "計畫狀態", week: 3), for: .recentWorkouts)

        store.invalidate([.homeRecentWorkouts, .recentWorkouts])

        XCTAssertEqual(store.load(Payload.self, for: .stateToday)?.value.headline, "狀態")
        XCTAssertNil(store.load(Payload.self, for: .homeRecentWorkouts))
        XCTAssertNil(store.load(Payload.self, for: .recentWorkouts))
    }

    func testClearAllRemovesEveryKey() {
        let store = makeStore()
        for key in App2SnapshotKey.allCases {
            store.save(Payload(headline: key.rawValue, week: 1), for: key)
        }

        store.clearAll()

        for key in App2SnapshotKey.allCases {
            XCTAssertNil(store.load(Payload.self, for: key), "\(key.rawValue) 沒清掉")
        }
    }

    /// 型別對不上（改過 DTO 形狀、或半寫入的檔）就丟掉，不讓它擋住這一輪重驗。
    func testCorruptSnapshotIsDiscarded() {
        struct Other: Codable { let totallyDifferent: [Int] }
        let store = makeStore()
        store.save(Payload(headline: "H", week: 1), for: .workoutStats)

        XCTAssertNil(store.load(Other.self, for: .workoutStats))
        // 丟掉之後連原本的型別也讀不到 —— 檔案已經不在。
        XCTAssertNil(store.load(Payload.self, for: .workoutStats))
    }
}
