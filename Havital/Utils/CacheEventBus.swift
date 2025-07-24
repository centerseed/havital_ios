import Foundation

// MARK: - 快取事件總線
class CacheEventBus {
    static let shared = CacheEventBus()
    
    private var cacheables: [Cacheable] = []
    private var listeners: [CacheEventListener] = []
    
    private init() {}
    
    // MARK: - 註冊管理
    
    func register(_ cacheable: Cacheable) {
        // 避免重複註冊
        if !cacheables.contains(where: { $0.cacheIdentifier == cacheable.cacheIdentifier }) {
            cacheables.append(cacheable)
            Logger.firebase("快取管理器已註冊", level: .info, jsonPayload: [
                "cache_identifier": cacheable.cacheIdentifier
            ])
        }
    }
    
    func addListener(_ listener: CacheEventListener) {
        listeners.append(listener)
    }
    
    // MARK: - 快取失效管理
    
    func invalidateCache(for reason: CacheInvalidationReason) {
        switch reason {
        case .userLogout:
            invalidateAllCaches()
        case .dataChanged(let dataType):
            invalidateRelatedCaches(for: dataType)
        case .manualClear:
            invalidateAllCaches()
        case .expired:
            invalidateExpiredCaches()
        }
        
        notifyListeners(reason: reason)
    }
    
    // MARK: - Private Methods
    
    private func invalidateAllCaches() {
        for cacheable in cacheables {
            cacheable.clearCache()
        }
        Logger.firebase("所有快取已清空", level: .info)
    }
    
    private func invalidateRelatedCaches(for dataType: DataType) {
        let relatedIdentifiers = getRelatedCacheIdentifiers(for: dataType)
        
        for cacheable in cacheables {
            if relatedIdentifiers.contains(cacheable.cacheIdentifier) {
                cacheable.clearCache()
            }
        }
        
        Logger.firebase("相關快取已清空", level: .info, jsonPayload: [
            "data_type": String(describing: dataType),
            "affected_caches": Array(relatedIdentifiers)
        ])
    }
    
    private func invalidateExpiredCaches() {
        for cacheable in cacheables {
            if cacheable.isExpired() {
                cacheable.clearCache()
            }
        }
    }
    
    private func getRelatedCacheIdentifiers(for dataType: DataType) -> Set<String> {
        switch dataType {
        case .workouts:
            return ["workouts_v2", "workout_cache", "UnifiedWorkoutManager"]
        case .trainingPlan:
            return ["training_plan", "weekly_summary", "TrainingPlanManager"] // 訓練計劃影響週總結
        case .weeklySummary:
            return ["weekly_summary", "WeeklySummaryManager"]
        case .targets:
            return ["targets", "training_plan", "TargetManager"] // 目標影響訓練計劃
        case .user:
            return Set(cacheables.map { $0.cacheIdentifier }) // 用戶變更影響所有
        case .healthData:
            return ["HealthDataUploadManager", "hrv_cache", "HRVManager", "health_data"] // 健康數據及相關緩存
        case .hrv:
            return ["hrv_cache", "HRVManager", "health_data"]
        case .vdot:
            return ["vdot_cache", "VDOTManager", "VDOT"]
        }
    }
    
    private func notifyListeners(reason: CacheInvalidationReason) {
        for listener in listeners {
            listener.onCacheInvalidated(for: "all", reason: reason)
        }
    }
    
    // MARK: - 快取狀態查詢
    
    func getCacheStatus() -> CacheStatus {
        let totalSize = cacheables.reduce(0) { $0 + $1.getCacheSize() }
        let expiredCount = cacheables.filter { $0.isExpired() }.count
        
        return CacheStatus(
            totalCaches: cacheables.count,
            totalSizeBytes: totalSize,
            expiredCaches: expiredCount,
            registeredCaches: cacheables.map { $0.cacheIdentifier }
        )
    }
}

// MARK: - 快取狀態結構
struct CacheStatus {
    let totalCaches: Int
    let totalSizeBytes: Int
    let expiredCaches: Int
    let registeredCaches: [String]
    
    var totalSizeMB: Double {
        Double(totalSizeBytes) / (1024 * 1024)
    }
}