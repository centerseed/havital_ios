import Foundation
import SwiftUI

// MARK: - 週跑量統計信息
struct WeeklyVolumeStatistics: Codable {
    let totalWeeks: Int
    let averageDistance: Double
    let maxDistance: Double
    let minDistance: Double
    let lastUpdated: Date

    init(from volumes: [WeeklySummaryItem]) {
        self.totalWeeks = volumes.count

        let distances = volumes.compactMap { $0.distanceKm }.filter { $0 > 0 }
        self.averageDistance = distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)
        self.maxDistance = distances.max() ?? 0
        self.minDistance = distances.min() ?? 0

        self.lastUpdated = Date()
    }
}

// MARK: - 週跑量快取管理器
typealias WeeklyVolumeCacheManager = BaseCacheManagerTemplate<[WeeklySummaryItem]>

// MARK: - 週跑量管理器
/// 專門管理所有歷史週跑量數據，獨立於訓練計劃
class WeeklyVolumeManager: ObservableObject, DataManageable {

    // MARK: - Type Definitions
    typealias DataType = [WeeklySummaryItem]
    typealias ServiceType = WeeklySummaryService

    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    // MARK: - Weekly Volume Specific Properties
    @Published var weeklyVolumes: [WeeklySummaryItem] = []
    @Published var statistics: WeeklyVolumeStatistics?
    @Published var displayLimit: Int = 8 // 預設顯示 8 週

