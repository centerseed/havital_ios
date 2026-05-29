import Foundation

// MARK: - 快取事件總線
class CacheEventBus {
    static let shared = CacheEventBus()

    private let stateQueue = DispatchQueue(label: "com.havital.cache-event-bus.state")
    private var cacheables: [Cacheable] = []
    private var listeners: [CacheEventListener] = []

    /// 事件訂閱器（回調式訂閱，使用字符串鍵）
    private var eventSubscriptions: [String: [@MainActor () async -> Void]] = [:]

    private init() {}
    
    // MARK: - 註冊管理
    
    func register(_ cacheable: Cacheable) {
        let didRegister = stateQueue.sync {
            if cacheables.contains(where: { $0.cacheIdentifier == cacheable.cacheIdentifier }) {
                return false
            }
            cacheables.append(cacheable)
            return true
        }

        if didRegister {
            Logger.firebase("快取管理器已註冊", level: .info, jsonPayload: [
                "cache_identifier": cacheable.cacheIdentifier
            ])
        }
    }
    
    func addListener(_ listener: CacheEventListener) {
        stateQueue.sync {
            listeners.append(listener)
        }
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
        case .reonboardingCompleted:
            // Re-onboarding 完成：不需要清除緩存，只需通知 UI
            // UI 層（AuthenticationViewModel）訂閱此事件來關閉 sheet
            Logger.firebase("Re-onboarding 完成，通知 UI 關閉 sheet", level: .info)
        case .weekChanged:
            // 跨週事件：不需要清除緩存，只需通知 TrainingPlanViewModel 更新 selectedWeek
            Logger.debug("[CacheEventBus] 跨週事件：通知 UI 更新當前週數")
        }

