import Foundation

// MARK: - App2MetricDetailCache
/// 指標詳情的 session 級快取（T-0357）。
///
/// 三個詳情 VM 是 push 進場時的 `@StateObject`——每次進頁都是新實例，沒有這層
/// 快取就每次都全頁 spinner 重抓。這裡存的是**抓回來的事實**（DTO 回應），不是
/// 投影後的畫面模型：hero 吃的 insight 來自首頁那一列、每次進頁都是新的，
/// 快取投影結果會把舊 insight 一起凍住；快取事實、投影現算，兩邊永遠一致。
///
/// **為什麼不是既有輪子**（2026-08-31 盤點）：`App2FileSnapshotStore` 是冷啟檔案
/// 快照（Codable、跨啟動），這裡只要 session 內秒開，DTO 不必為此加 Codable 落地；
/// `DualTrackCacheHelper` 是策略框架、無存儲；`VDOTService`／stats／health_daily
/// data source 均無快取。失效佈線同一落點（`CacheRegistrationCoordinator`），
/// 不是第二套失效路徑。
@MainActor
final class App2MetricDetailCache {
    static let shared = App2MetricDetailCache()

    struct Entry<Payload> {
        let payload: Payload
        let loadedAt: Date
    }

    struct VolumePayload {
        let stats: WorkoutStatsResponse
        let health: HealthDailyResponse?
        let targetKm: Double?
    }

    private(set) var volume: [App2MetricRange: Entry<VolumePayload>] = [:]
    private(set) var capability: [App2MetricRange: Entry<VDOTResponse>] = [:]
    private(set) var recovery: Entry<HealthDailyResponse>?

    /// 失效世代：`removeAll()` 遞增一次。
    ///
    /// 沒有這個數字，「事件清空之前起飛、清空之後才回來」的那一輪會把**清空前的
    /// 事實**重新填回已經清乾淨的快取——推播說資料變了，快取卻立刻長回舊的一份，
    /// 而且會黏著給下一次進頁用（2026-09-01 外審第二輪 D04）。重驗輪在發請求前
    /// 記下當時的世代，回來時對不上就不寫。
    private(set) var invalidationEpoch = 0

    func storeVolume(_ payload: VolumePayload, range: App2MetricRange, loadedAt: Date = Date()) {
        volume[range] = Entry(payload: payload, loadedAt: loadedAt)
    }

    func storeCapability(_ response: VDOTResponse, range: App2MetricRange, loadedAt: Date = Date()) {
        capability[range] = Entry(payload: response, loadedAt: loadedAt)
    }

    func storeRecovery(_ response: HealthDailyResponse, loadedAt: Date = Date()) {
        recovery = Entry(payload: response, loadedAt: loadedAt)
    }

    func removeAll() {
        volume.removeAll()
        capability.removeAll()
        recovery = nil
        invalidationEpoch += 1
    }

    /// 只有「這一輪起飛之後沒被清空過」才寫。世代對不上＝這份事實已經被事件
    /// 宣告過時，寫回去只會讓下一次進頁又吃到它。
    ///
    /// **畫面照發**（呼叫端負責）：這一輪沒有接手的新輪，丟掉就是一片空白，而且
    /// 沒有任何東西會再去抓。快取留空 ⇒ 下次進頁 miss 重抓，失效仍然生效。
    func storeIfCurrent(epoch: Int, _ store: (App2MetricDetailCache) -> Void) {
        guard invalidationEpoch == epoch else { return }
        store(self)
    }
}