    // MARK: - Dependencies
    let service: WeeklySummaryService
    private let cacheManager: WeeklyVolumeCacheManager
    private var lastRefreshTime: Date? // 冷卻機制

    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()

    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "WeeklyVolumeManager" }

    // MARK: - Singleton
    static let shared = WeeklyVolumeManager()

    // MARK: - Initialization
    private init() {
        self.service = WeeklySummaryService.shared
        // 使用較長的 TTL (24 小時)，因為週跑量數據變化較少
        self.cacheManager = WeeklyVolumeCacheManager(identifier: "weekly_volumes", defaultTTL: 86400) // 24 hour TTL

        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)

        setupNotificationObservers()
    }

    // MARK: - DataManageable Implementation

    func initialize() async {
        Logger.firebase(
            "WeeklyVolumeManager 初始化",
            level: .info,
            labels: ["module": "WeeklyVolumeManager", "action": "initialize"]
        )

        // 先載入本地快取數據
        await loadLocalData()

        // 載入週跑量數據
        await loadData()
    }

    func loadData() async {
        // 先同步載入本地緩存數據（如果有的話）
        await loadLocalData()

        await executeDataLoadingTask(id: "load_weekly_volumes") {
            try await self.performLoadWeeklyVolumes()
        }
    }

    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_weekly_volumes") {
            try await self.performRefreshWeeklyVolumes()
        } != nil
    }

    func clearAllData() async {
        await MainActor.run {
            weeklyVolumes = []
            statistics = nil
            lastSyncTime = nil
            syncError = nil
        }

        cacheManager.clearCache()

        Logger.firebase(
            "週跑量數據已清除",
            level: .info,
            labels: ["module": "WeeklyVolumeManager", "action": "clear_all_data"]
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
        if let cachedVolumes = cacheManager.loadFromCache() {
            Logger.firebase(
                "載入本地快取的週跑量數據",
                level: .debug,
                jsonPayload: [
                    "count": cachedVolumes.count,
                    "cache_age_seconds": cacheManager.getCacheAge() ?? 0
                ]
            )

            await updateUIState(volumes: cachedVolumes)
        }
    }

    // MARK: - Core Data Operations

    private func performLoadWeeklyVolumes() async throws -> [WeeklySummaryItem] {
        Logger.firebase(
            "開始載入週跑量數據",
            level: .debug,
            labels: ["module": "WeeklyVolumeManager", "action": "load_data", "limit": "\(displayLimit)"]
        )

        // 雙軌載入策略：首先檢查快取
        if let cachedVolumes = cacheManager.loadFromCache(), !cacheManager.isExpired() {
            Logger.firebase(
                "使用快取的週跑量數據",
                level: .debug,
                jsonPayload: ["count": cachedVolumes.count]
            )

            // 立即顯示快取數據
            await updateUIState(volumes: cachedVolumes)

            // 背景更新 - 只更新最新一週
            Task.detached { [weak self] in
                await self?.executeTask(id: TaskID("background_refresh_latest_volume")) { [weak self] in
                    await self?.refreshLatestWeekInBackground()
                }
            }

            return cachedVolumes
        }

        // 沒有快取或已過期，直接從 API 載入
        let freshVolumes = try await service.fetchAllWeeklyVolumes(limit: displayLimit)

        Logger.firebase(
            "成功載入週跑量數據",
            level: .info,
            jsonPayload: ["count": freshVolumes.count]
        )

        // 更新 UI 和快取
        await updateUIState(volumes: freshVolumes)
        cacheManager.saveToCache(freshVolumes)

        return freshVolumes
    }

    private func performRefreshWeeklyVolumes() async throws -> [WeeklySummaryItem] {
        Logger.firebase(
            "強制刷新週跑量數據",
            level: .debug,
            labels: ["module": "WeeklyVolumeManager", "action": "refresh_data"]
        )

        let freshVolumes = try await service.fetchAllWeeklyVolumes(limit: displayLimit)

        // 更新 UI 和快取
        await updateUIState(volumes: freshVolumes)
        cacheManager.forceRefresh(with: freshVolumes)

        Logger.firebase(
            "週跑量數據刷新完成",
            level: .info,
            jsonPayload: ["count": freshVolumes.count]
        )

        return freshVolumes
    }

    /// 背景更新最新一週的數據（增量更新策略）
    private func refreshLatestWeekInBackground() async {
        Logger.firebase(
            "背景更新最新週跑量",
            level: .debug,
            labels: ["module": "WeeklyVolumeManager", "action": "incremental_update"]
        )

        do {
            // 只獲取最新 1 週的數據
            let latestData = try await service.fetchAllWeeklyVolumes(limit: 1)

            guard !latestData.isEmpty else {
                Logger.firebase(
                    "背景更新：沒有最新數據",
                    level: .debug,
                    labels: ["module": "WeeklyVolumeManager"]
                )
                return
            }

            let latestWeek = latestData[0]

            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // 檢查是否需要更新（基於 week_start）
                if let existingIndex = self.weeklyVolumes.firstIndex(where: { $0.weekStart == latestWeek.weekStart }) {
                    // 更新現有週次
                    self.weeklyVolumes[existingIndex] = latestWeek
                    Logger.firebase(
                        "背景更新：已更新 \(latestWeek.weekStart) 週數據",
                        level: .debug,
                        jsonPayload: ["week_start": latestWeek.weekStart, "distance": latestWeek.distanceKm ?? 0]
                    )
                } else {
                    // 檢查是否是新的一週（日期最新）
                    let isNewest = self.weeklyVolumes.allSatisfy { volume in
                        guard let latestDate = latestWeek.weekStartDate,
                              let volumeDate = volume.weekStartDate else {
                            return false
                        }
                        return latestDate > volumeDate
                    }

                    if isNewest || self.weeklyVolumes.isEmpty {
                        // 新增最新週次
                        self.weeklyVolumes.insert(latestWeek, at: 0)
                        // 保持顯示數量限制
                        if self.weeklyVolumes.count > self.displayLimit {
                            self.weeklyVolumes = Array(self.weeklyVolumes.prefix(self.displayLimit))
                        }
                        Logger.firebase(
                            "背景更新：已新增 \(latestWeek.weekStart) 週數據",
                            level: .debug,
                            jsonPayload: ["week_start": latestWeek.weekStart, "distance": latestWeek.distanceKm ?? 0]
                        )
                    }
                }

                // 更新統計和快取
                self.updateStatistics()
                self.cacheManager.saveToCache(self.weeklyVolumes)
            }

        } catch {
            // 背景更新失敗不影響已顯示的數據
            Logger.firebase(
                "背景更新失敗，保持現有快取",
                level: .warn,
                jsonPayload: ["error": error.localizedDescription]
            )
        }
    }

    // MARK: - UI State Update

    private func updateUIState(volumes: [WeeklySummaryItem]) async {
        Logger.firebase(
            "準備更新 UI 狀態",
            level: .debug,
            jsonPayload: [
                "volumes_count": volumes.count,
                "volumes_preview": volumes.prefix(3).map { ["week_start": $0.weekStart, "distance": $0.distanceKm ?? 0] }
            ]
        )

        await MainActor.run { [weak self] in
            guard let self = self else { return }

            // 按日期降序排列（最新日期在前）
            self.weeklyVolumes = volumes.sorted { volume1, volume2 in
                guard let date1 = volume1.weekStartDate,
                      let date2 = volume2.weekStartDate else {
                    return false
                }
                return date1 > date2
            }

            Logger.firebase(
                "UI 狀態已更新（按日期排序）",
                level: .debug,
                jsonPayload: [
                    "weeklyVolumes_count": self.weeklyVolumes.count,
                    "sorted_volumes": self.weeklyVolumes.prefix(3).map { ["week_start": $0.weekStart, "distance": $0.distanceKm ?? 0] }
                ]
            )

            // 更新統計信息
            self.updateStatistics()

            // 更新同步時間
            self.lastSyncTime = Date()
            self.syncError = nil
        }
    }

    private func updateStatistics() {
        if !weeklyVolumes.isEmpty {
            self.statistics = WeeklyVolumeStatistics(from: weeklyVolumes)
        }
    }

    // MARK: - Public API

    /// 獲取趨勢數據（用於圖表顯示）
    /// - Returns: 按時間排序的週跑量數據，包含週開始日期和跑量
    func getDistanceTrend() -> [(weekStart: String, date: Date, distance: Double)] {
        Logger.firebase(
            "獲取週跑量趨勢數據",
            level: .debug,
            jsonPayload: [
                "total_volumes": weeklyVolumes.count,
                "volumes": weeklyVolumes.map { ["week_start": $0.weekStart, "distance": $0.distanceKm ?? 0] }
            ]
        )

        // 將相同 week_start 的數據合併，取距離最大值
        var weeklyDistanceMap: [String: (date: Date?, distance: Double)] = [:]

        for volume in weeklyVolumes {
            let weekStart = volume.weekStart
            let distance = volume.distanceKm ?? 0.0
            let date = volume.weekStartDate

            // 對於相同 week_start，保留距離較大的值
            if let existing = weeklyDistanceMap[weekStart] {
                if distance > existing.distance {
                    weeklyDistanceMap[weekStart] = (date: date, distance: distance)
                }
            } else {
                weeklyDistanceMap[weekStart] = (date: date, distance: distance)
            }
        }

        // 按日期排序（從舊到新）
        let sortedWeeks = weeklyDistanceMap
            .compactMap { (weekStart, value) -> (weekStart: String, date: Date, distance: Double)? in
                guard let date = value.date else { return nil }
                return (weekStart: weekStart, date: date, distance: value.distance)
            }
            .sorted { $0.date < $1.date }

        Logger.firebase(
            "週跑量趨勢數據處理完成（按日期排序，已去重）",
            level: .debug,
            jsonPayload: [
                "original_count": weeklyVolumes.count,
                "deduplicated_count": sortedWeeks.count,
                "trend_data": sortedWeeks.map { ["week_start": $0.weekStart, "distance": $0.distance] },
                "date_range": sortedWeeks.isEmpty ? "empty" : "\(sortedWeeks.first?.weekStart ?? "") ~ \(sortedWeeks.last?.weekStart ?? "")"
            ]
        )

        return sortedWeeks
    }

    /// 獲取指定週的跑量
    func getVolume(forWeek week: Int) -> WeeklySummaryItem? {
        return weeklyVolumes.first { $0.weekIndex == week }
    }

    /// 更新顯示週數限制
    func updateDisplayLimit(_ limit: Int) async {
        guard limit != displayLimit else { return }

        displayLimit = limit
        await loadData()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLogout),
            name: NSNotification.Name("UserDidLogout"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataSourceChange),
            name: NSNotification.Name("DataSourceDidChange"),
            object: nil
        )
    }

    @objc private func handleUserLogout() {
        Task {
            await clearAllData()
        }
    }

    @objc private func handleDataSourceChange() {
        Task {
            await refreshData()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelAllTasks()
    }
}
