import Foundation
import SwiftUI

// MARK: - 重構後的 VDOT Chart ViewModel (遵循統一架構模式)
/// 使用 VDOTManager 和 BaseDataViewModel 的標準化實現
@MainActor
class VDOTChartViewModelV2: BaseDataViewModel<EnhancedVDOTDataPoint, VDOTManager> {
    
    // MARK: - VDOT Specific Properties
    
    /// VDOT 數據點
    @Published var vdotPoints: [EnhancedVDOTDataPoint] = [] {
        didSet {
            // 當 VDOT 數據更新時，同步更新 data 數組以保持一致性
            data = vdotPoints
        }
    }
    
    /// 統計信息
    @Published var statistics: VDOTStatistics?
    
    /// 是否需要更新心率範圍
    @Published var needUpdatedHrRange: Bool = false
    
    /// 數據點限制
    @Published var dataLimit: Int = 14 {
        didSet {
            if dataLimit != oldValue {
                Task {
                    await updateDataLimit(dataLimit)
                }
            }
        }
    }
    
    // MARK: - Chart Display Properties
    
    /// Y 軸範圍
    var yAxisRange: ClosedRange<Double> {
        return manager.yAxisMin...manager.yAxisMax
    }
    
    /// 平均 VDOT
    var averageVdot: Double {
        return manager.averageVDOT
    }
    
    /// 最新 VDOT
    var latestVdot: Double {
        return manager.currentVDOT
    }
    
    /// VDOT 趨勢
    var vdotTrend: VDOTManager.VDOTTrend {
        return manager.vdotTrend
    }
    
    // MARK: - Initialization
    
    override init(manager: VDOTManager = VDOTManager.shared) {
        super.init(manager: manager)
        
        // 綁定 manager 的屬性到 ViewModel
        bindManagerProperties()
    }
    
    // MARK: - Setup & Initialization
    
    override func initialize() async {
        await manager.initialize()
        
        // 同步管理器狀態
        syncManagerState()
    }
    
    // MARK: - VDOT Data Management
    
    /// 載入 VDOT 數據
    override func loadData() async {
        await manager.loadData()
        syncManagerState()
    }
    
    /// 刷新 VDOT 數據
    override func refreshData() async {
        await manager.refreshData()
        syncManagerState()
    }
    
    /// 更新數據點限制
    func updateDataLimit(_ limit: Int) async {
        await manager.updateDataLimit(limit)
        syncManagerState()
    }
    
    /// 強制刷新數據（清除快取）
    func forceRefreshData() async {
        await executeWithErrorHandling {
            await self.manager.clearCache()
            await self.manager.refreshData()
            self.syncManagerState()
        }
    }
    
    // MARK: - VDOT Query Methods
    
    /// 獲取指定日期的 VDOT 值
    func getVDOTForDate(_ date: Date) -> Double? {
        return manager.getVDOTForDate(date)
    }
    
    /// 獲取當前（最新）VDOT 值
    func getCurrentVDOT() -> Double {
        return manager.currentVDOT
    }
    
    // MARK: - Chart Interaction
    
    /// 選中的數據點索引
    @Published var selectedDataPointIndex: Int?
    
    /// 選擇數據點
    func selectDataPoint(at index: Int?) {
        selectedDataPointIndex = index
    }
    
    /// 獲取選中數據點的信息
    var selectedDataPointInfo: String? {
        guard let index = selectedDataPointIndex,
              index < vdotPoints.count else { return nil }
        
        let point = vdotPoints[index]
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        
        return "\(formatter.string(from: point.date)): \(L10n.Performance.VDOT.dynamicVdot.localized) \(String(format: "%.1f", point.dynamicVdot))"
    }
    
    // MARK: - Data Formatting
    
    /// 格式化 VDOT 值顯示
    func formatVDOTValue(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }
    
    /// 格式化日期顯示
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    /// 獲取數據點的詳細信息
    func getDataPointInfo(at index: Int) -> String? {
        guard index < vdotPoints.count else { return nil }
        
        let point = vdotPoints[index]
        var info = "\(formatDate(point.date)): \(L10n.Performance.VDOT.dynamicVdot.localized) \(formatVDOTValue(point.dynamicVdot))"
        
        if let weightVdot = point.weightVdot {
            info += ", \(L10n.Performance.VDOT.weightedVdot.localized) \(formatVDOTValue(weightVdot))"
        }
        
        return info
    }
    
    // MARK: - Statistics Properties
    
