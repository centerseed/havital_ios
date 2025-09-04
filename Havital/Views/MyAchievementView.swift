import SwiftUI
import Charts
import HealthKit

struct SectionTitleWithInfo: View {
    let title: String
    let explanation: String
    @State private var showingInfo = false
    var useSheet: Bool = false
    var sheetContent: (() -> AnyView)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .if(!useSheet) { view in
                view.alert(title, isPresented: $showingInfo) {
                    Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {}
                } message: {
                    Text(explanation)
                }
            }
            .if(useSheet && sheetContent != nil) { view in
                view.sheet(isPresented: $showingInfo) {
                    sheetContent?()
                }
            }
            
            Spacer()
        }
    }
}

// Extension to support conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var sharedHealthDataManager = SharedHealthDataManager.shared
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // VDOT Chart Section - 所有數據源都顯示（從 API 獲取）
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: L10n.Performance.vdotTrend.localized,
                            explanation: L10n.Performance.vdotExplanation.localized
                        )
                        .padding(.horizontal)
                        
                        VDOTChartView()
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // Weekly Volume Chart Section - 週跑量趨勢圖
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: NSLocalizedString("performance.weekly_volume_trend", comment: "Weekly Volume Trend"),
                            explanation: NSLocalizedString("performance.weekly_volume_trend_description", comment: "Shows your weekly running mileage changes, helping you track training volume trends and adjust training plans.")
                        )
                        .padding(.horizontal)
                        
                        WeeklyVolumeChartView(showTitle: false)
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // HRV 趨勢圖 - 根據數據源選擇顯示方式
                    HRVChartSection()
                        .environmentObject(healthKitManager)
                        .environmentObject(sharedHealthDataManager)
                    
                    // 睡眠靜息心率圖 - 根據數據源選擇顯示方式
                    RestingHeartRateChartSection()
                        .environmentObject(healthKitManager)
                        .environmentObject(sharedHealthDataManager)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("performance.title", comment: "Performance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareWeeklyReview()
                    } label: {
                        if isGeneratingScreenshot {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isGeneratingScreenshot)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage = shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
        }
    }
    
    private func shareWeeklyReview() {
        isGeneratingScreenshot = true
        
        LongScreenshotCapture.captureView(
            VStack(spacing: 20) {
                // VDOT Chart Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitleWithInfo(
                        title: L10n.Performance.vdotTrend.localized,
                        explanation: L10n.Performance.vdotExplanation.localized
                    )
                    .padding(.horizontal)
                    
                    VDOTChartView()
                        .padding()
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(.horizontal)
                
                // Weekly Volume Chart Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitleWithInfo(
                        title: NSLocalizedString("performance.weekly_volume_trend", comment: "Weekly Volume Trend"),
                        explanation: NSLocalizedString("performance.weekly_volume_trend_description", comment: "Shows your weekly running mileage changes, helping you track training volume trends and adjust training plans.")
                    )
                    .padding(.horizontal)
                    
                    WeeklyVolumeChartView(showTitle: false)
                        .padding()
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(.horizontal)
                
                // HRV Chart Section
                HRVChartSection()
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)
                
                // Resting Heart Rate Chart Section
                RestingHeartRateChartSection()
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)
            }
            .padding(.vertical)
            .background(Color(UIColor.systemGroupedBackground))
        ) { image in
            DispatchQueue.main.async {
                self.isGeneratingScreenshot = false
                self.shareImage = image
                self.showShareSheet = true
            }
        }
    }
}

