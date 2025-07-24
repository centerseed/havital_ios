import Foundation
import SwiftUI
import HealthKit

// MARK: - HRV 數據點擴展
extension HRVDataPoint {
    var isEstimated: Bool { false } // 默認不是估算值
    var source: String? { nil }     // 默認無來源
    
    var timeOfDay: Int {
        Calendar.current.component(.hour, from: date)
    }
    
    var isMorningMeasurement: Bool {
        return timeOfDay >= 0 && timeOfDay < 6
    }
}

// MARK: - HRV 時間範圍
enum HRVTimeRange: String, CaseIterable, Codable {
    case week = "一週"
    case month = "一個月"
    case threeMonths = "三個月"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

// MARK: - 統一 HRV 管理器
/// 遵循 DataManageable 協議，提供標準化的 HRV 數據管理
class HRVManager: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = [HRVDataPoint]
    typealias ServiceType = HealthKitManager // HRV 主要來自 HealthKit
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - HRV Specific Properties
    @Published var hrvData: [HRVDataPoint] = []
    @Published var selectedTimeRange: HRVTimeRange = .week
    @Published var morningAverages: [(Date, Double)] = [] // 每日晨間平均值
    @Published var readAuthStatus: HKAuthorizationRequestStatus?
    @Published var diagnosticsInfo: HRVDiagnosticsInfo?
    
    // MARK: - Dependencies
    let service: HealthKitManager
    private let cacheManager: HRVCacheManager
    
