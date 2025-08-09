import Foundation

// MARK: - 快取管理協議
protocol Cacheable: AnyObject {
    /// 快取的唯一識別符
    var cacheIdentifier: String { get }
    
    /// 清空快取
    func clearCache()
    
    /// 獲取快取大小（位元組）
    func getCacheSize() -> Int
    
    /// 檢查快取是否過期
    func isExpired() -> Bool
}

// MARK: - 快取事件監聽協議
protocol CacheEventListener: AnyObject {
    func onCacheInvalidated(for identifier: String, reason: CacheInvalidationReason)
}

// MARK: - 快取失效原因
enum CacheInvalidationReason {
    case userLogout
    case dataChanged(DataType)
    case manualClear
    case expired
}

// MARK: - 資料類型
enum DataType {
    case workouts
    case trainingPlan
    case weeklySummary
    case targets
    case user
    case healthData
    case hrv
    case vdot
}