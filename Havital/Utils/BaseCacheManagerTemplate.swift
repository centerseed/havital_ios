import Foundation

// MARK: - 基礎快取管理器模板
/// 為所有功能提供標準化的快取管理實現
/// 整合 CacheEventBus 系統，遵循 UnifiedWorkoutManager 的快取模式
class BaseCacheManagerTemplate<DataType: Codable>: BaseCacheManager {
    
    // MARK: - Type Definitions
    typealias CacheDataType = DataType
    
    // MARK: - Properties
    let cacheIdentifier: String
    let cacheKey: String
    let defaultTTL: TimeInterval
    
    // MARK: - Cache Structure
    private struct CacheContainer: Codable {
        let data: DataType
        let timestamp: Date
    }
    
    // MARK: - Initialization
    init(identifier: String, defaultTTL: TimeInterval = 1800) { // 30 minutes default
        self.cacheIdentifier = identifier
        self.cacheKey = "cache_\(identifier)"
        self.defaultTTL = defaultTTL
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
    }
    
    // MARK: - BaseCacheManager Implementation
    
    func saveToCache(_ data: DataType) {
        let container = CacheContainer(data: data, timestamp: Date())
        
        do {
            let encodedData = try JSONEncoder().encode(container)
            UserDefaults.standard.set(encodedData, forKey: cacheKey)
            
            Logger.firebase(
                "快取保存成功",
                level: .debug,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "data_size": encodedData.count
                ]
            )
        } catch {
            Logger.firebase(
                "快取保存失敗",
                level: .error,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    func loadFromCache() -> DataType? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let container = try JSONDecoder().decode(CacheContainer.self, from: data)
            
            Logger.firebase(
                "快取讀取成功",
                level: .debug,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "cache_age_seconds": Int(Date().timeIntervalSince(container.timestamp))
                ]
            )
            
            return container.data
        } catch {
            Logger.firebase(
                "快取讀取失敗，清除損壞的快取",
                level: .warn,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "error": error.localizedDescription
                ]
            )
            clearCache()
            return nil
        }
    }
    
    // MARK: - Cacheable Protocol Implementation
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        
        Logger.firebase(
            "快取已清除",
            level: .info,
            jsonPayload: ["cache_identifier": cacheIdentifier]
        )
        
        // 發送快取失效通知
        NotificationCenter.default.post(
            name: .cacheDidInvalidate,
            object: nil,
            userInfo: ["cacheIdentifier": cacheIdentifier]
        )
    }
    
    func getCacheSize() -> Int {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return 0 }
        return data.count
    }
    
    func isExpired() -> Bool {
        return shouldRefresh(customTTL: nil)
    }
    
    // MARK: - Enhanced Cache Management
    
    /// 檢查快取年齡
    func getCacheAge() -> TimeInterval? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        do {
            let container = try JSONDecoder().decode(CacheContainer.self, from: data)
            return Date().timeIntervalSince(container.timestamp)
        } catch {
            return nil
        }
    }
    
    /// 獲取快取時間戳
    func getCacheTimestamp() -> Date? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        do {
            let container = try JSONDecoder().decode(CacheContainer.self, from: data)
            return container.timestamp
        } catch {
            return nil
        }
    }
    
    /// 條件性快取更新（只有在數據不同時才更新）
    func updateCacheIfChanged(_ newData: DataType) -> Bool where DataType: Equatable {
        let existingData = loadFromCache()
        
        if let existing = existingData, existing == newData {
            // 數據相同，不需要更新
            return false
        }
        
        // 數據不同，更新快取
        saveToCache(newData)
        return true
    }
    
    /// 強制刷新快取（忽略 TTL）
    func forceRefresh(with data: DataType) {
        saveToCache(data)
    }
}

// MARK: - Cache Statistics
extension BaseCacheManagerTemplate {
    
    /// 獲取快取統計資訊
    func getCacheStats() -> BaseCacheStats {
        let size = getCacheSize()
        let age = getCacheAge() ?? 0
        let isExpired = self.isExpired()
        let timestamp = getCacheTimestamp()
        
        return BaseCacheStats(
            identifier: cacheIdentifier,
            sizeBytes: size,
            ageSeconds: age,
            isExpired: isExpired,
            lastUpdated: timestamp
        )
    }
}

// MARK: - Base Cache Statistics Model
struct BaseCacheStats {
    let identifier: String
    let sizeBytes: Int
    let ageSeconds: TimeInterval
    let isExpired: Bool
    let lastUpdated: Date?
    
    var sizeMB: Double {
        Double(sizeBytes) / (1024 * 1024)
    }
    
    var ageMinutes: Double {
        ageSeconds / 60
    }
    
    var formattedAge: String {
        if ageSeconds < 60 {
            return "\(Int(ageSeconds))秒前"
        } else if ageSeconds < 3600 {
            return "\(Int(ageMinutes))分鐘前"
        } else {
            let hours = Int(ageSeconds / 3600)
            return "\(hours)小時前"
        }
    }
}

