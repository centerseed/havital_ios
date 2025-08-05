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
                    Button("了解", role: .cancel) {}
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
                            title: "VDOT 趨勢",
                            explanation: "VDOT 是根據您的跑步表現所計算出的有氧能力指標。隨著訓練進度的增加，您的 VDOT 值會逐漸提升。"
                        )
                        .padding(.horizontal)
                        
                        VDOTChartView()
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
            .navigationTitle("表現數據")
            .navigationBarTitleDisplayMode(.inline)
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
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: "請選擇數據來源以查看 HRV 趨勢")
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
                
            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: "請選擇數據來源以查看靜息心率趨勢")
                    .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
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
        let keys = ["7", "14", "30"].map { "health_data_cache_time_\($0)" }
        return keys.allSatisfy { key in
            guard let cacheTime = UserDefaults.standard.object(forKey: key) as? Date else { return true }
            return Date().timeIntervalSince(cacheTime) >= 1800 // 30分鐘
        }
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
                print("顯示緩存的健康數據，共 \(cachedData.count) 筆記錄")
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
        
        // 測試：直接使用 APIClient 獲取數據，與 VDOT 使用相同方式
        do {
            print("嘗試直接使用 APIClient 獲取健康數據...")
            let response: HealthDailyResponse = try await APIClient.shared.request(
                HealthDailyResponse.self,
                path: "/v2/workouts/health_daily?limit=14"
            )
            let newHealthData = response.data.healthData
            
            print("APIClient 直接調用返回: \(newHealthData.count) 筆健康記錄")
            if !newHealthData.isEmpty {
                print("健康數據樣本: \(newHealthData.prefix(2))")
            }
            
            await MainActor.run {
                if !newHealthData.isEmpty {
                    self.healthData = newHealthData
                    self.error = nil
                } else {
                    self.error = "伺服器暫時無法提供數據"
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch {
            print("APIClient 直接調用失敗: \(error)")
            
            // 回退到原來的方法
            let newHealthData = await healthDataUploadManager.getHealthData(days: 14)
            
            print("回退到 HealthDataUploadManager: \(newHealthData.count) 筆健康記錄")
            
            await MainActor.run {
                if !newHealthData.isEmpty {
                    self.healthData = newHealthData
                    self.error = nil
                } else if self.healthData.isEmpty {
                    self.error = "無法載入健康數據"
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
                self.error = "無法載入健康數據"
            }
        }
        
        // 如果沒有數據，拋出錯誤
        if newHealthData.isEmpty {
            throw NSError(domain: "SharedHealthDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "無法載入健康數據"])
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
    
    var body: some View {
        VStack {
            if sharedHealthDataManager.isLoading {
                ProgressView(loadingMessage)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = sharedHealthDataManager.error, !usingFallback {
                if fallbackToHealthKit && chartType == .hrv {
                    // HRV 可以回退到 HealthKit
                    HRVTrendChartView()
                        .environmentObject(healthKitManager)
                } else {
                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: error,
                        showRetryButton: true
                    ) {
                        Task {
                            await sharedHealthDataManager.refreshData()
                        }
                    }
                }
            } else if sharedHealthDataManager.healthData.isEmpty {
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
            await sharedHealthDataManager.loadHealthDataIfNeeded()
        }
    }
    
    private var loadingMessage: String {
        switch chartType {
        case .hrv: return "載入 HRV 數據中..."
        case .restingHeartRate: return "載入靜息心率數據中..."
        }
    }
    
    private var noDataMessage: String {
        switch chartType {
        case .hrv: return "無 HRV 數據"
        case .restingHeartRate: return "無靜息心率數據"
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
        case .hrv: return "心率變異性 (HRV) 趨勢"
        case .restingHeartRate: return "睡眠靜息心率"
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
                    Text("更新中...")
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
                ForEach(sharedHealthDataManager.healthData.indices, id: \.self) { index in
                    let record = sharedHealthDataManager.healthData[index]
                    switch chartType {
                    case .hrv:
                        if let hrv = record.hrvLastNightAvg {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("HRV", hrv)
                            )
                            .foregroundStyle(.blue)
                            .symbol(Circle())
                        }
                    case .restingHeartRate:
                        if let rhr = record.restingHeartRate {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("靜息心率", rhr)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
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
            let hrvValues = sharedHealthDataManager.healthData.compactMap { $0.hrvLastNightAvg }
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
            let hrValues = sharedHealthDataManager.healthData.compactMap { $0.restingHeartRate }.map { Double($0) }
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
                ProgressView("載入 HRV 數據中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error, !usingFallback {
                if fallbackToHealthKit {
                    // 使用 HealthKit 的 HRV 圖表作為回退
                    HRVTrendChartView()
                        .environmentObject(healthKitManager)
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
                                    x: .value("日期", formatDateForChart(record.date)),
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
            error = "無法載入 HRV 數據"
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
                ProgressView("載入靜息心率數據中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("載入失敗")
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
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("靜息心率", rhr)
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
