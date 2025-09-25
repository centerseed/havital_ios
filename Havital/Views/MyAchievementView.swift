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
                        .padding(.top, 12)
                        
                        VDOTChartView()
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)

                    // 訓練負荷圖 - 使用 health_daily API 取得 tsb_metrics
                    TrainingLoadChartSection()
                        .environmentObject(healthKitManager)
                        .environmentObject(sharedHealthDataManager)

                    // Weekly Volume Chart Section - 週跑量趨勢圖
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: NSLocalizedString("performance.weekly_volume_trend", comment: "Weekly Volume Trend"),
                            explanation: NSLocalizedString("performance.weekly_volume_trend_description", comment: "Shows your weekly running mileage changes, helping you track training volume trends and adjust training plans.")
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        WeeklyVolumeChartView(showTitle: false)
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // 合併的心率圖表 - HRV 和睡眠靜息心率
                    CombinedHeartRateChartSection()
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
                    .padding(.top, 12)
                    
                    VDOTChartView()
                        .padding()
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(.horizontal)

                // Training Load Chart Section
                TrainingLoadChartSection()
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)

                // Weekly Volume Chart Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitleWithInfo(
                        title: NSLocalizedString("performance.weekly_volume_trend", comment: "Weekly Volume Trend"),
                        explanation: NSLocalizedString("performance.weekly_volume_trend_description", comment: "Shows your weekly running mileage changes, helping you track training volume trends and adjust training plans.")
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    WeeklyVolumeChartView(showTitle: false)
                        .padding()
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .padding(.horizontal)
                
                // Combined Heart Rate Chart Section
                CombinedHeartRateChartSection()
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)

                // Training Load Chart Section
                TrainingLoadChartSection()
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

