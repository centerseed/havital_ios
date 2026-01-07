import Foundation

// MARK: - 快取事件總線
class CacheEventBus {
    static let shared = CacheEventBus()

    private var cacheables: [Cacheable] = []
    private var listeners: [CacheEventListener] = []

    /// 事件訂閱器（回調式訂閱，使用字符串鍵）
    private var eventSubscriptions: [String: [@MainActor () async -> Void]] = [:]

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
        case .onboardingCompleted:
            // Onboarding 完成時清除所有緩存，確保顯示最新數據
            invalidateAllCaches()
            Logger.firebase("Onboarding 完成，清除所有緩存", level: .info)
        }

        notifyListeners(reason: reason)
    }

    /// 發布事件（便利方法，語義更清晰）
    func publish(_ event: CacheInvalidationReason) {
        invalidateCache(for: event)

        // 通知事件訂閱者
        Task {
            await notifyEventSubscribers(for: event)
        }
    }

    // MARK: - Event Subscription (回調式訂閱)

    /// 基於標識符的事件訂閱
    /// - Key: subscriberId, Value: event handler
    private var identifierBasedSubscriptions: [String: (CacheInvalidationReason) -> Void] = [:]

    /// 訂閱特定事件
    /// - Parameters:
    ///   - eventKey: 事件鍵（如 "onboardingCompleted"）
    ///   - handler: 事件處理回調
    func subscribe(for eventKey: String, handler: @escaping @MainActor () async -> Void) {
        if eventSubscriptions[eventKey] == nil {
            eventSubscriptions[eventKey] = []
        }
        eventSubscriptions[eventKey]?.append(handler)
        Logger.debug("[CacheEventBus] 訂閱事件: \(eventKey)")
    }

    /// 基於標識符的全局事件訂閱
    /// - Parameters:
    ///   - identifier: 訂閱者標識符（用於取消訂閱）
    ///   - handler: 事件處理回調，接收所有事件類型
    func subscribe(forIdentifier identifier: String, handler: @escaping (CacheInvalidationReason) -> Void) {
        identifierBasedSubscriptions[identifier] = handler
        Logger.debug("[CacheEventBus] 訂閱者註冊: \(identifier)")
    }

    /// 取消訂閱
    /// - Parameter identifier: 訂閱者標識符
    func unsubscribe(forIdentifier identifier: String) {
        identifierBasedSubscriptions.removeValue(forKey: identifier)
        Logger.debug("[CacheEventBus] 訂閱者取消註冊: \(identifier)")
    }

    /// 通知事件訂閱者
    private func notifyEventSubscribers(for event: CacheInvalidationReason) async {
        let eventKey: String
        switch event {
        case .onboardingCompleted:
            eventKey = "onboardingCompleted"
        case .userLogout:
            eventKey = "userLogout"
        case .dataChanged(let dataType):
            eventKey = "dataChanged.\(dataType)"
        case .manualClear:
            eventKey = "manualClear"
        case .expired:
            eventKey = "expired"
        }

        // 通知基於 eventKey 的訂閱者
        if let handlers = eventSubscriptions[eventKey] {
            Logger.debug("[CacheEventBus] 通知 \(handlers.count) 個 eventKey 訂閱者: \(eventKey)")
            for handler in handlers {
                await handler()
            }
        }

        // 通知基於 identifier 的訂閱者
        let identifierSubscribers = identifierBasedSubscriptions
        if !identifierSubscribers.isEmpty {
            Logger.debug("[CacheEventBus] 通知 \(identifierSubscribers.count) 個 identifier 訂閱者: \(eventKey)")
            for (_, handler) in identifierSubscribers {
                handler(event)
            }
        }
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