    // MARK: - TaskManageable Properties
    var activeTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "HRVManager" }
    
    // MARK: - Singleton
    static let shared = HRVManager()
    
    // MARK: - Initialization
    private init() {
        self.service = HealthKitManager()
        self.cacheManager = HRVCacheManager()
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "HRVManager 初始化",
            level: .info,
            labels: ["module": "HRVManager", "action": "initialize"]
        )
        
        // 檢查授權狀態
        await checkAuthorizationStatus()
        
        // 載入 HRV 數據
        await loadData()
    }
    
    func loadData() async {
        await executeDataLoadingTask(id: "load_hrv_data") {
            try await self.performLoadHRVData()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_hrv_data") {
            try await self.performRefreshHRVData()
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            hrvData = []
            morningAverages = []
            diagnosticsInfo = nil
            lastSyncTime = nil
            syncError = nil
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "HRV 數據已清除",
            level: .info,
            labels: ["module": "HRVManager", "action": "clear_all_data"]
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
    
    // MARK: - Core HRV Logic
    
    private func performLoadHRVData() async throws {
        // 優先從快取載入
        if let cachedData = cacheManager.loadHRVData(for: selectedTimeRange),
           !cacheManager.shouldRefresh() {
            await MainActor.run {
                self.updateHRVData(cachedData)
            }
            return
        }
        
        // 從 HealthKit 獲取
        let dateRange = getDateRange(for: selectedTimeRange)
        let rawData = try await service.fetchHRVData(start: dateRange.start, end: dateRange.end)
        
        // 轉換為標準化數據點
        let dataPoints = rawData.map { (date, value) in
            HRVDataPoint(
                date: date,
                value: value
            )
        }
        
        // 更新 UI 和快取
        await MainActor.run {
            self.updateHRVData(dataPoints)
        }
        
        cacheManager.saveHRVData(dataPoints, for: selectedTimeRange)
        
        // 發送通知
        NotificationCenter.default.post(name: .hrvDataDidUpdate, object: nil)
        
        Logger.firebase(
            "HRV 數據載入成功",
            level: .info,
            jsonPayload: [
                "time_range": selectedTimeRange.rawValue,
                "data_points": dataPoints.count,
                "morning_points": dataPoints.filter { $0.isMorningMeasurement }.count
            ]
        )
    }
    
    private func performRefreshHRVData() async throws {
        let dateRange = getDateRange(for: selectedTimeRange)
        let rawData = try await service.fetchHRVData(start: dateRange.start, end: dateRange.end)
        
        let dataPoints = rawData.map { (date, value) in
            HRVDataPoint(
                date: date,
                value: value
            )
        }
        
        await MainActor.run {
            self.updateHRVData(dataPoints)
        }
        
        cacheManager.saveHRVData(dataPoints, for: selectedTimeRange)
        
        // 發送通知
        NotificationCenter.default.post(name: .hrvDataDidUpdate, object: nil)
    }
    
    // MARK: - Time Range Management
    
    func switchTimeRange(_ timeRange: HRVTimeRange) async {
        guard timeRange != selectedTimeRange else { return }
        
        await MainActor.run {
            selectedTimeRange = timeRange
        }
        
        await loadData()
    }
    
    // MARK: - Authorization & Diagnostics
    
    func checkAuthorizationStatus() async {
        await executeDataLoadingTask(id: "check_auth_status", showLoading: false) {
            do {
                let status = try await self.service.checkHRVReadAuthorization()
                
                await MainActor.run {
                    self.readAuthStatus = status
                }
                
                Logger.firebase(
                    "HRV 授權狀態檢查完成",
                    level: .info,
                    jsonPayload: ["status": String(describing: status)]
                )
            } catch {
                Logger.firebase(
                    "HRV 授權狀態檢查失敗: \(error.localizedDescription)",
                    level: .error
                )
                throw error
            }
        }
    }
    
    func loadDiagnostics() async {
        await executeDataLoadingTask(id: "load_diagnostics", showLoading: false) {
            let dateRange = self.getDateRange(for: self.selectedTimeRange)
            
            do {
                let authStatus = try await self.service.checkHRVReadAuthorization()
                let diagnostics = try await self.service.fetchHRVDiagnostics(
                    start: dateRange.start,
                    end: dateRange.end
                )
                
                let diagnosticsInfo = HRVDiagnosticsInfo(
                    authorizationStatus: authStatus,
                    rawSampleCount: diagnostics.rawSampleCount,
                    sources: diagnostics.sources,
                    timeRange: self.selectedTimeRange,
                    dateRange: dateRange
                )
                
                await MainActor.run {
                    self.diagnosticsInfo = diagnosticsInfo
                }
                
            } catch {
                Logger.firebase(
                    "HRV 診斷信息載入失敗: \(error.localizedDescription)",
                    level: .error
                )
                throw error
            }
        }
    }
    
    // MARK: - Data Processing
    
    private func updateHRVData(_ dataPoints: [HRVDataPoint]) {
        hrvData = dataPoints.sorted { $0.date < $1.date }
        calculateMorningAverages()
    }
    
    private func calculateMorningAverages() {
        let calendar = Calendar.current
        
        // 按日期分組
        let groupedData = Dictionary(grouping: hrvData) { dataPoint in
            calendar.startOfDay(for: dataPoint.date)
        }
        
        // 計算每天的晨間平均值
        morningAverages = groupedData.compactMap { (date, dataPoints) -> (Date, Double)? in
            let morningPoints = dataPoints.filter { $0.isMorningMeasurement }
            
            guard !morningPoints.isEmpty else { return nil }
            
            let average = morningPoints.reduce(0.0) { $0 + $1.value } / Double(morningPoints.count)
            return (date, average)
        }
        .sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Helper Methods
    
    private func getDateRange(for timeRange: HRVTimeRange) -> (start: Date, end: Date) {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: now)!
        return (start: startDate, end: now)
    }
    
    var yAxisRange: ClosedRange<Double> {
        guard !morningAverages.isEmpty else { return 0...100 }
        
        let values = morningAverages.map { $0.1 }
        let min = values.min() ?? 0
        let max = values.max() ?? 100
        
        // 添加 10% 的 padding
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .appleHealthDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
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

// MARK: - Diagnostics Info Structure
struct HRVDiagnosticsInfo {
    let authorizationStatus: HKAuthorizationRequestStatus
    let rawSampleCount: Int
    let sources: [String]
    let timeRange: HRVTimeRange
    let dateRange: (start: Date, end: Date)
    
    var formattedDescription: String {
        let sourcesString = sources.joined(separator: ", ")
        return "讀取授權: \(authorizationStatus); 原始樣本數: \(rawSampleCount); 來源: [\(sourcesString)]"
    }
}

// MARK: - Cache Manager
private class HRVCacheManager: BaseCacheManagerTemplate<HRVCacheData> {
    
    init() {
        super.init(identifier: "hrv_cache", defaultTTL: 1800) // 30 minutes
    }
    
    // MARK: - Specialized Cache Methods
    
    func saveHRVData(_ data: [HRVDataPoint], for timeRange: HRVTimeRange) {
        var cacheData = loadFromCache() ?? HRVCacheData()
        cacheData.hrvDataByTimeRange[timeRange] = data
        saveToCache(cacheData)
    }
    
    func loadHRVData(for timeRange: HRVTimeRange) -> [HRVDataPoint]? {
        return loadFromCache()?.hrvDataByTimeRange[timeRange]
    }
}

// MARK: - Cache Data Structure
private struct HRVCacheData: Codable {
    var hrvDataByTimeRange: [HRVTimeRange: [HRVDataPoint]] = [:]
}
