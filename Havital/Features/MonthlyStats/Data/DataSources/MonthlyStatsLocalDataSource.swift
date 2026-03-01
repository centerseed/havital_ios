import Foundation

// MARK: - MonthlyStats Local Data Source
/// 月度統計 Local Data Source - Data Layer
/// 負責管理月度統計的數據緩存和同步時間戳（永久 TTL）
final class MonthlyStatsLocalDataSource {

    // MARK: - Constants

    private enum Keys {
        /// 時間戳前綴
        static let timestampPrefix = "monthly_stats_timestamp_"
        /// 數據緩存前綴
        static let dataPrefix = "monthly_stats_data_"
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults

    /// ✅ 實際數據緩存管理器（永久 TTL = 365 天）
    /// 格式：存儲每個月份的 [DailyStat] 數據
    private var dataCacheManagers: [String: BaseCacheManagerTemplate<[DailyStat]>] = [:]

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        Logger.debug("[MonthlyStatsLocalDataSource] 初始化完成")
    }

    // MARK: - Data Management

    /// 獲取指定月份的月度統計數據（從緩存）
    /// ✅ Clean Architecture: 永遠返回可用數據，不因 TTL 拒絕返回
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 每日統計數據列表，nil 表示未緩存過
    func getMonthlyStats(year: Int, month: Int) -> [DailyStat]? {
        let cacheKey = dataCacheKey(year: year, month: month)
        let cacheManager = getOrCreateCacheManager(for: cacheKey)

        let stats = cacheManager.loadFromCache()

        if let stats = stats {
            if cacheManager.isExpired() {
                Logger.debug("[MonthlyStatsLocalDataSource] 緩存已過期但仍返回，\(year)-\(String(format: "%02d", month))，數量: \(stats.count)")
            } else {
                Logger.debug("[MonthlyStatsLocalDataSource] 緩存有效，\(year)-\(String(format: "%02d", month))，數量: \(stats.count)")
            }
        } else {
            Logger.debug("[MonthlyStatsLocalDataSource] 無緩存數據，\(year)-\(String(format: "%02d", month))")
        }

        return stats
    }

    /// 保存月度統計數據到緩存
    /// - Parameters:
    ///   - stats: 每日統計數據列表
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    func saveMonthlyStats(_ stats: [DailyStat], year: Int, month: Int) {
        let cacheKey = dataCacheKey(year: year, month: month)
        let cacheManager = getOrCreateCacheManager(for: cacheKey)

        cacheManager.saveToCache(stats)
        Logger.debug("[MonthlyStatsLocalDataSource] saveMonthlyStats - 已保存 \(year)-\(String(format: "%02d", month))，共 \(stats.count) 條記錄")
    }

    // MARK: - Timestamp Management

    /// 獲取指定月份的同步時間戳
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 同步時間，nil 表示未同步過
    func getSyncTimestamp(year: Int, month: Int) -> Date? {
        let key = timestampKey(year: year, month: month)
        return userDefaults.object(forKey: key) as? Date
    }

    /// 設置指定月份的同步時間戳
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    func setSyncTimestamp(year: Int, month: Int) {
        let key = timestampKey(year: year, month: month)
        userDefaults.set(Date(), forKey: key)
        Logger.debug("[MonthlyStatsLocalDataSource] 月度時間戳已保存: \(year)-\(String(format: "%02d", month))")
    }

    /// 檢查指定月份是否已同步過
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: true 表示已同步（有時間戳），false 表示未同步
    func hasSynced(year: Int, month: Int) -> Bool {
        return getSyncTimestamp(year: year, month: month) != nil
    }

    /// 清除指定月份的同步時間戳（手動刷新時使用）
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    func clearSyncTimestamp(year: Int, month: Int) {
        let key = timestampKey(year: year, month: month)
        userDefaults.removeObject(forKey: key)
        Logger.debug("[MonthlyStatsLocalDataSource] 月度時間戳已清除: \(year)-\(String(format: "%02d", month))")
    }

    /// 清除所有月度統計時間戳和數據緩存（登出時調用）
    func clearAll() {
        // 清除時間戳
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let timestampKeys = allKeys.filter { $0.hasPrefix(Keys.timestampPrefix) }

        timestampKeys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }

        // 清除所有數據緩存
        dataCacheManagers.values.forEach { manager in
            manager.clearCache()
        }
        dataCacheManagers.removeAll()

        Logger.debug("[MonthlyStatsLocalDataSource] 已清除 \(timestampKeys.count) 個月度時間戳和所有數據緩存")
    }

    /// 獲取所有已同步的月份列表（用於調試）
    func getAllSyncedMonths() -> [(year: Int, month: Int, timestamp: Date)] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let timestampKeys = allKeys.filter { $0.hasPrefix(Keys.timestampPrefix) }

        var result: [(year: Int, month: Int, timestamp: Date)] = []

        for key in timestampKeys {
            // 解析 key: "monthly_stats_timestamp_2024_01"
            let components = key.replacingOccurrences(of: Keys.timestampPrefix, with: "").split(separator: "_")
            guard components.count == 2,
                  let year = Int(components[0]),
                  let month = Int(components[1]),
                  let timestamp = userDefaults.object(forKey: key) as? Date else {
                continue
            }

            result.append((year: year, month: month, timestamp: timestamp))
        }

        return result.sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    // MARK: - Helper Methods

    /// 構建時間戳 Key
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: UserDefaults Key（格式：monthly_stats_timestamp_2024_01）
    private func timestampKey(year: Int, month: Int) -> String {
        return "\(Keys.timestampPrefix)\(year)_\(String(format: "%02d", month))"
    }

    /// 構建數據緩存 Key
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: Cache Key（格式：monthly_stats_data_2024_01）
    private func dataCacheKey(year: Int, month: Int) -> String {
        return "\(Keys.dataPrefix)\(year)_\(String(format: "%02d", month))"
    }

    /// 獲取或創建指定月份的 CacheManager
    /// - Parameter cacheKey: 緩存 key
    /// - Returns: BaseCacheManagerTemplate 實例
    private func getOrCreateCacheManager(for cacheKey: String) -> BaseCacheManagerTemplate<[DailyStat]> {
        if let existing = dataCacheManagers[cacheKey] {
            return existing
        }

        // 創建新的 CacheManager（永久 TTL = 365 天）
        let manager = BaseCacheManagerTemplate<[DailyStat]>(
            identifier: cacheKey,
            defaultTTL: 365 * 24 * 60 * 60  // 365 天
        )

        dataCacheManagers[cacheKey] = manager
        return manager
    }
}