// MARK: - Combined Heart Rate Chart Section
struct CombinedHeartRateChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager

    @State private var selectedTab: HeartRateChartTab = .hrv

    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題和選項卡
            VStack(spacing: 8) {
                // 統一標題
                HStack {
                    Text("心率數據趨勢")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 12)

                    Spacer()
                }
                .padding(.horizontal)

                // 選項卡切換
                Picker("Heart Rate Chart Type", selection: $selectedTab) {
                    ForEach(HeartRateChartTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
            }

            // 圖表內容
            Group {
                switch selectedTab {
                case .hrv:
                    hrvChartContent
                case .restingHeartRate:
                    restingHeartRateChartContent
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var hrvChartContent: some View {
        switch dataSourcePreference {
        case .appleHealth:
            // Apple Health: 優先使用 API，失敗時回退到 HealthKit
            SharedHealthDataChartView(chartType: .hrv, fallbackToHealthKit: true)
                .environmentObject(healthKitManager)
                .environmentObject(sharedHealthDataManager)

        case .garmin:
            // Garmin: 僅使用 API 數據
            SharedHealthDataChartView(chartType: .hrv, fallbackToHealthKit: false)
                .environmentObject(healthKitManager)
                .environmentObject(sharedHealthDataManager)

        case .unbound:
            // 未綁定數據源
            EmptyDataSourceView(message: L10n.Performance.HRV.selectDataSourceHrv.localized)
        }
    }

    @ViewBuilder
    private var restingHeartRateChartContent: some View {
        switch dataSourcePreference {
        case .appleHealth:
            // Apple Health: 使用現有的 HealthKit 數據
            SleepHeartRateChartView()
                .environmentObject(healthKitManager)

        case .garmin:
            // Garmin: 使用相同的 SleepHeartRateChartView，但設定 SharedHealthDataManager
            SleepHeartRateChartViewWithGarmin()
                .environmentObject(healthKitManager)

        case .unbound:
            // 未綁定數據源
            EmptyDataSourceView(message: NSLocalizedString("performance.select_data_source_resting_hr", comment: "Please select a data source to view resting heart rate trends"))
        }
    }
}

// MARK: - Heart Rate Chart Tab Enum
enum HeartRateChartTab: String, CaseIterable {
    case hrv = "hrv"
    case restingHeartRate = "restingHeartRate"

    var title: String {
        switch self {
        case .hrv: return L10n.Performance.HRV.hrvTitle.localized
        case .restingHeartRate: return NSLocalizedString("performance.resting_hr_title", comment: "Sleep Resting Heart Rate")
        }
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
                    restingHeartRate: nil,
                    atl: nil,
                    ctl: nil,
                    fitness: nil,
                    tsb: nil,
                    updatedAt: nil,
                    workoutTrigger: nil
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

// MARK: - Training Load Chart Section
struct TrainingLoadChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager

    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferenceManager.shared.dataSourcePreference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitleWithInfo(
                    title: L10n.Performance.TrainingLoad.trainingLoadTitle.localized,
                    explanation: L10n.Performance.TrainingLoad.trainingLoadExplanation.localized,
                    useSheet: true,
                    sheetContent: {
                        AnyView(TrainingLoadDetailExplanationView())
                    }
                )

                Spacer()

                Button(action: {
                    Task {
                        await TrainingLoadDataManager.shared.clearCache()
                        // 觸發重新載入
                        NotificationCenter.default.post(name: NSNotification.Name("ReloadTrainingLoadData"), object: nil)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            switch dataSourcePreference {
            case .appleHealth, .garmin:
                // 無論 Apple Health 還是 Garmin，都使用 health_daily API 獲取 TSB metrics
                TrainingLoadChartView()
                    .environmentObject(healthKitManager)
                    .environmentObject(sharedHealthDataManager)
                    .padding()

            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: L10n.Performance.TrainingLoad.selectDataSourceTrainingLoad.localized)
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Training Load Chart View
struct TrainingLoadChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()

    @State private var chartHealthData: [HealthRecord] = []
    @State private var isLoadingChartData = false
    @State private var chartError: String?

    var body: some View {
        VStack {
            if isLoadingChartData {
                ProgressView(L10n.Performance.TrainingLoad.loadingTrainingLoad.localized)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = chartError {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: error,
                    showRetryButton: true
                ) {
                    Task {
                        await loadChartData()
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    // Title for empty state
                    HStack {
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferenceManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }
                    .padding(.bottom, 8)

                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: L10n.Performance.TrainingLoad.noTrainingLoadData.localized
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                // 檢查是否有足夠的TSB數據
                let validTSBData = chartHealthData.compactMap { record in
                    record.fitness != nil || record.tsb != nil ? record : nil
                }

                if validTSBData.count < 1 {
                    VStack {
                        EmptyStateView(
                            type: .loadingFailed,
                            customMessage: L10n.Performance.TrainingLoad.insufficientData.localized
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    trainingLoadChartView
                }
            }
        }
        .task {
            await loadChartData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrainingLoadData"))) { _ in
            Task {
                await loadChartData()
            }
        }
    }

    @ViewBuilder
    private var trainingLoadChartView: some View {
        VStack(spacing: 20) {
            // Chart title and status indicators

            // Combined Fitness & TSB Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("體適能指數 & 訓練壓力平衡")
                    .font(.subheadline)
                    .fontWeight(.medium)

                    if isLoadingChartData {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("同步中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                

                Chart {
                    // TSB 背景色分區（映射到fitness軸）
                    // 橙色區：TSB < -5（進步中但疲勞累積）
                    RectangleMark(
                        xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                        xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                        yStart: .value("下限", mapTSBBoundaryToFitnessScale(tsbYAxisDomainIndependent.lowerBound)),
                        yEnd: .value("上限", mapTSBBoundaryToFitnessScale(-6))
                    )
                    .foregroundStyle(Color.orange.opacity(0.1))

                    // 綠色區：-6 ≤ TSB ≤ +5（平衡狀態）
                    RectangleMark(
                        xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                        xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                        yStart: .value("下限", mapTSBBoundaryToFitnessScale(-6)),
                        yEnd: .value("上限", mapTSBBoundaryToFitnessScale(5))
                    )
                    .foregroundStyle(Color.green.opacity(0.1))

                    // 藍色區：TSB > +4（最佳狀態）
                    RectangleMark(
                        xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                        xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                        yStart: .value("下限", mapTSBBoundaryToFitnessScale(5)),
                        yEnd: .value("上限", mapTSBBoundaryToFitnessScale(tsbYAxisDomainIndependent.upperBound))
                    )
                    .foregroundStyle(Color.blue.opacity(0.1))

                    // Fitness Index line (左軸)
                    ForEach(chartHealthData.indices, id: \.self) { index in
                        let record = chartHealthData[index]
                        if let fitness = record.fitness {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("體適能指數", fitness),
                                series: .value("類型", "體適能指數")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }

                    // Fitness 線上的點 - 根據 total_tss 決定實心或空心
                    ForEach(chartHealthData.indices, id: \.self) { index in
                        let record = chartHealthData[index]
                        if let fitness = record.fitness {
                            if let totalTss = record.totalTss, totalTss == 0 {
                                // 空心圓 - total_tss = 0
                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(40)

                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness)
                                )
                                .foregroundStyle(.white)
                                .symbol(.circle)
                                .symbolSize(10)
                            } else {
                                // 實心圓 - total_tss > 0
                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(30)
                            }
                        }
                    }

                    // TSB line (右軸，映射到fitness軸範圍)
                    ForEach(chartHealthData.indices, id: \.self) { index in
                        let record = chartHealthData[index]
                        if let tsb = record.tsb {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("TSB", mapTSBToFitnessScale(tsb)),
                                series: .value("類型", "TSB")
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }

                    // TSB 分界線（映射到fitness軸範圍）
                    RuleMark(y: .value("TSB +5", mapTSBBoundaryToFitnessScale(5)))
                        .foregroundStyle(.blue.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                    RuleMark(y: .value("TSB 0", mapTSBBoundaryToFitnessScale(0)))
                        .foregroundStyle(.gray)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    RuleMark(y: .value("TSB -5", mapTSBBoundaryToFitnessScale(-5)))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartForegroundStyleScale([
                    "體適能指數": .blue,
                    "TSB": .green
                ])
                .frame(height: 200)
                .chartYAxis {
                    // 只顯示左軸 - 體適能指數（藍色）
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.0f", doubleValue))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisTick()
                    }
                    // TSB 右軸已隱藏
                }
                .chartYScale(domain: fitnessYAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatWeekForDisplay(date))
                                    .font(.caption2)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            AxisTick()
                        }
                    }
                }

                // TSB 狀態說明
                VStack(alignment: .leading, spacing: 4) {
                    Text("TSB 狀態指標")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    HStack(spacing: 16) {
                        // 橙色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text("疲勞累積")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // 綠色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text("平衡狀態")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // 藍色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text("最佳狀態")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

        }
    }


    /// Fitness Y-axis domain (左軸) - 獨立範圍
    private var fitnessYAxisDomain: ClosedRange<Double> {
        let fitnessValues = chartHealthData.compactMap { $0.fitness }
        guard !fitnessValues.isEmpty else { return 0...10 }
        let minValue = fitnessValues.min() ?? 0
        let maxValue = fitnessValues.max() ?? 10
        let range = maxValue - minValue
        if range < 2 {
            let center = (minValue + maxValue) / 2
            return (center - 1)...(center + 1)
        } else {
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
        }
    }

    /// TSB Y-axis domain (右軸) - 獨立範圍，上下界各擴展10
    private var tsbYAxisDomainIndependent: ClosedRange<Double> {
        let tsbValues = chartHealthData.compactMap { $0.tsb }
        guard !tsbValues.isEmpty else { return -30...30 }
        let minValue = tsbValues.min() ?? -5
        let maxValue = tsbValues.max() ?? 5

        // 確保包含 TSB 的關鍵分界線，並在上下界各加10
        let expandedMin = min(minValue, -5) - 2
        let expandedMax = max(maxValue, 5) + 2
        let expandedRange = expandedMax - expandedMin

        if expandedRange < 10 {
            return -6...6
        } else {
            let margin = expandedRange * 0.2
            return (expandedMin - margin)...(expandedMax + margin)
        }
    }

    /// 將TSB值映射到fitness軸範圍（實現雙軸效果）
    private func mapTSBToFitnessScale(_ tsbValue: Double) -> Double {
        let tsbDomain = tsbYAxisDomainIndependent
        let fitnessDomain = fitnessYAxisDomain

        // 將TSB值從其範圍映射到fitness範圍
        let tsbRange = tsbDomain.upperBound - tsbDomain.lowerBound
        let fitnessRange = fitnessDomain.upperBound - fitnessDomain.lowerBound

        let normalizedTSB = (tsbValue - tsbDomain.lowerBound) / tsbRange
        return fitnessDomain.lowerBound + (normalizedTSB * fitnessRange)
    }

    /// 將背景區域的TSB值映射到fitness軸範圍
    private func mapTSBBoundaryToFitnessScale(_ tsbBoundary: Double) -> Double {
        let tsbDomain = tsbYAxisDomainIndependent
        let fitnessDomain = fitnessYAxisDomain

        let tsbRange = tsbDomain.upperBound - tsbDomain.lowerBound
        let fitnessRange = fitnessDomain.upperBound - fitnessDomain.lowerBound

        let normalizedTSB = (tsbBoundary - tsbDomain.lowerBound) / tsbRange
        return fitnessDomain.lowerBound + (normalizedTSB * fitnessRange)
    }

    /// 將fitness軸值反向映射為TSB值（用於右軸標籤顯示）
    private func reverseMappingToTSBScale(_ fitnessValue: Double) -> Double {
        let tsbDomain = tsbYAxisDomainIndependent
        let fitnessDomain = fitnessYAxisDomain

        let tsbRange = tsbDomain.upperBound - tsbDomain.lowerBound
        let fitnessRange = fitnessDomain.upperBound - fitnessDomain.lowerBound

        let normalizedFitness = (fitnessValue - fitnessDomain.lowerBound) / fitnessRange
        return tsbDomain.lowerBound + (normalizedFitness * tsbRange)
    }

    private var tsbYAxisDomain: ClosedRange<Double> {
        let tsbValues = chartHealthData.compactMap { $0.tsb }
        guard !tsbValues.isEmpty else { return -50...50 }

        let minValue = tsbValues.min() ?? -50
        let maxValue = tsbValues.max() ?? 50
        let range = maxValue - minValue

        if range < 10 {
            let center = (minValue + maxValue) / 2
            return (center - 25)...(center + 25)
        } else {
            let margin = range * 0.2
            return (minValue - margin)...(maxValue + margin)
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

    /// 格式化週數顯示（例如: w23, w24, w25, w26）
    private func formatWeekForDisplay(_ date: Date) -> String {
        // 簡化邏輯：基於當前週數和數據範圍計算週數標籤
        let currentWeek = trainingPlanViewModel.currentWeek
        if currentWeek == 0 {
            let calendar = Calendar.current
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return "w\(weekOfYear)"
        }

        // 獲取數據的日期範圍，計算相對週數
        let sortedData = chartHealthData.sorted { $0.date < $1.date }
        guard !sortedData.isEmpty else { return "w\(currentWeek)" }

        let dateString = formatDateString(date)
        if let index = sortedData.firstIndex(where: { $0.date == dateString }) {
            // 最新數據對應當前週數，往前推算
            let totalDataPoints = sortedData.count
            let weeksSpan = max(4, totalDataPoints / 7) // 數據跨越的週數
            let relativePosition = Double(index) / Double(totalDataPoints - 1)
            let displayWeek = max(1, currentWeek - weeksSpan + Int(relativePosition * Double(weeksSpan)) + 1)
            return "w\(displayWeek)"
        }

        return "w\(currentWeek)"
    }

    /// 將 Date 轉換為 yyyy-MM-dd 格式的字串
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// 將 ISO 8601 格式或其他格式的日期字串轉換為 yyyy-MM-dd 格式
    private func convertToDateString(_ dateString: String) -> String {
        // 如果已經是 yyyy-MM-dd 格式，直接返回
        if dateString.count == 10 && dateString.contains("-") {
            return dateString
        }

        // 嘗試解析 ISO 8601 格式
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd"
            outputFormatter.timeZone = TimeZone.current
            return outputFormatter.string(from: date)
        }

        // 回退：返回原字串或默認值
        return dateString.isEmpty ? "2025-07-01" : dateString
    }

    // MARK: - Independent Data Loading
    private func loadChartData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }

        do {
            // 使用新的訓練負荷數據管理器（智能緩存 + 增量同步）
            Logger.debug("TrainingLoadChartView: 開始載入訓練負荷數據")
            let cachedHealthData = await TrainingLoadDataManager.shared.getTrainingLoadData()

            // 立即顯示緩存數據
            await MainActor.run {
                chartHealthData = cachedHealthData
                isLoadingChartData = false

                // 調試：檢查載入的數據是否包含 createdAt
                print("🔍 載入的數據筆數: \(cachedHealthData.count)")
                for (index, record) in cachedHealthData.prefix(3).enumerated() {
                    print("  記錄[\(index)]: date=\(record.date), createdAt=\(record.createdAt ?? "nil"), atl=\(record.atl?.description ?? "nil"), tsb=\(record.tsb?.description ?? "nil")")
                }
            }

            // 驗證數據質量
            let validTSBData = cachedHealthData.compactMap { record in
                record.fitness != nil || record.tsb != nil ? record : nil
            }

            // 詳細調試：檢查每筆記錄的 fitness 和 tsb 值
            print("🔍 驗證 TSB 數據有效性:")
            for (index, record) in cachedHealthData.prefix(5).enumerated() {
                let isValid = record.fitness != nil || record.tsb != nil
                print("  記錄[\(index)]: date=\(record.date), fitness=\(record.fitness?.description ?? "nil"), tsb=\(record.tsb?.description ?? "nil"), 有效=\(isValid)")
            }

            print("🔍 UI 顯示檢查: 總數據=\(cachedHealthData.count), 有效TSB數據=\(validTSBData.count)")

            Logger.debug("TrainingLoadChartView: 載入完成，總記錄數：\(cachedHealthData.count)，有效TSB數據：\(validTSBData.count)")

            // 如果沒有足夠的數據，嘗試強制刷新
            if validTSBData.count < 5 && cachedHealthData.count < 10 {
                Logger.debug("TrainingLoadChartView: 數據不足，執行強制刷新")

                await MainActor.run { isLoadingChartData = true }

                let freshData = try await TrainingLoadDataManager.shared.forceRefreshData()

                await MainActor.run {
                    chartHealthData = freshData
                    isLoadingChartData = false

                    if freshData.isEmpty {
                        chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "Unable to load chart data")
                    }
                }

                Logger.debug("TrainingLoadChartView: 強制刷新完成，獲得 \(freshData.count) 筆記錄")
            }
        } catch {
            await MainActor.run {
                chartError = error.localizedDescription
                isLoadingChartData = false
            }
        }
    }

    /// 強制刷新訓練負荷數據
    private func forceRefreshTrainingLoadData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }

        do {
            Logger.debug("TrainingLoadChartView: 用戶觸發強制刷新")
            let freshData = try await TrainingLoadDataManager.shared.forceRefreshData()

            await MainActor.run {
                chartHealthData = freshData
                isLoadingChartData = false

                if freshData.isEmpty {
                    chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "Unable to load chart data")
                }
            }

            Logger.debug("TrainingLoadChartView: 強制刷新成功，獲得 \(freshData.count) 筆記錄")

        } catch {
            await MainActor.run {
                chartError = error.localizedDescription
                isLoadingChartData = false
            }

            Logger.error("TrainingLoadChartView: 強制刷新失敗 - \(error.localizedDescription)")
        }
    }
}

// MARK: - Training Load Detail Explanation View
struct TrainingLoadDetailExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("訓練負荷詳細說明")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("了解您的體適能指數和訓練壓力平衡，幫助您優化訓練計劃")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 體適能指數 Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("體適能指數 (Fitness Index)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        Text("體適能指數反映您**相對於自己過往表現**的運動能力水平。這個數值會根據您最近的訓練強度、頻率和持續時間動態調整，重點在於觀察**趨勢變化**。")
                            .font(.body)

                        // 體適能指數趨勢說明
                        VStack(alignment: .leading, spacing: 8) {
                            Text("如何解讀趨勢：")
                                .font(.headline)
                                .padding(.top, 8)

                            fitnessRangeView(range: "↗️", description: "持續上升 - 體適能向上提升，但要注意疲勞的累積", color: .green, icon: "arrow.up.circle.fill")
                            fitnessRangeView(range: "➡️", description: "穩定維持 - 體能保持良好狀態", color: .blue, icon: "minus.circle.fill")
                            fitnessRangeView(range: "↘️", description: "下降趨勢 - 通常為減量期，關注TSB和HRV恢復", color: .orange, icon: "arrow.down.circle.fill")
                            Text("💡 重點：關注線條的**走向**比單一數值更重要")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.leading, 12)
                    }

                    Divider()

                    // TSB Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gauge.medium")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("訓練壓力平衡 (TSB)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        Text("TSB 反映您當前的訓練疲勞與恢復狀態之間的平衡。這個指標幫助您了解何時需要休息，何時可以增加訓練強度。")
                            .font(.body)

                        // TSB 狀態說明
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TSB 狀態解讀：")
                                .font(.headline)
                                .padding(.top, 8)

                            tsbStatusView(
                                range: "+5 以上",
                                title: "最佳狀態",
                                description: "身體已充分恢復，適合進行高強度訓練或比賽",
                                color: .blue,
                                icon: "star.circle.fill",
                                backgroundColor: Color.blue.opacity(0.1)
                            )

                            tsbStatusView(
                                range: "-5 到 +5",
                                title: "平衡狀態",
                                description: "訓練與恢復達到良好平衡，可維持規律訓練",
                                color: .green,
                                icon: "checkmark.circle.fill",
                                backgroundColor: Color.green.opacity(0.1)
                            )

                            tsbStatusView(
                                range: "-5 以下",
                                title: "疲勞累積",
                                description: "體能消耗較大，建議降低訓練強度或增加休息",
                                color: .orange,
                                icon: "exclamationmark.triangle.fill",
                                backgroundColor: Color.orange.opacity(0.1)
                            )
                        }
                        .padding(.leading, 12)
                    }

                    Divider()

                    // 圖表解讀 Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("圖表解讀指南")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            chartLegendView(
                                color: .blue,
                                title: "藍色線條 - 體適能指數",
                                description: "顯示您相對於過往表現的體能變化趨勢。重點觀察線條走向：上升代表進步，平穩代表維持，下降提醒調整訓練。"
                            )

                            chartLegendView(
                                color: .green,
                                title: "綠色線條 - TSB 值",
                                description: "顯示您的疲勞恢復狀態。觀察這條線的變化，可以幫助您決定訓練強度。"
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("圓點標記說明")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                HStack(alignment: .center, spacing: 8) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 12, height: 12)
                                    Text("實心圓點：有訓練的日子")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack(alignment: .center, spacing: 8) {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                        .frame(width: 12, height: 12)
                                    Text("空心圓點：當日無訓練")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    // 實用建議 Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.title2)
                            Text("實用建議")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            suggestionView(
                                icon: "arrow.up.circle.fill",
                                iconColor: .green,
                                title: "體適能指數上升 + TSB值偏高",
                                suggestion: "體能提升且恢復良好，可適當增加訓練強度，但需監控疲勞累積"
                            )

                            suggestionView(
                                icon: "checkmark.circle.fill",
                                iconColor: .blue,
                                title: "體適能指數穩定 + TSB平衡",
                                suggestion: "理想的訓練狀態，維持當前節奏並觀察長期趨勢"
                            )

                            suggestionView(
                                icon: "arrow.down.circle.fill",
                                iconColor: .orange,
                                title: "體適能指數下降",
                                suggestion: "可能處於減量期或需要恢復，關注TSB回升和HRV改善趨勢"
                            )

                            suggestionView(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .red,
                                title: "持續疲勞累積 (TSB <-10)",
                                suggestion: "建議進入恢復期，降低訓練量直到TSB和HRV顯示恢復跡象"
                            )
                        }
                        .padding(.leading, 12)
                    }

                    Divider()

                    // 注意事項
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重要提醒")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("• 訓練負荷數據需要至少 2-3 週的運動記錄才能提供準確的趨勢分析")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• 體適能指數下降不一定是壞事，可能代表正在進行有計畫的減量或恢復期")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• 建議同時觀察 TSB 和 HRV 趨勢，綜合判斷身體的恢復狀態")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• 如有身體不適，請優先考慮休息，數據僅供參考不可完全依賴")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fitnessRangeView(range: String, description: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(range)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .leading)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func tsbStatusView(
        range: String,
        title: String,
        description: String,
        color: Color,
        icon: String,
        backgroundColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(range)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .leading)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func chartLegendView(color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 20)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func suggestionView(icon: String, iconColor: Color, title: String, suggestion: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Health Data Models are now in APIClient.swift

#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
