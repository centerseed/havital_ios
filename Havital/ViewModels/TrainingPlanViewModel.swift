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

    // EditScheduleView 相關
    @Published var isEditingLoaded = false
    @Published var editingDays: [MutableTrainingDay] = []
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

    // 🆕 新增：訓練計畫狀態（來自後端 API）
    @Published var planStatusResponse: PlanStatusResponse?
    @Published var nextWeekInfo: NextWeekInfo?
    @Published var showSuccessToast = false
    @Published var successMessage: String = ""

    // plan/status API 緩存時間戳（8 小時內不重複呼叫）
    private var lastPlanStatusFetchTime: Date?
    private let planStatusCacheInterval: TimeInterval = 8 * 60 * 60 // 8 小時
    // ✅ 短期防抖（5 秒）已由 TaskManageable 的 cooldownSeconds 統一處理

    // 調整建議確認相關屬性
    @Published var showAdjustmentConfirmation = false
    @Published var pendingAdjustments: [AdjustmentItem] = []
    @Published var isUpdatingAdjustments = false
    @Published var pendingTargetWeek: Int?
    @Published var pendingSummaryId: String?

    // 編輯課表相關 - 編輯狀態由 EditScheduleView 管理

    // 網路錯誤處理
    @Published var networkError: NetworkError?
    @Published var showNetworkErrorAlert = false
    @Published var showNetworkErrorToast = false
    
    // 週摘要列表
    @Published var weeklySummaries: [WeeklySummaryItem] = []
    @Published var isLoadingWeeklySummaries = false
    @Published var weeklySummariesError: Error?

    // VDOT 和配速計算相關屬性
    @Published var currentVDOT: Double?
    @Published var calculatedPaces: [PaceCalculator.PaceZone: String] = [:]
    @Published var isLoadingPaces = false

    /// 清除網路錯誤Toast狀態
    @MainActor
    func clearNetworkErrorToast() {
        showNetworkErrorToast = false
        networkError = nil
    }
    
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
    
    // 簡化的初始化狀態標記
    private var hasInitialized = false
    
    // 防重複更新機制
    private var lastWeekDataUpdateTime: Date?
    private let weekDataUpdateInterval: TimeInterval = 3 // 3秒防重複
    
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
        
        await executeTask(id: TaskID("fetch_weekly_summaries"), cooldownSeconds: 5) {
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
            // 檢查是否為取消錯誤
            if error.isCancellationError {
                Logger.debug("Fetch weekly summaries task cancelled, ignoring error")
                return
            }

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

            Logger.debug("📊 [WeeklySummaries] API 回傳 \(summaries.count) 週資料")
            for summary in summaries {
                Logger.debug("  週數 \(summary.weekIndex): weekPlan=\(summary.weekPlan != nil ? "有" : "無"), weekSummary=\(summary.weekSummary != nil ? "有" : "無")")
            }

            await MainActor.run {
                // 按照週數從新到舊排序
                self.weeklySummaries = summaries.sorted { $0.weekIndex > $1.weekIndex }
                // 更新緩存
                cacheWeeklySummaries(self.weeklySummaries)

                Logger.debug("📊 [WeeklySummaries] 已更新UI列表，共 \(self.weeklySummaries.count) 週")
            }
        } catch {
            // 檢查是否為取消錯誤
            if error.isCancellationError {
                Logger.debug("Force update weekly summaries task cancelled, ignoring error")
                return
            }

            Logger.error("Failed to force update weekly summaries: \(error.localizedDescription)")
        }
    }
    
    // 在產生新課表後調用
    func onNewPlanGenerated() {
        Task { [weak self] in
            await self?.forceUpdateWeeklySummaries()
        }
    }

    // 在產生週回顧後調用
    func onWeeklySummaryGenerated() {
        Task { [weak self] in
            await self?.forceUpdateWeeklySummaries()
        }
    }
    
    // 簡化的初始化 - 單一路徑
    init() {
        Logger.debug("TrainingPlanViewModel: 開始簡化的初始化")

        // 非同步初始化 - 使用單一統一的初始化方法
        Task { [weak self] in
            try? await TrackedTask("TrainingPlanViewModel: init") {
                await self?.performUnifiedInitialization()
            }.value
        }
    }
    
    /// 統一的初始化方法 - 合併所有初始化邏輯
    private func performUnifiedInitialization() async {
        // 防止重複初始化
        guard !hasInitialized else {
            Logger.debug("TrainingPlanViewModel: 已初始化，跳過")
            return
        }
        hasInitialized = true
        
        Logger.debug("TrainingPlanViewModel: 開始統一初始化流程")
        
        // 1. 等待用戶認證完成
        await waitForUserDataReady()
        
        // 2. 初始化 UnifiedWorkoutManager - 統一的運動數據源
        await unifiedWorkoutManager.initialize()
        await unifiedWorkoutManager.loadWorkouts()
        
        // 3. 載入訓練概覽和週計劃
        await loadTrainingData()
        
        // 4. 載入當前週數據
        await loadCurrentWeekData()

        // 5. 載入 VDOT 並計算配速
        await loadVDOTAndCalculatePaces()

        // 6. 設置通知監聽器
        await setupNotificationListeners()

        Logger.debug("TrainingPlanViewModel: 統一初始化完成")
    }
    
    /// 載入訓練相關數據
    private func loadTrainingData() async {
        let onboardingCompleted = AuthenticationService.shared.hasCompletedOnboarding
        let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()

        await MainActor.run {
            if onboardingCompleted && savedOverview.createdAt.isEmpty {
                self.showSyncingSplash = true
            }

            if !savedOverview.createdAt.isEmpty {
                self.trainingOverview = savedOverview
                // 🔧 暫時保留本地計算，但會被 API 狀態覆蓋
                self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: savedOverview.createdAt) ?? 1
                self.selectedWeek = self.currentWeek
            }
        }

        // 載入訓練概覽
        await loadTrainingOverview()

        // 🆕 載入訓練計畫狀態（使用新 API）
        // 初始化時跳過緩存，確保獲取最新狀態
        await loadPlanStatus(skipCache: true)

        // 根據狀態決定是否載入週計劃
        if weeklyPlan == nil {
            await handlePlanStatusAction()
        }
    }

    // MARK: - 🆕 新增：載入訓練計畫狀態

    /// 載入訓練計畫狀態（使用後端 API）
    /// - Parameter skipCache: 是否跳過緩存檢查（預設為 false）
    func loadPlanStatus(skipCache: Bool = false) async {
        await executeTask(id: TaskID("load_plan_status"), cooldownSeconds: 5) {
            await self.performLoadPlanStatus(skipCache: skipCache)
        }
    }

    private func performLoadPlanStatus(skipCache: Bool = false) async {
        // 🔧 檢查是否需要跳過緩存（8 小時長期緩存）
        // ✅ 短期防抖（5 秒）已由 TaskManageable 的 cooldownSeconds 處理
        if !skipCache, let lastFetchTime = lastPlanStatusFetchTime {
            let timeSinceLastFetch = Date().timeIntervalSince(lastFetchTime)
            if timeSinceLastFetch < planStatusCacheInterval {
                let remainingTime = planStatusCacheInterval - timeSinceLastFetch
                let remainingHours = Int(remainingTime / 3600)
                let remainingMinutes = Int((remainingTime.truncatingRemainder(dividingBy: 3600)) / 60)
                Logger.debug("⏱️ [PlanStatus] 使用長期緩存，距離上次調用 \(Int(timeSinceLastFetch / 60)) 分鐘，剩餘 \(remainingHours) 小時 \(remainingMinutes) 分鐘後可重新調用")
                return
            }
        }

        Logger.debug("🔄 [PlanStatus] 開始呼叫 GET /plan/race_run/status (skipCache: \(skipCache))")

        do {
            let status = try await TrainingPlanService.shared.getPlanStatus()

            // 更新緩存時間戳（8 小時長期緩存）
            await MainActor.run {
                self.lastPlanStatusFetchTime = Date()
            }

            await MainActor.run {
                self.planStatusResponse = status

                // ✅ 使用後端計算的週數，覆蓋本地計算
                self.currentWeek = status.currentWeek
                self.selectedWeek = status.currentWeek

                // 儲存下週資訊（如果有）
                self.nextWeekInfo = status.nextWeekInfo

                Logger.debug("✅ [PlanStatus] 載入訓練狀態成功")
                Logger.debug("📊 [PlanStatus] currentWeek: \(status.currentWeek) / totalWeeks: \(status.totalWeeks)")

                // 對比本地保存的 totalWeeks
                if let localOverview = self.trainingOverview {
                    Logger.debug("📊 [Local] trainingOverview.totalWeeks: \(localOverview.totalWeeks)")
                    if localOverview.totalWeeks != status.totalWeeks {
                        Logger.warn("⚠️ [Mismatch] 後端返回 totalWeeks=\(status.totalWeeks)，但本地為 \(localOverview.totalWeeks)")
                    }
                }

                Logger.debug("🎯 [PlanStatus] nextAction: \(status.nextAction.rawValue)")
                Logger.debug("🚀 [PlanStatus] canGenerateNextWeek: \(status.canGenerateNextWeek)")
                Logger.debug("📅 [PlanStatus] trainingStartDate: \(status.metadata.trainingStartDate)")
                Logger.debug("📅 [PlanStatus] currentWeekStartDate: \(status.metadata.currentWeekStartDate)")
                Logger.debug("⏰ [PlanStatus] serverTime: \(status.metadata.serverTime)")

                if let nextWeekInfo = status.nextWeekInfo {
                    Logger.debug("📋 [NextWeek] weekNumber: \(nextWeekInfo.weekNumber)")
                    Logger.debug("📋 [NextWeek] canGenerate: \(nextWeekInfo.canGenerate)")
                    Logger.debug("📋 [NextWeek] hasPlan: \(nextWeekInfo.hasPlan)")
                    Logger.debug("📋 [NextWeek] requiresCurrentWeekSummary: \(nextWeekInfo.requiresCurrentWeekSummary)")
                    Logger.debug("📋 [NextWeek] nextAction: \(nextWeekInfo.nextAction)")
                }
            }

        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                Logger.debug("⚠️ [PlanStatus] 載入任務被取消，忽略錯誤")
                return
            }

            Logger.error("❌ [PlanStatus] 載入失敗: \(error.localizedDescription)")

            // 失敗時回退到本地計算
            await MainActor.run {
                if let overview = self.trainingOverview {
                    let localWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? 1
                    self.currentWeek = localWeek
                    self.selectedWeek = self.currentWeek

                    Logger.debug("🔄 [PlanStatus] 回退到本地計算：currentWeek=\(localWeek)")
                }
            }
        }
    }

    /// 根據 next_action 處理下一步操作
    private func handlePlanStatusAction() async {
        guard let status = planStatusResponse else {
            Logger.debug("⚠️ [Action] 無 planStatusResponse，使用舊邏輯載入課表")
            await loadWeeklyPlan()
            return
        }

        Logger.debug("🔄 [Action] 開始處理 nextAction: \(status.nextAction.rawValue)")

        switch status.nextAction {
        case .viewPlan:
            Logger.debug("📖 [Action] viewPlan - 載入並顯示課表")
            await loadWeeklyPlan()

        case .createSummary, .createPlan:
            Logger.debug("🔍 [Action] \(status.nextAction.rawValue) - 檢查緩存...")
            // ✅ 雙軌緩存策略：先檢查是否有緩存的當週課表
            if let cachedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: currentWeek) {
                // 立即顯示緩存數據
                Logger.debug("✅ [Cache] 找到緩存的第 \(currentWeek) 週課表（week: \(cachedPlan.weekOfPlan)）")
                await updateWeeklyPlanUI(plan: cachedPlan, status: .ready(cachedPlan))
                Logger.debug("✅ [Cache] 設置 planStatus = .ready，避免顯示 .noPlan 狀態")
            } else {
                // 沒有緩存時才顯示「產生週回顧/課表」按鈕
                Logger.debug("📝 [Cache] 無緩存數據，設置 planStatus = .noPlan")
                await MainActor.run {
                    self.planStatus = .noPlan
                    self.showNewWeekPrompt = true
                }
            }

        case .trainingCompleted:
            Logger.debug("🏁 [Action] trainingCompleted - 檢查緩存...")
            // ✅ 雙軌緩存策略：先檢查是否有緩存的當週課表
            if let cachedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: currentWeek) {
                // 立即顯示緩存數據，而不是直接顯示「訓練已完成」
                Logger.debug("✅ [Cache] 找到緩存的第 \(currentWeek) 週課表（week: \(cachedPlan.weekOfPlan)）")
                await updateWeeklyPlanUI(plan: cachedPlan, status: .ready(cachedPlan))
                Logger.debug("✅ [Cache] 設置 planStatus = .ready，避免顯示 .completed 狀態")
            } else {
                // 沒有緩存時才顯示「訓練已完成」提示
                Logger.debug("🎉 [Status] 無緩存數據，設置 planStatus = .completed")
                await MainActor.run {
                    self.planStatus = .completed
                }
            }

        case .noActivePlan:
            Logger.warn("⚠️ [Action] noActivePlan - 用戶沒有啟動中的訓練計畫")
            await MainActor.run {
                self.planStatus = .noPlan
            }
        }

        Logger.debug("✅ [Action] handlePlanStatusAction 完成")
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
    
    // 移除複雜的 loadTrainingOverviewWithUserContext - 已合併到 performUnifiedInitialization
    
    // MARK: - Notification Setup
    
    /// 設置通知監聽器（在初始化完成後調用，避免競爭條件）
    @MainActor
    private func setupNotificationListeners() async {
        // 監聽 workouts 更新通知
        NotificationCenter.default.publisher(for: .workoutsDidUpdate)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // 防止在初始化期間響應通知
                guard self.hasInitialized else {
                    print("初始化期間跳過 workoutsDidUpdate 通知")
                    return
                }
                
                // 根據通知原因決定是否需要更新
                let reason = (notification.object as? [String: String])?["reason"] ?? "unknown"
                print("收到 workoutsDidUpdate 通知，原因: \(reason)")
                
                switch reason {
                case "initial_cache", "initial_load":
                    // 初始載入時不需要重複更新（數據已經在初始化時載入）
                    print("初始載入通知，跳過週數據更新")
                    return
                    
                case "background_update", "user_refresh", "new_workout_synced", "force_refresh":
                    // 只有在有實際新數據時才更新週數據
                    print("發現新運動數據，開始更新週數據...")
                    Task {
                        await self.smartUpdateWeekData()
                    }
                    
                default:
                    // 其他情況也更新（保持兼容性）
                    print("未知通知原因，執行週數據更新...")
                    Task {
                        await self.smartUpdateWeekData()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 監聽訓練概覽更新通知
        NotificationCenter.default.publisher(for: NSNotification.Name("TrainingOverviewUpdated"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // 防止在初始化期間響應通知
                guard self.hasInitialized else {
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

                        // ✅ 已移除 loadWeeklyPlan() 調用
                        // 理由：overview 更新只影響元數據（如 totalWeeks），不影響週課表內容
                        // 週課表由獨立的 API 管理，如需更新會透過 plan/status API 告知
                        print("概覽更新完成，重新載入相關資訊...")
                        await self.loadCurrentWeekDistance()
                        await self.loadCurrentWeekIntensity()
                        await self.loadWorkoutsForCurrentWeek()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 智能更新週數據：防重複 + 批量更新
    private func smartUpdateWeekData() async {
        let now = Date()
        
        // 防重複更新：3秒內不重複更新週數據
        if let lastUpdate = lastWeekDataUpdateTime,
           now.timeIntervalSince(lastUpdate) < weekDataUpdateInterval {
            print("週數據更新過於頻繁，忽略此次更新請求（距上次更新 \(Int(now.timeIntervalSince(lastUpdate)))秒）")
            return
        }
        
        // 記錄更新時間
        lastWeekDataUpdateTime = now
        
        print("開始智能週數據更新...")
        
        // 批量執行週相關數據更新
        await executeTask(id: TaskID("smart_week_data_update")) { [weak self] in
            guard let self = self else { return }
            
            // 並行執行所有週數據載入
            async let weekDistance = self.performLoadCurrentWeekDistance()
            async let weekIntensity = self.performLoadCurrentWeekIntensity()
            async let weekWorkouts = self.performLoadWorkoutsForCurrentWeek()
            
            // 等待所有更新完成
            let _ = try await (weekDistance, weekIntensity, weekWorkouts)
            
            print("智能週數據更新完成")
        }
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
    func createWeeklySummary(weekNumber: Int? = nil) async {
        // 計算目標週數用於 TaskID
        let targetWeek = weekNumber ?? calculateCurrentTrainingWeek() ?? currentWeek
        await executeTask(id: TaskID("create_weekly_summary_\(targetWeek)"), cooldownSeconds: 5) {
            await self.performCreateWeeklySummary(weekNumber: weekNumber)
        }
    }

    private func performCreateWeeklySummary(weekNumber: Int? = nil) async {
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
            // 使用傳入的週數，如果沒有則計算當前訓練週數
            let targetWeek: Int
            if let weekNumber = weekNumber {
                targetWeek = weekNumber
                Logger.debug("使用指定週數產生週回顧: 第 \(targetWeek) 週")
            } else {
                guard let currentWeek = calculateCurrentTrainingWeek() else {
                    throw NSError(
                        domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法計算當前訓練週數"])
                }
                targetWeek = currentWeek
                Logger.debug("使用當前週數產生週回顧: 第 \(targetWeek) 週")
            }

            // 從API獲取週訓練回顧數據
            let summary = try await weeklySummaryService.createWeeklySummary(weekNumber: targetWeek)

            // 保存到本地儲存
            WeeklySummaryStorage.shared.saveWeeklySummary(summary, weekNumber: targetWeek)

            await MainActor.run {
                self.weeklySummary = summary
                self.lastFetchedWeekNumber = targetWeek
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
    
    // 重新嘗試產生週回顧（強制更新模式）
    @MainActor
    func retryCreateWeeklySummary() async {
        let targetWeek = calculateCurrentTrainingWeek() ?? currentWeek
        await executeTask(id: TaskID("retry_create_weekly_summary_\(targetWeek)")) {
            await self.performRetryCreateWeeklySummary()
        }
    }

    private func performRetryCreateWeeklySummary() async {
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

            Logger.debug("重新嘗試產生週回顧（強制更新模式）: 週數 \(currentWeek)")

            // 使用強制更新模式從API獲取週訓練回顧數據
            let summary = try await weeklySummaryService.createWeeklySummary(forceUpdate: true)

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

            Logger.debug("強制更新週回顧成功")

        } catch {
            Logger.error("強制更新週回顧失敗: \(error)")

            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
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
            self.pendingTargetWeek = nil  // 清除待處理的目標週數
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

            // 🔧 關鍵修復：更新週計劃後，立即載入該週的訓練記錄
            // 這確保 workoutsByDayV2 被填充，使得 TrainingPlanView 中的訓練記錄能正確顯示
            Task {
                await self.loadWorkoutsForCurrentWeek()
            }
        } else {
            Logger.debug("updateWeeklyPlanUI: 週計劃為 nil")
        }
        self.planStatus = status

        // 🔧 修復：確保載入狀態重置，避免按鈕被禁用
        self.isLoading = false

        updatePromptViews()
    }
    
    func loadWeeklyPlan(skipCache: Bool = false, targetWeek: Int? = nil) async {
        let weekToLoad = targetWeek ?? selectedWeek
        await executeTask(id: TaskID("load_weekly_plan_\(weekToLoad)"), cooldownSeconds: 5) {
            await self.performLoadWeeklyPlan(skipCache: skipCache, targetWeek: targetWeek)
        }
    }
    
    /// 執行實際的載入邏輯
    private func performLoadWeeklyPlan(skipCache: Bool = false, targetWeek: Int? = nil) async {
        // 修正：在載入計畫前，務必先重新計算當前週數，確保資料最新
        if let overview = trainingOverview, !overview.createdAt.isEmpty {
            self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? self.currentWeek
        }
        
        // 決定要載入的週數：如果有指定目標週數則使用，否則使用選擇的週數
        let weekToLoad = targetWeek ?? selectedWeek
        
        // 僅在已有 trainingOverview.id 時才載入週計劃，避免無 overview 時報錯
        guard let overview = trainingOverview, !overview.id.isEmpty else { return }
        
        // 檢查是否應該跳過快取
        let shouldSkipCache = skipCache || shouldBypassCacheForWeeklyPlan()
        
        // 先檢查本地緩存（除非被要求跳過）
        if !shouldSkipCache, let savedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: weekToLoad) {
            // 立即使用緩存數據更新 UI，不顯示 loading 狀態
            let cw = calculateCurrentTrainingWeek() ?? 0
            let status: PlanStatus = cw > overview.totalWeeks ? .completed : .ready(savedPlan)
            await updateWeeklyPlanUI(plan: savedPlan, status: status)
            
            // 在背景更新最新數據
            Task {
                do {
                    guard let overviewId = trainingOverview?.id else { throw NSError() }
                    Logger.info("Load weekly plan with planId: \(overviewId)_\(weekToLoad).")
                    let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                        planId: "\(overviewId)_\(weekToLoad)")
                    
                    // 檢查計劃是否有變更
                    let planChanged = savedPlan.id != newPlan.id || savedPlan.weekOfPlan != newPlan.weekOfPlan
                    
                    await updateWeeklyPlanUI(plan: newPlan, planChanged: planChanged, status: .ready(newPlan))
                    
                } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                    // 404: 無週計劃
                    await updateWeeklyPlanUI(plan: nil, status: .noPlan)
                } catch {
                    // 檢查是否為取消錯誤，如果是則忽略
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled ||
                       error is CancellationError ||
                       error.localizedDescription.contains("cancelled") ||
                       error.localizedDescription.contains("canceled") ||
                       error.localizedDescription.contains("取消") {
                        Logger.debug("背景更新計劃任務被取消，忽略此錯誤")
                        return
                    }
                    
                    // 其他錯誤: 檢查是否為網路問題
                    if let networkError = self.handleNetworkError(error) {
                        await MainActor.run {
                            self.networkError = networkError
                            // 雙軌架構：背景更新失敗時顯示Toast而不是Alert
                            self.showNetworkErrorToast = true
                        }
                    } else {
                        // 其他錯誤: 保持使用本地數據，顯示Toast提示
                        Logger.error("API加載計劃失敗，保持使用本地數據: \(error)")
                        
                        await MainActor.run {
                            self.showNetworkErrorToast = true
                        }
                        
                        // 記錄背景更新失敗的詳細錯誤資訊到 Firebase
                        // Create JSON-safe userInfo by converting non-serializable objects to strings
                        let safeUserInfo: [String: String] = (error as NSError).userInfo.compactMapValues { value in
                            if let stringValue = value as? String {
                                return stringValue
                            } else if let numberValue = value as? NSNumber {
                                return numberValue.stringValue
                            } else {
                                return String(describing: value)
                            }
                        }

                        let errorDetails: [String: Any] = [
                            "error_type": String(describing: type(of: error)),
                            "error_description": error.localizedDescription,
                            "error_domain": (error as NSError).domain,
                            "error_code": (error as NSError).code,
                            "error_userInfo": safeUserInfo,
                            "overview_id": trainingOverview?.id ?? "unknown",
                            "current_week": currentWeek,
                            "selected_week": selectedWeek,
                            "week_to_load": weekToLoad,
                            "context": "background_refresh_weekly_plan",
                            "has_cached_plan": weeklyPlan != nil
                        ]
                        
                        Logger.firebase("Background weekly plan refresh failed",
                                      level: .error,
                                      labels: ["cloud_logging": "true", "component": "TrainingPlanViewModel", "operation": "backgroundRefresh"],
                                      jsonPayload: errorDetails)
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
                Logger.debug("weekToLoad: \(weekToLoad)")
                Logger.debug("準備載入週計劃 ID: \(overviewId)_\(weekToLoad)")
                
                if weekToLoad > trainingOverview!.totalWeeks {
                    Logger.debug("要載入的週數超過總週數，設置 .completed 狀態")
                    await updateWeeklyPlanUI(plan: nil, status: .completed)
                } else {
                    let planId = "\(overviewId)_\(weekToLoad)"
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
                // 檢查是否為任務取消錯誤（支援多種取消錯誤類型）
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("載入週計劃任務被取消 (URLError)，忽略此錯誤")
                    return // 忽略取消錯誤，不更新 UI 狀態
                }
                
                // 檢查其他類型的取消錯誤
                if error is CancellationError {
                    Logger.debug("載入週計劃任務被取消 (CancellationError)，忽略此錯誤")
                    return
                }
                
                // 檢查錯誤描述中是否包含取消相關關鍵字
                if error.localizedDescription.contains("cancelled") || 
                   error.localizedDescription.contains("canceled") ||
                   error.localizedDescription.contains("取消") {
                    Logger.debug("載入週計劃任務被取消 (描述匹配)，忽略此錯誤: \(error.localizedDescription)")
                    return
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
                
                // 記錄詳細錯誤資訊到 Firebase Cloud Logging
                // Create JSON-safe userInfo by converting non-serializable objects to strings
                let safeUserInfo: [String: String] = (error as NSError).userInfo.compactMapValues { value in
                    if let stringValue = value as? String {
                        return stringValue
                    } else if let numberValue = value as? NSNumber {
                        return numberValue.stringValue
                    } else {
                        return String(describing: value)
                    }
                }

                let errorDetails: [String: Any] = [
                    "error_type": String(describing: type(of: error)),
                    "error_description": error.localizedDescription,
                    "error_domain": (error as NSError).domain,
                    "error_code": (error as NSError).code,
                    "error_userInfo": safeUserInfo,
                    "overview_id": trainingOverview?.id ?? "unknown",
                    "current_week": currentWeek,
                    "selected_week": selectedWeek,
                    "week_to_load": weekToLoad,
                    "plan_status": String(describing: planStatus),
                    "context": "load_weekly_plan"
                ]
                
                Logger.firebase("Weekly plan loading failed with detailed error info",
                              level: .error,
                              labels: ["cloud_logging": "true", "component": "TrainingPlanViewModel", "operation": "loadWeeklyPlan"],
                              jsonPayload: errorDetails)
                
                if let networkError = self.handleNetworkError(error) {
                    Logger.debug("識別為網路錯誤，檢查是否有緩存數據")
                    await MainActor.run {
                        self.networkError = networkError
                        
                        // 雙軌架構核心：如果沒有緩存數據才顯示錯誤畫面
                        if self.weeklyPlan == nil {
                            // 沒有任何數據，顯示錯誤畫面
                            self.showNetworkErrorAlert = true
                        } else {
                            // 有緩存數據，只顯示Toast提示
                            self.showNetworkErrorToast = true
                        }
                    }
                } else {
                    Logger.debug("非網路錯誤，檢查是否有緩存數據決定顯示方式")
                    if self.weeklyPlan == nil {
                        // 沒有緩存數據，顯示錯誤畫面  
                        await updateWeeklyPlanUI(plan: nil, status: .error(error))
                    } else {
                        // 有緩存數據，顯示Toast提示但保持現有UI
                        await MainActor.run {
                            self.showNetworkErrorToast = true
                        }
                    }
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
    
    /// 統一的指定週計劃載入 - 使用 loadWeeklyPlan 更新 selectedWeek
    func fetchWeekPlan(week: Int) async {
        // ✅ 方案 3: 前端驗證週次範圍
        if let totalWeeks = trainingOverview?.totalWeeks {
            if week < 1 || week > totalWeeks {
                Logger.error("⚠️ ViewModel: 週次 \(week) 超出計劃範圍 (1-\(totalWeeks))，拒絕載入")

                await MainActor.run {
                    self.error = NSError(
                        domain: "TrainingPlanViewModel",
                        code: 400,
                        userInfo: [
                            NSLocalizedDescriptionKey: String(format: NSLocalizedString("training.week_out_of_range", comment: "Week %d is out of plan range (1-%d)"), week, totalWeeks)
                        ]
                    )
                    self.showNetworkErrorToast = true
                }
                return
            }
        }

        // 更新當前選擇的週數
        await MainActor.run {
            self.selectedWeek = week
        }

        // 使用統一的載入方法，指定載入目標週數
        await loadWeeklyPlan(skipCache: true, targetWeek: week)

        // 載入相關數據
        await loadWorkoutsForCurrentWeek()
        await loadCurrentWeekData()
        await identifyTodayTraining()
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
            Logger.debug("""
            📅 [getCurrentWeekDates] 使用 weekDateInfo
               - startDate: \(info.startDate.formatted(date: .abbreviated, time: .omitted))
               - endDate: \(info.endDate.formatted(date: .abbreviated, time: .omitted))
               - selectedWeek: \(self.selectedWeek)
            """)
            return (info.startDate, info.endDate)
        }

        // 默認情況：返回當前自然週的範圍
        Logger.debug("⚠️ [getCurrentWeekDates] weekDateInfo 為 nil，使用系統日期計算自然週")

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

        Logger.debug("""
        📅 [getCurrentWeekDates] 系統週範圍
           - startDate: \(startDate.formatted(date: .abbreviated, time: .omitted))
           - endDate: \(endOfDay.formatted(date: .abbreviated, time: .omitted))
        """)

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
    
    // ✅ 優化：委派給 TrainingPlanManager，統一使用雙軌緩存策略
    func loadTrainingOverview() async {
        Logger.debug("TrainingPlanViewModel: 開始載入訓練概覽（委派給 TrainingPlanManager）")

        // 委派給 TrainingPlanManager 載入（使用雙軌緩存策略）
        await TrainingPlanManager.shared.loadTrainingOverview()

        // 從 TrainingPlanManager 同步數據到 ViewModel
        let managerOverview = await MainActor.run { TrainingPlanManager.shared.trainingOverview }

        if let overview = managerOverview {
            await MainActor.run {
                self.trainingOverview = overview
                self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? 1
                self.selectedWeek = self.currentWeek
            }

            Logger.debug("✅ 成功從 TrainingPlanManager 同步訓練概覽")
            Logger.debug("Plan Overview id: \(overview.id)")
            logCurrentTrainingWeek()
        } else {
            Logger.debug("⚠️ TrainingPlanManager 沒有訓練概覽數據")
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

        do {
            Logger.debug("開始產生第 \(targetWeek) 週課表...")

            // 檢查是否有調整建議需要確認
            if await shouldShowAdjustmentConfirmation(for: targetWeek) {
                endBackgroundTask() // 結束背景任務但不顯示載入動畫
                return // 等待用戶確認調整建議後再繼續
            }

            // 只有在不需要顯示調整確認時才開始載入動畫
            isLoadingAnimation = true
            planStatus = .loading

            // Defer ending the background task to ensure it's called
            defer {
                endBackgroundTask()
                Task { @MainActor in
                    isLoadingAnimation = false // 結束時隱藏動畫
                }
            }

            // ✅ 優化：直接使用 createWeeklyPlan 的返回值，避免重複調用 API
            let newPlan = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)

            await MainActor.run {
                isLoading = true
                error = nil
            }

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
            Logger.error("產生課表失敗: \(error)")
            await updateWeeklyPlanUI(plan: nil, status: .error(error))
        }
    }

    // 移除重複的初始化標記
    
    // 移除重複的 loadAllInitialData - 現在由 performUnifiedInitialization 統一處理
    
    /// 統一的刷新方法 - 使用 loadWeeklyPlan 的 skipCache 功能
    func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
        // 手動刷新時，重新檢查 plan status（跳過 8 小時緩存限制）
        if isManualRefresh {
            await loadPlanStatus(skipCache: true)
        }

        // 簡化為使用統一的載入方法，但跳過緩存
        await loadWeeklyPlan(skipCache: true)

        // 刷新運動數據
        await unifiedWorkoutManager.refreshWorkouts()

        // 重新載入當前週數據
        await loadCurrentWeekData()
    }
    
    // 移除複雜的 performRefreshWeeklyPlan - 功能已由 loadWeeklyPlan(skipCache: true) 取代
    
    // 修正的載入當前週訓練記錄方法（使用統一的數據來源）
    func loadWorkoutsForCurrentWeek() async {
        await MainActor.run {
            isLoadingWorkouts = true
        }
        
        do {
            // 獲取當前週的時間範圍（移除 ensureWorkoutDataLoaded 調用以避免重複載入）
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
    
    // 用於批量更新的純邏輯方法（不直接更新 UI 狀態）
    private func performLoadWorkoutsForCurrentWeek() async throws {
        // 獲取當前週的時間範圍
        let (weekStart, weekEnd) = getCurrentWeekDates()

        Logger.debug("""
        🏃 [LoadWorkouts] 開始加載當前週的 workout
           - 日期範圍: \(weekStart.formatted(date: .abbreviated, time: .omitted)) ~ \(weekEnd.formatted(date: .abbreviated, time: .omitted))
           - selectedWeek: \(self.selectedWeek)
           - currentWeek: \(self.currentWeek)
        """)

        // 從 UnifiedWorkoutManager 獲取該週的運動記錄
        let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
            startDate: weekStart,
            endDate: weekEnd
        )

        Logger.debug("📊 [LoadWorkouts] 獲取到 \(weekWorkouts.count) 個 workout 記錄")

        // 按日期分組
        let grouped = groupWorkoutsByDayFromV2(weekWorkouts)

        Logger.debug("""
        🗂️ [LoadWorkouts] 分組完成
           - 分組數量: \(grouped.count) 天
           - 日期分佈: \(grouped.map { "Day \($0.key): \($0.value.count)" }.joined(separator: ", "))
        """)

        // 更新UI（只更新數據，不更新 loading 狀態）
        await MainActor.run {
            self.workoutsByDayV2 = grouped
        }

        Logger.debug("✅ [LoadWorkouts] workoutsByDayV2 已更新")
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

            // 🔧 關鍵修復：使用 weekDateInfo 的日期映射而不是純粹的 Calendar.weekday
            // 這確保了 workoutsByDayV2 的鍵與 dayIndexInt 保持一致
            var dayIndex: Int?

            if let weekDateInfo = self.weekDateInfo {
                // 逐一檢查 daysMap 中的日期，找到與 workout 日期匹配的日期索引
                for (index, dateInWeek) in weekDateInfo.daysMap {
                    if calendar.isDate(workout.startDate, inSameDayAs: dateInWeek) {
                        dayIndex = index
                        break
                    }
                }
            }

            // 後備方案：如果沒有 weekDateInfo，使用 Calendar.weekday
            if dayIndex == nil {
                let weekday = calendar.component(.weekday, from: workout.startDate)
                dayIndex = weekday == 1 ? 7 : weekday - 1

                Logger.debug("⚠️ 使用後備方案計算 dayIndex: \(dayIndex ?? 0)")
            }

            guard let dayIndex = dayIndex else {
                Logger.error("❌ 無法計算 workout 的 dayIndex: \(workout.startDate)")
                continue
            }

            Logger.debug("📅 workout (\(workout.startDate.formatted(date: .abbreviated, time: .omitted))) → dayIndex: \(dayIndex)")

            if grouped[dayIndex] == nil {
                grouped[dayIndex] = []
            }
            grouped[dayIndex]?.append(workout)
        }

        // 對每天的運動記錄按日期排序（最新的在前面）
        for (day, dayWorkouts) in grouped {
            grouped[day] = dayWorkouts.sorted { $0.startDate > $1.startDate }
        }

        Logger.debug("✅ groupWorkoutsByDayFromV2 分組結果: \(grouped.map { "dayIndex:\($0.key)=\($0.value.count)個workout" }.joined(separator: ", "))")

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
        // 簡化：移除初始化期間檢查，統一處理
        
        await loadCurrentWeekDistance()
        await loadCurrentWeekIntensity()
    }
    
    // 確保運動數據已載入 - 僅檢查狀態，不重複調用 API
    private func ensureWorkoutDataLoaded() async {
        // 如果正在執行初始載入，等待完成
        if unifiedWorkoutManager.isPerformingInitialLoad {
            Logger.debug("UnifiedWorkoutManager 正在載入中，等待完成...")
            // 簡單等待一下讓初始載入完成
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            return
        }
        
        // 如果沒有數據且不在載入中，才發起載入
        if !unifiedWorkoutManager.hasWorkouts {
            Logger.debug("UnifiedWorkoutManager 沒有數據，先載入運動記錄...")
            await unifiedWorkoutManager.loadWorkouts()
        }
    }
    
    // 載入本週訓練強度分鐘數
    // ✅ 純內存計算（無 API 調用），不參數化 TaskID
    func loadCurrentWeekIntensity() async {
        await executeTask(id: TaskID("load_current_week_intensity"), cooldownSeconds: 5) {
            await self.performLoadCurrentWeekIntensity()
        }
    }
    
    private func performLoadCurrentWeekIntensity() async {
        let logPrefix = "[INTENSITY_DEBUG]"
        print("\(logPrefix) ========== 開始載入本週訓練強度 ==========")
        await MainActor.run {
            isLoadingIntensity = true
        }

        defer {
            Task { @MainActor in
                isLoadingIntensity = false
            }
        }

        do {
            let (weekStart, weekEnd) = getCurrentWeekDates()
            print("\(logPrefix) 週範圍: \(formatDate(weekStart)) ~ \(formatDate(weekEnd))")

            // 從 UnifiedWorkoutManager 獲取該週的運動記錄
            let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
                startDate: weekStart,
                endDate: weekEnd
            )

            // 過濾掉瑜伽、普拉提和重量訓練等非有氧運動
            let aerobicWorkouts = weekWorkouts.filter { workout in
                shouldIncludeInTrainingLoad(activityType: workout.activityType)
            }

            print("\(logPrefix) 該週總運動: \(weekWorkouts.count) 筆，有氧運動: \(aerobicWorkouts.count) 筆")

            // 直接使用 API 提供的 intensity_minutes 數據
            let intensity = aggregateIntensityFromV2Workouts(aerobicWorkouts)

            print("\(logPrefix) 訓練強度聚合完成 - 低: \(intensity.low), 中: \(intensity.medium), 高: \(intensity.high)")
            
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
    
    // 判斷運動類型是否應該包含在訓練負荷計算中
    private func shouldIncludeInTrainingLoad(activityType: String) -> Bool {
        // 包含有氧運動類型，排除瑜伽、普拉提、重量訓練等
        let aerobicActivityTypes: Set<String> = [
            "running",       // 跑步 (API 使用的是 "running")
            "run",           // 跑步 (保持向後相容)
            "walking",       // 步行 (API 使用的是 "walking")
            "walk",          // 步行 (保持向後相容)
            "cycling",       // 騎車
            "swimming",      // 游泳 (API 使用的是 "swimming")
            "swim",          // 游泳 (保持向後相容)
            "hiit",          // 高強度間歇訓練
            "mixedCardio",   // 混合有氧
            "hiking"         // 健行
        ]
        
        return aerobicActivityTypes.contains(activityType.lowercased())
    }
    
    // 聚合 V2 API 提供的 intensity_minutes 數據
    private func aggregateIntensityFromV2Workouts(_ workouts: [WorkoutV2]) -> TrainingIntensityManager.IntensityMinutes {
        let logPrefix = "[INTENSITY_DEBUG]"
        var totalLow: Double = 0
        var totalMedium: Double = 0
        var totalHigh: Double = 0

        print("\(logPrefix) 開始計算訓練強度，總共有 \(workouts.count) 筆運動記錄")

        for workout in workouts {
            print("\(logPrefix) 處理運動: \(workout.id), 類型: \(workout.activityType), 開始時間: \(workout.startTimeUtc ?? "nil")")

            // 檢查是否有 intensity_minutes 數據
            var foundIntensityData = false

            if let advancedMetrics = workout.advancedMetrics {
                print("\(logPrefix) [\(workout.id)] advancedMetrics 存在")

                // 嘗試處理 APIIntensityMinutes (AdvancedMetrics 類型)
                if let intensityMinutes = advancedMetrics.intensityMinutes {
                    let low = intensityMinutes.low ?? 0.0
                    let medium = intensityMinutes.medium ?? 0.0
                    let high = intensityMinutes.high ?? 0.0

                    totalLow += low
                    totalMedium += medium
                    totalHigh += high
                    foundIntensityData = true

                    print("\(logPrefix) [\(workout.id)] ✅ intensityMinutes 有值 - low: \(low), medium: \(medium), high: \(high)")
                } else {
                    print("\(logPrefix) [\(workout.id)] ⚠️ intensityMinutes 為 nil")
                }
            } else {
                print("\(logPrefix) [\(workout.id)] ⚠️ advancedMetrics 為 nil")
            }

            // 如果沒有找到數據，進行更詳細的調試
            if !foundIntensityData {
                print("\(logPrefix) [\(workout.id)] 未找到強度數據，使用備選方案")

                // 作為備選方案，嘗試從運動持續時間估算低強度分鐘數
                // 這確保至少有一些訓練負荷數據而不是顯示"資料不足"
                let fallbackLowIntensity = Double(workout.durationSeconds) / 60.0
                if fallbackLowIntensity > 0 {
                    totalLow += fallbackLowIntensity
                    print("\(logPrefix) [\(workout.id)] 使用 duration 備選估算: 低強度 \(fallbackLowIntensity) 分鐘")
                }
            }
        }

        print("\(logPrefix) ========== 計算結果 ==========")
        print("\(logPrefix) 總低強度: \(totalLow), 總中強度: \(totalMedium), 總高強度: \(totalHigh)")

        // 如果沒有從 API 獲得任何強度數據，記錄這個問題
        if totalMedium == 0 && !workouts.isEmpty {
            print("\(logPrefix) ⚠️ 警告: 中強度為 0，請檢查 API 回應中的 intensity_minutes.medium 欄位")
        }

        return TrainingIntensityManager.IntensityMinutes(
            low: totalLow,
            medium: totalMedium,
            high: totalHigh
        )
    }

    /// 調試 AdvancedMetrics 結構，幫助了解數據格式問題
    private func debugAdvancedMetricsStructure(_ metrics: AdvancedMetrics, workoutId: String) {
        Logger.debug("運動 \(workoutId) - AdvancedMetrics 詳細調試:")
        Logger.debug("  - dynamicVdot: \(metrics.dynamicVdot?.description ?? "nil")")
        Logger.debug("  - tss: \(metrics.tss?.description ?? "nil")")
        Logger.debug("  - trainingType: \(metrics.trainingType ?? "nil")")
        Logger.debug("  - intensityMinutes: \(String(describing: metrics.intensityMinutes))")

        if let intensityMinutes = metrics.intensityMinutes {
            Logger.debug("    - intensityMinutes.low: \(intensityMinutes.low?.description ?? "nil")")
            Logger.debug("    - intensityMinutes.medium: \(intensityMinutes.medium?.description ?? "nil")")
            Logger.debug("    - intensityMinutes.high: \(intensityMinutes.high?.description ?? "nil")")
        }

        Logger.debug("  - intervalCount: \(metrics.intervalCount?.description ?? "nil")")
        Logger.debug("  - rpe: \(metrics.rpe?.description ?? "nil")")

        // 使用反射檢查是否有其他我們遺漏的屬性
        let mirror = Mirror(reflecting: metrics)
        Logger.debug("  - AdvancedMetrics 所有屬性:")
        for child in mirror.children {
            Logger.debug("    - \(child.label ?? "unnamed"): \(child.value)")
        }
    }
    
    func loadCurrentWeekDistance() async {
        await executeTask(id: TaskID("load_current_week_distance"), cooldownSeconds: 5) {
            await self.performLoadCurrentWeekDistance()
        }
    }

    // ✅ 純內存計算（無 API 調用）
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
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            print("🗓️ 計算當週跑量時間範圍: \(weekStart) 到 \(weekEnd)")
            
            // 從 UnifiedWorkoutManager 獲取該週的運動記錄
            let weekWorkouts = unifiedWorkoutManager.getWorkoutsInDateRange(
                startDate: weekStart,
                endDate: weekEnd
            )
            
            print("🏃 UnifiedWorkoutManager 獲取到 \(weekWorkouts.count) 筆該週記錄")
            
            // 過濾僅包含跑步類型的鍛煉
            let runWorkouts = weekWorkouts.filter { $0.activityType == "running" }
            
            print("🏃 其中跑步記錄 \(runWorkouts.count) 筆")
            for workout in runWorkouts {
                print("   - \(workout.id): \(workout.startDate), 距離: \((workout.distance ?? 0) / 1000.0) km")
            }
            
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

    // 重新嘗試載入週訓練回顧（強制更新模式）
    func retryLoadWeeklySummary() async {
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

            Logger.debug("重新嘗試載入第\(currentWeek-1)週的週回顧（強制更新模式）")

            // 使用強制更新模式從API獲取週訓練回顧數據
            let summary = try await weeklySummaryService.createWeeklySummary(
                weekNumber: currentWeek - 1, forceUpdate: true)

            await MainActor.run {
                self.weeklySummary = summary
                self.isLoadingWeeklySummary = false
            }

            Logger.debug("強制更新載入週回顧成功")

        } catch {
            Logger.error("強制更新載入週回顧失敗: \(error)")

            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
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
    
    func weekdayShortName(for index: Int) -> String {
        return ViewModelUtils.weekdayShortName(for: index)
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
    
    // 移除重複的 refreshWorkoutData - 直接使用 unifiedWorkoutManager.refreshWorkouts()

    // MARK: - VDOT and Pace Calculation

    /// 載入 VDOT 並計算配速表
    func loadVDOTAndCalculatePaces() async {
        await MainActor.run {
            isLoadingPaces = true
        }

        // 確保 VDOTManager 已載入緩存數據（先嘗試從緩存載入，這是同步操作）
        if !VDOTManager.shared.hasData {
            Logger.debug("TrainingPlanViewModel: VDOTManager 尚未載入數據，先載入本地緩存...")
            // 先同步載入緩存，這樣可以立即使用加權跑力
            VDOTManager.shared.loadLocalCacheSync()

            // 等待主線程更新完成
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // 如果緩存也沒有數據，才等待 API 初始化
            if !VDOTManager.shared.hasData {
                Logger.debug("TrainingPlanViewModel: 本地緩存無數據，等待 API 初始化...")
                await VDOTManager.shared.initialize()
            }
        }

        // 從 VDOTManager 獲取當前 VDOT（使用 weight_vdot / averageVDOT）
        let vdot = VDOTManager.shared.averageVDOT
        let dynamicVdot = VDOTManager.shared.currentVDOT
        Logger.debug("TrainingPlanViewModel: 從 VDOTManager 獲取 averageVDOT (加權跑力) = \(vdot), dynamicVDOT = \(dynamicVdot)")

        await MainActor.run {
            // 如果 VDOT 有效，則使用它；否則使用預設值
            if PaceCalculator.isValidVDOT(vdot) {
                self.currentVDOT = vdot
                Logger.info("TrainingPlanViewModel: ✅ 使用實際加權跑力 VDOT = \(vdot)")
            } else {
                self.currentVDOT = PaceCalculator.defaultVDOT
                Logger.warn("TrainingPlanViewModel: ⚠️ VDOT 無效 (\(vdot))，使用預設值 \(PaceCalculator.defaultVDOT)")
            }

            // 計算所有訓練區間的配速
            if let vdot = self.currentVDOT {
                self.calculatedPaces = PaceCalculator.calculateTrainingPaces(vdot: vdot)
                Logger.debug("TrainingPlanViewModel: 配速計算完成，VDOT = \(vdot)")
            }

            isLoadingPaces = false
        }
    }

    /// 根據訓練類型獲取建議配速
    /// - Parameter trainingType: 訓練類型（例如："easy"、"tempo"、"interval"）
    /// - Returns: 建議配速字串，格式為 mm:ss；如果無法計算則返回 nil
    func getSuggestedPace(for trainingType: String) -> String? {
        guard let vdot = currentVDOT else { return nil }
        return PaceCalculator.getSuggestedPace(for: trainingType, vdot: vdot)
    }

    /// 獲取訓練類型對應的配速區間範圍
    /// - Parameter trainingType: 訓練類型
    /// - Returns: (下限配速, 上限配速) 的元組；如果無法計算則返回 nil
    func getPaceRange(for trainingType: String) -> (min: String, max: String)? {
        guard let vdot = currentVDOT else { return nil }
        return PaceCalculator.getPaceRange(for: trainingType, vdot: vdot)
    }

    /// 重新計算配速（當 VDOT 更新時調用）
    func recalculatePaces() async {
        await loadVDOTAndCalculatePaces()
    }

    // MARK: - Edit Schedule Methods
    
    /// 檢查特定日期是否可以編輯
    /// 規則：只有今天以後且沒有跑步記錄的課表才可編輯
    func canEditDay(_ dayIndex: Int) -> Bool {
        // 獲取該天的日期
        guard let dayDate = getDateForDay(dayIndex: dayIndex) else { return false }
        
        // 取得今天的開始時間 (00:00)
        let today = Calendar.current.startOfDay(for: Date())
        
        // 只有今天以後的日期才能編輯
        guard dayDate >= today else {
            return false
        }
        
        // 檢查是否已有訓練記錄
        let hasWorkouts = !(workoutsByDayV2[dayIndex]?.isEmpty ?? true)
        return !hasWorkouts
    }
    
    /// 取得編輯狀態說明文字
    func getEditStatusMessage(for dayIndex: Int) -> String {
        guard let dayDate = getDateForDay(dayIndex: dayIndex) else {
            return NSLocalizedString("edit_schedule.cannot_edit_past", comment: "過去的課表無法編輯")
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if dayDate < today {
            return NSLocalizedString("edit_schedule.cannot_edit_past", comment: "過去的課表無法編輯")
        }
        
        let hasWorkouts = !(workoutsByDayV2[dayIndex]?.isEmpty ?? true)
        if hasWorkouts {
            return NSLocalizedString("edit_schedule.cannot_edit_completed", comment: "已有訓練記錄的課表無法編輯")
        }
        
        return NSLocalizedString("edit_schedule.drag_to_swap", comment: "長按拖曳以交換課表")
    }
    
    /// 更新週課表 (儲存編輯後的課表)
    @MainActor
    func updateWeeklyPlan(_ editablePlan: MutableWeeklyPlan) async {
        await executeTask(id: TaskID("update_weekly_plan_\(editablePlan.weekOfPlan)")) { [weak self] in
            guard let self = self else { return }

            do {
                Logger.debug("準備儲存編輯後的週課表: week=\(editablePlan.weekOfPlan)")

                // 1. 轉換為 WeeklyPlan
                let updatedPlan = editablePlan.toWeeklyPlan()

                // 2. 呼叫 API 儲存
                let savedPlan = try await TrainingPlanService.shared.modifyWeeklyPlan(
                    planId: updatedPlan.id,
                    updatedPlan: updatedPlan
                )

                // 3. 更新 UI 和緩存
                await self.updateWeeklyPlanUI(plan: savedPlan, status: .ready(savedPlan))

                Logger.debug("課表儲存成功: ID=\(savedPlan.id)")
            } catch {
                // 處理取消錯誤
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("儲存任務被取消，忽略錯誤")
                    return
                }

                Logger.error("儲存課表失敗: \(error.localizedDescription)")

                // 顯示錯誤 Toast（不跳 ErrorView）
                await MainActor.run {
                    self.showNetworkErrorToast = true
                }
            }
        }
    }

    /// 從編輯畫面更新週計劃，確保緩存一致性
    @MainActor
    func updateWeeklyPlanFromEdit(_ updatedPlan: WeeklyPlan) {
        Logger.debug("從編輯畫面更新週計劃: 週數=\(updatedPlan.weekOfPlan), ID=\(updatedPlan.id)")

        // 使用統一的 updateWeeklyPlanUI 方法，確保緩存一致性
        updateWeeklyPlanUI(plan: updatedPlan, status: .ready(updatedPlan))

        Logger.debug("週計劃已更新並保存到緩存")
    }

    // MARK: - 調整建議確認相關方法

    /// 檢查是否需要顯示調整建議確認畫面
    /// 簡化邏輯：只檢查一次，不做複雜的狀態管理
    @MainActor
    private func shouldShowAdjustmentConfirmation(for targetWeek: Int) async -> Bool {
        // 檢查上一週是否有週總結
        let previousWeek = targetWeek - 1

        // 🔧 修復：確保有 planId 才能構建正確的 summaryId
        guard let planId = trainingOverview?.id, !planId.isEmpty else {
            Logger.error("無法顯示調整建議：缺少 planId")
            return false
        }

        var existingAdjustments: [AdjustmentItem] = []
        var actualSummaryId: String?

        if previousWeek > 0 {
            do {
                let summary = try await WeeklySummaryService.shared.getWeeklySummary(weekNumber: previousWeek)
                actualSummaryId = summary.id

                if let items = summary.nextWeekAdjustments.items {
                    existingAdjustments = items
                }
            } catch {
                Logger.debug("無法獲取上週總結: \(error)")
            }
        }

        // 🔧 修復：如果無法從 API 獲取真實 ID，使用正確的格式構建
        let summaryId = actualSummaryId ?? "\(planId)_\(previousWeek)_summary"
        Logger.debug("📋 使用 summaryId: \(summaryId) (來源: \(actualSummaryId != nil ? "API" : "構建"))")

        // 設置待確認的調整建議
        pendingAdjustments = existingAdjustments
        pendingTargetWeek = targetWeek
        pendingSummaryId = summaryId

        // 顯示調整建議確認畫面
        showAdjustmentConfirmation = true
        isLoading = false

        return true
    }

    /// 確認調整建議並繼續產生週課表
    /// 簡化邏輯：確認後直接產生課表，不再回到 generateNextWeekPlan
    @MainActor
    func confirmAdjustments(_ selectedItems: [AdjustmentItem]) async {
        guard let targetWeek = pendingTargetWeek,
              let summaryId = pendingSummaryId else {
            Logger.error("缺少必要的參數來確認調整建議")
            return
        }

        // 🔧 修復：立即關閉調整建議畫面，防止重複點擊
        showAdjustmentConfirmation = false

        // 清理調整建議相關狀態
        let currentTargetWeek = targetWeek  // 保存週數，因為後面會清空
        pendingAdjustments = []
        pendingTargetWeek = nil
        pendingSummaryId = nil

        // 清除週回顧狀態
        clearWeeklySummary()

        // 在背景更新調整建議到後端（不阻塞 UI）
        Task.detached {
            do {
                _ = try await WeeklySummaryService.shared.updateAdjustments(
                    summaryId: summaryId,
                    items: selectedItems
                )
                Logger.debug("調整建議已更新到後端")
            } catch {
                Logger.error("更新調整建議失敗（不影響課表產生）: \(error)")
            }
        }

        // 繼續產生週課表（不再經過 shouldShowAdjustmentConfirmation 檢查）
        await generateNextWeekPlanAfterAdjustment(targetWeek: currentTargetWeek)
    }

    /// 取消調整建議確認
    @MainActor
    func cancelAdjustmentConfirmation() {
        showAdjustmentConfirmation = false
        pendingAdjustments = []
        pendingTargetWeek = nil
        pendingSummaryId = nil

        // 停止載入動畫
        isLoadingAnimation = false
        planStatus = weeklyPlan != nil ? .ready(weeklyPlan!) : .noPlan
    }

    /// 確認調整建議後繼續產生週課表
    @MainActor
    private func generateNextWeekPlanAfterAdjustment(targetWeek: Int) async {
        // 確保顯示正確的載入動畫類型（課表產生而非週回顧）
        isLoadingWeeklySummary = false
        // 開始載入動畫
        isLoadingAnimation = true
        planStatus = .loading

        do {
            Logger.debug("調整建議確認完成，繼續產生第 \(targetWeek) 週課表...")
            // ✅ 優化：直接使用 createWeeklyPlan 的返回值，避免重複調用 API
            let newPlan = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)

            updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))

            Logger.debug("第 \(targetWeek) 週課表產生完成")
        } catch {
            Logger.error("產生課表失敗: \(error)")
            await MainActor.run {
                self.error = error
                self.planStatus = .error(error)
            }
        }

        // 結束載入動畫
        isLoadingAnimation = false
    }

    // MARK: - 🆕 新增：週日產生下週課表流程

    /// 產生下週課表（週日提前產生）
    /// - Parameter nextWeekInfo: 下週資訊（來自 planStatusResponse）
    func generateNextWeekPlan(nextWeekInfo: NextWeekInfo) async {
        Logger.debug("🔔 [GenerateNextWeek] 方法被調用")

        guard let status = planStatusResponse else {
            Logger.error("❌ [NextWeekPlan] 無法產生：缺少 planStatusResponse")
            return
        }

        let targetWeek = nextWeekInfo.weekNumber

        Logger.debug("🎯 [NextWeekPlan] 開始產生第 \(targetWeek) 週課表")
        Logger.debug("""
        📝 [NextWeekPlan] 流程資訊
           - 當前週: \(status.currentWeek)
           - 目標週: \(targetWeek)
           - 需要週回顧: \(nextWeekInfo.requiresCurrentWeekSummary)
        """)

        // 階段 1：如果需要先產生週回顧
        if nextWeekInfo.requiresCurrentWeekSummary {
            // 使用 next_week_info.week_number 作為週回顧的週數（後端會自動減一）
            let summaryWeek = nextWeekInfo.weekNumber
            Logger.debug("⏸️ [NextWeekPlan] 需要先產生第 \(summaryWeek) 週回顧，暫停流程")

            // 保存目標週數，用於週回顧完成後產生課表
            await MainActor.run {
                self.pendingTargetWeek = targetWeek
            }

            // 產生指定週的週回顧
            await createWeeklySummary(weekNumber: summaryWeek)

            // 等待用戶確認調整建議（在 showWeeklySummary view 中處理）
            // 用戶點擊「產生下週課表」按鈕後會使用 pendingTargetWeek
            return
        }

        // 階段 2：直接產生下週課表（週回顧已完成或不需要）
        Logger.debug("▶️ [NextWeekPlan] 週回顧已完成，直接產生課表")
        await performGenerateNextWeekPlan(targetWeek: targetWeek)
    }

    /// 確認調整建議並產生下週課表
    /// - Parameter targetWeek: 目標週數
    func confirmAdjustmentsAndGenerateNextWeek(targetWeek: Int) async {
        Logger.debug("✅ [NextWeekPlan] 用戶已確認調整建議，繼續產生第 \(targetWeek) 週課表")
        // 用戶已確認調整建議，繼續產生課表
        await performGenerateNextWeekPlan(targetWeek: targetWeek)
    }

    /// 執行產生下週課表（內部方法）
    private func performGenerateNextWeekPlan(targetWeek: Int) async {
        await MainActor.run {
            self.isLoadingAnimation = true
            self.planStatus = .loading
        }

        defer {
            Task { @MainActor in
                self.isLoadingAnimation = false
            }
        }

        do {
            Logger.debug("🔄 [NextWeekPlan] 呼叫 API: POST /plan/race_run/weekly/v2 {week_of_training: \(targetWeek)}")

            // 呼叫 API 產生課表
            let newPlan = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)

            Logger.debug("✅ [NextWeekPlan] API 回應成功，課表 ID: \(newPlan.id)")

            // ✅ 產生成功，切換到下週並顯示課表
            // 使用 updateWeeklyPlanUI 來確保 weekDateInfo 正確更新
            await updateWeeklyPlanUI(plan: newPlan, planChanged: true, status: .ready(newPlan))

            await MainActor.run {
                Logger.debug("""
                🔄 [NextWeekPlan] 更新 UI 狀態
                   - selectedWeek: \(self.selectedWeek) → \(targetWeek)
                   - planStatus: → ready
                   - 顯示 Toast: true
                """)

                // 清除待處理的目標週數
                self.pendingTargetWeek = nil

                // 顯示成功 Toast
                self.showSuccessToast = true
                self.successMessage = "第\(targetWeek)週課表已產生！"
            }

            // 保存到緩存
            TrainingPlanStorage.saveWeeklyPlan(newPlan)
            Logger.debug("💾 [NextWeekPlan] 已保存到本地緩存")

            // 🔧 重新載入 workout 記錄，確保只顯示新週的訓練記錄
            Logger.debug("🔄 [NextWeekPlan] 重新載入當前週的 workout 記錄...")
            await loadWorkoutsForCurrentWeek()

            // 重新載入狀態（驗證）
            // 剛生成新課表，需要立即同步狀態，跳過緩存
            Logger.debug("🔄 [NextWeekPlan] 重新載入狀態驗證...")
            await loadPlanStatus(skipCache: true)

            // 更新訓練進度
            await forceUpdateWeeklySummaries()

            // 🔧 手動更新週選擇器列表，確保新課表可以被選擇
            await MainActor.run {
                Logger.debug("🔍 [NextWeekPlan] 檢查週摘要列表，目標週: \(targetWeek)")
                Logger.debug("   當前列表週數: \(self.weeklySummaries.map { $0.weekIndex })")

                // 檢查是否已存在該週
                if let index = self.weeklySummaries.firstIndex(where: { $0.weekIndex == targetWeek }) {
                    let currentSummary = self.weeklySummaries[index]
                    Logger.debug("   第 \(targetWeek) 週已存在，weekPlan: \(currentSummary.weekPlan ?? "nil")")

                    // 如果 weekPlan 是 nil，手動設置
                    if currentSummary.weekPlan == nil {
                        Logger.debug("🔧 [NextWeekPlan] 手動設置第 \(targetWeek) 週的 weekPlan = \(newPlan.id)")
                        let updatedItem = WeeklySummaryItem(
                            weekIndex: currentSummary.weekIndex,
                            weekStart: currentSummary.weekStart,
                            weekStartTimestamp: currentSummary.weekStartTimestamp,
                            distanceKm: currentSummary.distanceKm,
                            weekPlan: newPlan.id,  // 使用新產生的課表 ID
                            weekSummary: currentSummary.weekSummary,
                            completionPercentage: currentSummary.completionPercentage
                        )
                        self.weeklySummaries[index] = updatedItem
                        Logger.debug("✅ [NextWeekPlan] 第 \(targetWeek) 週 weekPlan 已更新")
                    }
                } else {
                    Logger.debug("⚠️ [NextWeekPlan] 週摘要列表中找不到第 \(targetWeek) 週，需要手動新增")

                    // 手動添加新週到列表（推測週開始日期）
                    guard let overview = self.trainingOverview else {
                        Logger.error("❌ [NextWeekPlan] 無法添加第 \(targetWeek) 週：缺少 trainingOverview")
                        return
                    }

                    // 計算週開始日期（假設從訓練開始日期算起）
                    let calendar = Calendar.current
                    if let startDate = ISO8601DateFormatter().date(from: overview.createdAt),
                       let weekStartDate = calendar.date(byAdding: .weekOfYear, value: targetWeek - 1, to: startDate) {
                        let dateFormatter = ISO8601DateFormatter()
                        let weekStartString = dateFormatter.string(from: weekStartDate)

                        let newItem = WeeklySummaryItem(
                            weekIndex: targetWeek,
                            weekStart: weekStartString,
                            weekStartTimestamp: weekStartDate.timeIntervalSince1970,
                            distanceKm: nil,
                            weekPlan: newPlan.id,
                            weekSummary: nil,
                            completionPercentage: nil
                        )

                        self.weeklySummaries.append(newItem)
                        // 重新排序
                        self.weeklySummaries.sort { $0.weekIndex > $1.weekIndex }

                        Logger.debug("✅ [NextWeekPlan] 已手動添加第 \(targetWeek) 週到列表")
                    }
                }

                Logger.debug("📊 [NextWeekPlan] 最終列表: \(self.weeklySummaries.count) 週")

                // 更新快取
                self.cacheWeeklySummaries(self.weeklySummaries)
                Logger.debug("💾 [NextWeekPlan] 已更新週摘要快取")
            }

            Logger.debug("✅ [NextWeekPlan] 完整流程結束，第 \(targetWeek) 週課表已成功產生並顯示")

        } catch {
            Logger.error("❌ [NextWeekPlan] 產生第 \(targetWeek) 週課表失敗: \(error.localizedDescription)")

            await MainActor.run {
                self.error = error
                self.planStatus = .error(error)
            }
        }
    }

    /// 清除成功 Toast
    func clearSuccessToast() {
        Task { @MainActor in
            self.showSuccessToast = false
            self.successMessage = ""
        }
    }

    // MARK: - App Lifecycle

    /// App 從後台回到前台時的輕量級數據同步
    func onAppBecameActive() async {
        Logger.debug("🔄 [AppLifecycle] TrainingPlanViewModel: App 回到前台")

        // 只有在用戶已認證且有訓練概覽時才同步
        guard AuthenticationService.shared.isAuthenticated,
              let _ = trainingOverview else {
            Logger.debug("⚠️ [AppLifecycle] 用戶未認證或無訓練概覽，跳過同步")
            return
        }

        // 只重新載入 plan status（輕量級 API 調用）
        Logger.debug("📊 [AppLifecycle] 檢查 plan status...")
        await loadPlanStatus()

        Logger.debug("✅ [AppLifecycle] Plan status 已更新")
    }

    deinit {
        cancelAllTasks()
    }
}
