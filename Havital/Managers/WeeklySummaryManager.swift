import Foundation
import SwiftUI

// MARK: - 週總結統計信息
struct WeeklySummaryStatistics: Codable {
    let totalWeeks: Int
    let averageDistance: Double
    let averageCompletionPercentage: Double
    let lastUpdated: Date
    
    init(from summaries: [WeeklySummaryItem]) {
        self.totalWeeks = summaries.count
        
        let distances = summaries.compactMap { $0.distanceKm }
        self.averageDistance = distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)
        
        let completions = summaries.compactMap { $0.completionPercentage }
        self.averageCompletionPercentage = completions.isEmpty ? 0 : completions.reduce(0, +) / Double(completions.count)
        
        self.lastUpdated = Date()
    }
}

// MARK: - 週總結快取管理器
typealias WeeklySummaryCacheManager = BaseCacheManagerTemplate<[WeeklySummaryItem]>

// MARK: - 統一週總結管理器
/// 遵循 DataManageable 協議，提供標準化的週總結數據管理
class WeeklySummaryManager: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = [WeeklySummaryItem]
    typealias ServiceType = WeeklySummaryService
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - Weekly Summary Specific Properties
    @Published var weeklySummaries: [WeeklySummaryItem] = []
    @Published var statistics: WeeklySummaryStatistics?
    
    // MARK: - Dependencies
    let service: WeeklySummaryService
    private let cacheManager: WeeklySummaryCacheManager
    private var lastRefreshTime: Date? // 冷卻機制
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "WeeklySummaryManager" }
    
    // MARK: - Singleton
    static let shared = WeeklySummaryManager()
    
    // MARK: - Initialization
    private init() {
        self.service = WeeklySummaryService.shared
        self.cacheManager = WeeklySummaryCacheManager(identifier: "weekly_summaries", defaultTTL: 3600) // 1 hour TTL
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "WeeklySummaryManager 初始化",
            level: .info,
            labels: ["module": "WeeklySummaryManager", "action": "initialize"]
        )

        // 先載入本地快取數據
        await loadLocalData()

        // 載入週總結數據
        await loadData()
    }
    
    func loadData() async {
        // 先同步載入本地緩存數據（如果有的話）
        await loadLocalData()

        await executeDataLoadingTask(id: "load_weekly_summaries") {
            try await self.performLoadWeeklySummaries()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_weekly_summaries") {
            try await self.performRefreshWeeklySummaries()
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            weeklySummaries = []
            statistics = nil
            lastSyncTime = nil
            syncError = nil
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "週總結數據已清除",
            level: .info,
            labels: ["module": "WeeklySummaryManager", "action": "clear_all_data"]
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
    
    // MARK: - Local Data Management

    private func loadLocalData() async {
        if let cachedSummaries = cacheManager.loadFromCache() {
            Logger.firebase(
                "載入本地快取的週總結數據",
                level: .debug,
                jsonPayload: [
                    "count": cachedSummaries.count,
                    "cache_age_seconds": cacheManager.getCacheAge() ?? 0
                ]
            )

            await updateUIState(summaries: cachedSummaries)
        }
    }
    
    // MARK: - Core Data Operations
    
    private func performLoadWeeklySummaries() async throws -> [WeeklySummaryItem] {
        Logger.firebase(
            "開始載入週總結數據",
            level: .debug,
            labels: ["module": "WeeklySummaryManager", "action": "load_data"]
        )
        
        // 雙軌載入策略：首先檢查快取
        if let cachedSummaries = cacheManager.loadFromCache(), !cacheManager.isExpired() {
            Logger.firebase(
                "使用快取的週總結數據",
                level: .debug,
                jsonPayload: ["count": cachedSummaries.count]
            )

            // 立即顯示快取數據
            await updateUIState(summaries: cachedSummaries)

            // 背景更新
            Task.detached { [weak self] in
                await self?.executeTask(id: TaskID("background_refresh_weekly_summaries")) { [weak self] in
                    await self?.refreshInBackground()
                }
            }

            return cachedSummaries
        }
        
        // 沒有快取或已過期，直接從 API 載入
        let freshSummaries = try await service.fetchWeeklySummaries()

        // 保存到快取
        cacheManager.saveToCache(freshSummaries)

        Logger.firebase(
            "成功載入週總結數據",
            level: .info,
            jsonPayload: [
                "count": freshSummaries.count,
                "has_distance_data": freshSummaries.contains { $0.distanceKm != nil }
            ]
        )

        await updateUIState(summaries: freshSummaries)

        return freshSummaries
    }
    
    private func performRefreshWeeklySummaries() async throws -> [WeeklySummaryItem] {
        // 冷卻機制：避免頻繁刷新
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < 30 {
            Logger.firebase(
                "刷新冷卻中，跳過本次刷新",
                level: .debug,
                labels: ["module": "WeeklySummaryManager"]
            )
            // 返回當前快取的數據而不是拋出錯誤
            if let cachedSummaries = cacheManager.loadFromCache() {
                return cachedSummaries
            } else {
                return weeklySummaries
            }
        }
        
        let summaries = try await service.fetchWeeklySummaries()

        // 更新快取
        cacheManager.saveToCache(summaries)
        lastRefreshTime = Date()

        await updateUIState(summaries: summaries)

        Logger.firebase(
            "週總結數據刷新完成",
            level: .info,
            jsonPayload: ["count": summaries.count]
        )

        return summaries
    }
    
    private func refreshInBackground() async {
        do {
            let latestSummaries = try await service.fetchWeeklySummaries()
            cacheManager.saveToCache(latestSummaries)

            await updateUIState(summaries: latestSummaries)

            Logger.firebase(
                "背景更新週總結數據完成",
                level: .debug,
                jsonPayload: ["count": latestSummaries.count]
            )
        } catch {
            // 背景更新失敗不影響已顯示的快取
            Logger.firebase(
                "背景更新失敗，保持現有快取",
                level: .debug,
                jsonPayload: ["error": error.localizedDescription]
            )
        }
    }
    
    // MARK: - UI State Management

    @MainActor
    private func updateUIState(summaries: [WeeklySummaryItem]) {
        weeklySummaries = summaries
        statistics = WeeklySummaryStatistics(from: summaries)
        lastSyncTime = Date()
        syncError = nil

        Logger.firebase(
            "UI 狀態已更新",
            level: .debug,
            jsonPayload: [
                "summaries_count": summaries.count,
                "average_distance": statistics?.averageDistance ?? 0,
                "average_completion": statistics?.averageCompletionPercentage ?? 0
            ]
        )
    }
    
    // MARK: - Public API
    
    /// 獲取特定週次的總結
    func getSummaryForWeek(_ weekIndex: Int) -> WeeklySummaryItem? {
        return weeklySummaries.first { $0.weekIndex == weekIndex }
    }
    
    /// 獲取最近 N 週的總結
    func getRecentSummaries(limit: Int = 10) -> [WeeklySummaryItem] {
        return Array(weeklySummaries.sorted { $0.weekIndex > $1.weekIndex }.prefix(limit))
    }
    
    /// 獲取有距離數據的總結
    func getSummariesWithDistance() -> [WeeklySummaryItem] {
        return weeklySummaries.filter { $0.distanceKm != nil }
    }
    
    // MARK: - Notification Setup
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .cacheDidInvalidate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let cacheIdentifier = notification.userInfo?["cacheIdentifier"] as? String,
                  cacheIdentifier == self.cacheIdentifier else { return }
            
            Logger.firebase(
                "收到快取失效通知，重新載入數據",
                level: .info,
                labels: ["module": "WeeklySummaryManager"]
            )
            
            Task {
                await self.loadData()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelAllTasks()
    }
}

// MARK: - WeeklySummaryManager Extension for Statistics
extension WeeklySummaryManager {
    
    /// 計算總距離
    var totalDistance: Double {
        weeklySummaries.compactMap { $0.distanceKm }.reduce(0, +)
    }
    
    /// 計算平均完成度
    var averageCompletion: Double {
        let completions = weeklySummaries.compactMap { $0.completionPercentage }
        return completions.isEmpty ? 0 : completions.reduce(0, +) / Double(completions.count)
    }
    
    /// 獲取趨勢數據（用於圖表顯示）
    func getDistanceTrend() -> [(week: Int, distance: Double)] {
        return weeklySummaries
            .map { summary in
                let distance = summary.distanceKm ?? 0.0
                return (week: summary.weekIndex, distance: distance)
            }
            .sorted { $0.week < $1.week }
    }
    
    /// 獲取完成度趨勢
    func getCompletionTrend() -> [(week: Int, completion: Double)] {
        return weeklySummaries
            .compactMap { summary in
                guard let completion = summary.completionPercentage else { return nil }
                return (week: summary.weekIndex, completion: completion)
            }
            .sorted { $0.week < $1.week }
    }
}