// MARK: - HRV Chart Section
struct HRVChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            switch dataSourcePreference {
            case .appleHealth:
                // Apple Health: 優先使用 API，失敗時回退到 HealthKit
                SharedHealthDataChartView(chartType: .hrv, fallbackToHealthKit: true)
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)
                    .padding()
                
            case .garmin:
                // Garmin: 僅使用 API 數據
                SharedHealthDataChartView(chartType: .hrv, fallbackToHealthKit: false)
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)
                    .padding()
                
            case .strava:
                // Strava: 不支援 HRV 數據
                EmptyDataSourceView(message: "Strava 不提供心率變異性數據")
                    .padding()
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: L10n.Performance.HRV.selectDataSourceHrv.localized)
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Resting Heart Rate Chart Section
struct RestingHeartRateChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    
    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            switch dataSourcePreference {
            case .appleHealth:
                // Apple Health: 使用現有的 HealthKit 數據
                SleepHeartRateChartView()
                    .environmentObject(healthKitManager)
                    .padding()
                
            case .garmin:
                // Garmin: 使用相同的 SleepHeartRateChartView，但設定 SharedHealthDataManager
                SleepHeartRateChartViewWithGarmin()
                    .environmentObject(healthKitManager)
                    .padding()
                
            case .strava:
                // Strava: 不支援靜息心率數據
                EmptyDataSourceView(message: "Strava 不提供靜息心率數據")
                    .padding()
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: NSLocalizedString("performance.select_data_source_resting_hr", comment: "Please select a data source to view resting heart rate trends"))
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Common Time Range Enum
enum ChartTimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    case threeMonths = "threeMonths"
    
    var localizedTitle: String {
        switch self {
        case .week: return L10n.Performance.TimeRange.week.localized
        case .month: return L10n.Performance.TimeRange.month.localized
        case .threeMonths: return L10n.Performance.TimeRange.threeMonths.localized
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

// MARK: - Shared Health Data Manager
class SharedHealthDataManager: ObservableObject, TaskManageable {
    // MARK: - Singleton
    static let shared = SharedHealthDataManager()
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    @Published var healthData: [HealthRecord] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isRefreshing = false // 新增：區分初始載入和刷新
    
    private let healthDataUploadManager = HealthDataUploadManager.shared
    private var hasLoaded = false
    
    private init() {
        setupNotificationObservers()
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 設置通知監聽
    private func setupNotificationObservers() {
        // 監聽 Garmin 數據刷新通知
        NotificationCenter.default.addObserver(
            forName: .garminHealthDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.forceRefreshData()
            }
        }
        
        // 監聽數據源切換通知
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.forceRefreshData()
            }
        }
    }
    
    func loadHealthDataIfNeeded() async {
        // 如果正在載入中，等待當前載入完成而不是跳過
        if isLoading {
            // 創建一個輪詢機制，等待載入完成
            while isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            return
        }
        
        let taskId = "load_health_data"
        
        await executeTask(id: taskId, operation: {
            return try await self.performLoadHealthDataIfNeeded()
        })
        
        // 確保數據載入完成後再返回
        while isLoading || isRefreshing {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        }
    }
    
    private func performLoadHealthDataIfNeeded() async throws {
        // 設置載入狀態
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // 檢查是否需要強制刷新（緩存過期或從未載入）
        if hasLoaded && !isCacheExpired() { 
            return 
        }
        
        // 第一步：先嘗試載入緩存數據
        await loadCachedDataFirst()
        
        // 第二步：背景更新API數據
        await refreshDataFromAPI()
    }
    
    /// 檢查緩存是否過期
    private func isCacheExpired() -> Bool {
        let timeKey = "health_data_cache_time_14"
        guard let cacheTime = UserDefaults.standard.object(forKey: timeKey) as? Date else { return true }
        return Date().timeIntervalSince(cacheTime) >= 1800 // 30分鐘
    }
    
    /// 強制刷新數據（忽略已載入狀態）
    func forceRefreshData() async {
        let taskId = "force_refresh_health_data"
        
        guard await executeTask(id: taskId, operation: {
            return try await self.performForceRefreshData()
        }) != nil else {
            return
        }
    }
    
    private func performForceRefreshData() async throws {
        hasLoaded = false
        try await performLoadHealthDataIfNeeded()
    }
    
    /// 先載入緩存數據（如果有的話）
    private func loadCachedDataFirst() async {
        // 檢查是否有緩存數據
        let cachedData = await getCachedHealthData(days: 14)
        
        await MainActor.run {
            if !cachedData.isEmpty {
                self.healthData = cachedData
                self.error = nil
                print("Displaying cached health data: \(cachedData.count) records")
            } else {
                // 沒有緩存數據時才顯示載入指示器
                self.isLoading = true
                self.error = nil
            }
        }
    }
    
    /// 從API刷新數據
    private func refreshDataFromAPI() async {
        hasLoaded = true
        
        await MainActor.run {
            if !self.healthData.isEmpty {
                // 有緩存數據時，使用刷新指示器而不是載入指示器
                self.isRefreshing = true
            } else {
                // 沒有緩存數據時，使用載入指示器
                self.isLoading = true
            }
        }
        
        // 使用統一架構的 HealthDataUploadManagerV2 獲取數據
        do {
            print("Using HealthDataUploadManagerV2 to get health data...")
            await HealthDataUploadManagerV2.shared.loadData()
            
            await MainActor.run {
                // 從 HealthDataUploadManagerV2 獲取指定天數的數據
                if let collection = HealthDataUploadManagerV2.shared.healthDataCollections[14] {
                    let newHealthData = collection.records
                    print("HealthDataUploadManagerV2 returned: \(newHealthData.count) health records")
                    
                    if !newHealthData.isEmpty {
                        self.healthData = newHealthData
                        self.error = nil
                    } else {
                        self.error = L10n.Performance.DataSource.serverError.localized
                    }
                } else {
                    self.error = L10n.Performance.DataSource.noHealthData.localized
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch {
            print("APIClient direct call failed: \(error)")
            
            // 回退到原來的方法
            let newHealthData = await healthDataUploadManager.getHealthData(days: 14)
            
            print("Fallback to HealthDataUploadManager: \(newHealthData.count) health records")
            
            await MainActor.run {
                if !newHealthData.isEmpty {
                    self.healthData = newHealthData
                    self.error = nil
                } else if self.healthData.isEmpty {
                    self.error = L10n.Performance.DataSource.loadHealthDataError.localized
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }
    
    /// 獲取緩存的健康數據
    private func getCachedHealthData(days: Int) async -> [HealthRecord] {
        // 直接調用 HealthDataUploadManager 的緩存檢查邏輯
        let cacheKey = "cached_health_daily_data_\(days)"
        let timeKey = "health_data_cache_time_\(days)"
        
        guard let cacheTime = UserDefaults.standard.object(forKey: timeKey) as? Date,
              Date().timeIntervalSince(cacheTime) < 1800 else { // 30分鐘有效期
            return []
        }
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedData = try? JSONDecoder().decode([HealthRecord].self, from: data) else {
            return []
        }
        
        return cachedData
    }
    
    /// 手動刷新數據
    func refreshData() async {
        let taskId = "refresh_health_data"
        
        guard await executeTask(id: taskId, operation: {
            return try await self.performRefreshData()
        }) != nil else {
            return
        }
    }
    
    private func performRefreshData() async throws {
        await MainActor.run {
            self.isRefreshing = true
            self.error = nil
        }
        
        let newHealthData = await healthDataUploadManager.refreshHealthData(days: 14)
        
        await MainActor.run {
            self.healthData = newHealthData
            self.isRefreshing = false
            if newHealthData.isEmpty {
                self.error = L10n.Performance.DataSource.loadDataError.localized
            }
        }
        
        // 如果沒有數據，拋出錯誤
        if newHealthData.isEmpty {
            throw NSError(domain: "SharedHealthDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.Performance.DataSource.loadHealthDataError.localized])
        }
    }
}

// MARK: - Chart Type Enum
enum HealthChartType {
    case hrv
    case restingHeartRate
}

// MARK: - Shared Health Data Chart View
struct SharedHealthDataChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    
    let chartType: HealthChartType
    let fallbackToHealthKit: Bool
    
    @State private var usingFallback = false
    @State private var selectedTimeRange: ChartTimeRange = .month
    @State private var chartHealthData: [HealthRecord] = []
    @State private var isLoadingChartData = false
    @State private var chartError: String?
    
    var body: some View {
        VStack {
            if isLoadingChartData {
                ProgressView(loadingMessage)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = chartError, !usingFallback {
                if fallbackToHealthKit && chartType == .hrv {
                    // HRV 可以回退到 HealthKit
                    HRVTrendChartView()
                        .environmentObject(healthKitManager)
                        .frame(height: 180)
                } else {
                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: error,
                        showRetryButton: true
                    ) {
                        Task {
                            await loadChartData()
                        }
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    // Title and Garmin Attribution for empty state
                    HStack {
                        Text(chartTitle)
                            .font(.headline)
                        
                        Spacer()
                        
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferenceManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }
                    .padding(.bottom, 8)
                    
                    EmptyStateView(type: chartType == .hrv ? .hrvData : .sleepHeartRateData)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                chartView
            }
        }
        .task {
            await loadChartData()
        }
        .onChange(of: selectedTimeRange) { _ in
            Task {
                await loadChartData()
            }
        }
    }
    
    private var loadingMessage: String {
        switch chartType {
        case .hrv: return L10n.Performance.HRV.loadingHrv.localized
        case .restingHeartRate: return NSLocalizedString("performance.loading_resting_hr", comment: "Loading resting heart rate data...")
        }
    }
    
    private var noDataMessage: String {
        switch chartType {
        case .hrv: return L10n.Performance.HRV.noHrvData.localized
        case .restingHeartRate: return NSLocalizedString("performance.no_resting_hr_data", comment: "No resting heart rate data")
        }
    }
    
    private var chartIcon: String {
        switch chartType {
        case .hrv: return "heart.text.square"
        case .restingHeartRate: return "heart"
        }
    }
    
    private var chartTitle: String {
        switch chartType {
        case .hrv: return L10n.Performance.HRV.hrvTitle.localized
        case .restingHeartRate: return NSLocalizedString("performance.resting_hr_title", comment: "Sleep Resting Heart Rate")
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        VStack {
            // Chart title and status indicators
            HStack {
                Text(chartTitle)
                    .font(.headline)
                
                Spacer()
                
                if sharedHealthDataManager.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("performance.updating", comment: "Updating..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if usingFallback {
                    // Remove local data indicator
                } else {
                    // Garmin Attribution for main chart data
                    ConditionalGarminAttributionView(
                        dataProvider: UserPreferenceManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                        deviceModel: nil,
                        displayStyle: .titleLevel
                    )
                }
            }
            .padding(.bottom, 8)
            
            
            Chart {
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    switch chartType {
                    case .hrv:
                        if let hrv = record.hrvLastNightAvg {
                            LineMark(
                                x: .value(L10n.Performance.Chart.date.localized, formatDateForChart(record.date)),
                                y: .value("HRV", hrv)
                            )
                            .foregroundStyle(.blue)
                            .symbol(Circle())
                        }
                    case .restingHeartRate:
                        if let rhr = record.restingHeartRate {
                            LineMark(
                                x: .value(L10n.Performance.Chart.date.localized, formatDateForChart(record.date)),
                                y: .value(L10n.Performance.Chart.restingHeartRate.localized, rhr)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatDateForDisplay(date))
                                .font(.caption)
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        switch chartType {
        case .hrv:
            let hrvValues = chartHealthData.compactMap { $0.hrvLastNightAvg }
            guard !hrvValues.isEmpty else { return 0...100 }
            
            let minValue = hrvValues.min() ?? 0
            let maxValue = hrvValues.max() ?? 100
            let range = maxValue - minValue
            
            if range < 10 {
                let center = (minValue + maxValue) / 2
                return (center - 15)...(center + 15)
            } else {
                let margin = range * 0.2
                return (minValue - margin)...(maxValue + margin)
            }
            
        case .restingHeartRate:
            let hrValues = chartHealthData.compactMap { $0.restingHeartRate }.map { Double($0) }
            guard !hrValues.isEmpty else { return 40...100 }
            
            let minValue = hrValues.min() ?? 40
            let maxValue = hrValues.max() ?? 100
            let range = maxValue - minValue
            
            if range < 5 {
                let center = (minValue + maxValue) / 2
                return (center - 10)...(center + 10)
            } else {
                let margin = range * 0.2
                return (minValue - margin)...(maxValue + margin)
            }
        }
    }
    
    
    private func formatDateForChart(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Independent Data Loading
    private func loadChartData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }
        
        do {
            // 使用 HealthDataUploadManager 獲取指定天數的數據
            let newHealthData = await HealthDataUploadManager.shared.getHealthData(days: selectedTimeRange.days)
            
            await MainActor.run {
                chartHealthData = newHealthData
                isLoadingChartData = false
                
                if newHealthData.isEmpty {
                    chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "Unable to load chart data")
                }
            }
        } catch {
            await MainActor.run {
                chartError = error.localizedDescription
                isLoadingChartData = false
            }
        }
    }
}

// MARK: - Legacy API Based Chart Views (保留以防需要)
struct APIBasedHRVChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    let fallbackToHealthKit: Bool
    
    @State private var healthData: [HealthRecord] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var usingFallback = false
    
    // 簡單的 task 取消追蹤
    @State private var loadTask: Task<Void, Never>?
    
    init(fallbackToHealthKit: Bool = true) {
        self.fallbackToHealthKit = fallbackToHealthKit
    }
    
    // 計算 HRV Y 軸範圍
    private var hrvYAxisDomain: ClosedRange<Double> {
        let hrvValues = healthData.compactMap { $0.hrvLastNightAvg }
        guard !hrvValues.isEmpty else { return 0...100 }
        
        let minValue = hrvValues.min() ?? 0
        let maxValue = hrvValues.max() ?? 100
        let range = maxValue - minValue
        
        // 如果數據範圍太小，手動擴展範圍來顯示變化
        if range < 10 {
            let center = (minValue + maxValue) / 2
            return (center - 15)...(center + 15)
        } else {
            // 增加 20% 的邊距
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView(L10n.Performance.HRV.loadingHrv.localized)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error, !usingFallback {
                if fallbackToHealthKit {
                    // 使用 HealthKit 的 HRV 圖表作為回退
                    HRVTrendChartView()
                        .environmentObject(healthKitManager)
                        .frame(height: 180)
                } else {
                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: error,
                        showRetryButton: true
                    ) {
                        Task {
                            await loadHealthData()
                        }
                    }
                }
            } else if healthData.isEmpty {
                EmptyStateView(type: .hrvData)
            } else {
                VStack {
                    Chart {
                        ForEach(healthData.indices, id: \.self) { index in
                            let record = healthData[index]
                            if let hrv = record.hrvLastNightAvg {
                                LineMark(
                                    x: .value(L10n.Performance.Chart.date.localized, formatDateForChart(record.date)),
                                    y: .value("HRV", hrv)
                                )
                                .foregroundStyle(.blue)
                                .symbol(Circle())
                            }
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartYScale(domain: hrvYAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
        .onAppear {
            // 如果沒有數據且不在載入中，才載入
            if healthData.isEmpty && !isLoading {
                loadTask?.cancel()
                loadTask = Task {
                    await loadHealthData()
                }
            }
        }
        .onDisappear {
            // 不取消任務，讓數據保持可用
            // loadTask?.cancel()
        }
    }
    
    private func loadHealthData() async {
        // 檢查是否已經在載入中，避免重複調用
        if isLoading {
            return
        }
        
        isLoading = true
        usingFallback = false
        
        // 優先嘗試從 API 獲取數據
        let newHealthData = await HealthDataUploadManager.shared.getHealthData(days: 14)
        
        // 無論如何都要更新 loading 狀態
        defer {
            isLoading = false
        }
        
        // 只有在獲取到數據時才更新，避免 TaskManageable 跳過時清空現有數據
        if !newHealthData.isEmpty {
            healthData = newHealthData
            error = nil
        } else if healthData.isEmpty {
            // 只有在沒有現有數據時才設為錯誤狀態
            error = L10n.Performance.HRV.noHrvData.localized
        }
    }
    
    private func getLocalHRVData() async -> [HealthRecord] {
        // 從 HealthKit 獲取本地 HRV 數據作為回退
        var records: [HealthRecord] = []
        let calendar = Calendar.current
        
        for i in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            do {
                // 獲取該日期的 HRV 數據
                let startOfDay = Calendar.current.startOfDay(for: date)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                
                let hrvDataPoints = try await healthKitManager.fetchHRVData(start: startOfDay, end: endOfDay)
                let avgHRV = hrvDataPoints.isEmpty ? nil : hrvDataPoints.map { $0.1 }.reduce(0, +) / Double(hrvDataPoints.count)
                
                let record = HealthRecord(
                    date: ISO8601DateFormatter().string(from: date),
                    dailyCalories: nil,
                    hrvLastNightAvg: avgHRV,
                    restingHeartRate: nil
                )
                records.append(record)
            } catch {
                // 單日數據失敗，跳過
                continue
            }
        }
        
        return records.reversed() // 時間順序排列
    }
    
    private func formatDateForChart(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
}

struct APIBasedRestingHeartRateChartView: View {
    @State private var healthData: [HealthRecord] = []
    @State private var isLoading = true
    @State private var error: String?
    
    // 簡單的 task 取消追蹤
    @State private var loadTask: Task<Void, Never>?
    
    // 計算靜息心率 Y 軸範圍
    private var restingHRYAxisDomain: ClosedRange<Double> {
        let hrValues = healthData.compactMap { $0.restingHeartRate }.map { Double($0) }
        guard !hrValues.isEmpty else { return 40...100 }
        
        let minValue = hrValues.min() ?? 40
        let maxValue = hrValues.max() ?? 100
        let range = maxValue - minValue
        
        // 如果數據範圍太小，手動擴展範圍來顯示變化
        if range < 5 {
            let center = (minValue + maxValue) / 2
            return (center - 10)...(center + 10)
        } else {
            // 增加 20% 的邊距
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
        }
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView(NSLocalizedString("performance.loading_resting_hr", comment: "Loading resting heart rate data..."))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("performance.load_failed", comment: "Load failed"))
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if healthData.isEmpty {
                EmptyStateView(type: .sleepHeartRateData)
            } else {
                Chart {
                    ForEach(healthData.indices, id: \.self) { index in
                        let record = healthData[index]
                        if let rhr = record.restingHeartRate {
                            LineMark(
                                x: .value(L10n.Performance.Chart.date.localized, formatDateForChart(record.date)),
                                y: .value(L10n.Performance.Chart.restingHeartRate.localized, rhr)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYScale(domain: restingHRYAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .task {
            loadTask?.cancel()
            loadTask = Task {
                await loadHealthData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        
        healthData = await HealthDataUploadManager.shared.getHealthData(days: 14)
        error = nil
        
        isLoading = false
    }
    
    private func formatDateForChart(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Empty Data Source View
struct EmptyDataSourceView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - Health Data Models are now in APIClient.swift

#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
