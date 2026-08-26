import FirebaseAuth
import Foundation

// MARK: - App2SnapshotKey
/// 一個 key ＝ **一支端點的最後一次成功回應**。
///
/// 快照只是顯示層快取：冷啟先把上一次的畫面渲染出來，背景重驗成功後靜默替換。
/// 它不是第二份真相 —— 沒有任何寫入路徑讀它，也不做離線編輯。
///
/// **為什麼不沿用既有的 LocalDataSource 快取**（`TrainingPlanV2LocalDataSource`
/// 等，全在 UserDefaults）：那一組是 repository 的 dual-track 快取，key 是靜態的、
/// 不帶 uid，且 `.dataChanged(.user)` 每次啟動都會清掉大部分（`CacheEventBus`
/// 的 `preservedCaches` 只留課表那一份）。冷啟先渲染需要的是「不隨啟動被清、
/// 且換帳號一定讀不到」，兩條都不成立，所以這裡是一份獨立的顯示層落地，
/// 不是把既有快取抄一遍。
enum App2SnapshotKey: String, CaseIterable {
    /// `GET /v2/plan/status`
    case planStatus = "v2_plan_status"
    /// `GET /v2/state/today`（由 `DailyStateRepositoryImpl` 落地 DTO，不落 entity）
    case stateToday = "v2_state_today"
    /// `GET /v2/plan/weekly/{plan_id}` —— 本週那一份。首頁今日卡與課表頁共用同一份。
    case weeklyPlan = "v2_plan_weekly_current"
    /// `GET /v2/workouts` 的紀錄頁那一頁（含月量彙總需要的筆數）。
    case recentWorkouts = "v2_workouts_recent"
    /// `GET /v2/workouts` 的首頁那一頁（只為了判「今天跑完沒」）。
    /// **與紀錄頁分兩個 key**：兩邊 pageSize 不同，共用一個 key 會讓紀錄頁的
    /// 「較上月」拿首頁那 10 筆去算（`monthlyTotals` 的 `coversLastMonth` 誤判成 true）。
    case homeRecentWorkouts = "v2_workouts_recent_home"
    /// `GET /v2/workouts/stats`
    case workoutStats = "v2_workouts_stats"
}

// MARK: - App2Snapshot
/// 落地的一筆快照：payload ＋ 取得時間。
///
/// `fetchedAt` 目前**不做 TTL 淘汰**（顯示層永遠先給舊的，再靜默換新），
/// 存著是為了日後要標「資料為 X 分鐘前」時不必再改落地格式。
struct App2Snapshot<Value> {
    let value: Value
    let fetchedAt: Date
}

// MARK: - App2SnapshotStoring
/// **不綁 actor**：寫入端有 repository（可能在背景 task），讀取端是 `@MainActor`
/// 的 ViewModel。實作自己用鎖保證安全，呼叫端不必為了落地換執行緒。
protocol App2SnapshotStoring: AnyObject {
    func load<Value: Decodable>(_ type: Value.Type, for key: App2SnapshotKey) -> App2Snapshot<Value>?
    func save<Value: Encodable>(_ value: Value, for key: App2SnapshotKey)
    func invalidate(_ keys: Set<App2SnapshotKey>)
    func clearAll()
}

// MARK: - App2FileSnapshotStore
/// JSON 落地在 Application Support/`App2Snapshots/<key>.json`。
///
/// **每一筆都蓋上寫入當下的 uid**，讀取時 uid 對不上就當作沒有快照 ——
/// 換帳號絕不能吃到前一個帳號的畫面。登出另有一條清空路徑
/// （`CacheRegistrationCoordinator` 訂閱 `.userLogout`），uid 戳是它的第二道保險：
/// 清空失敗、或清空前就被讀到，都還有這一層擋著。既有的 LocalDataSource 快取
/// 全部沒有這一層，所以這裡不沿用它們的 key 慣例。
///
/// 沒有 uid（尚未登入／auth 還沒恢復）時**不讀也不寫**：來源不明的快照不進畫面。
final class App2FileSnapshotStore: App2SnapshotStoring, @unchecked Sendable {

