import Foundation
import SwiftUI

// MARK: - VDOT 數據擴展結構
struct EnhancedVDOTDataPoint: Codable {
    let date: Date
    let dynamicVdot: Double    // 動態跑力
    let weightVdot: Double?    // 加權跑力
    let source: String?        // 數據來源
    let workoutId: String?     // 關聯的運動記錄 ID
    
    // 為了向後兼容，保留原始 VDOTDataPoint 介面
    var value: Double { dynamicVdot }
    
    init(from vdotEntry: VDOTEntry) {
        self.date = Date(timeIntervalSince1970: vdotEntry.datetime)
        self.dynamicVdot = vdotEntry.dynamicVdot
        self.weightVdot = vdotEntry.weightVdot
        self.source = "API"
        self.workoutId = nil // 如果 API 提供的話，可以添加
    }
    
    init(date: Date, dynamicVdot: Double, weightVdot: Double?, source: String? = nil, workoutId: String? = nil) {
        self.date = date
        self.dynamicVdot = dynamicVdot
        self.weightVdot = weightVdot
        self.source = source
        self.workoutId = workoutId
    }
}

// MARK: - VDOT 日期範圍
struct VDOTDateRange: Codable {
    let start: Date
    let end: Date
}

// MARK: - VDOT 統計信息  
struct VDOTStatistics: Codable {
    let latestDynamicVdot: Double
    let averageWeightedVdot: Double
    let dataPointCount: Int
    let dateRange: VDOTDateRange
    let yAxisMin: Double
    let yAxisMax: Double
    let lastUpdated: Date
    
    init(from dataPoints: [EnhancedVDOTDataPoint]) {
        guard let latest = dataPoints.max(by: { $0.date < $1.date }) else {
            self.latestDynamicVdot = 0
            self.averageWeightedVdot = 0
            self.dataPointCount = 0
            self.dateRange = VDOTDateRange(start: Date(), end: Date())
            self.yAxisMin = 30
            self.yAxisMax = 40
            self.lastUpdated = Date()
            return
        }
        
        self.latestDynamicVdot = latest.dynamicVdot
        self.averageWeightedVdot = latest.weightVdot ?? 0
        self.dataPointCount = dataPoints.count
        
        let dates = dataPoints.map { $0.date }
        self.dateRange = VDOTDateRange(start: dates.min() ?? Date(), end: dates.max() ?? Date())
        
        // 計算 Y 軸範圍
        let values = dataPoints.map { $0.dynamicVdot }
        if let minValue = values.min(), let maxValue = values.max() {
            let padding = (maxValue - minValue) * 0.05
            let yMin = Swift.max(minValue - padding, 0)
            let yMax = maxValue + padding
            
            let minimumRange = 5.0
            let range = yMax - yMin
            if range < minimumRange {
                let additionalPadding = (minimumRange - range) / 2
                let newYMin = Swift.max(yMin - additionalPadding, 0)
                let newYMax = yMax + additionalPadding
                self.yAxisMin = newYMin
                self.yAxisMax = newYMax
            } else {
                self.yAxisMin = yMin
                self.yAxisMax = yMax
            }
        } else {
            self.yAxisMin = 30
            self.yAxisMax = 40
        }
        
        self.lastUpdated = Date()
    }
}

