import Combine
import HealthKit
import SwiftUI
import Firebase

// 導入APINetworkError以便在錯誤處理中使用
// 這需要確保APIClient.swift中的APINetworkError是public的
// 如果不是，我們需要在這裡創建一個映射

// 網路錯誤類型
enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverError
    case badResponse
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "無法連接到網路，請檢查網路連線"
        case .timeout:
            return "網路連線超時，請稍後再試"
        case .serverError:
            return "伺服器錯誤，請稍後再試"
        case .badResponse:
            return "伺服器回應異常，請稍後再試"
        }
    }
}

@MainActor
class TrainingPlanViewModel: ObservableObject, TaskManageable {
    @Published var weeklyPlan: WeeklyPlan?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentWeekDistance: Double = 0.0
    // 使用 Published 確保 UI 能即時更新
    @Published private(set) var _currentWeekIntensity: TrainingIntensityManager.IntensityMinutes = .zero
    @Published var isLoadingIntensity = false
    private let intensityManager = TrainingIntensityManager.shared
    
    // 使用計算屬性確保每次讀取都得到最新的值
    var currentWeekIntensity: TrainingIntensityManager.IntensityMinutes {
        // 最新的強度值應該是計算後的實際值
        return TrainingIntensityManager.IntensityMinutes(
            low: _currentWeekIntensity.low,
            medium: _currentWeekIntensity.medium,
            high: _currentWeekIntensity.high
        )
    }
    @Published var isLoadingDistance = false
    @Published var workoutsByDay: [Int: [HKWorkout]] = [:]
    @Published var workoutsByDayV2: [Int: [WorkoutV2]] = [:]
    @Published var isLoadingWorkouts = false
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var selectedWeek: Int = 1
    @Published var currentWeek: Int = 1
    @Published var weekDateInfo: WeekDateInfo?
    @Published var showSyncingSplash: Bool = false // 新增此行
    /// 無對應週計畫時顯示
    @Published var noWeeklyPlanAvailable: Bool = false
    /// 當週尚無週計劃時顯示產生新週提示
    @Published var showNewWeekPrompt: Bool = false
    /// 當到新週但無計畫時提示
    @Published var showFinalWeekPrompt: Bool = false
    
    /// 可選過去週數範圍（不包含未來週）
    var availableWeeks: [Int] {
        if let currentWeek = calculateCurrentTrainingWeek() {
            return Array(1...currentWeek)
        }
        return []
    }
    
    // 週訓練回顧相關屬性
    @Published var weeklySummary: WeeklyTrainingSummary?
    @Published var isLoadingWeeklySummary = false
    @Published var weeklySummaryError: Error?
    @Published var showWeeklySummary = false
    @Published var lastFetchedWeekNumber: Int?
    
    // 網路錯誤處理
    @Published var networkError: NetworkError?
    @Published var showNetworkErrorAlert = false
    
    // 週摘要列表
    @Published var weeklySummaries: [WeeklySummaryItem] = []
    @Published var isLoadingWeeklySummaries = false
    @Published var weeklySummariesError: Error?
    
    // 統一使用 UnifiedWorkoutManager
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared
    private let workoutService = WorkoutV2Service.shared
    private let weeklySummaryService = WeeklySummaryService.shared
    
    // 追蹤哪些日子被展開的狀態
    @Published var expandedDayIndices = Set<Int>()
    
    // 添加屬性來追蹤當前計劃的週數，用於檢測計劃變更
    private var currentPlanWeek: Int?
    
    // 控制 loading 動畫顯示
    @Published var isLoadingAnimation = false
    
    // 初始化狀態標記，防止競爭條件
    private var isInitializing = true
    private var hasCompletedInitialLoad = false
    
    // Modifications data
    @Published var modifications: [Modification] = []
    @Published var modDescription: String = ""
    
    // 添加 Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // 任務管理 (使用 Actor-based TaskManageable 協議)
    let taskRegistry = TaskRegistry()
    
    // 可注入的現在時間，預設為系統時間，便於測試
    var now: () -> Date = { Date() }
    
    // MARK: - Network Error Handling
    
