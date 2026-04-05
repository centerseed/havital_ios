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
                .font(AppFont.headline())
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

// MARK: - Card Style Modifier for Dark Mode Support
struct CardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                // Dark mode: 使用稍亮的灰色背景
                // Light mode: 使用白色背景
                colorScheme == .dark
                    ? Color(UIColor.systemGray6)
                    : Color(UIColor.systemBackground)
            )
            .cornerRadius(10)
            .overlay(
                // 添加微妙的邊框以增強卡片邊界
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.white.opacity(0.08)  // Dark mode: 增強淺色陰影
                    : Color.black.opacity(0.1),   // Light mode: 使用深色陰影
                radius: colorScheme == .dark ? 5 : 1,
                x: 0,
                y: colorScheme == .dark ? 2 : 1
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var sharedHealthDataManager = SharedHealthDataManager.shared
    @ObservedObject private var trainingReadinessManager = TrainingReadinessManager.shared
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    @State private var refreshRotation: Double = 0

    // Personal Best v2 慶祝動畫相關
    @State private var showCelebration = false
    @State private var celebrationUpdate: PersonalBestUpdate?

    // 從快取讀取當前用戶資料（Clean Architecture）
    private var cachedUser: User? {
        UserProfileLocalDataSource().getUserProfile()
    }

    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferencesManager.shared.dataSourcePreference
    }

    // 格式化更新時間
    private var formattedUpdateTime: String? {
        guard let lastSync = trainingReadinessManager.lastSyncTime else {
            return nil
        }
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return "\(DateFormatterHelper.formatTime(lastSync))\(L10n.MyAchievement.updated.localized)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Training Readiness Section - 訓練準備度
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionTitleWithInfo(
                                title: NSLocalizedString("training_readiness.title", comment: ""),
                                explanation: NSLocalizedString("training_readiness.description", comment: "")
                            )

                            Spacer()

                            // Last updated time
                            if let updateTime = formattedUpdateTime {
                                Text(updateTime)
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                            }

                            Button(action: {
                                TrackedTask("MyAchievementView: forceRefresh") {
                                    print("[MyAchievementView] 🔄 用戶點擊刷新按鈕")
                                    await trainingReadinessManager.forceRefresh()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(trainingReadinessManager.isLoading ? .gray : .blue)
                                    .font(AppFont.body())
                                    .rotationEffect(.degrees(refreshRotation))
                            }
                            .disabled(trainingReadinessManager.isLoading)
                            .onChange(of: trainingReadinessManager.isLoading) { oldValue, newValue in
                                if newValue {
                                    // Start continuous rotation
                                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                        refreshRotation = 360
                                    }
                                } else {
                                    // Stop rotation
                                    withAnimation(.linear(duration: 0.2)) {
                                        refreshRotation = 0
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        TrainingReadinessView()
                            .padding()
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    // Personal Best v2 Card - 個人最佳成績
                    PersonalBestCardView(
                        personalBestData: cachedUser?.personalBestV2?["race_run"]
                    )

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
                    .cardStyle()
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
            .onAppear {
                // Load training readiness data when view appears
                TrackedTask("MyAchievementView: loadData") {
                    await trainingReadinessManager.loadData()
                }

                // Check for pending Personal Best celebration
                checkForCelebration()
            }
            .onReceive(NotificationCenter.default.publisher(for: .personalBestDidUpdate)) { notification in
                if let update = notification.object as? PersonalBestUpdate {
                    celebrationUpdate = update
                    showCelebration = true
                }
            }
            .overlay {
                if showCelebration, let update = celebrationUpdate {
                    PersonalBestCelebrationView(update: update) {
                        showCelebration = false
                        PersonalBestCelebrationStorage.markCelebrationAsShown()
                    }
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
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
                // Training Readiness Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitleWithInfo(
                        title: NSLocalizedString("training_readiness.title", comment: ""),
                        explanation: NSLocalizedString("training_readiness.description", comment: "")
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)

                    TrainingReadinessView()
                        .padding()
                }
                .cardStyle()
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
                .cardStyle()
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

    // MARK: - Personal Best Celebration

    /// 檢查是否有待顯示的慶祝動畫
    private func checkForCelebration() {
        if let pendingUpdate = PersonalBestCelebrationStorage.getPendingCelebrationUpdate() {
            celebrationUpdate = pendingUpdate

            // 延遲顯示，避免與頁面載入動畫衝突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCelebration = true
            }
        }
    }
}

// MARK: - Chart Tab Enums
enum HeartRateChartTab: String, CaseIterable {
    case hrv = "HRV"
    case restingHeartRate = "Resting HR"

    var title: String {
        switch self {
        case .hrv:
            return NSLocalizedString("performance.hrv", comment: "HRV")
        case .restingHeartRate:
            return NSLocalizedString("performance.resting_hr", comment: "Resting HR")
        }
    }
}

enum TrainingLoadChartTab: String, CaseIterable {
    case fitness = "Fitness"
    case tsb = "TSB"

    var title: String {
        switch self {
        case .fitness:
            return NSLocalizedString("performance.training_load.fitness_index", comment: "Fitness Index")
        case .tsb:
            return NSLocalizedString("performance.training_load.tsb", comment: "Training Stress Balance")
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
        UserPreferencesManager.shared.dataSourcePreference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題和選項卡
            VStack(spacing: 8) {
                // 動態標題和數據源標籤
                HStack {
                    SectionTitleWithInfo(
                        title: L10n.Performance.HRV.hrvTitle.localized,
                        explanation: L10n.Performance.HRV.selectDataSourceHrv.localized
                    )
                    
                    Spacer()
                    
                    // Chart title and status indicators
                    HStack {
                        if sharedHealthDataManager.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(NSLocalizedString("performance.updating", comment: "Updating..."))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        } else {
                            // Garmin Attribution for main chart data
                            ConditionalGarminAttributionView(
                                dataProvider: UserPreferencesManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                                deviceModel: nil,
                                displayStyle: .titleLevel
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

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
            .id(selectedTab) // 穩定視圖身份，防止切換時滾動
            .frame(minHeight: 200) // 設置最小高度，減少布局抖動
            .padding()
        }
        .cardStyle()
        .padding(.horizontal)
    }

    @ViewBuilder
    private var hrvChartContent: some View {
        // 移除高頻日誌：此方法在每次 UI 重新渲染時都會被調用

        switch dataSourcePreference {
        case .appleHealth:
            // Apple Health: 直接使用 HealthKit 數據（與靜息心率保持一致）
            HRVTrendChartView()
                .environmentObject(healthKitManager)

        case .garmin:
            // Garmin: 使用 API 數據
            SharedHealthDataChartView(chartType: .hrv, fallbackToHealthKit: false)
                .environmentObject(healthKitManager)
                .environmentObject(sharedHealthDataManager)

        case .strava:
            // Strava: 使用 API 數據
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
        case .appleHealth, .garmin:
            // ✅ 統一使用 SleepHeartRateChartView，ViewModel 會自動根據數據源處理
            SleepHeartRateChartView()
                .environmentObject(healthKitManager)

        case .strava:
            // Strava 不提供靜息心率數據
            EmptyDataSourceView(message: "Strava 不提供靜息心率數據")

        case .unbound:
            // 未綁定數據源
            EmptyDataSourceView(message: NSLocalizedString("performance.select_data_source_resting_hr", comment: "Please select a data source to view resting heart rate trends"))
        }
    }
}

// MARK: - Resting Heart Rate Chart Section
struct RestingHeartRateChartSection: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager

    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferencesManager.shared.dataSourcePreference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            switch dataSourcePreference {
            case .appleHealth, .garmin:
                // ✅ 統一使用 SleepHeartRateChartView，ViewModel 會自動根據數據源處理
                SleepHeartRateChartView()
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
    
    private let healthDataUploadManager = HealthDataUploadManagerV2.shared
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
            TrackedTask("TrainingReadinessManager: garminHealthDataRefresh") {
                await self?.forceRefreshData()
            }
        }

        // 監聽數據源切換通知
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            TrackedTask("TrainingReadinessManager: dataSourceChanged") {
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
            await APICallTracker.$currentSource.withValue("MyAchievementView: refreshDataFromAPI") {
                await HealthDataUploadManagerV2.shared.loadData()
            }
            
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
        
        await healthDataUploadManager.refreshData()
        let newHealthData = await healthDataUploadManager.getHealthData(days: 14)
        
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
                        TrackedTask("CombinedHeartRateChart: loadChartData") {
                            await loadChartData()
                        }
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    // Title and Garmin Attribution for empty state
                    HStack {
                        Text(chartTitle)
                            .font(AppFont.headline())
                        
                        Spacer()
                        
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferencesManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
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
            await TrackedTask("CombinedHeartRateChart: loadChartData") {
                await loadChartData()
            }.value
        }
        .onChange(of: selectedTimeRange) { _ in
            TrackedTask("CombinedHeartRateChart: timeRangeChanged") {
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
                                .font(AppFont.caption())
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
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
    }
    
    private func formatDateForDisplay(_ date: Date) -> String {
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.formatShortDate(date)
    }
    
    // MARK: - Independent Data Loading
    private func loadChartData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }

        print("🔍 [SharedHealthDataChartView] 開始載入圖表數據，類型: \(chartType), fallback: \(fallbackToHealthKit)")

        do {
            // 使用 HealthDataUploadManager 獲取指定天數的數據
            print("🔍 [SharedHealthDataChartView] 調用 HealthDataUploadManager.getHealthData(days: \(selectedTimeRange.days))")
            let newHealthData = await HealthDataUploadManagerV2.shared.getHealthData(days: selectedTimeRange.days)
            
            print("🔍 [SharedHealthDataChartView] 獲取到健康數據: \(newHealthData.count) 筆記錄")
            if chartType == .hrv {
                let hrvRecords = newHealthData.filter { $0.hrvLastNightAvg != nil }
                print("🔍 [SharedHealthDataChartView] HRV 有效記錄: \(hrvRecords.count) 筆")
                for record in hrvRecords.prefix(3) {
                    print("   - 日期: \(record.date), HRV: \(record.hrvLastNightAvg ?? 0)")
                }
            }

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
                        TrackedTask("HRVTrendChartView: loadHealthData") {
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
                loadTask = TrackedTask("HRVTrendChartView: onAppear") {
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
        let newHealthData = await HealthDataUploadManagerV2.shared.getHealthData(days: 14)
        
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
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
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
                        .font(AppFont.headline())
                    Text(error)
                        .font(AppFont.caption())
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
            loadTask = TrackedTask("RestingHeartRateChartView: loadHealthData") {
                await loadHealthData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        
        healthData = await HealthDataUploadManagerV2.shared.getHealthData(days: 14)
        error = nil
        
        isLoading = false
    }
    
    private func formatDateForChart(_ dateString: String) -> Date {
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
    }
}

// MARK: - Empty Data Source View
struct EmptyDataSourceView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(AppFont.dataMedium())
                .foregroundColor(.gray)
            
            Text(message)
                .font(AppFont.bodySmall())
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

    @State private var selectedTab: TrainingLoadChartTab = .fitness

    // 當前數據源設定
    private var dataSourcePreference: DataSourceType {
        UserPreferencesManager.shared.dataSourcePreference
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題和選項卡
            VStack(spacing: 8) {
                // 統一標題
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
                        TrackedTask("TrainingLoadChartSection: clearCache") {
                            await TrainingLoadDataManager.shared.clearCache()
                            // 觸發重新載入
                            NotificationCenter.default.post(name: NSNotification.Name("ReloadTrainingLoadData"), object: nil)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(AppFont.body())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // 選項卡切換
                Picker("Training Load Chart Type", selection: $selectedTab) {
                    ForEach(TrainingLoadChartTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
            }

            // 圖表內容
            switch dataSourcePreference {
            case .appleHealth, .garmin, .strava:
                Group {
                    switch selectedTab {
                    case .fitness:
                        FitnessIndexChartView()
                            .environmentObject(healthKitManager)
                            .environmentObject(sharedHealthDataManager)
                    case .tsb:
                        TSBChartView()
                            .environmentObject(healthKitManager)
                            .environmentObject(sharedHealthDataManager)
                    }
                }
                .padding()

            case .unbound:
                // 未綁定數據源
                EmptyDataSourceView(message: L10n.Performance.TrainingLoad.selectDataSourceTrainingLoad.localized)
                    .padding()
            }
        }
        .cardStyle()
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
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if let error = chartError {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: error,
                    showRetryButton: true
                ) {
                    TrackedTask("TrainingLoadChartView: loadChartData") {
                        await loadChartData()
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    // Title for empty state
                    HStack {
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferencesManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
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
                    Text(NSLocalizedString("performance.fitness_balance", comment: "Fitness Index & Training Stress Balance"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)

                    if isLoadingChartData {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("performance.syncing", comment: "Syncing..."))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                

                Chart {
                    // TSB 背景色分區（映射到fitness軸）
                    // 紅色區：TSB < -7（疲勞累積，需要休息）
                    RectangleMark(
                        xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                        xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                        yStart: .value("下限", mapTSBBoundaryToFitnessScale(tsbYAxisDomainIndependent.lowerBound)),
                        yEnd: .value("上限", mapTSBBoundaryToFitnessScale(-7))
                    )
                    .foregroundStyle(Color.red.opacity(0.1))

                    // 綠色區：-7 ≤ TSB ≤ +5（平衡狀態）
                    RectangleMark(
                        xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                        xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                        yStart: .value("下限", mapTSBBoundaryToFitnessScale(-7)),
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

                    // Fitness Index line (左軸) - Y軸值乘以10顯示
                    ForEach(chartHealthData.indices, id: \.self) { index in
                        let record = chartHealthData[index]
                        if let fitness = record.fitness {
                            LineMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("體適能指數", fitness * 10),
                                series: .value("類型", "體適能指數")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }

                    // Fitness 線上的點 - 根據 total_tss 決定實心或空心，Y軸值乘以10顯示
                    ForEach(chartHealthData.indices, id: \.self) { index in
                        let record = chartHealthData[index]
                        if let fitness = record.fitness {
                            if let totalTss = record.totalTss, totalTss == 0 {
                                // 空心圓 - total_tss = 0
                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness * 10)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(40)

                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness * 10)
                                )
                                .foregroundStyle(.white)
                                .symbol(.circle)
                                .symbolSize(10)
                            } else {
                                // 實心圓 - total_tss > 0
                                PointMark(
                                    x: .value("日期", formatDateForChart(record.date)),
                                    y: .value("體適能指數", fitness * 10)
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

                    RuleMark(y: .value("TSB -7", mapTSBBoundaryToFitnessScale(-7)))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartForegroundStyleScale([
                    NSLocalizedString("myachievement.text_10", comment: ""): .blue,
                    NSLocalizedString("trainingreadiness.tsb", comment: ""): .green
                ])
                .frame(height: 200)
                .chartYAxis {
                    // 只顯示左軸 - 體適能指數（藍色）
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.0f", doubleValue))
                                    .font(AppFont.caption())
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
                                    .font(AppFont.captionSmall())
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            AxisTick()
                        }
                    }
                }

                // TSB 狀態說明
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("myachievement.tsb", comment: ""))
                        .font(AppFont.caption())
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    HStack(spacing: 16) {
                        // 紅色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text(NSLocalizedString("myachievement.text_3", comment: ""))
                                .font(AppFont.captionSmall())
                                .foregroundColor(.secondary)
                        }

                        // 綠色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text(NSLocalizedString("myachievement.text_4", comment: ""))
                                .font(AppFont.captionSmall())
                                .foregroundColor(.secondary)
                        }

                        // 藍色區說明
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text(NSLocalizedString("myachievement.text_5", comment: ""))
                                .font(AppFont.captionSmall())
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

        }
    }


    /// Fitness Y-axis domain (左軸) - 獨立範圍，值乘以10顯示
    private var fitnessYAxisDomain: ClosedRange<Double> {
        let fitnessValues = chartHealthData.compactMap { $0.fitness }.map { $0 * 10 }
        guard !fitnessValues.isEmpty else { return 0...100 }
        let minValue = fitnessValues.min() ?? 0
        let maxValue = fitnessValues.max() ?? 100
        let range = maxValue - minValue
        if range < 20 {
            let center = (minValue + maxValue) / 2
            return (center - 10)...(center + 10)
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
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
    }

    private func formatDateForDisplay(_ date: Date) -> String {
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.formatShortDate(date)
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

// MARK: - Fitness Index Chart View (Training Index)
struct FitnessIndexChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()

    @State private var chartHealthData: [HealthRecord] = []
    @State private var isLoadingChartData = false
    @State private var chartError: String?

    var body: some View {
        VStack {
            if isLoadingChartData {
                ProgressView(NSLocalizedString("trainingprogress.text_0", comment: ""))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = chartError {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: error,
                    showRetryButton: true
                ) {
                    TrackedTask("FitnessIndexChartView: loadChartData") {
                        await loadChartData()
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    HStack {
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferencesManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }
                    .padding(.bottom, 8)

                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: "暫無訓練指數數據"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                // 檢查是否有足夠的訓練指數數據（ATL）
                let validFitnessData = chartHealthData.compactMap { record in
                    record.atl != nil ? record : nil
                }

                if validFitnessData.count < 1 {
                    VStack {
                        EmptyStateView(
                            type: .loadingFailed,
                            customMessage: NSLocalizedString("performancechart.text_0", comment: "")
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    fitnessIndexChartView
                }
            }
        }
        .task {
            await TrackedTask("FitnessIndexChartView: loadChartData") {
                await loadChartData()
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrainingLoadData"))) { _ in
            TrackedTask("FitnessIndexChartView: reloadTrainingLoadData") {
                await loadChartData()
            }
        }
    }

    @ViewBuilder
    private var fitnessIndexChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 移除標題，因為已在tab中顯示
            if isLoadingChartData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("misc.syncing", comment: ""))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Chart {
                // 動態綠色區域（CTL × 0.5 到 CTL × 1.5 範圍）- 先畫背景
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let ctl = record.ctl {
                        AreaMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            yStart: .value("CTL下界", max(0, (ctl * 0.7) * 10)),
                            yEnd: .value("CTL上界", (ctl * 1.3) * 10)
                        )
                        .foregroundStyle(Color.green.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // 動態 CTL 上界線（CTL × 1.5）
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let ctl = record.ctl {
                        LineMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            y: .value("CTL上界", (ctl * 1.3) * 10),
                            series: .value("線條", "CTL上界")
                        )
                        .foregroundStyle(.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // 動態 CTL 下界線（CTL × 0.5，最小值為0）
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let ctl = record.ctl {
                        LineMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            y: .value("CTL下界", max(0, (ctl * 0.7) * 10)),
                            series: .value("線條", "CTL下界")
                        )
                        .foregroundStyle(.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // ATL line (改用 ATL 作為) - ATL乘以10顯示，使用 series 形成連續線
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let atl = record.atl {
                        LineMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            y: .value("訓練指數", atl * 10),
                            series: .value("線條", "ATL")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // ATL 線上的點 - 根據 total_tss 決定實心或空心，ATL乘以10顯示
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let atl = record.atl {
                        if let totalTss = record.totalTss, totalTss == 0 {
                            // 空心圓 - total_tss = 0
                            PointMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("訓練指數", atl * 10)
                            )
                            .foregroundStyle(.blue)
                            .symbol(.circle)
                            .symbolSize(40)

                            PointMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("訓練指數", atl * 10)
                            )
                            .foregroundStyle(.white)
                            .symbol(.circle)
                            .symbolSize(10)
                        } else {
                            // 實心圓 - total_tss > 0
                            PointMark(
                                x: .value("日期", formatDateForChart(record.date)),
                                y: .value("訓練指數", atl * 10)
                            )
                            .foregroundStyle(.blue)
                            .symbol(.circle)
                            .symbolSize(30)
                        }
                    }
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.0f", doubleValue))
                                .font(AppFont.caption())
                                .foregroundColor(.blue)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisTick()
                }
            }
            .chartYScale(domain: fitnessYAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatWeekForDisplay(date))
                                .font(AppFont.captionSmall())
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisTick()
                    }
                }
            }

            // 圓點標記說明和CTL區間說明
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.MyAchievement.markerExplanation.localized)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        Text(L10n.MyAchievement.hasTraining.localized)
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 12, height: 12)
                        Text(L10n.MyAchievement.restDay.localized)
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // 簡化說明
                let hasCtlData = !chartHealthData.compactMap { $0.ctl }.isEmpty
                if hasCtlData {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.green.opacity(0.4))
                                .frame(width: 12, height: 12)
                            Text(NSLocalizedString("myachievement.text_6", comment: ""))
                                .font(AppFont.captionSmall())
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    /// Fitness Y-axis domain - 基於CTL值，綠區佔70%
    private var fitnessYAxisDomain: ClosedRange<Double> {
        let atlValues = chartHealthData.compactMap { $0.atl }
        guard !atlValues.isEmpty else { return 0...100 }

        // 基於CTL數據計算動態範圍（CTL × 0.5 到 CTL × 1.5）
        let ctlValues = chartHealthData.compactMap { $0.ctl }
        if !ctlValues.isEmpty {
            // 計算所有CTL點的動態範圍（CTL × 0.5 到 CTL × 1.5）
            let ctlUpperBounds = ctlValues.map { ($0 * 1.5) * 10 }
            let ctlLowerBounds = ctlValues.map { max(0, ($0 * 0.5) * 10) }

            let ctlMin = ctlLowerBounds.min() ?? 0
            let ctlMax = ctlUpperBounds.max() ?? 100

            // 確保ATL數據也在範圍內
            let atlValuesScaled = atlValues.map { $0 * 10 }
            let atlMin = atlValuesScaled.min() ?? ctlMin
            let atlMax = atlValuesScaled.max() ?? ctlMax

            // 計算最終範圍，添加少量緩衝
            let finalMin = max(0, min(ctlMin, atlMin) - 5)
            let finalMax = max(ctlMax, atlMax) + 5

            return finalMin...finalMax
        } else {
            // 没有CTL数据时，回退到ATL范围（ATL也乘以10）
            let atlValuesScaled = atlValues.map { $0 * 10 }
            let minValue = atlValuesScaled.min() ?? 0
            let maxValue = atlValuesScaled.max() ?? 100
            let range = maxValue - minValue
            if range < 20 {
                let center = (minValue + maxValue) / 2
                return (center - 10)...(center + 10)
            } else {
                let margin = range * 0.2
                return (minValue - margin)...(maxValue + margin)
            }
        }
    }

    /// 計算CTL基線值
    private func calculateCTLBaseline() -> Double? {
        let ctlValues = chartHealthData.compactMap { $0.ctl }
        guard !ctlValues.isEmpty else { return nil }

        // 使用CTL值的平均值作為基線
        let baseline = ctlValues.reduce(0, +) / Double(ctlValues.count)

        // 確保CTL基線在合理範圍內（與ATL數據相近）
        let atlValues = chartHealthData.compactMap { $0.atl }
        if !atlValues.isEmpty {
            let atlAverage = atlValues.reduce(0, +) / Double(atlValues.count)
            // 如果CTL與ATL相差太大，使用ATL平均值作為基線
            if abs(baseline - atlAverage) > 3 {
                return atlAverage
            }
        }

        return baseline
    }

    /// 將CTL值映射到顯示值
    private func mapCTLToDisplayValue(_ ctlValue: Double) -> Double {
        // 直接返回CTL值（已經在調用時乘以10），因為我們的Y軸域已經基於CTL*10計算
        return ctlValue
    }

    private func formatDateForChart(_ dateString: String) -> Date {
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
    }

    private func formatWeekForDisplay(_ date: Date) -> String {
        let currentWeek = trainingPlanViewModel.currentWeek
        if currentWeek == 0 {
            let calendar = Calendar.current
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return "w\(weekOfYear)"
        }

        let sortedData = chartHealthData.sorted { $0.date < $1.date }
        guard !sortedData.isEmpty else { return "w\(currentWeek)" }

        let dateString = formatDateString(date)
        if let index = sortedData.firstIndex(where: { $0.date == dateString }) {
            let totalDataPoints = sortedData.count
            let weeksSpan = max(4, totalDataPoints / 7)
            let relativePosition = Double(index) / Double(totalDataPoints - 1)
            let displayWeek = max(1, currentWeek - weeksSpan + Int(relativePosition * Double(weeksSpan)) + 1)
            return "w\(displayWeek)"
        }

        return "w\(currentWeek)"
    }

    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // MARK: - Data Loading
    private func loadChartData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }

        do {
            let cachedHealthData = await TrainingLoadDataManager.shared.getTrainingLoadData()

            await MainActor.run {
                chartHealthData = cachedHealthData
                isLoadingChartData = false

                if cachedHealthData.isEmpty {
                    chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "")
                }
            }

            let validFitnessData = cachedHealthData.compactMap { record in
                record.atl != nil ? record : nil
            }

            if validFitnessData.count < 5 && cachedHealthData.count < 10 {
                await MainActor.run { isLoadingChartData = true }

                let freshData = try await TrainingLoadDataManager.shared.forceRefreshData()

                await MainActor.run {
                    chartHealthData = freshData
                    isLoadingChartData = false

                    if freshData.isEmpty {
                        chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "")
                    }
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

// MARK: - TSB Chart View
struct TSBChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sharedHealthDataManager: SharedHealthDataManager
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()

    @State private var chartHealthData: [HealthRecord] = []
    @State private var isLoadingChartData = false
    @State private var chartError: String?

    var body: some View {
        VStack {
            if isLoadingChartData {
                ProgressView(NSLocalizedString("trainingprogress.text_0", comment: ""))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = chartError {
                EmptyStateView(
                    type: .loadingFailed,
                    customMessage: error,
                    showRetryButton: true
                ) {
                    TrackedTask("TSBChartView: loadChartData") {
                        await loadChartData()
                    }
                }
            } else if chartHealthData.isEmpty {
                VStack {
                    HStack {
                        ConditionalGarminAttributionView(
                            dataProvider: UserPreferencesManager.shared.dataSourcePreference == .garmin ? "Garmin" : nil,
                            deviceModel: nil,
                            displayStyle: .titleLevel
                        )
                    }
                    .padding(.bottom, 8)

                    EmptyStateView(
                        type: .loadingFailed,
                        customMessage: "暫無TSB數據"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                // 檢查是否有足夠的TSB數據
                let validTSBData = chartHealthData.compactMap { record in
                    record.tsb != nil ? record : nil
                }

                if validTSBData.count < 1 {
                    VStack {
                        EmptyStateView(
                            type: .loadingFailed,
                            customMessage: NSLocalizedString("performancechart.text_0", comment: "")
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    tsbChartView
                }
            }
        }
        .task {
            await TrackedTask("TSBChartView: loadChartData") {
                await loadChartData()
            }.value
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadTrainingLoadData"))) { _ in
            TrackedTask("TSBChartView: reloadTrainingLoadData") {
                await loadChartData()
            }
        }
    }

    @ViewBuilder
    private var tsbChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 移除標題，因為已在tab中顯示
            if isLoadingChartData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("misc.syncing", comment: ""))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Chart {
                // TSB 背景色分區
                // 紅色區：TSB < -7（疲勞狀態，需要休息）
                RectangleMark(
                    xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                    xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                    yStart: .value("下限", tsbYAxisDomain.lowerBound),
                    yEnd: .value("上限", -7)
                )
                .foregroundStyle(Color.red.opacity(0.1))

                // 綠色區：-7 ≤ TSB ≤ +1（平衡狀態）
                RectangleMark(
                    xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                    xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                    yStart: .value("下限", -7),
                    yEnd: .value("上限", 1)
                )
                .foregroundStyle(Color.green.opacity(0.1))

                // 藍色區：TSB > +1（最佳狀態）
                RectangleMark(
                    xStart: .value("開始", chartHealthData.first.map { formatDateForChart($0.date) } ?? Date()),
                    xEnd: .value("結束", chartHealthData.last.map { formatDateForChart($0.date) } ?? Date()),
                    yStart: .value("下限", 1),
                    yEnd: .value("上限", tsbYAxisDomain.upperBound)
                )
                .foregroundStyle(Color.blue.opacity(0.1))

                // TSB line
                ForEach(chartHealthData.indices, id: \.self) { index in
                    let record = chartHealthData[index]
                    if let tsb = record.tsb {
                        LineMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            y: .value("TSB", tsb)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        PointMark(
                            x: .value("日期", formatDateForChart(record.date)),
                            y: .value("TSB", tsb)
                        )
                        .foregroundStyle(.green)
                        .symbol(.circle)
                        .symbolSize(25)
                    }
                }

                // TSB 分界線
                RuleMark(y: .value("TSB +1", 1))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                RuleMark(y: .value("TSB 0", 0))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                RuleMark(y: .value("TSB -7", -7))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.0f", doubleValue))
                                .font(AppFont.caption())
                                .foregroundColor(.green)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisTick()
                }
            }
            .chartYScale(domain: tsbYAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatWeekForDisplay(date))
                                .font(AppFont.captionSmall())
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisTick()
                    }
                }
            }

            // TSB 狀態說明
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("myachievement.tsb", comment: ""))
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text(NSLocalizedString("myachievement.text_4", comment: ""))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text(NSLocalizedString("myachievement.text_4", comment: ""))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text(NSLocalizedString("myachievement.text_5", comment: ""))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    /// TSB Y-axis domain
    private var tsbYAxisDomain: ClosedRange<Double> {
        let tsbValues = chartHealthData.compactMap { $0.tsb }
        guard !tsbValues.isEmpty else { return -10...10 }
        let minValue = tsbValues.min() ?? -5
        let maxValue = tsbValues.max() ?? 2

        // 確保包含 TSB 的關鍵分界線（-4, 0, +1）
        let expandedMin = min(minValue, -4) - 1
        let expandedMax = max(maxValue, 1) + 1
        let expandedRange = expandedMax - expandedMin

        if expandedRange < 6 {
            return -5...3
        } else {
            let margin = expandedRange * 0.2
            return (expandedMin - margin)...(expandedMax + margin)
        }
    }

    private func formatDateForChart(_ dateString: String) -> Date {
        // ✅ 使用統一的日期格式化工具，確保使用用戶設定的時區
        return DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd") ?? Date()
    }

    private func formatWeekForDisplay(_ date: Date) -> String {
        let currentWeek = trainingPlanViewModel.currentWeek
        if currentWeek == 0 {
            let calendar = Calendar.current
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return "w\(weekOfYear)"
        }

        let sortedData = chartHealthData.sorted { $0.date < $1.date }
        guard !sortedData.isEmpty else { return "w\(currentWeek)" }

        let dateString = formatDateString(date)
        if let index = sortedData.firstIndex(where: { $0.date == dateString }) {
            let totalDataPoints = sortedData.count
            let weeksSpan = max(4, totalDataPoints / 7)
            let relativePosition = Double(index) / Double(totalDataPoints - 1)
            let displayWeek = max(1, currentWeek - weeksSpan + Int(relativePosition * Double(weeksSpan)) + 1)
            return "w\(displayWeek)"
        }

        return "w\(currentWeek)"
    }

    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // MARK: - Data Loading
    private func loadChartData() async {
        await MainActor.run {
            isLoadingChartData = true
            chartError = nil
        }

        do {
            let cachedHealthData = await TrainingLoadDataManager.shared.getTrainingLoadData()

            await MainActor.run {
                chartHealthData = cachedHealthData
                isLoadingChartData = false

                if cachedHealthData.isEmpty {
                    chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "")
                }
            }

            let validTSBData = cachedHealthData.compactMap { record in
                record.tsb != nil ? record : nil
            }

            if validTSBData.count < 5 && cachedHealthData.count < 10 {
                await MainActor.run { isLoadingChartData = true }

                let freshData = try await TrainingLoadDataManager.shared.forceRefreshData()

                await MainActor.run {
                    chartHealthData = freshData
                    isLoadingChartData = false

                    if freshData.isEmpty {
                        chartError = NSLocalizedString("performance.cannot_load_chart_data", comment: "")
                    }
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

// MARK: - Training Load Detail Explanation View
struct TrainingLoadDetailExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("trainingload.text_0", comment: ""))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(NSLocalizedString("trainingload.text_1", comment: ""))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 體適能指數 Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                                .font(AppFont.title2())
                            Text(NSLocalizedString("trainingload.text_2", comment: ""))
                                .font(AppFont.title2())
                                .fontWeight(.semibold)
                        }

                        Text(NSLocalizedString("trainingload.text_3", comment: ""))
                            .font(AppFont.body())

                        // 體適能指數趨勢說明
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("trainingload.text_4", comment: ""))
                                .font(AppFont.headline())
                                .padding(.top, 8)

                            fitnessRangeView(range: "↗️", description: NSLocalizedString("trainingload.text_5", comment: ""), color: .green, icon: "arrow.up.circle.fill")
                            fitnessRangeView(range: "➡️", description: NSLocalizedString("trainingload.text_6", comment: ""), color: .blue, icon: "minus.circle.fill")
                            fitnessRangeView(range: "↘️", description: NSLocalizedString("trainingload.text_7", comment: ""), color: .orange, icon: "arrow.down.circle.fill")
                            Text(NSLocalizedString("trainingload.text_8", comment: ""))
                                .font(AppFont.bodySmall())
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
                                .font(AppFont.title2())
                            Text(NSLocalizedString("trainingload.text_9", comment: ""))
                                .font(AppFont.title2())
                                .fontWeight(.semibold)
                        }

                        Text(NSLocalizedString("trainingload.text_10", comment: ""))
                            .font(AppFont.body())

                        // TSB 狀態說明
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("trainingload.text_11", comment: ""))
                                .font(AppFont.headline())
                                .padding(.top, 8)

                            tsbStatusView(
                                range: NSLocalizedString("trainingload.text_12", comment: ""),
                                title: NSLocalizedString("myachievement.text_5", comment: ""),
                                description: NSLocalizedString("trainingload.text_13", comment: ""),
                                color: .blue,
                                icon: "star.circle.fill",
                                backgroundColor: Color.blue.opacity(0.1)
                            )

                            tsbStatusView(
                                range: NSLocalizedString("trainingload.text_14", comment: ""),
                                title: NSLocalizedString("myachievement.text_4", comment: ""),
                                description: NSLocalizedString("trainingload.text_15", comment: ""),
                                color: .green,
                                icon: "checkmark.circle.fill",
                                backgroundColor: Color.green.opacity(0.1)
                            )

                            tsbStatusView(
                                range: NSLocalizedString("trainingload.text_16", comment: ""),
                                title: NSLocalizedString("myachievement.text_3", comment: ""),
                                description: NSLocalizedString("trainingload.text_17", comment: ""),
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
                                .font(AppFont.title2())
                            Text(NSLocalizedString("trainingload.text_18", comment: ""))
                                .font(AppFont.title2())
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            chartLegendView(
                                color: .blue,
                                title: NSLocalizedString("trainingload.text_19", comment: ""),
                                description: NSLocalizedString("trainingload.text_20", comment: "")
                            )

                            chartLegendView(
                                color: .green,
                                title: NSLocalizedString("trainingload.text_21", comment: ""),
                                description: NSLocalizedString("trainingload.text_22", comment: "")
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.MyAchievement.dotExplanation.localized)
                                    .font(AppFont.bodySmall())
                                    .fontWeight(.medium)

                                HStack(alignment: .center, spacing: 8) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 12, height: 12)
                                    Text(L10n.MyAchievement.solidDot.localized)
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                }

                                HStack(alignment: .center, spacing: 8) {
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                        .frame(width: 12, height: 12)
                                    Text(L10n.MyAchievement.hollowDot.localized)
                                        .font(AppFont.caption())
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
                                .font(AppFont.title2())
                            Text(NSLocalizedString("trainingload.text_23", comment: ""))
                                .font(AppFont.title2())
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            suggestionView(
                                icon: "arrow.up.circle.fill",
                                iconColor: .green,
                                title: NSLocalizedString("trainingload.text_24", comment: ""),
                                suggestion: NSLocalizedString("trainingload.text_25", comment: "")
                            )

                            suggestionView(
                                icon: "checkmark.circle.fill",
                                iconColor: .blue,
                                title: NSLocalizedString("trainingload.text_26", comment: ""),
                                suggestion: NSLocalizedString("trainingload.text_27", comment: "")
                            )

                            suggestionView(
                                icon: "arrow.down.circle.fill",
                                iconColor: .orange,
                                title: NSLocalizedString("trainingload.text_28", comment: ""),
                                suggestion: NSLocalizedString("trainingload.text_29", comment: "")
                            )

                            suggestionView(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .red,
                                title: NSLocalizedString("trainingload.text_30", comment: ""),
                                suggestion: NSLocalizedString("trainingload.text_31", comment: "")
                            )
                        }
                        .padding(.leading, 12)
                    }

                    Divider()

                    // 注意事項
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("trainingload.text_32", comment: ""))
                            .font(AppFont.headline())
                            .foregroundColor(.secondary)

                        Text(NSLocalizedString("trainingload.text_33", comment: ""))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)

                        Text(NSLocalizedString("trainingload.text_34", comment: ""))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)

                        Text(NSLocalizedString("trainingload.text_35", comment: ""))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)

                        Text(NSLocalizedString("trainingload.text_36", comment: ""))
                            .font(AppFont.caption())
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
                    Button(NSLocalizedString("common.done", comment: "")) {
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
                .font(AppFont.bodySmall())
                .fontWeight(.medium)
                .frame(width: 40, alignment: .leading)

            Text(description)
                .font(AppFont.bodySmall())
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
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .leading)

                Text(title)
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
            }

            Text(description)
                .font(AppFont.caption())
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
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                Text(description)
                    .font(AppFont.caption())
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
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                Text(suggestion)
                    .font(AppFont.caption())
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