// MARK: - 統一 VDOT 管理器
/// 遵循 DataManageable 協議，提供標準化的 VDOT 數據管理
class VDOTManager: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = [EnhancedVDOTDataPoint]
    typealias ServiceType = APIClient
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - VDOT Specific Properties
    @Published var vdotDataPoints: [EnhancedVDOTDataPoint] = []
    @Published var statistics: VDOTStatistics?
    @Published var needUpdatedHrRange: Bool = false
    @Published var dataLimit: Int = 14 // 預設顯示最近 14 筆數據
    
    // MARK: - Dependencies
    let service: APIClient
    private let cacheManager: VDOTCacheManager
    private var lastRefreshTime: Date? // 🚨 添加冷卻機制
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "VDOTManager" }
    
    // MARK: - Singleton
    static let shared = VDOTManager()
    
    // MARK: - Initialization
    private init() {
        self.service = APIClient.shared
        self.cacheManager = VDOTCacheManager()
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "VDOTManager 初始化",
            level: .info,
            labels: ["module": "VDOTManager", "action": "initialize"]
        )
        
        // 先載入本地快取數據
        loadLocalData()
        
        // 載入 VDOT 數據
        await loadData()
    }
    
    func loadData() async {
        await executeDataLoadingTask(id: "load_vdot_data") {
            try await self.performLoadVDOTData()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_vdot_data") {
            try await self.performRefreshVDOTData()
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            vdotDataPoints = []
            statistics = nil
            needUpdatedHrRange = false
            lastSyncTime = nil
            syncError = nil
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "VDOT 數據已清除",
            level: .info,
            labels: ["module": "VDOTManager", "action": "clear_all_data"]
        )
    }
    
    // MARK: - Cacheable Implementation
    
    func clearCache() {
        cacheManager.clearCache()
    }
    
    func getCacheSize() -> Int {
        return cacheManager.getCacheSize()
    }
    
    func isExpired() -> Bool {
        return cacheManager.isExpired()
    }
    
    // MARK: - Core VDOT Logic
    
    private func loadLocalData() {
        if let cachedData = cacheManager.loadFromCache() {
            DispatchQueue.main.async {
                self.vdotDataPoints = cachedData.dataPoints
                self.needUpdatedHrRange = cachedData.needUpdatedHrRange
                self.statistics = VDOTStatistics(from: cachedData.dataPoints)
            }
        }
    }
    
    private func performLoadVDOTData() async throws {
        // 檢查快取是否有效
        if let cachedData = cacheManager.loadFromCache(),
           !cacheManager.shouldRefresh() {
            await MainActor.run {
                self.vdotDataPoints = cachedData.dataPoints
                self.needUpdatedHrRange = cachedData.needUpdatedHrRange
                self.statistics = VDOTStatistics(from: cachedData.dataPoints)
            }
            
            Logger.firebase(
                "使用快取的 VDOT 數據",
                level: .debug,
                labels: ["module": "VDOTManager", "action": "load_from_cache"],
                jsonPayload: ["data_points": cachedData.dataPoints.count]
            )
            return
        }
        
        // 從 API 獲取數據
        let response: VDOTResponse = try await service.request(
            VDOTResponse.self,
            path: "/v2/workouts/vdots?limit=\(dataLimit)"
        )
        
        let enhancedDataPoints = response.data.vdots.map { entry in
            EnhancedVDOTDataPoint(from: entry)
        }.sorted { $0.date < $1.date }
        
        let statistics = VDOTStatistics(from: enhancedDataPoints)
        
        // 更新 UI 和快取
        await MainActor.run {
            self.vdotDataPoints = enhancedDataPoints
            self.needUpdatedHrRange = response.data.needUpdatedHrRange
            self.statistics = statistics
        }
        
        // 保存到快取
        let cacheData = VDOTCacheData(
            dataPoints: enhancedDataPoints,
            needUpdatedHrRange: response.data.needUpdatedHrRange
        )
        cacheManager.saveToCache(cacheData)
        
        // 發送通知
        NotificationCenter.default.post(name: .vdotDataDidUpdate, object: nil)
        
        Logger.firebase(
            "VDOT 數據載入成功",
            level: .info,
            labels: ["module": "VDOTManager", "action": "load_vdot_data"],
            jsonPayload: [
                "data_points": enhancedDataPoints.count,
                "latest_vdot": statistics.latestDynamicVdot,
                "average_vdot": statistics.averageWeightedVdot,
                "need_hr_update": response.data.needUpdatedHrRange
            ]
        )
    }
    
    private func performRefreshVDOTData() async throws {
        // 強制從 API 獲取
        let response: VDOTResponse = try await service.request(
            VDOTResponse.self,
            path: "/v2/workouts/vdots?limit=\(dataLimit)"
        )
        
        let enhancedDataPoints = response.data.vdots.map { entry in
            EnhancedVDOTDataPoint(from: entry)
        }.sorted { $0.date < $1.date }
        
        let statistics = VDOTStatistics(from: enhancedDataPoints)
        
        await MainActor.run {
            self.vdotDataPoints = enhancedDataPoints
            self.needUpdatedHrRange = response.data.needUpdatedHrRange
            self.statistics = statistics
        }
        
        // 強制更新快取
        let cacheData = VDOTCacheData(
            dataPoints: enhancedDataPoints,
            needUpdatedHrRange: response.data.needUpdatedHrRange
        )
        cacheManager.forceRefresh(with: cacheData)
        
        // 發送通知
        NotificationCenter.default.post(name: .vdotDataDidUpdate, object: nil)
    }
    
    // MARK: - Data Limit Management
    
    func updateDataLimit(_ limit: Int) async {
        guard limit != dataLimit else { return }
        
        await MainActor.run {
            dataLimit = limit
        }
        
        // 重新載入數據
        await refreshData()
    }
    
    // MARK: - VDOT Query Methods
    
    /// 獲取指定日期的 VDOT 值
    func getVDOTForDate(_ date: Date) -> Double? {
        let sortedPoints = vdotDataPoints.sorted(by: { $0.date > $1.date })
        
        for point in sortedPoints {
            if point.date <= date {
                return point.dynamicVdot
            }
        }
        
        return sortedPoints.last?.dynamicVdot
    }
    
    /// 獲取當前（最新）VDOT 值
    var currentVDOT: Double {
        return statistics?.latestDynamicVdot ?? 0
    }
    
    /// 獲取加權平均 VDOT 值
    var averageVDOT: Double {
        return statistics?.averageWeightedVdot ?? 0
    }
    
    /// 獲取 Y 軸範圍用於圖表顯示
    var yAxisMin: Double {
        return statistics?.yAxisMin ?? 30
    }
    
    var yAxisMax: Double {
        return statistics?.yAxisMax ?? 40
    }
    
    var yAxisRange: ClosedRange<Double> {
        return yAxisMin...yAxisMax
    }
    
    /// 檢查是否有數據
    var hasData: Bool {
        return !vdotDataPoints.isEmpty
    }
    
    /// 獲取數據點數量
    var dataPointCount: Int {
        return vdotDataPoints.count
    }
    
    // MARK: - Background Refresh with Cooldown
    
    /// 帶冷卻機制的背景刷新，避免頻繁 API 調用
    private func backgroundRefreshWithCooldown() async {
        let now = Date()
        
        // 🚨 冷卻機制：60秒內不重複調用
        if let lastRefresh = lastRefreshTime,
           now.timeIntervalSince(lastRefresh) < 60 {
            print("🚨 VDOTManager: backgroundRefresh 冷卻中，跳過 API 調用")
            return
        }
        
        lastRefreshTime = now
        print("🚨 VDOTManager: 開始 backgroundRefresh")
        
        _ = await executeDataLoadingTask(id: "background_refresh_cooldown", showLoading: false) {
            return await self.refreshData()
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .workoutsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 運動記錄更新時，可能需要重新計算 VDOT
            Task {
                // 🚨 優化：檢查是否為批次上傳，避免頻繁調用 VDOT API
                if let userInfo = notification.object as? [String: Any],
                   let isBatchUpload = userInfo["batchUpload"] as? Bool,
                   isBatchUpload {
                    print("🚨 VDOTManager: 收到批次上傳通知，延遲刷新 VDOT 數據")
                    // 批次上傳時延遲刷新，避免頻繁 API 調用
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
                }
                await self?.backgroundRefreshWithCooldown()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.clearAllData()
                await self?.initialize()
            }
        }
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Statistics Extension
extension VDOTManager {
    
    /// 獲取 VDOT 趨勢（增長或下降）
    var vdotTrend: VDOTTrend {
        guard vdotDataPoints.count >= 2 else { return .stable }
        
        let recent = vdotDataPoints.suffix(2)
        let older = recent.first!.dynamicVdot
        let newer = recent.last!.dynamicVdot
        
        let difference = newer - older
        if abs(difference) < 0.5 {
            return .stable
        } else if difference > 0 {
            return .improving
        } else {
            return .declining
        }
    }
    
    enum VDOTTrend {
        case improving
        case stable  
        case declining
        
        var description: String {
            switch self {
            case .improving: return "上升趨勢"
            case .stable: return "穩定"
            case .declining: return "下降趨勢"
            }
        }
    }
}

// MARK: - Cache Manager
private class VDOTCacheManager: BaseCacheManagerTemplate<VDOTCacheData> {
    
    init() {
        super.init(identifier: "vdot_cache", defaultTTL: 1800) // 30 minutes
    }
}

// MARK: - Cache Data Structure
private struct VDOTCacheData: Codable {
    let dataPoints: [EnhancedVDOTDataPoint]
    let needUpdatedHrRange: Bool
}