    /// 處理網路錯誤
    private func handleNetworkError(_ error: Error) -> NetworkError? {
        // 檢查是否為APINetworkError
        if let apiError = error as? APINetworkError {
            switch apiError {
            case .noConnection:
                return .noConnection
            case .timeout:
                return .timeout
            case .serverError:
                return .serverError
            case .badResponse:
                return .badResponse
            }
        }
        
        // 檢查是否為URLError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noConnection
            case .timedOut:
                return .timeout
            case .badServerResponse:
                return .badResponse
            default:
                return nil
            }
        }
        
        return nil
    }
    
    /// 重試網路請求
    func retryNetworkRequest() async {
        networkError = nil
        showNetworkErrorAlert = false
        
        // 重新載入週計劃
        await loadWeeklyPlan()
    }
    
    // 本地緩存相關
    private let userDefaults = UserDefaults.standard
    private let weeklySummariesCacheKey = "cached_weekly_summaries"
    private let lastUpdateTimeKey = "last_weekly_summaries_update"
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60 // 24小時
    
    // 檢查是否需要更新緩存
    private var shouldUpdateCache: Bool {
        guard let lastUpdate = userDefaults.object(forKey: lastUpdateTimeKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) > cacheExpirationInterval
    }
    
    // 從本地緩存加載數據
    private func loadCachedWeeklySummaries() {
        if let data = userDefaults.data(forKey: weeklySummariesCacheKey),
           let summaries = try? JSONDecoder().decode([WeeklySummaryItem].self, from: data) {
            self.weeklySummaries = summaries
        }
    }
    
    // 保存數據到本地緩存
    private func cacheWeeklySummaries(_ summaries: [WeeklySummaryItem]) {
        if let data = try? JSONEncoder().encode(summaries) {
            userDefaults.set(data, forKey: weeklySummariesCacheKey)
            userDefaults.set(Date(), forKey: lastUpdateTimeKey)
        }
    }
    
    // 更新週摘要列表
    @MainActor
    func fetchWeeklySummaries() async {
        // 如果不需要更新緩存且有緩存數據，直接使用緩存
        if !shouldUpdateCache && !weeklySummaries.isEmpty {
            return
        }
        
        await executeTask(id: "fetch_weekly_summaries") {
            await self.performFetchWeeklySummaries()
        }
    }
    
    private func performFetchWeeklySummaries() async {
        await MainActor.run {
            isLoadingWeeklySummaries = true
        }
        defer { 
            Task { @MainActor in
                isLoadingWeeklySummaries = false
            }
        }
        
        do {
            let summaries = try await weeklySummaryService.fetchWeeklySummaries()
            await MainActor.run {
                // 按照週數從新到舊排序
                self.weeklySummaries = summaries.sorted { $0.weekIndex > $1.weekIndex }
                // 更新緩存
                cacheWeeklySummaries(self.weeklySummaries)
            }
        } catch {
            Logger.error("Failed to fetch weekly summaries: \(error.localizedDescription)")
            await MainActor.run {
                // 如果獲取失敗但有緩存，使用緩存數據
                if weeklySummaries.isEmpty {
                    loadCachedWeeklySummaries()
                }
            }
        }
    }
    
    // 強制更新週摘要列表（用於產生新課表或週回顧後）
    @MainActor
    func forceUpdateWeeklySummaries() async {
        await executeTask(id: "force_update_weekly_summaries") {
            await self.performForceUpdateWeeklySummaries()
        }
    }
    
    private func performForceUpdateWeeklySummaries() async {
        do {
            let summaries = try await weeklySummaryService.fetchWeeklySummaries()
            await MainActor.run {
                // 按照週數從新到舊排序
                self.weeklySummaries = summaries.sorted { $0.weekIndex > $1.weekIndex }
                // 更新緩存
                cacheWeeklySummaries(self.weeklySummaries)
            }
        } catch {
            Logger.error("Failed to force update weekly summaries: \(error.localizedDescription)")
        }
    }
    
    // 在產生新課表後調用
    func onNewPlanGenerated() {
        Task {
            await forceUpdateWeeklySummaries()
        }
    }
    
    // 在產生週回顧後調用
    func onWeeklySummaryGenerated() {
        Task {
            await forceUpdateWeeklySummaries()
        }
    }
    
    // 初始化：等待用戶資料載入完成後再載入訓練資料
    init() {
        // 基本狀態初始化，延遲資料載入到用戶確認後
        Logger.debug("TrainingPlanViewModel: 開始初始化")
        
        // 設置通知監聽器將在初始化完成後調用
        
        // 非同步任務：正確的初始化順序
        Task {
            await self.initializeWithUserContext()
        }
    }
    
    // 依正確順序初始化：用戶資料 -> 訓練概覽 -> 週計劃
    private func initializeWithUserContext() async {
        Logger.debug("TrainingPlanViewModel: 等待用戶資料載入完成...")
        
        // 等待用戶認證和資料載入完成
        await waitForUserDataReady()
        
        Logger.debug("TrainingPlanViewModel: 用戶資料就緒，開始載入訓練資料")
        
        let onboardingCompleted = AuthenticationService.shared.hasCompletedOnboarding
        let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()

        await MainActor.run {
            if onboardingCompleted && savedOverview.createdAt.isEmpty {
                self.showSyncingSplash = true
            }

            if !savedOverview.createdAt.isEmpty {
                self.trainingOverview = savedOverview
                self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: savedOverview.createdAt) ?? 1
                self.selectedWeek = self.currentWeek
            }
        }
        
        // 載入或更新訓練概覽
        await loadTrainingOverviewWithUserContext(savedOverview: savedOverview, onboardingCompleted: onboardingCompleted)
    }
    
    // 等待用戶資料就緒
    private func waitForUserDataReady() async {
        // 檢查是否已認證且用戶資料載入完成
        let maxWaitTime: TimeInterval = 10.0 // 最多等待10秒
        let checkInterval: TimeInterval = 0.1 // 每100ms檢查一次
        var waitedTime: TimeInterval = 0
        
        while waitedTime < maxWaitTime {
            let isAuthenticated = AuthenticationService.shared.isAuthenticated
            
            // 簡化檢查：主要確認用戶已認證
            if isAuthenticated {
                Logger.debug("TrainingPlanViewModel: 用戶已認證，資料就緒")
                return
            }
            
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            waitedTime += checkInterval
        }
        
        Logger.warn("TrainingPlanViewModel: 等待用戶資料超時，繼續初始化")
    }
    
    // 載入訓練概覽（考慮用戶上下文）
    private func loadTrainingOverviewWithUserContext(savedOverview: TrainingPlanOverview, onboardingCompleted: Bool) async {
        if savedOverview.createdAt.isEmpty {
            // 只有當本地 createdAt 為空時，才真正需要決定是否顯示 Splash 並從 API 獲取
            if onboardingCompleted {
                // 已 onboarding 但本地無資料，此時 showSyncingSplash 應為 true (已在同步區塊設定)
            } else {
                // 未 onboarding，無論本地是否有資料，都不應顯示此特定 splash
                // 確保 splash 關閉，因為這不是我們要處理的 splash case
                await MainActor.run {
                    self.showSyncingSplash = false
                }
            }

            do {
                let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
                TrainingPlanStorage.saveTrainingPlanOverview(overview) // 保存到本地
                await MainActor.run {
                    self.trainingOverview = overview
                    self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? 1
                    // Initialize selectedWeek to currentWeek to avoid showing incorrect week selection
                    self.selectedWeek = self.currentWeek
                    self.showSyncingSplash = false // 成功獲取後關閉 splash
                }
            } catch {
                Logger.error("初始化獲取訓練計劃概覽失敗: \(error)")
                await MainActor.run {
                    self.showSyncingSplash = false // 獲取失敗也關閉 splash，避免卡住
                }
            }
        } else {
            // 本地 savedOverview.createdAt 不是空的
            // 如果已 onboarding，確保 splash 是關閉的
            if onboardingCompleted {
                await MainActor.run {
                    self.showSyncingSplash = false
                }
            }
            // 如果未 onboarding，splash 狀態不由這裡的邏輯控制，應保持預設或由其他邏輯處理
        }
        // 無論如何，最後都要嘗試載入週計劃
        await self.loadWeeklyPlan()
        
        // 確保載入週數據（距離和強度），繞過 isInitializing 檢查
        await self.loadCurrentWeekDistance()
        await self.loadCurrentWeekIntensity()
        
        // 初始化完成後，設置通知監聽器，避免競爭條件
        await self.setupNotificationListeners()
        await MainActor.run {
            self.isInitializing = false
            self.hasCompletedInitialLoad = true
        }
    }
    
    // MARK: - Notification Setup
    
    /// 設置通知監聽器（在初始化完成後調用，避免競爭條件）
    @MainActor
    private func setupNotificationListeners() async {
        // 監聽 workouts 更新通知
        NotificationCenter.default.publisher(for: .workoutsDidUpdate)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // 防止在初始化期間響應通知
                guard !self.isInitializing, self.hasCompletedInitialLoad else {
                    print("初始化期間跳過 workoutsDidUpdate 通知")
                    return
                }
                
                print("收到 workoutsDidUpdate 通知，重新加載週跑量、訓練強度和每日訓練記錄...")
                Task {
                    // 使用統一方法同時更新週跑量和訓練強度
                    await self.loadCurrentWeekData()
                    // 同時更新每日訓練記錄，以便 DailyTrainingCard 能顯示最新數據
                    await self.loadWorkoutsForCurrentWeek()
                }
            }
            .store(in: &cancellables)
        
        // 監聽訓練概覽更新通知
        NotificationCenter.default.publisher(for: NSNotification.Name("TrainingOverviewUpdated"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // 防止在初始化期間響應通知
                guard !self.isInitializing, self.hasCompletedInitialLoad else {
                    print("初始化期間跳過 TrainingOverviewUpdated 通知")
                    return
                }
                
                if let updatedOverview = notification.object as? TrainingPlanOverview {
                    print("收到 TrainingOverviewUpdated 通知，更新訓練概覽...")
                    Task {
                        await MainActor.run {
                            self.trainingOverview = updatedOverview
                            // 重新計算當前週數
                            self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: updatedOverview.createdAt) ?? 1
                            self.selectedWeek = self.currentWeek
                        }
                        
                        // 重要：更新 overview 後必須重新載入週課表和其他相關資訊
                        print("概覽更新完成，開始重新載入週課表和相關資訊...")
                        await self.loadWeeklyPlan()
                        await self.loadCurrentWeekDistance()
                        await self.loadCurrentWeekIntensity()
                        await self.loadWorkoutsForCurrentWeek()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Plan display state
    enum PlanStatus: Equatable {
        case loading
        case noPlan
        case ready(WeeklyPlan)
        case completed
        case error(Error)
        
        static func == (lhs: PlanStatus, rhs: PlanStatus) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading),
                 (.noPlan, .noPlan),
                 (.completed, .completed):
                return true
            case (.ready(let lhsPlan), .ready(let rhsPlan)):
                return lhsPlan.id == rhsPlan.id
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    @Published var planStatus: PlanStatus = .loading
    
    // 獲取訓練回顧的方法
    @MainActor
    func createWeeklySummary() async {
        await executeTask(id: "create_weekly_summary") {
            await self.performCreateWeeklySummary()
        }
    }
    
    private func performCreateWeeklySummary() async {
        await MainActor.run {
            isLoadingAnimation = true // 顯示 Loading 動畫
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        
        defer {
            // 無論成功或失敗，最後都關閉動畫
            Task { @MainActor in
                isLoadingAnimation = false // 隱藏 Loading 動畫
            }
        }
        
        do {
            // 計算當前訓練週數
            guard let currentWeek = calculateCurrentTrainingWeek() else {
                throw NSError(
                    domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法計算當前訓練週數"])
            }
            
            // 從API獲取週訓練回顧數據
            let summary = try await weeklySummaryService.createWeeklySummary()
            
            // 保存到本地儲存
            WeeklySummaryStorage.shared.saveWeeklySummary(summary, weekNumber: currentWeek)
            
            await MainActor.run {
                self.weeklySummary = summary
                self.lastFetchedWeekNumber = currentWeek
                self.showWeeklySummary = true
                self.isLoadingWeeklySummary = false
            }
            
            // 更新訓練進度
            await forceUpdateWeeklySummaries()
            
        } catch {
            Logger.error("載入週訓練回顧失敗: \(error)")
            
            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
            }
            
            // 嘗試從本地儲存加載
            if let savedSummary = WeeklySummaryStorage.shared.loadWeeklySummary() {
                await MainActor.run {
                    self.weeklySummary = savedSummary
                    self.lastFetchedWeekNumber = WeeklySummaryStorage.shared
                        .getLastFetchedWeekNumber()
                    self.showWeeklySummary = true
                }
            }
        }
    }
    
    // 清除訓練回顧的方法
    func clearWeeklySummary() {
        WeeklySummaryStorage.shared.clearSavedWeeklySummary()
        
        Task { @MainActor in
            self.weeklySummary = nil
            self.lastFetchedWeekNumber = nil
            self.showWeeklySummary = false
        }
    }
    
    // 取得上兩週日期範圍的方法
    func getLastTwoWeeksRange() -> String {
        return WeekDateService.lastTwoWeeksRange()
    }
    
    /// 取得上週一到上週日的日期範圍字串（格式 MM/dd-MM/dd）
    func getLastWeekRangeString() -> String {
        return WeekDateService.lastWeekRange()
    }
    
    // 計算從訓練開始到當前的週數（改進版）
    func calculateCurrentTrainingWeek() -> Int? {
        return TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: trainingOverview?.createdAt ?? "")
    }
    
    // 取得訓練週數並輸出日誌
    func logCurrentTrainingWeek() {
        if let week = calculateCurrentTrainingWeek() {
            Logger.debug("當前是第 \(week) 週訓練")
        } else {
            Logger.debug("無法計算訓練週數")
        }
    }
    
    // 從 TrainingRecordViewModel 重用的方法
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return workoutService.isWorkoutUploaded(workout)
    }
    
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return workoutService.getWorkoutUploadTime(workout)
    }
    
    // 更新提示顯示狀態
    internal func updatePromptViews() {
        let cw = calculateCurrentTrainingWeek() ?? 0
        let total = trainingOverview?.totalWeeks ?? 0
        switch planStatus {
        case .noPlan:
            // 尚未生成本週計畫
            showNewWeekPrompt = (selectedWeek == cw)
            noWeeklyPlanAvailable = (selectedWeek < cw)
            showFinalWeekPrompt = false
        case .completed:
            // 完成最後一週後提示
            showFinalWeekPrompt = (selectedWeek == total)
            showNewWeekPrompt = false
            noWeeklyPlanAvailable = false
        default:
            // 其他狀態不顯示提示
            showNewWeekPrompt = false
            noWeeklyPlanAvailable = false
            showFinalWeekPrompt = false
        }
    }
    
    // Consolidated UI updater for weekly plan
    @MainActor private func updateWeeklyPlanUI(plan: WeeklyPlan?, planChanged: Bool = false, status: PlanStatus) {
        if let plan = plan {
            Logger.debug("updateWeeklyPlanUI: 更新週計劃 - 週數=\(plan.weekOfPlan), ID=\(plan.id)")
            Logger.debug("updateWeeklyPlanUI: 更新前 selectedWeek=\(self.selectedWeek)")
            
            self.weeklyPlan = plan
            self.currentPlanWeek = plan.weekOfPlan
            if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: plan.weekOfPlan) {
                self.weekDateInfo = info
            }
            self.selectedWeek = plan.weekOfPlan
            
            Logger.debug("updateWeeklyPlanUI: 更新後 selectedWeek=\(self.selectedWeek)")
            
            // Save the plan to cache when updating UI
            TrainingPlanStorage.saveWeeklyPlan(plan)
            if planChanged {
                self.workoutsByDay.removeAll()
                self.expandedDayIndices.removeAll()
            }
        } else {
            Logger.debug("updateWeeklyPlanUI: 週計劃為 nil")
        }
        self.planStatus = status
        updatePromptViews()
    }
    
    func loadWeeklyPlan(skipCache: Bool = false) async {
        await executeTask(id: "load_weekly_plan") {
            await self.performLoadWeeklyPlan(skipCache: skipCache)
        }
    }
    
    /// 執行實際的載入邏輯
    private func performLoadWeeklyPlan(skipCache: Bool = false) async {
        // 修正：在載入計畫前，務必先重新計算當前週數，確保資料最新
        if let overview = trainingOverview, !overview.createdAt.isEmpty {
            self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? self.currentWeek
        }
        
        // 僅在已有 trainingOverview.id 時才載入週計劃，避免無 overview 時報錯
        guard let overview = trainingOverview, !overview.id.isEmpty else { return }
        
        // 檢查是否應該跳過快取
        let shouldSkipCache = skipCache || shouldBypassCacheForWeeklyPlan()
        
        // 先檢查本地緩存（除非被要求跳過）
        if !shouldSkipCache, let savedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: currentWeek) {
            // 立即使用緩存數據更新 UI，不顯示 loading 狀態
            let cw = calculateCurrentTrainingWeek() ?? 0
            let status: PlanStatus = cw > overview.totalWeeks ? .completed : .ready(savedPlan)
            await updateWeeklyPlanUI(plan: savedPlan, status: status)
            
            // 在背景更新最新數據
            Task {
                do {
                    guard let overviewId = trainingOverview?.id else { throw NSError() }
                    Logger.info("Load weekly plan with planId: \(overviewId)_\(currentWeek).")
                    let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                        planId: "\(overviewId)_\(self.currentWeek)")
                    
                    // 檢查計劃是否有變更
                    let planChanged = savedPlan.id != newPlan.id || savedPlan.weekOfPlan != newPlan.weekOfPlan
                    
                    await updateWeeklyPlanUI(plan: newPlan, planChanged: planChanged, status: .ready(newPlan))
                    
                } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                    // 404: 無週計劃
                    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                } catch {
                    // 其他錯誤: 檢查是否為網路問題
                    if let networkError = self.handleNetworkError(error) {
                        await MainActor.run {
                            self.networkError = networkError
                            self.showNetworkErrorAlert = true
                        }
                    } else {
                        // 其他錯誤: 保持使用本地數據
                        Logger.error("API加載計劃失敗，保持使用本地數據: \(error)")
                    }
                }
            }
        } else {
            // 本地無數據或跳過快取時顯示 loading 狀態
            // 但只有在目前沒有任何計劃時才顯示 loading，避免閃爍
            if weeklyPlan == nil {
                planStatus = .loading
            }
            
            do {
                guard let overview = trainingOverview, !overview.id.isEmpty else {
                    Logger.debug("訓練概覽不存在或 ID 為空，先嘗試載入概覽")
                    await loadTrainingOverview()
                    guard trainingOverview != nil, !trainingOverview!.id.isEmpty else {
                        await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                        return
                    }
                    return // 添加 return，避免 guard 語句繼續執行
                }
                
                let overviewId = trainingOverview!.id
                Logger.debug("overview.totalWeeks: \(trainingOverview!.totalWeeks)")
                Logger.debug("cw: \(calculateCurrentTrainingWeek() ?? 0)")
                Logger.debug("self.currentWeek: \(self.currentWeek)")
                Logger.debug("self.selectedWeek: \(self.selectedWeek)")
                Logger.debug("準備載入週計劃 ID: \(overviewId)_\(self.currentWeek)")
                
                if (calculateCurrentTrainingWeek() ?? 0 > trainingOverview!.totalWeeks) {
                    Logger.debug("當前週數超過總週數，設置 .completed 狀態")
                    await updateWeeklyPlanUI(plan: nil, status: .completed)
                } else {
                    let planId = "\(overviewId)_\(self.currentWeek)"
                    Logger.debug("呼叫 API 載入週計劃，planId: \(planId)")
                    let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(planId: planId)
                    
                    Logger.debug("成功載入週計劃: 週數=\(newPlan.weekOfPlan), ID=\(newPlan.id)")
                    await updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))
                }
                
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404: 無週計劃，設置 .noPlan 狀態顯示「取得週回顧」按鈕
                Logger.debug("週計劃 404 錯誤，設置 .noPlan 狀態")
                await updateWeeklyPlanUI(plan: nil, status: .noPlan)
            } catch {
                // 檢查是否為任務取消錯誤
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("載入週計劃任務被取消，忽略此錯誤")
                    return // 忽略取消錯誤，不更新 UI 狀態
                }
                
                // 檢查是否為 API 404 錯誤（資源不存在）
                if let apiError = error as? APIError {
                    switch apiError {
                    case .business(.notFound(_)):
                        Logger.debug("API 404 錯誤，設置 .noPlan 狀態顯示「取得週回顧」按鈕")
                        await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                        return
                    default:
                        break
                    }
                }
                
                // 處理網路錯誤
                Logger.error("載入週計劃失敗: \(error.localizedDescription)")
                if let networkError = self.handleNetworkError(error) {
                    Logger.debug("識別為網路錯誤，顯示網路錯誤提示")
                    await MainActor.run {
                        self.networkError = networkError
                        self.showNetworkErrorAlert = true
                    }
                } else {
                    Logger.debug("非網路錯誤，設置 .error 狀態顯示 ErrorView")
                    await updateWeeklyPlanUI(plan: nil, status: .error(error))
                }
            }
        }
    }
    
    /// 判斷是否應該跳過週課表快取
    private func shouldBypassCacheForWeeklyPlan() -> Bool {
        // 如果是新的一週開始，需要跳過快取以確保週回顧按鈕正確顯示
        guard let overview = trainingOverview,
              let currentWeek = calculateCurrentTrainingWeek() else {
            return false
        }
        
        // 檢查是否有本地快取的週課表
        guard let savedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: currentWeek) else {
            return false // 沒有快取，不需要跳過
        }
        
        // 如果當前週數大於快取的週數，可能需要顯示週回顧按鈕
        return currentWeek > savedPlan.weekOfPlan
    }
    
    /// 依據指定週數產生對應週計劃
    func fetchWeekPlan(week: Int) async {
        planStatus = .loading
        await MainActor.run {
            error = nil
        }
        do {
            // 僅使用 GET 查詢指定週計劃
            guard let overviewId = trainingOverview?.id else { throw NSError() }
            let plan = try await TrainingPlanService.shared.getWeeklyPlanById(
                planId: "\(overviewId)_\(week)")
            
            await updateWeeklyPlanUI(plan: plan, status: .ready(plan))
            
            // 載入該週的健康資料
            await loadWorkoutsForCurrentWeek()
            await loadCurrentWeekData()
            await identifyTodayTraining()
            
        } catch let err as TrainingPlanService.WeeklyPlanError where err == .notFound {
            // 404 錯誤：顯示「取得週回顧」按鈕
            Logger.debug("fetchWeekPlan 404 錯誤，設置 .noPlan 狀態")
            await updateWeeklyPlanUI(plan: nil, status: .noPlan)
        } catch {
            // 檢查是否為任務取消錯誤
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                Logger.debug("載入週計劃任務被取消，忽略此錯誤")
                return // 忽略取消錯誤，不更新 UI 狀態
            }
            
            // 檢查是否為 API 404 錯誤
            if let apiError = error as? APIError {
                switch apiError {
                case .business(.notFound(_)):
                    Logger.debug("fetchWeekPlan API 404 錯誤，設置 .noPlan 狀態")
                    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                    return
                default:
                    break
                }
            }
            
            await updateWeeklyPlanUI(plan: nil, status: .error(error))
        }
    }
    
    // MARK: - New prompt display logic
    /// 是否已完成所有週的訓練
    var isFinalWeek: Bool {
        guard let plan = weeklyPlan else { return false }
        return currentWeek > plan.totalWeeks
    }
    
    /// 是否需要顯示「產生新週」提示
    var isNewWeekPromptNeeded: Bool {
        if planStatus == .loading {
            return false
        }
        return weeklyPlan == nil && selectedWeek == currentWeek
    }
    
    // 獲取當前週的日期範圍 (用於獲取訓練記錄)
    func getCurrentWeekDates() -> (Date, Date) {
        if let info = weekDateInfo {
            return (info.startDate, info.endDate)
        }
        
        // 默認情況：返回當前自然週的範圍
        let calendar = Calendar.current
        let today = Date()
        
        // 找到本週的週一
        let weekday = calendar.component(.weekday, from: today)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        
        // 週一日期
        let startDate = calendar.date(
            byAdding: .day, value: -adjustedWeekday + 1, to: calendar.startOfDay(for: today))!
        
        // 週日日期 (週一加6天)
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
        
        return (startDate, endOfDay)
    }
    
    // 獲取特定課表日的日期
    func getDateForDay(dayIndex: Int) -> Date? {
        return weekDateInfo?.daysMap[dayIndex]
    }
    
    // 判斷特定課表日是否為今天
    func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 修正的 loadTrainingOverview 方法
    func loadTrainingOverview() async {
        // 首先從本地存儲加載
        let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()
        if !savedOverview.trainingPlanName.isEmpty {
            await MainActor.run {
                self.trainingOverview = savedOverview
                // 重新計算當前週數，確保使用最新的本地數據
                self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: savedOverview.createdAt) ?? 1
                self.selectedWeek = self.currentWeek
            }
            
            // 輸出當前訓練週數
            logCurrentTrainingWeek()
            
            Logger.debug("已從本地加載訓練計劃概覽，跳過API調用以保留本地更新")
            return // 如果本地有數據，就不要從API獲取，避免覆蓋本地更新
        }
        
        // 只有當本地沒有數據時才從API獲取
        do {
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
            
            // 成功獲取後更新UI
            await MainActor.run {
                self.trainingOverview = overview
                self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? 1
                self.selectedWeek = self.currentWeek
            }
            Logger.debug("成功從API載入訓練計劃概覽")
            Logger.debug("Plan Overview id \(overview.id)")
            TrainingPlanStorage.saveTrainingPlanOverview(overview)
            logCurrentTrainingWeek()
        } catch {
            Logger.error("載入訓練計劃概覽從API失敗: \(error)")
            // 如果本地也沒有數據且API失敗，這是真正的錯誤
            if savedOverview.trainingPlanName.isEmpty {
                Logger.error("本地和API都無法獲取訓練計劃概覽")
            }
        }
    }
    
    // 用於 TrainingPlanView 中展示訓練計劃名稱
    var trainingPlanName: String {
        if let overview = trainingOverview, !overview.trainingPlanName.isEmpty {
            return overview.trainingPlanName
        }
        return "第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃"
    }
    
    // 在產生新週計劃時更新概覽
    // 產生指定週數的課表
    @MainActor
    func generateNextWeekPlan(targetWeek: Int) async {
        isLoadingAnimation = true // 開始時顯示動畫
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        // 開始背景任務
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        // 在 defer 區塊外定義一個函數來結束背景任務
        func endBackgroundTask() {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        // Defer ending the background task to ensure it's called
        defer {
            endBackgroundTask()
            Task { @MainActor in
                isLoadingAnimation = false // 結束時隱藏動畫
            }
        }
        planStatus = .loading
        
        do {
            Logger.debug("開始產生第 \(targetWeek) 週課表...")
            _ = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)
            
            // 產生成功後重新載入課表
            do {
                await MainActor.run {
                    isLoading = true
                    error = nil
                }
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                
                await updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))
                
                // 重新載入訓練計劃概覽，確保獲取最新資訊
                Logger.debug("重新載入訓練計劃概覽")
                await loadTrainingOverview()
                
                // 更新訓練進度
                await forceUpdateWeeklySummaries()
                
            } catch {
                Logger.error("重新載入課表失敗: \(error)")
                throw error
            }
        } catch {
            Logger.error("產生課表失敗: \(error)")
            await updateWeeklyPlanUI(plan: nil, status: .error(error))
        }
    }

    // Flag to ensure initial data load only once
    private var hasLoadedInitialData = false
    
    /// 只在第一次執行：先載入概覽，再載入週計劃、VDOT、記錄、距離等
    func loadAllInitialData() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        
        Logger.debug("TrainingPlanViewModel.loadAllInitialData: 開始執行")
        
        // 確保用戶資料已就緒
        await waitForUserDataReady()
        
        // 標記正在初始化
        await MainActor.run {
            isInitializing = true
        }
        
        // 首先確保 UnifiedWorkoutManager 被正確初始化和載入數據
        Logger.debug("初始化 UnifiedWorkoutManager...")
        await unifiedWorkoutManager.initialize()
        
        // 載入運動記錄（優先使用緩存）
        await unifiedWorkoutManager.loadWorkouts()
        Logger.debug("UnifiedWorkoutManager 載入完成，共有 \(unifiedWorkoutManager.workouts.count) 筆運動記錄")
        
        // 依序載入 overview，再載入 weeklyPlan
        await loadTrainingOverview()
        if weeklyPlan == nil {
            await loadWeeklyPlan()
        }
        
        // 確保基礎數據載入（簡單直接的方式）
        await loadWorkoutsForCurrentWeek()
        
        // 手動載入週數據，繞過初始化檢查
        await loadCurrentWeekDistance()
        await loadCurrentWeekIntensity()
        
        // 初始化完成後設置通知監聽器
        await setupNotificationListeners()
        await MainActor.run {
            isInitializing = false
            hasCompletedInitialLoad = true
        }
    }
    
    func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
        await executeTask(id: "refresh_weekly_plan") {
            await self.performRefreshWeeklyPlan(isManualRefresh: isManualRefresh)
        }
    }
    
    /// 執行實際的刷新邏輯
    private func performRefreshWeeklyPlan(isManualRefresh: Bool) async {
        // 檢查是否被取消
        guard !Task.isCancelled else { return }
        
        // 修正：在刷新計畫前，務必先重新計算當前週數，確保資料最新
        if let overview = trainingOverview, !overview.createdAt.isEmpty {
            self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? self.currentWeek
        }
        
        // 檢查是否被取消
        guard !Task.isCancelled else { return }
        
        // 刷新 UnifiedWorkoutManager 的數據
        await unifiedWorkoutManager.refreshWorkouts()
        
        // 檢查是否被取消
        guard !Task.isCancelled else { return }
        
        // 手動刷新時跳過快取，直接從 API 獲取最新數據
        if isManualRefresh {
            await loadWeeklyPlan(skipCache: true)
            return
        }
        
        // 下拉刷新僅更新資料，不變更 planStatus
        
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            // 檢查是否被取消
            guard !Task.isCancelled else { return }
            
            do {
                Logger.debug("開始更新計劃 (嘗試 \(currentRetry + 1)/\(maxRetries))")
                // 使用獨立 Task 呼叫 Service，避免 Button 或 View 取消影響
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let weekId = "\(overviewId)_\(self.currentWeek)"
                Logger.info("Load weekly plan with planId: \(weekId).")
                
                let newPlan = try await Task.detached(priority: .userInitiated) {
                    try await TrainingPlanService.shared.getWeeklyPlanById(planId: weekId)
                }.value
                
                // 檢查是否被取消
                guard !Task.isCancelled else { return }
                
                // 檢查計劃是否有變更
                let planWeekChanged =
                currentPlanWeek != nil && currentPlanWeek != newPlan.weekOfPlan
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                
                await updateWeeklyPlanUI(plan: newPlan, planChanged: planWeekChanged, status: .ready(newPlan))
                
                Logger.debug("完成更新計劃")
                
                // 檢查是否被取消
                guard !Task.isCancelled else { return }
                
                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek()
                
                // 檢查是否被取消
                guard !Task.isCancelled else { return }
                
                await identifyTodayTraining()
                
                // 檢查是否被取消
                guard !Task.isCancelled else { return }
                
                // 修正：無條件重新載入週數據，確保跨週時能正確歸零
                await loadCurrentWeekData()
                
                break  // 成功後跳出重試迴圈
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404 時標記無週計劃並結束重試，顯示「取得週回顧」按鈕
                Logger.debug("刷新週計劃 404 錯誤，設置 .noPlan 狀態")
                await MainActor.run {
                    self.weeklyPlan = nil
                }
                await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                break
            } catch let error as APIError {
                switch error {
                case .business(.notFound(_)):
                    // API 404 錯誤也應該顯示「取得週回顧」按鈕
                    Logger.debug("刷新週計劃 API 404 錯誤，設置 .noPlan 狀態")
                    await MainActor.run {
                        self.weeklyPlan = nil
                    }
                    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                    break
                default:
                    // 其他 API 錯誤當作普通錯誤處理，不 break，繼續到重試邏輯
                    currentRetry += 1
                    if currentRetry >= maxRetries {
                        await updateWeeklyPlanUI(plan: nil, status: .error(error))
                        Logger.error("刷新訓練計劃失敗 (已重試 \(maxRetries) 次): \(error)")
                    } else {
                        Logger.error("刷新訓練計劃失敗，準備重試: \(error)")
                        try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))  // 等待1秒後重試
                    }
                }
            } catch {
                currentRetry += 1
                if currentRetry >= maxRetries {
                    await updateWeeklyPlanUI(plan: nil, status: .error(error))
                    Logger.error("刷新訓練計劃失敗 (已重試 \(maxRetries) 次): \(error)")
                } else {
                    Logger.error("刷新訓練計劃失敗，準備重試: \(error)")
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))  // 等待1秒後重試
                }
            }
        }
    }
    
    // 修正的載入當前週訓練記錄方法（使用統一的數據來源）
    func loadWorkoutsForCurrentWeek() async {
        await MainActor.run {
            isLoadingWorkouts = true
        }
        
        do {
            // 確保 UnifiedWorkoutManager 有數據
            await ensureWorkoutDataLoaded()
            
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 從 UnifiedWorkoutManager 獲取該週的運動記錄
            let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
                startDate: weekStart,
                endDate: weekEnd
            )
            
            // 使用 V2 格式進行分組
            let groupedWorkoutsV2 = groupWorkoutsByDayFromV2(weekWorkouts)
            
            Logger.debug("分組後的訓練記錄:")
            for (day, dayWorkouts) in groupedWorkoutsV2 {
                Logger.debug(
                    "星期\(["一", "二", "三", "四", "五", "六", "日"][day-1]): \(dayWorkouts.count) 條記錄")
            }
            
            // 檢查今天的運動記錄
            let calendar = Calendar.current
            let today = Date()
            let todayWeekday = calendar.component(.weekday, from: today)
            let todayIndex = todayWeekday == 1 ? 7 : todayWeekday - 1  // 轉換為1-7代表週一到週日
            
            if let todayWorkouts = groupedWorkoutsV2[todayIndex], !todayWorkouts.isEmpty {
                Logger.debug(
                    "今天(星期\(["一", "二", "三", "四", "五", "六", "日"][todayIndex-1]))有 \(todayWorkouts.count) 條訓練記錄"
                )
            } else {
                Logger.debug("今天沒有訓練記錄")
            }
            
            // 更新 UI
            await MainActor.run {
                self.workoutsByDayV2 = groupedWorkoutsV2
                self.isLoadingWorkouts = false
            }
            
            // 載入週數據（距離和強度）
            if let plan = weeklyPlan, plan.totalDistance > 0 {
                await loadCurrentWeekData()
            }
            
        } catch {
            Logger.error("載入訓練記錄時出錯: \(error)")
            
            await MainActor.run {
                self.isLoadingWorkouts = false
            }
        }
    }
    
    // 改進的按日期分組方法
    private func groupWorkoutsByDay(_ workouts: [HKWorkout]) -> [Int: [HKWorkout]] {
        let calendar = Calendar.current
        var grouped: [Int: [HKWorkout]] = [:]
        
        // 定義跑步相關的活動類型
        let runningActivityTypes: [HKWorkoutActivityType] = [
            .running,
            .walking,
            .hiking,
            .trackAndField,
            .crossTraining,
        ]
        
        for workout in workouts {
            // 只處理跑步相關的鍛煉
            guard runningActivityTypes.contains(workout.workoutActivityType) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: workout.startDate)
            // 轉換 weekday 為 1-7（週一到週日）
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            if grouped[adjustedWeekday] == nil {
                grouped[adjustedWeekday] = []
            }
            grouped[adjustedWeekday]?.append(workout)
        }
        
        // 對每天的運動記錄按日期排序（最新的在前面）
        for (day, dayWorkouts) in grouped {
            grouped[day] = dayWorkouts.sorted { $0.startDate > $1.startDate }
        }
        
        return grouped
    }
    
    // 從 V2 API 數據按日期分組
    private func groupWorkoutsByDayFromV2(_ workouts: [WorkoutV2]) -> [Int: [WorkoutV2]] {
        let calendar = Calendar.current
        var grouped: [Int: [WorkoutV2]] = [:]
        
        // 定義跑步相關的活動類型
        let runningActivityTypes = ["running", "walking", "hiking", "cross_training"]
        
        for workout in workouts {
            // 只處理跑步相關的鍛煉
            guard runningActivityTypes.contains(workout.activityType) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: workout.startDate)
            // 轉換 weekday 為 1-7（週一到週日）
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            if grouped[adjustedWeekday] == nil {
                grouped[adjustedWeekday] = []
            }
            grouped[adjustedWeekday]?.append(workout)
        }
        
        // 對每天的運動記錄按日期排序（最新的在前面）
        for (day, dayWorkouts) in grouped {
            grouped[day] = dayWorkouts.sorted { $0.startDate > $1.startDate }
        }
        
        return grouped
    }
    
    // 識別並自動展開當天的訓練
    func identifyTodayTraining() async {
        if let plan = weeklyPlan {
            await MainActor.run {
                for day in plan.days
                where isToday(dayIndex: day.dayIndexInt, planWeek: plan.weekOfPlan) {
                    expandedDayIndices.insert(day.dayIndexInt)
                    break
                }
            }
        }
    }
    
    // 統一載入週數據（距離和強度）
    func loadCurrentWeekData() async {
        // 防止在初始化期間重複載入
        guard !isInitializing else {
            print("初始化期間跳過 loadCurrentWeekData")
            return
        }
        
        await loadCurrentWeekDistance()
        await loadCurrentWeekIntensity()
    }
    
    // 確保運動數據已載入
    private func ensureWorkoutDataLoaded() async {
        if !unifiedWorkoutManager.hasWorkouts {
            Logger.debug("UnifiedWorkoutManager 沒有數據，先載入運動記錄...")
            await unifiedWorkoutManager.loadWorkouts()
        }
    }
    
    // 載入本週訓練強度分鐘數
    func loadCurrentWeekIntensity() async {
        await executeTask(id: "load_current_week_intensity") {
            await self.performLoadCurrentWeekIntensity()
        }
    }
    
    private func performLoadCurrentWeekIntensity() async {
        Logger.debug("載入本週訓練強度...")
        await MainActor.run {
            isLoadingIntensity = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingIntensity = false
            }
        }
        
        do {
            // 確保 UnifiedWorkoutManager 有數據
            await ensureWorkoutDataLoaded()
            
            let (weekStart, weekEnd) = getCurrentWeekDates()
            Logger.debug("計算 \(formatDate(weekStart)) 開始的週訓練強度...")
            
            // 從 UnifiedWorkoutManager 獲取該週的運動記錄
            let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
                startDate: weekStart,
                endDate: weekEnd
            )
            
            // 直接使用 API 提供的 intensity_minutes 數據
            let intensity = aggregateIntensityFromV2Workouts(weekWorkouts)
            
            Logger.debug("訓練強度聚合完成 - 低: \(intensity.low), 中: \(intensity.medium), 高: \(intensity.high)")
            
            // 確保在主線程上更新 UI
            await MainActor.run {
                self._currentWeekIntensity = intensity
                self.objectWillChange.send()
                
                // 記錄完成的強度值
                Logger.debug("已更新強度值 - 低: \(intensity.low), 中: \(intensity.medium), 高: \(intensity.high)")
            }
            
        } catch {
            Logger.error("加載本週訓練強度時出錯: \(error)")
        }
    }
    
    // 聚合 V2 API 提供的 intensity_minutes 數據
    private func aggregateIntensityFromV2Workouts(_ workouts: [WorkoutV2]) -> TrainingIntensityManager.IntensityMinutes {
        var totalLow: Double = 0
        var totalMedium: Double = 0
        var totalHigh: Double = 0
        
        for workout in workouts {
            // 直接使用 API 提供的 intensity_minutes 數據
            if let intensityMinutes = workout.advancedMetrics?.intensityMinutes {
                totalLow += intensityMinutes.low ?? 0.0
                totalMedium += intensityMinutes.medium ?? 0.0
                totalHigh += intensityMinutes.high ?? 0.0
                
                Logger.debug("運動 \(workout.id): 低=\(intensityMinutes.low ?? 0), 中=\(intensityMinutes.medium ?? 0), 高=\(intensityMinutes.high ?? 0)")
            } else {
                Logger.debug("運動 \(workout.id) 沒有 intensity_minutes 數據")
            }
        }
        
        return TrainingIntensityManager.IntensityMinutes(
            low: totalLow,
            medium: totalMedium,
            high: totalHigh
        )
    }
    
    func loadCurrentWeekDistance() async {
        await executeTask(id: "load_current_week_distance") {
            await self.performLoadCurrentWeekDistance()
        }
    }
    
    private func performLoadCurrentWeekDistance() async {
        Logger.debug("載入週跑量中...")
        await MainActor.run {
            isLoadingDistance = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingDistance = false
            }
        }
        
        do {
            // 確保 UnifiedWorkoutManager 有數據
            await ensureWorkoutDataLoaded()
            
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 從 UnifiedWorkoutManager 獲取該週的運動記錄
            let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
                startDate: weekStart,
                endDate: weekEnd
            )
            
            // 過濾僅包含跑步類型的鍛煉
            let runWorkouts = weekWorkouts.filter { $0.activityType == "running" }
            
            // 計算跑步距離總和（從 V2 數據）
            let totalDistance = runWorkouts.compactMap { workout in
                workout.distance
            }.reduce(0, +) / 1000.0 // 轉換為公里
            
            Logger.debug("載入週跑量完成，週跑量為\(totalDistance)公里")
            
            // 更新UI
            await MainActor.run {
                self.currentWeekDistance = totalDistance
            }
            
        } catch {
            Logger.error("加載本週跑量時出錯: \(error)")
        }
    }
    
    // 載入週訓練回顧數據
    func loadWeeklySummary() async {
        await MainActor.run {
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        
        do {
            // 獲取當前訓練週數
            guard let currentWeek = calculateCurrentTrainingWeek() else {
                throw NSError(
                    domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法計算當前訓練週數"])
            }
            
            // 從API獲取週訓練回顧數據
            Logger.debug("嘗試得到第\(currentWeek-1)週的週回顧")
            let summary = try await weeklySummaryService.createWeeklySummary(
                weekNumber: currentWeek - 1)
            
            await MainActor.run {
                self.weeklySummary = summary
                self.isLoadingWeeklySummary = false
            }
            
        } catch {
            Logger.error("載入週訓練回顧失敗: \(error)")
            
            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
            }
            
            // 嘗試從本地存儲加載
            if let savedSummary = WeeklySummaryStorage.shared.loadWeeklySummary() {
                await MainActor.run {
                    self.weeklySummary = savedSummary
                }
            }
        }
    }
    
    // 判斷是否應該顯示產生下週課表按鈕
    // 判斷是否應該顯示產生課表按鈕，並返回應該產生的週數
    func shouldShowNextWeekButton(plan: WeeklyPlan) -> (shouldShow: Bool, nextWeek: Int) {
        // 計算當前實際訓練週數
        guard let currentTrainingWeek = calculateCurrentTrainingWeek() else {
            // 如果無法計算當前訓練週數，則使用計劃週數+1
            let nextWeek = plan.weekOfPlan + 1
            let hasNextWeek = nextWeek <= plan.totalWeeks
            return (hasNextWeek, nextWeek)
        }
        
        // 如果當前實際訓練週數大於計畫週數，則應該顯示按鈕產生對應週數的課表
        if currentTrainingWeek > plan.weekOfPlan {
            // 確保不超過總週數
            let hasNextWeek = currentTrainingWeek <= plan.totalWeeks
            return (hasNextWeek, currentTrainingWeek)
        } else {
            // 如果當前實際訓練週數等於或小於計畫週數，不需要顯示按鈕
            return (false, currentTrainingWeek)
        }
    }
    
    func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        return ViewModelUtils.formatDistance(distance, unit: unit)
    }
    
    func formatShortDate(_ date: Date) -> String {
        return ViewModelUtils.formatShortDate(date)
    }
    
    func formatTime(_ date: Date) -> String {
        return ViewModelUtils.formatTime(date)
    }
    
    func formatPace(_ paceInSeconds: Double) -> String {
        return ViewModelUtils.formatPace(paceInSeconds)
    }
    
    func weekdayName(for index: Int) -> String {
        return ViewModelUtils.weekdayName(for: index)
    }
    
    // 用於除錯的日期格式化工具
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func formatDebugDate(_ date: Date) -> String {
        return ViewModelUtils.formatDebugDate(date)
    }
    
    // 獲取指定週訓練回顧的方法
    func fetchWeeklySummary(weekNumber: Int) async {
        await MainActor.run {
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        do {
            let summary = try await weeklySummaryService.getWeeklySummary(weekNumber: weekNumber)
            Logger.info("fetchWeeklySummary for week : \(weekNumber)")
            WeeklySummaryStorage.shared.saveWeeklySummary(summary, weekNumber: weekNumber)
            await MainActor.run {
                self.weeklySummary = summary
                self.lastFetchedWeekNumber = weekNumber
                self.showWeeklySummary = true
                self.isLoadingWeeklySummary = false
            }
        } catch {
            Logger.error("載入週訓練回顧(第 \(weekNumber) 週)失敗: \(error)")
            await MainActor.run {
                self.weeklySummaryError = error
            }
        }
    }
    
    // 刷新運動數據（供外部調用）
    func refreshWorkoutData() async {
        await unifiedWorkoutManager.refreshWorkouts()
    }
    
    deinit {
        cancelAllTasks()
    }
}