    /// 統計信息描述
    var statisticsDescription: String {
        guard let stats = statistics else {
            return L10n.Performance.VDOT.noStatistics.localized
        }
        
        return """
        \(L10n.Performance.VDOT.latestDynamicVdot.localized): \(formatVDOTValue(stats.latestDynamicVdot))
        \(L10n.Performance.VDOT.averageWeightedVdot.localized): \(formatVDOTValue(stats.averageWeightedVdot))
        \(L10n.Performance.VDOT.dataPointCount.localized): \(stats.dataPointCount)
        \(L10n.Performance.VDOT.trend.localized): \(vdotTrend.description)
        """
    }
    
    /// 數據範圍描述
    var dataRangeDescription: String {
        guard let stats = statistics,
              stats.dataPointCount > 0 else {
            return "暫無數據"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        
        return "\(formatter.string(from: stats.dateRange.start)) - \(formatter.string(from: stats.dateRange.end))"
    }
    
    // MARK: - Notification Setup Override
    
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        
        // 監聽 VDOT 數據更新
        let vdotUpdateObserver = NotificationCenter.default.addObserver(
            forName: .vdotDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncManagerState()
        }
        notificationObservers.append(vdotUpdateObserver)
        
        // 監聽運動記錄更新（可能影響 VDOT 計算）
        let workoutUpdateObserver = NotificationCenter.default.addObserver(
            forName: .workoutsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.backgroundRefresh()
            }
        }
        notificationObservers.append(workoutUpdateObserver)
    }
    
    // MARK: - Private Helper Methods
    
    private func bindManagerProperties() {
        // 如果需要，可以使用 Combine 來綁定 manager 的屬性變化
        // 目前使用 syncManagerState() 的方式來同步狀態
    }
    
    private func syncManagerState() {
        vdotPoints = manager.vdotDataPoints
        statistics = manager.statistics
        needUpdatedHrRange = manager.needUpdatedHrRange
        dataLimit = manager.dataLimit
        
        // 同步基礎屬性
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
}

// MARK: - Computed Properties for UI
extension VDOTChartViewModelV2 {
    
    /// 是否有數據 (重名，使用不同名稱)
    var hasVDOTData: Bool {
        return manager.hasData
    }
    
    /// 數據狀態描述
    var dataStatusDescription: String {
        if isLoading {
            return "載入中..."
        } else if let error = syncError {
            return "載入失敗: \(error)"
        } else if !hasVDOTData {
            return "暫無跑力數據"
        } else {
            return "\(manager.dataPointCount) 筆數據"
        }
    }
    
    /// 是否應該顯示心率範圍更新提示
    var shouldShowHRRangeUpdateAlert: Bool {
        return needUpdatedHrRange
    }
    
    /// 心率範圍更新提示文字
    var hrRangeUpdateMessage: String {
        return "建議更新心率區間設定以獲得更準確的跑力計算"
    }
    
    /// 快取狀態描述
    var cacheStatusDescription: String {
        let size = manager.getCacheSize()
        let isExpired = manager.isExpired()
        
        if size == 0 {
            return "無快取數據"
        } else {
            let status = isExpired ? "已過期" : "有效"
            return "快取大小: \(size) bytes (\(status))"
        }
    }
}

// MARK: - Data Limit Options
extension VDOTChartViewModelV2 {
    
    /// 可用的數據限制選項
    var availableDataLimits: [Int] {
        return [7, 14, 21, 30, 60]
    }
    
    /// 數據限制描述
    func dataLimitDescription(for limit: Int) -> String {
        if limit == 7 {
            return "一週"
        } else if limit == 14 {
            return "兩週"
        } else if limit == 21 {
            return "三週"
        } else if limit == 30 {
            return "一個月"
        } else if limit == 60 {
            return "兩個月"
        } else {
            return "\(limit) 筆"
        }
    }
}

// MARK: - Legacy Compatibility (漸進式遷移支援)
extension VDOTChartViewModelV2 {
    
    /// 為了與現有 UI 代碼兼容，提供舊的方法名稱和屬性
    func fetchVDOTData(limit: Int = 14, forceFetch: Bool = false) async {
        if limit != dataLimit {
            dataLimit = limit
        }
        
        if forceFetch {
            await forceRefreshData()
        } else {
            await loadData()
        }
    }
    
    func refreshVDOTData() async {
        await forceRefreshData()
    }
    
    /// 提供錯誤處理的兼容性
    var error: String? {
        get { return syncError }
        set { syncError = newValue }
    }
}