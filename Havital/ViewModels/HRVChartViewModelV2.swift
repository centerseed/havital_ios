import SwiftUI
import HealthKit

// MARK: - 重構後的 HRV Chart ViewModel (遵循統一架構模式)
/// 使用 HRVManager 和 BaseDataViewModel 的標準化實現
@MainActor
class HRVChartViewModelV2: BaseDataViewModel<HRVDataPoint, HRVManager> {
    
    // MARK: - HRV Specific Properties
    
    /// HRV 原始數據點
    @Published var hrvData: [HRVDataPoint] = [] {
        didSet {
            // 當 HRV 數據更新時，同步更新 data 數組以保持一致性
            data = hrvData
        }
    }
    
    /// 每日晨間平均值 (用於圖表顯示)
    @Published var morningAverages: [(Date, Double)] = []
    
    /// 選擇的時間範圍
    @Published var selectedTimeRange: HRVTimeRange = .week {
        didSet {
            if selectedTimeRange != oldValue {
                Task {
                    await switchTimeRange(selectedTimeRange)
                }
            }
        }
    }
    
    /// 授權狀態
    @Published var readAuthStatus: HKAuthorizationRequestStatus?
    
    /// 診斷信息
    @Published var diagnosticsInfo: HRVDiagnosticsInfo?
    @Published var diagnosticsText: String?
    
    // MARK: - Initialization
    
    override init(manager: HRVManager = HRVManager.shared) {
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
    
    // MARK: - HRV Data Management
    
    /// 載入 HRV 數據
    override func loadData() async {
        await manager.loadData()
        syncManagerState()
    }
    
    /// 刷新 HRV 數據
    override func refreshData() async {
        await manager.refreshData()
        syncManagerState()
    }
    
    /// 切換時間範圍
    func switchTimeRange(_ timeRange: HRVTimeRange) async {
        await manager.switchTimeRange(timeRange)
        syncManagerState()
    }
    
    // MARK: - Authorization & Diagnostics
    
    /// 檢查授權狀態
    func checkAuthorizationStatus() async {
        await manager.checkAuthorizationStatus()
        readAuthStatus = manager.readAuthStatus
    }
    
    /// 載入診斷信息
    func loadDiagnostics() async {
        await executeWithErrorHandling {
            await self.manager.loadDiagnostics()
            self.diagnosticsInfo = self.manager.diagnosticsInfo
            self.diagnosticsText = self.diagnosticsInfo?.formattedDescription
        }
    }
    
    /// 重新授權 (如果需要)
    func requestAuthorization() async {
        await executeWithErrorHandling {
            try await self.manager.service.requestAuthorization()
            await self.checkAuthorizationStatus()
            await self.loadData()
        }
    }
    
    // MARK: - Chart Helper Properties
    
    /// Y 軸範圍
    var yAxisRange: ClosedRange<Double> {
        return manager.yAxisRange
    }
    
    /// 是否有 HRV 數據
    var hasHRVData: Bool {
        return !morningAverages.isEmpty
    }
    
    /// 最新的 HRV 值
    var latestHRVValue: Double? {
        return morningAverages.last?.1
    }
    
    /// 平均 HRV 值
    var averageHRVValue: Double? {
        guard !morningAverages.isEmpty else { return nil }
        let sum = morningAverages.reduce(0.0) { $0 + $1.1 }
        return sum / Double(morningAverages.count)
    }
    
    /// 晨間測量點數量
    var morningMeasurementCount: Int {
        return hrvData.filter { $0.isMorningMeasurement }.count
    }
    
    /// 總測量點數量
    var totalMeasurementCount: Int {
        return hrvData.count
    }
    
    // MARK: - Time Range Helpers
    
    /// 所有可用的時間範圍
    var availableTimeRanges: [HRVTimeRange] {
        return HRVTimeRange.allCases
    }
    
    /// 當前時間範圍的描述
    var currentTimeRangeDescription: String {
        return selectedTimeRange.rawValue
    }
    
    /// 當前時間範圍的天數
    var currentTimeRangeDays: Int {
        return selectedTimeRange.days
    }
    
    // MARK: - Data Formatting
    
    /// 格式化 HRV 值顯示
    func formatHRVValue(_ value: Double) -> String {
        return String(format: "%.1f ms", value)
    }
    
    /// 格式化日期顯示
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    /// 獲取數據點的詳細信息
    func getDataPointInfo(at index: Int) -> String? {
        guard index < morningAverages.count else { return nil }
        
        let (date, value) = morningAverages[index]
        return "\(formatDate(date)): \(formatHRVValue(value))"
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
        guard let index = selectedDataPointIndex else { return nil }
        return getDataPointInfo(at: index)
    }
    
    // MARK: - Notification Setup Override
    
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        
        // 監聽 HRV 數據更新
        let hrvUpdateObserver = NotificationCenter.default.addObserver(
            forName: .hrvDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncManagerState()
        }
        notificationObservers.append(hrvUpdateObserver)
        
        // 監聽健康數據刷新
        let healthDataRefreshObserver = NotificationCenter.default.addObserver(
            forName: .appleHealthDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
        notificationObservers.append(healthDataRefreshObserver)
    }
    
    // MARK: - Private Helper Methods
    
    private func bindManagerProperties() {
        // 如果需要，可以使用 Combine 來綁定 manager 的屬性變化
        // 目前使用 syncManagerState() 的方式來同步狀態
    }
    
    private func syncManagerState() {
        hrvData = manager.hrvData
        morningAverages = manager.morningAverages
        selectedTimeRange = manager.selectedTimeRange
        readAuthStatus = manager.readAuthStatus
        diagnosticsInfo = manager.diagnosticsInfo
        diagnosticsText = diagnosticsInfo?.formattedDescription
        
        // 同步基礎屬性
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
}

// MARK: - Computed Properties for UI
extension HRVChartViewModelV2 {
    
    /// 數據狀態描述
    var dataStatusDescription: String {
        if isLoading {
            return "載入中..."
        } else if let error = syncError {
            return "載入失敗: \(error)"
        } else if !hasHRVData {
            return "暫無 HRV 數據"
        } else {
            return "\(morningAverages.count) 天的數據"
        }
    }
    
    /// 授權狀態描述
    var authStatusDescription: String {
        guard let status = readAuthStatus else {
            return "授權狀態未知"
        }
        
        switch status {
        case .unnecessary:
            return "無需授權"
        case .shouldRequest:
            return "應該請求授權"
        case .unknown:
            return "授權狀態未知"
        @unknown default:
            return "授權狀態未知"
        }
    }
    
    /// 是否應該顯示授權請求按鈕
    var shouldShowAuthRequest: Bool {
        return readAuthStatus == .shouldRequest
    }
    
    /// 是否可以載入診斷信息
    var canLoadDiagnostics: Bool {
        return readAuthStatus != .shouldRequest
    }
}

// MARK: - Legacy Compatibility (漸進式遷移支援)
extension HRVChartViewModelV2 {
    
    /// 為了與現有 UI 代碼兼容，提供舊的方法名稱和屬性
    func loadHRVData() async {
        await loadData()
    }
    
    func fetchDiagnostics() async {
        await loadDiagnostics()
    }
    
    func fetchReadAuthStatus() async {
        await checkAuthorizationStatus()
    }
    
    /// 提供舊的時間範圍枚舉兼容性
    typealias TimeRange = HRVTimeRange
    
    /// 提供錯誤處理的兼容性
    var error: String? {
        get { return syncError }
        set { syncError = newValue }
    }
}