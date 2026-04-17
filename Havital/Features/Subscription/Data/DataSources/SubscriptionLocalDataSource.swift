import Foundation

// MARK: - SubscriptionLocalDataSource Protocol
protocol SubscriptionLocalDataSourceProtocol {
    func getStatus() -> SubscriptionStatusDTO?
    func saveStatus(_ dto: SubscriptionStatusDTO)
    func isExpired() -> Bool
    func clearAll()
}

// MARK: - SubscriptionLocalDataSource
/// 訂閱狀態本地緩存 - Data Layer
/// 使用 UserDefaults + JSONEncoder + TTL timestamp
final class SubscriptionLocalDataSource: SubscriptionLocalDataSourceProtocol {

    // MARK: - Constants

    private enum Keys {
        static let statusData = "subscription_status_v1"
        static let timestamp = "subscription_status_v1_timestamp"
    }

    private enum TTL {
        /// 緩存有效期 300 秒（5 分鐘）
        static let status: TimeInterval = 300
    }

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        CacheEventBus.shared.register(self)
    }

    // MARK: - Read

    /// 取得緩存的訂閱狀態 DTO
    func getStatus() -> SubscriptionStatusDTO? {
        guard let data = defaults.data(forKey: Keys.statusData) else {
            return nil
        }

        do {
            return try decoder.decode(SubscriptionStatusDTO.self, from: data)
        } catch {
            Logger.debug("[SubscriptionLocalDS] Failed to decode status, clearing cache")
            clearAll()
            return nil
        }
    }

    // MARK: - Write

    /// 儲存訂閱狀態 DTO 到緩存
    func saveStatus(_ dto: SubscriptionStatusDTO) {
        do {
            let data = try encoder.encode(dto)
            defaults.set(data, forKey: Keys.statusData)
            // 使用 TimeInterval（Unix timestamp）儲存，避免 Date as key 問題
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.timestamp)
            Logger.debug("[SubscriptionLocalDS] Status saved to cache")
        } catch {
            Logger.error("[SubscriptionLocalDS] Failed to encode status: \(error)")
        }
    }

    // MARK: - TTL Check

    /// 檢查緩存是否已過期
    func isExpired() -> Bool {
        let savedTimestamp = defaults.double(forKey: Keys.timestamp)
        // double 預設回傳 0，表示從未儲存過
        guard savedTimestamp > 0 else {
            return true
        }
        let elapsed = Date().timeIntervalSince1970 - savedTimestamp
        return elapsed > TTL.status
    }

    // MARK: - Clear

    /// 清除所有緩存數據
    func clearAll() {
        defaults.removeObject(forKey: Keys.statusData)
        defaults.removeObject(forKey: Keys.timestamp)
        Logger.debug("[SubscriptionLocalDS] Cache cleared")
    }
}

// MARK: - Cacheable Protocol Conformance
extension SubscriptionLocalDataSource: Cacheable {

    var cacheIdentifier: String {
        return "SubscriptionLocalDataSource"
    }

    func clearCache() {
        clearAll()
    }

    func getCacheSize() -> Int {
        if let data = defaults.data(forKey: "subscription_status_v1") {
            return data.count
        }
        return 0
    }
}