    static let shared = App2FileSnapshotStore()

    private let directory: URL
    private let currentUserID: () -> String?
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    /// 同一個 key 可能同時被背景寫入與主執行緒讀取（例如首頁重驗時課表頁剛好冷啟）。
    private let lock = NSLock()

    init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        currentUserID: @escaping () -> String? = App2FileSnapshotStore.defaultUserID
    ) {
        self.fileManager = fileManager
        self.currentUserID = currentUserID
        self.directory = directory ?? Self.defaultDirectory(fileManager: fileManager)
    }

    // MARK: - App2SnapshotStoring

    func load<Value: Decodable>(_ type: Value.Type, for key: App2SnapshotKey) -> App2Snapshot<Value>? {
        guard let uid = currentUserID() else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        do {
            let envelope = try decoder.decode(ReadEnvelope<Value>.self, from: data)
            guard envelope.uid == uid else {
                // 前一個帳號留下來的。當作沒有，並就地清掉。
                Logger.debug("[App2Snapshot] uid 不符,丟棄 \(key.rawValue)")
                try? fileManager.removeItem(at: url(for: key))
                return nil
            }
            return App2Snapshot(
                value: envelope.payload,
                fetchedAt: Date(timeIntervalSince1970: envelope.fetchedAt)
            )
        } catch {
            // 舊格式／半寫入的檔：丟掉重來，不讓它擋住這一輪的重驗。
            Logger.debug("[App2Snapshot] \(key.rawValue) 解不開,丟棄: \(error)")
            try? fileManager.removeItem(at: url(for: key))
            return nil
        }
    }

    func save<Value: Encodable>(_ value: Value, for key: App2SnapshotKey) {
        guard let uid = currentUserID() else { return }
        lock.lock()
        defer { lock.unlock() }
        let envelope = WriteEnvelope(
            uid: uid,
            fetchedAt: Date().timeIntervalSince1970,
            payload: value
        )
        do {
            try ensureDirectory()
            let data = try encoder.encode(envelope)
            try data.write(to: url(for: key), options: .atomic)
        } catch {
            // 落地失敗不影響這一輪的畫面 —— 下次冷啟就是沒有快照而已。
            Logger.debug("[App2Snapshot] \(key.rawValue) 寫入失敗: \(error)")
        }
    }

    func invalidate(_ keys: Set<App2SnapshotKey>) {
        lock.lock()
        defer { lock.unlock() }
        for key in keys {
            try? fileManager.removeItem(at: url(for: key))
        }
    }

    func clearAll() {
        invalidate(Set(App2SnapshotKey.allCases))
    }

    // MARK: - Private

    private func url(for key: App2SnapshotKey) -> URL {
        directory.appendingPathComponent("\(key.rawValue).json")
    }

    private func ensureDirectory() throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        // 顯示層快取，不必進 iCloud 備份。
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("App2Snapshots", isDirectory: true)
    }

    /// 目前登入者的 uid。Demo 登入沒有 Firebase session，走既有的 auth session 快取
    /// （`AuthSessionRepositoryImpl.getCurrentUser()` 會補上持久化的 demo user）。
    static func defaultUserID() -> String? {
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty { return uid }
        let container = DependencyContainer.shared
        guard container.isRegistered(AuthSessionRepository.self) else { return nil }
        let repository = container.resolve() as AuthSessionRepository
        return repository.getCurrentUser()?.uid
    }

    // MARK: - Envelope

    private struct WriteEnvelope<Value: Encodable>: Encodable {
        let uid: String
        let fetchedAt: Double
        let payload: Value
    }

    private struct ReadEnvelope<Value: Decodable>: Decodable {
        let uid: String
        let fetchedAt: Double
        let payload: Value
    }
}