        notifyListeners(reason: reason)
    }

    /// 發布事件（便利方法，語義更清晰）
    func publish(_ event: CacheInvalidationReason) {
        invalidateCache(for: event)

        // 通知事件訂閱者（確保在主線程執行，因為訂閱者可能更新 UI）
        Task { @MainActor in
            await notifyEventSubscribers(for: event)
        }
    }

    /// 依序發布多個事件，保證訂閱者收到事件的順序與陣列順序一致。
    /// 使用場景：需要原子性保證事件順序時（如 userLogout 必須在 dataChanged(.user) 之前）。
    /// 每個事件的 cache invalidation 同步執行，subscriber 通知在同一 Task 中依序 await。
    func publishSequence(_ events: [CacheInvalidationReason]) {
        guard !events.isEmpty else { return }
        // Cache invalidation is synchronous — run all in order first.
        for event in events {
            invalidateCache(for: event)
        }
        // Subscriber notifications are async; fire them in one Task to guarantee order.
        Task { @MainActor in
            for event in events {
                await notifyEventSubscribers(for: event)
            }
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
        stateQueue.sync {
            if eventSubscriptions[eventKey] == nil {
                eventSubscriptions[eventKey] = []
            }
            eventSubscriptions[eventKey]?.append(handler)
        }
        Logger.trace("[CacheEventBus] 訂閱事件: \(eventKey)")
    }

    /// 基於標識符的全局事件訂閱
    /// - Parameters:
    ///   - identifier: 訂閱者標識符（用於取消訂閱）
    ///   - handler: 事件處理回調，接收所有事件類型
    func subscribe(forIdentifier identifier: String, handler: @escaping (CacheInvalidationReason) -> Void) {
        stateQueue.sync {
            identifierBasedSubscriptions[identifier] = handler
        }
        Logger.trace("[CacheEventBus] 訂閱者註冊: \(identifier)")
    }

    /// 取消訂閱
    /// - Parameter identifier: 訂閱者標識符
    func unsubscribe(forIdentifier identifier: String) {
        stateQueue.sync {
            identifierBasedSubscriptions.removeValue(forKey: identifier)
        }
        Logger.trace("[CacheEventBus] 訂閱者取消註冊: \(identifier)")
    }

    /// 通知事件訂閱者
    private func notifyEventSubscribers(for event: CacheInvalidationReason) async {
        let eventKey: String
        switch event {
        case .onboardingCompleted:
            eventKey = "onboardingCompleted"
        case .reonboardingCompleted:
            eventKey = "reonboardingCompleted"
        case .userLogout:
            eventKey = "userLogout"
        case .dataChanged(let dataType):
            eventKey = "dataChanged.\(dataType)"
        case .manualClear:
            eventKey = "manualClear"
        case .expired:
            eventKey = "expired"
        case .weekChanged:
            eventKey = "weekChanged"
        }

        let (handlers, identifierSubscribers) = stateQueue.sync {
            (
                eventSubscriptions[eventKey] ?? [],
                Array(identifierBasedSubscriptions.values)
            )
        }

        // 通知基於 eventKey 的訂閱者
        if !handlers.isEmpty {
            Logger.debug("[CacheEventBus] 通知 \(handlers.count) 個 eventKey 訂閱者: \(eventKey)")
            for handler in handlers {
                await handler()
            }
        }

        // 通知基於 identifier 的訂閱者
        if !identifierSubscribers.isEmpty {
            Logger.debug("[CacheEventBus] 通知 \(identifierSubscribers.count) 個 identifier 訂閱者: \(eventKey)")
            for handler in identifierSubscribers {
                handler(event)
            }
        }
    }

    // MARK: - Private Methods
    
    private func invalidateAllCaches() {
        let cacheables = stateQueue.sync { self.cacheables }
        for cacheable in cacheables {
            cacheable.clearCache()
        }
        Logger.firebase("所有快取已清空", level: .info)
    }
    
    private func invalidateRelatedCaches(for dataType: DataType) {
        let relatedIdentifiers = getRelatedCacheIdentifiers(for: dataType)
        let cacheables = stateQueue.sync { self.cacheables }
        
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
        let cacheables = stateQueue.sync { self.cacheables }
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
        case .trainingPlanV2:
            return ["training_plan_v2", "weekly_plan_v2"]
        case .weeklySummary:
            return ["weekly_summary", "WeeklySummaryManager"]
        case .targets:
            return ["targets", "training_plan", "TargetManager"] // 目標影響訓練計劃
        case .user:
            // 用戶 PROFILE 變更（含每次啟動 auth 狀態變化）會發此事件。清 profile 衍生的快取，
            // 但「保留」計畫/運動/週總結的雙軌快取——否則每次啟動都清光 → 課表 relaunch 卡 loading。
            // 跨用戶污染由換帳號時的 .userLogout（清光全部，見 LoginViewModel）防護，此處毋須清計畫/運動。
            // 只保留「課表」雙軌快取（修 relaunch 卡 loading）。
            // Workout 快取「仍清」——它每次啟動清掉重抓才正確；保留會讓 loadMore 的 append 累積/重複，
            // 造成週里程（getAllWorkoutsAsync 加總）膨脹。換帳號由 .userLogout 清光全部。
            let preservedCaches: Set<String> = [
                "TrainingPlanV2LocalDataSource"
            ]
            return Set(cacheables.map { $0.cacheIdentifier }).subtracting(preservedCaches)
        case .healthData:
            return ["HealthDataUploadManager", "hrv_cache", "HRVManager", "health_data"] // 健康數據及相關緩存
        case .hrv:
            return ["hrv_cache", "HRVManager", "health_data"]
        case .vdot:
            return ["vdot_cache", "VDOTManager", "VDOT"]
        }
    }
    
    private func notifyListeners(reason: CacheInvalidationReason) {
        let listeners = stateQueue.sync { self.listeners }
        for listener in listeners {
            listener.onCacheInvalidated(for: "all", reason: reason)
        }
    }
    
    // MARK: - 快取狀態查詢
    
    func getCacheStatus() -> CacheStatus {
        let cacheables = stateQueue.sync { self.cacheables }
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
