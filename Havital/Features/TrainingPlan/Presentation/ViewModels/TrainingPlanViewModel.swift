import Foundation
import SwiftUI
import Combine

// MARK: - TrainingPlan ViewModel (Composition)
/// 組合 WeeklyPlanViewModel 和 WeeklySummaryViewModel
/// 負責協調週計畫和週回顧的交互
/// 這是 TrainingPlanView 的主 ViewModel
@MainActor
class TrainingPlanViewModel: ObservableObject {

    // MARK: - Child ViewModels
    @Published var weeklyPlanVM: WeeklyPlanViewModel
    @Published var summaryVM: WeeklySummaryViewModel

    // MARK: - Published State

    /// 計畫狀態（統一管理）
    @Published var planStatus: PlanStatus = .loading

    /// 計畫狀態響應
    @Published var planStatusResponse: PlanStatusResponse?

    /// 訓練計畫名稱
    @Published var trainingPlanName: String = "訓練計畫"

    /// 網路錯誤（用於 Toast 顯示）
    @Published var networkError: Error?

    /// 成功提示訊息
    @Published var successToast: String?

    /// 是否顯示新建週計畫 sheet
    @Published var showNewWeekSheet: Bool = false

    /// 展開的天數索引集合
    @Published var expandedDayIndices: Set<Int> = []

    /// 是否顯示載入動畫
    @Published var isLoadingAnimation: Bool = false

    /// 網路錯誤 Alert 顯示狀態
    @Published var showNetworkErrorAlert: Bool = false

    /// 網路錯誤 Toast 顯示狀態
    @Published var showNetworkErrorToast: Bool = false

    // MARK: - Legacy Compatibility (for Previews)
    @Published var currentWeekDistance: Double = 0.0
    @Published var currentWeekIntensity: WeeklyPlan.IntensityTotalMinutes = .init(low: 0, medium: 0, high: 0)
    @Published var weeklySummaries: [WeeklySummaryItem] = []
    @Published var isLoadingWeeklySummaries: Bool = false

    /// 真實的已完成訓練記錄（按天分組）
    @Published var workoutsByDayV2: [Int: [WorkoutV2]] = [:]

    /// 是否正在載入訓練記錄
    @Published var isLoadingWorkouts: Bool = false

    /// 是否已完成初始化（用於防止初始化期間響應通知）
    private var hasInitialized: Bool = false

    func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        return String(format: "%.0f", distance)
    }

    /// 獲取指定週計畫（Legacy Proxy）
    func fetchWeekPlan(week: Int) async {
        Logger.debug("[TrainingPlanVM] Fetching week plan for week \(week)")

        // 顯示 loading 狀態
        planStatus = .loading

        // 切換週次
        await weeklyPlanVM.selectWeek(week)

        // ✅ 切換週次後，重新載入訓練記錄
        await loadWorkoutsForCurrentWeek()

        // ✅ 所有數據準備完畢後，手動更新 planStatus
        switch weeklyPlanVM.state {
        case .loaded(let plan):
            planStatus = .ready(plan)
            Logger.debug("[TrainingPlanVM] ✅ Week \(week) plan loaded successfully")
        case .error(let error):
            planStatus = .error(error as NSError)
            Logger.error("[TrainingPlanVM] ❌ Error loading week \(week): \(error.localizedDescription)")
        case .empty:
            planStatus = .noPlan
            Logger.debug("[TrainingPlanVM] No plan available for week \(week)")
        case .loading:
            Logger.debug("[TrainingPlanVM] ⚠️ Still loading after selectWeek(\(week)) completed")
        }
    }

    // MARK: - Helper Methods (Delegating to Utilities)

    /// 獲取星期名稱
    func weekdayName(for dayIndex: Int) -> String {
        return DateFormatterHelper.weekdayName(for: dayIndex)
    }

    /// 格式化短日期
    func formatShortDate(_ date: Date) -> String {
        return DateFormatterHelper.formatShortDate(date)
    }

    /// 獲取指定日期索引對應的日期
    func getDateForDay(dayIndex: Int) -> Date? {
        // 使用 WeekDateService 計算（與重構前邏輯一致）
        guard let overview = trainingOverview else {
            Logger.error("[TrainingPlanVM] No training overview available for date calculation")
            return nil
        }

        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: currentWeek) else {
            Logger.error("[TrainingPlanVM] Failed to calculate week date info for week \(currentWeek)")
            return nil
        }

        let date = weekInfo.daysMap[dayIndex]
        Logger.debug("[TrainingPlanVM] getDateForDay(\(dayIndex)) for week \(currentWeek) -> \(date?.description ?? "nil")")
        return date
    }

    /// 檢查是否為今天
    func isToday(_ date: Date) -> Bool {
        return DateFormatterHelper.isToday(date)
    }

    /// 檢查是否為今天 (By Day Index)
    func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else { return false }
        return isToday(date)
    }

    /// 格式化配速
    func formatPace(_ pace: String?) -> String {
        return PaceFormatterHelper.formatPace(pace)
    }

    /// 獲取建議配速
    func getSuggestedPace(for trainingType: String, vdot: Double) -> String {
        return PaceFormatterHelper.getSuggestedPace(for: trainingType, vdot: vdot)
    }

    /// 載入當前週的訓練記錄（使用 Use Case）
    func loadWorkoutsForCurrentWeek() async {
        await MainActor.run {
            isLoadingWorkouts = true
        }

        // 使用 selectedWeek 確保日期範圍與顯示的週計畫對齊
        guard let overview = trainingOverview,
              let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            Logger.error("[TrainingPlanVM] Failed to calculate week dates")
            await MainActor.run { isLoadingWorkouts = false }
            return
        }

        Logger.debug("[TrainingPlanVM] Loading workouts from \(weekInfo.startDate) to \(weekInfo.endDate)")

        // ✅ 使用 Use Case 載入並分組訓練記錄
        let grouped = loadWeeklyWorkoutsUseCase.execute(weekInfo: weekInfo)

        await MainActor.run {
            self.workoutsByDayV2 = grouped
            self.isLoadingWorkouts = false
            self.objectWillChange.send()
        }

        Logger.debug("[TrainingPlanVM] Grouped workouts: \(grouped.keys.sorted())")

        // 載入完成後，計算週跑量和強度分布
        await loadCurrentWeekMetrics()
    }

    /// 載入當前週的訓練指標（距離和強度）
    private func loadCurrentWeekMetrics() async {
        guard let overview = trainingOverview,
              let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            Logger.error("[TrainingPlanVM] Failed to calculate week dates for metrics")
            return
        }

        Logger.debug("[TrainingPlanVM] Calculating metrics for week \(selectedWeek)")

        // ✅ 使用 Use Case 計算訓練指標
        let metrics = aggregateWorkoutMetricsUseCase.execute(weekInfo: weekInfo)

        await MainActor.run {
            self.currentWeekDistance = metrics.totalDistanceKm
            self.currentWeekIntensity = metrics.intensity
        }

        Logger.debug("[TrainingPlanVM] Week metrics - Distance: \(metrics.totalDistanceKm) km, Intensity: low=\(metrics.intensity.low), medium=\(metrics.intensity.medium), high=\(metrics.intensity.high)")
    }

    /// 計算當前訓練週數
    func calculateCurrentTrainingWeek() -> Int {
        return currentWeek
    }

    /// 獲取當前週的起始日期（週一）
    func getWeekStartDate() -> Date? {
        guard let overview = trainingOverview else {
            return nil
        }

        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: currentWeek) else {
            return nil
        }

        return weekInfo.startDate
    }

    // MARK: - Dependencies

    private let repository: TrainingPlanRepository
    private let loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase
    private let aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase

    // MARK: - Subscribers

    private var cancellables = Set<AnyCancellable>()

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    init(
        repository: TrainingPlanRepository,
        loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase,
        aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase,
        weeklyPlanVM: WeeklyPlanViewModel? = nil,
        summaryVM: WeeklySummaryViewModel? = nil
    ) {
        self.repository = repository
        self.loadWeeklyWorkoutsUseCase = loadWeeklyWorkoutsUseCase
        self.aggregateWorkoutMetricsUseCase = aggregateWorkoutMetricsUseCase
        self.weeklyPlanVM = weeklyPlanVM ?? WeeklyPlanViewModel(repository: repository)
        self.summaryVM = summaryVM ?? WeeklySummaryViewModel(repository: repository)

        setupBindings()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        let container = DependencyContainer.shared

        // 註冊必要的模組
        if !container.isRegistered(TrainingPlanRepository.self) {
            container.registerTrainingPlanModule()
        }
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        let repository: TrainingPlanRepository = container.resolve()
        let loadWeeklyWorkoutsUseCase = container.makeLoadWeeklyWorkoutsUseCase()
        let aggregateWorkoutMetricsUseCase = container.makeAggregateWorkoutMetricsUseCase()

        self.init(
            repository: repository,
            loadWeeklyWorkoutsUseCase: loadWeeklyWorkoutsUseCase,
            aggregateWorkoutMetricsUseCase: aggregateWorkoutMetricsUseCase
        )
    }

    // MARK: - Setup

    private func setupBindings() {
        // ❌ 移除自動更新 planStatus 的訂閱，改為手動控制
        // 原因：自動訂閱會在 weeklyPlanVM.$state 變化時立即觸發 UI 更新，
        // 導致 View 在 workouts 加載完成前就渲染，造成已完成的 workout 不顯示
        //
        // weeklyPlanVM.$state
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] state in
        //         self?.updatePlanStatus(from: state)
        //     }
        //     .store(in: &cancellables)

        // ✅ 保留其他必要的訂閱
        // 監聯週回顧的 isGenerating 狀態，控制載入動畫
        summaryVM.$isGenerating
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingAnimation)

        // ✅ 關鍵修復：監聽 workouts 更新通知
        // 當 UnifiedWorkoutManager 完成載入後，重新載入本週 workouts
        NotificationCenter.default.publisher(for: .workoutsDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // 防止在初始化期間響應通知（避免重複載入）
                guard self.hasInitialized else {
                    Logger.debug("[TrainingPlanVM] 初始化期間跳過 workoutsDidUpdate 通知")
                    return
                }

                // 根據通知原因決定是否需要更新
                let reason = (notification.object as? [String: String])?["reason"] ?? "unknown"
                Logger.debug("[TrainingPlanVM] 收到 workoutsDidUpdate 通知，原因: \(reason)")

                switch reason {
                case "initial_cache", "initial_load":
                    // ✅ 初始載入時需要更新 UI（修復首次進入不顯示 workouts 的問題）
                    Logger.debug("[TrainingPlanVM] 初始載入通知，更新週 workouts")
                    Task {
                        await self.loadWorkoutsForCurrentWeek()
                    }

                case "background_update", "user_refresh", "new_workout_synced", "force_refresh", "background_refresh":
                    // 有新數據時更新週數據
                    Logger.debug("[TrainingPlanVM] 發現新運動數據，更新週 workouts")
                    Task {
                        await self.loadWorkoutsForCurrentWeek()
                    }

                default:
                    // 其他情況也更新（保持兼容性）
                    Logger.debug("[TrainingPlanVM] 未知通知原因，執行週 workouts 更新")
                    Task {
                        await self.loadWorkoutsForCurrentWeek()
                    }
                }
            }
            .store(in: &cancellables)

        // ✅ Clean Architecture: 訂閱 Onboarding 完成事件
        // 當用戶完成 Onboarding 時，清除所有緩存並強制重新載入數據
        CacheEventBus.shared.subscribe(for: "onboardingCompleted") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[TrainingPlanVM] 收到 onboardingCompleted 事件，重新載入所有數據")

            // 清除 Repository 緩存
            await self.repository.clearCache()

            // 重新載入所有數據
            await self.initialize()

            Logger.debug("[TrainingPlanVM] ✅ Onboarding 完成後數據重新載入完成")
        }

        // ✅ Clean Architecture: 訂閱用戶登出事件
        // 當用戶登出時，清除所有緩存並重置狀態
        CacheEventBus.shared.subscribe(for: "userLogout") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[TrainingPlanVM] 收到 userLogout 事件，清除所有緩存")

            // 清除 Repository 緩存
            await self.repository.clearCache()

            // 重置 UI 狀態
            await MainActor.run {
                self.planStatus = .loading
                self.planStatusResponse = nil
                self.workoutsByDayV2 = [:]
                self.currentWeekDistance = 0.0
                self.hasInitialized = false
            }

            Logger.debug("[TrainingPlanVM] ✅ 用戶登出後緩存已清除")
        }

        // ✅ Clean Architecture: 訂閱訓練計畫修改事件
        // 當訓練計畫被修改時（例如從 EditScheduleView），刷新週計畫
        CacheEventBus.shared.subscribe(for: "trainingPlanModified") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[TrainingPlanVM] 收到 trainingPlanModified 事件，刷新週計畫")

            // 強制刷新當前週計畫
            await self.weeklyPlanVM.refreshWeeklyPlan()

            // 重新載入本週的 workouts（可能受計畫修改影響）
            await self.loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanVM] ✅ 訓練計畫刷新完成")
        }

        // ✅ Clean Architecture: 訂閱目標更新事件
        // 當用戶修改訓練目標時，可能影響 VDOT 和配速建議
        CacheEventBus.shared.subscribe(for: "targetUpdated") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[TrainingPlanVM] 收到 targetUpdated 事件，刷新訓練概覽")

            // 刷新訓練概覽（可能包含新的目標信息）
            await self.weeklyPlanVM.loadOverview()

            // 重新載入計畫狀態
            await self.loadPlanStatus()

            Logger.debug("[TrainingPlanVM] ✅ 目標更新後數據已刷新")
        }

        // 監聽歷史週回顧列表狀態，更新 legacy properties
        summaryVM.$summariesState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.weeklySummaries = state.data ?? []
                self?.isLoadingWeeklySummaries = state.isLoading
            }
            .store(in: &cancellables)
    }

    /// 根據 ViewState 更新 PlanStatus
    private func updatePlanStatus(from state: ViewState<WeeklyPlan>) {
        switch state {
        case .loading:
            planStatus = .loading
        case .loaded(let plan):
            planStatus = .ready(plan)
        case .empty:
            planStatus = .noPlan
        case .error(let error):
            planStatus = .error(error as NSError)
        }
    }

    // MARK: - Public Methods - Initialization

    /// 初始化載入所有數據
    func initialize() async {
        Logger.debug("[TrainingPlanVM] Initializing...")

        // 顯示 loading 狀態
        planStatus = .loading

        // 步驟 1: 載入計畫狀態
        await loadPlanStatus()

        // 根據 plan status 決定下一步操作
        guard let response = planStatusResponse else {
            Logger.error("[TrainingPlanVM] No plan status response")
            planStatus = .noPlan
            return
        }

        // 步驟 2: 載入訓練概覽
        await weeklyPlanVM.loadOverview()

        // 步驟 3: 根據 nextAction 決定是否載入週計畫
        if response.nextAction == .viewPlan {
            await weeklyPlanVM.loadWeeklyPlan()

            // ✅ 關鍵修改：立即載入 workouts，在更新 planStatus 之前
            await loadWorkoutsForCurrentWeek()

            // ✅ 所有數據準備完畢後，手動更新 planStatus
            switch weeklyPlanVM.state {
            case .loaded(let plan):
                planStatus = .ready(plan)
                Logger.debug("[TrainingPlanVM] ✅ All data loaded, UI ready to display")
            case .error(let error):
                planStatus = .error(error as NSError)
                Logger.error("[TrainingPlanVM] ❌ Error loading plan: \(error.localizedDescription)")
            case .empty:
                planStatus = .noPlan
                Logger.debug("[TrainingPlanVM] No plan available")
            case .loading:
                // 理論上不應該到這裡，因為 loadWeeklyPlan() 是 async 的
                Logger.debug("[TrainingPlanVM] ⚠️ Still loading after loadWeeklyPlan() completed")
            }
        } else {
            // ✅ 如果不需要顯示計畫（例如需要產生週回顧），確保 weeklyPlanVM 狀態不是 loading
            // 否則 viewModel.isLoading 會一直為 true，導致按鈕無法點擊
            weeklyPlanVM.state = .empty
            planStatus = .noPlan
            Logger.debug("[TrainingPlanVM] No plan to view (nextAction: \(response.nextAction))")
        }

        // ✅ 標記初始化完成，允許通知監聽器開始響應
        hasInitialized = true
        Logger.debug("[TrainingPlanVM] ✅ 初始化完成，通知監聽器已啟用")
    }

    // MARK: - Plan Status

    /// 載入計畫狀態
    func loadPlanStatus(skipCache: Bool = false) async {
        Logger.debug("[TrainingPlanVM] Loading plan status (skipCache: \(skipCache))")

        do {
            let status = skipCache
                ? try await repository.refreshPlanStatus()
                : try await repository.getPlanStatus()

            planStatusResponse = status

            // 更新當前週數
            weeklyPlanVM.currentWeek = status.currentWeek
            weeklyPlanVM.selectedWeek = status.currentWeek

            // 更新訓練計畫名稱
            if let overview = weeklyPlanVM.overviewState.data {
                trainingPlanName = overview.trainingPlanName
            }

            // 🔍 [DEBUG] 詳細的 status API 回應日誌
            Logger.debug("========================================")
            Logger.debug("[TrainingPlanVM] 📊 Plan Status API 回應:")
            Logger.debug("  current_week: \(status.currentWeek)")
            Logger.debug("  total_weeks: \(status.totalWeeks)")
            Logger.debug("  next_action: \(status.nextAction)")
            Logger.debug("  can_generate_next_week: \(status.canGenerateNextWeek)")
            Logger.debug("  current_week_plan_id: \(status.currentWeekPlanId ?? "null")")
            Logger.debug("  previous_week_summary_id: \(status.previousWeekSummaryId ?? "null")")
            if let nextWeekInfo = status.nextWeekInfo {
                Logger.debug("  next_week_info:")
                Logger.debug("    - week_number: \(nextWeekInfo.weekNumber)")
                Logger.debug("    - has_plan: \(nextWeekInfo.hasPlan)")
                Logger.debug("    - can_generate: \(nextWeekInfo.canGenerate)")
                Logger.debug("    - requires_current_week_summary: \(nextWeekInfo.requiresCurrentWeekSummary)")
                Logger.debug("    - next_action: \(nextWeekInfo.nextAction)")
            } else {
                Logger.debug("  next_week_info: null")
            }
            Logger.debug("========================================")
        } catch {
            Logger.error("[TrainingPlanVM] Failed to load plan status: \(error.localizedDescription)")
            networkError = error
        }
    }

    // MARK: - Weekly Plan Actions

    /// 刷新週計畫（手動下拉）
    func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
        Logger.debug("[TrainingPlanVM] Refreshing weekly plan (manual: \(isManualRefresh))")

        // 顯示 loading 狀態
        planStatus = .loading

        // 刷新計畫狀態
        await loadPlanStatus(skipCache: isManualRefresh)

        // 刷新週計畫
        await weeklyPlanVM.refreshWeeklyPlan()

        // ✅ 刷新訓練記錄
        await loadWorkoutsForCurrentWeek()

        // ✅ 所有數據準備完畢後，手動更新 planStatus
        switch weeklyPlanVM.state {
        case .loaded(let plan):
            planStatus = .ready(plan)
            Logger.debug("[TrainingPlanVM] ✅ Weekly plan refreshed successfully")
        case .error(let error):
            planStatus = .error(error as NSError)
            Logger.error("[TrainingPlanVM] ❌ Error refreshing plan: \(error.localizedDescription)")
        case .empty:
            planStatus = .noPlan
            Logger.debug("[TrainingPlanVM] No plan available after refresh")
        case .loading:
            Logger.debug("[TrainingPlanVM] ⚠️ Still loading after refreshWeeklyPlan() completed")
        }
    }

    /// 產生下週課表
    func generateNextWeekPlan(targetWeek: Int) async {
        // 🔍 [DEBUG] Enhanced entry point logging
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 🎯 generateNextWeekPlan(targetWeek: \(targetWeek)) 被調用")
        Logger.debug("[TrainingPlanVM] currentWeek: \(currentWeek)")
        Logger.debug("[TrainingPlanVM] selectedWeek: \(selectedWeek)")
        Logger.debug("========================================")

        // ✅ 檢查是否需要先產生當前週回顧（根據 targetWeek 推算）
        // 如果要產生第7週課表，需要先檢查第6週週回顧是否存在
        let requiredSummaryWeek = targetWeek - 1

        // 嘗試獲取上週週回顧，如果不存在則先產生
        Logger.debug("[TrainingPlanVM] 檢查是否需要先產生第 \(requiredSummaryWeek) 週的週回顧")

        do {
            // ✅ 通過 Repository 檢查週回顧是否存在（符合 Clean Arch）
            _ = try await repository.getWeeklySummary(weekNumber: requiredSummaryWeek)
            Logger.debug("[TrainingPlanVM] 第 \(requiredSummaryWeek) 週週回顧已存在，直接產生課表")
        } catch {
            // 週回顧不存在，需要先產生
            Logger.debug("[TrainingPlanVM] 第 \(requiredSummaryWeek) 週週回顧不存在，先產生週回顧")

            // 設置待產生的目標週數
            summaryVM.pendingTargetWeek = targetWeek

            // 產生週回顧
            await summaryVM.createWeeklySummary(weekNumber: requiredSummaryWeek)

            // 檢查是否有調整項目需要確認
            if !summaryVM.pendingAdjustments.isEmpty {
                Logger.debug("[TrainingPlanVM] 有 \(summaryVM.pendingAdjustments.count) 個調整項目，等待用戶確認後再產生課表")
                isLoadingAnimation = false
                return
            }

            Logger.debug("[TrainingPlanVM] 週回顧已完成，無調整項目，繼續產生課表")
        }

        isLoadingAnimation = true

        await weeklyPlanVM.generateWeeklyPlan(targetWeek: targetWeek)

        // 刷新計畫狀態 (這會更新 weeklyPlanVM.currentWeek)
        await loadPlanStatus(skipCache: true)
        
        // ✅ 產生後需要載入該週的訓練記錄
        await loadWorkoutsForCurrentWeek()

        // ✅ 手動更新 planStatus，讓 UI 顯示新課表
        switch weeklyPlanVM.state {
        case .loaded(let plan):
            planStatus = .ready(plan)
            Logger.debug("[TrainingPlanVM] ✅ Next week plan ready")
        case .error(let error):
            planStatus = .error(error as NSError)
            Logger.error("[TrainingPlanVM] ❌ Failed to generate next week plan: \(error.localizedDescription)")
        case .empty:
            // 這種情況理論上不應發生在生成成功後
            planStatus = .noPlan
        case .loading:
            break
        }

        isLoadingAnimation = false

        if case .ready = planStatus {
            successToast = NSLocalizedString("training.plan_generated", comment: "Plan generated successfully")
        }
    }

    /// 產生下週課表（使用 NextWeekInfo）
    func generateNextWeekPlan(nextWeekInfo: NextWeekInfo) async {
        // ✅ 檢查是否需要先產生當前週回顧
        if nextWeekInfo.requiresCurrentWeekSummary {
            // 計算當前週數（下週週數 - 1）
            let currentWeek = nextWeekInfo.weekNumber - 1

            Logger.debug("[TrainingPlanVM] 需要先產生第 \(currentWeek) 週的週回顧")

            // 設置待產生的下週週數（必須在 createWeeklySummary 之前設置）
            summaryVM.pendingTargetWeek = nextWeekInfo.weekNumber

            // 產生當前週回顧
            await summaryVM.createWeeklySummary(weekNumber: currentWeek)

            // 週回顧創建後：
            // - 如果有調整項目 → 顯示調整確認 sheet → 確認後自動調用 confirmAdjustments → 產生下週課表
            // - 如果無調整項目 → 直接顯示週回顧 sheet，但週回顧已經產生完成，可以直接產生下週課表

            // ✅ 檢查是否有調整項目需要確認
            if !summaryVM.pendingAdjustments.isEmpty {
                Logger.debug("[TrainingPlanVM] 有 \(summaryVM.pendingAdjustments.count) 個調整項目，等待用戶確認")
                // 有調整項目，等待用戶確認後會自動產生下週課表
                return
            } else {
                Logger.debug("[TrainingPlanVM] 無調整項目，週回顧已完成，繼續產生第 \(nextWeekInfo.weekNumber) 週課表")
                // 無調整項目，直接產生下週課表
                await generateNextWeekPlan(targetWeek: nextWeekInfo.weekNumber)
                return
            }
        }

        // ✅ 無需週回顧，直接產生下週課表
        Logger.debug("[TrainingPlanVM] 本週回顧已完成，直接產生第 \(nextWeekInfo.weekNumber) 週課表")
        await generateNextWeekPlan(targetWeek: nextWeekInfo.weekNumber)
    }

    // MARK: - Business Logic Methods

    /// 決定下一個要產生的週數
    /// 根據當前狀態智能判斷應該產生哪一週的課表
    /// - Returns: 目標週數
    func determineNextPlanWeek() -> Int {
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 🧮 計算目標週數（Business Logic）")
        Logger.debug("[TrainingPlanVM] currentWeek: \(currentWeek)")
        Logger.debug("[TrainingPlanVM] pendingTargetWeek: \(summaryVM.pendingTargetWeek?.description ?? "nil")")
        Logger.debug("[TrainingPlanVM] current_week_plan_id: \(planStatusResponse?.currentWeekPlanId ?? "null")")

        let targetWeek: Int

        // 1. 如果有 pendingTargetWeek，使用它（來自 GenerateNextWeekButton 流程）
        if let pendingWeek = summaryVM.pendingTargetWeek {
            targetWeek = pendingWeek
            Logger.debug("[TrainingPlanVM] ✅ 決策邏輯 1: 使用 pendingTargetWeek = \(pendingWeek)")
        }
        // 2. 如果當前週課表不存在，產生當前週
        else if planStatusResponse?.currentWeekPlanId == nil {
            targetWeek = currentWeek
            Logger.debug("[TrainingPlanVM] ✅ 決策邏輯 2: 當前週課表不存在，產生當前週 = \(currentWeek)")
        }
        // 3. 當前週課表存在，產生下一週
        else {
            targetWeek = currentWeek + 1
            Logger.debug("[TrainingPlanVM] ✅ 決策邏輯 3: 當前週課表存在，產生下一週 = \(currentWeek + 1)")
        }

        Logger.debug("[TrainingPlanVM] 🎯 最終決定：targetWeek = \(targetWeek)")
        Logger.debug("========================================")

        return targetWeek
    }

    // MARK: - Weekly Summary Actions

    /// 創建週回顧
    func createWeeklySummary(weekNumber: Int? = nil) async {
        // 🔍 [DEBUG] Entry point logging
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 📝 createWeeklySummary(weekNumber: \(weekNumber?.description ?? "nil")) 被調用")
        Logger.debug("[TrainingPlanVM] currentWeek: \(currentWeek)")
        Logger.debug("[TrainingPlanVM] → 轉發到 summaryVM.createWeeklySummary")
        Logger.debug("========================================")

        await summaryVM.createWeeklySummary(weekNumber: weekNumber)
    }

    /// 重試創建週回顧
    func retryCreateWeeklySummary() async {
        await summaryVM.retryCreateWeeklySummary()
    }

    /// 清除週回顧
    func clearWeeklySummary() {
        // 🔍 [DEBUG] 週回顧關閉日誌
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 🔴 週回顧彈窗被關閉")
        Logger.debug("[TrainingPlanVM] 清除 summaryVM 狀態並刷新 plan status")
        Logger.debug("========================================")

        summaryVM.clearSummary()

        // ✅ 刷新計畫狀態，因為產生週回顧後 nextAction 可能已改變
        Task {
            await loadPlanStatus(skipCache: true)
            Logger.debug("[TrainingPlanVM] ✅ Plan status 已刷新（關閉週回顧後）")
        }
    }

    /// 獲取指定週回顧（Legacy Proxy）
    /// 實際上是調用 createWeeklySummary，如果存在則返回，不存在則創建
    func fetchWeeklySummary(weekNumber: Int) async {
        await summaryVM.createWeeklySummary(weekNumber: weekNumber)
    }

    /// 獲取所有週回顧（Legacy Proxy）
    func fetchWeeklySummaries() async {
        await summaryVM.loadWeeklySummaries()
    }

    // MARK: - Adjustment Actions

    /// 確認調整並產生下週課表
    func confirmAdjustments(_ selectedItems: [AdjustmentItem]) async {
        await summaryVM.confirmAdjustments(selectedItems)

        // 調整確認後，產生下週課表
        if let targetWeek = summaryVM.pendingTargetWeek {
            await generateNextWeekPlan(targetWeek: targetWeek)
        }
    }

    /// 確認調整並產生下週課表（同時執行）
    func confirmAdjustmentsAndGenerateNextWeek(targetWeek: Int) async {
        // 🔍 [DEBUG] Entry point logging
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 🔄 confirmAdjustmentsAndGenerateNextWeek(targetWeek: \(targetWeek)) 被調用")
        Logger.debug("[TrainingPlanVM] pendingAdjustments count: \(summaryVM.pendingAdjustments.count)")
        Logger.debug("========================================")

        // ✅ 先確認調整（如果有的話）
        if !summaryVM.pendingAdjustments.isEmpty {
            Logger.debug("[TrainingPlanVM] Confirming \(summaryVM.pendingAdjustments.count) adjustments before generating next week")
            await summaryVM.confirmAdjustments(summaryVM.pendingAdjustments)
        } else {
            Logger.debug("[TrainingPlanVM] No pending adjustments to confirm")
        }

        // ✅ 無論是否有調整，都要產生下週課表
        Logger.debug("[TrainingPlanVM] Generating next week plan for week \(targetWeek)")
        await generateNextWeekPlan(targetWeek: targetWeek)
    }

    /// 取消調整確認
    func cancelAdjustmentConfirmation() {
        summaryVM.cancelAdjustmentConfirmation()
    }

    // MARK: - Helper Methods

    /// 獲取上週日期範圍字串
    func getLastWeekRangeString() -> String {
        return summaryVM.getLastWeekRangeString()
    }

    /// 清除網路錯誤 Toast
    func clearNetworkErrorToast() {
        networkError = nil
    }

    /// 清除成功 Toast
    func clearSuccessToast() {
        successToast = nil
    }

    // MARK: - Computed Properties for View Bindings

    /// 當前週數
    var currentWeek: Int {
        return weeklyPlanVM.currentWeek
    }

    /// 是否正在載入
    var isLoading: Bool {
        return weeklyPlanVM.isLoading || summaryVM.isLoading
    }

    /// 週回顧（透過 summaryVM）
    var weeklySummary: WeeklyTrainingSummary? {
        return summaryVM.currentSummary
    }

    /// 是否正在載入週回顧
    var isLoadingWeeklySummary: Bool {
        return summaryVM.isGenerating
    }

    /// 週回顧錯誤
    var weeklySummaryError: Error? {
        return summaryVM.summaryError
    }

    /// 是否顯示週回顧 sheet（綁定到 summaryVM）
    var showWeeklySummary: Binding<Bool> {
        return Binding(
            get: { self.summaryVM.showSummarySheet },
            set: { self.summaryVM.showSummarySheet = $0 }
        )
    }

    /// 是否顯示調整確認 sheet（綁定到 summaryVM）
    var showAdjustmentConfirmation: Binding<Bool> {
        return Binding(
            get: { self.summaryVM.showAdjustmentConfirmation },
            set: { self.summaryVM.showAdjustmentConfirmation = $0 }
        )
    }

    /// 待確認的調整項目
    var pendingAdjustments: [AdjustmentItem] {
        return summaryVM.pendingAdjustments
    }

    /// 待確認的 summary ID
    var pendingSummaryId: String? {
        return summaryVM.pendingSummaryId
    }

    /// 待確認的目標週數
    var pendingTargetWeek: Int? {
        return summaryVM.pendingTargetWeek
    }

    /// 選擇的週數
    var selectedWeek: Int {
        get { return weeklyPlanVM.selectedWeek }
        set { weeklyPlanVM.selectedWeek = newValue }
    }

    /// 週計畫數據
    var weeklyPlan: WeeklyPlan? {
        return weeklyPlanVM.weeklyPlan
    }

    /// 訓練總覽
    var trainingOverview: TrainingPlanOverview? {
        return weeklyPlanVM.overviewState.data
    }

    /// 下週資訊
    var nextWeekInfo: NextWeekInfo? {
        return planStatusResponse?.nextWeekInfo
    }

    /// 成功訊息（用於 Toast 顯示）
    var successMessage: String {
        return successToast ?? ""
    }

    /// 是否顯示成功 Toast（Binding）
    var showSuccessToast: Binding<Bool> {
        return Binding(
            get: { self.successToast != nil },
            set: { if !$0 { self.successToast = nil } }
        )
    }

    // MARK: - Convenience Methods

    /// 載入週計畫（代理到 weeklyPlanVM）
    func loadWeeklyPlan() async {
        await weeklyPlanVM.loadWeeklyPlan()
    }

    /// 更新訓練計畫概覽（當賽事目標變更時調用）
    /// - Parameter overviewId: 概覽 ID
    /// - Returns: 更新後的訓練計畫概覽
    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        Logger.debug("[TrainingPlanVM] Updating overview: \(overviewId)")

        let updatedOverview = try await repository.updateOverview(overviewId: overviewId)

        // 更新本地狀態
        await weeklyPlanVM.loadOverview()

        // ✅ Clean Architecture: 發布事件讓其他模組知道 Overview 已更新
        CacheEventBus.shared.publish(.dataChanged(.trainingPlan))

        // 兼容性通知：同步發送 NotificationCenter 通知 (供舊組件及測試監聽)
        await MainActor.run {
            NotificationCenter.default.post(name: .trainingOverviewUpdated, object: updatedOverview)
        }

        Logger.debug("[TrainingPlanVM] ✅ Overview updated successfully")
        return updatedOverview
    }

    /// 重試網路請求
    func retryNetworkRequest() async {
        Logger.debug("[TrainingPlanVM] Retrying network request")
        await refreshWeeklyPlan(isManualRefresh: true)
    }

    // MARK: - Pace Calculation Properties (Legacy Proxy)

    /// 當前 VDOT 值
    var currentVDOT: Double? {
        // TODO: Get real VDOT from user profile
        return 45.0
    }

    /// 計算出的配速表
    var calculatedPaces: [PaceCalculator.PaceZone: String] {
        guard let vdot = currentVDOT else { return [:] }
        return PaceCalculator.calculateTrainingPaces(vdot: vdot)
    }

    /// 獲取建議配速
    func getSuggestedPace(for trainingType: String) -> String? {
        guard let vdot = currentVDOT else { return nil }
        return PaceCalculator.getSuggestedPace(for: trainingType, vdot: vdot)
    }

    /// 獲取配速區間範圍
    func getPaceRange(for trainingType: String) -> (min: String, max: String)? {
        guard let vdot = currentVDOT else { return nil }
        return PaceCalculator.getPaceRange(for: trainingType, vdot: vdot)
    }
}

// MARK: - PlanStatus Enum
/// 訓練計畫狀態（TrainingPlanView 使用）
enum PlanStatus: Equatable {
    case loading
    case noPlan        // 顯示「產生週回顧」按鈕
    case ready(WeeklyPlan)  // 顯示計畫內容
    case completed     // 顯示最後一週提示
    case error(Error)  // 顯示 ErrorView - 僅用於真實錯誤

    static func == (lhs: PlanStatus, rhs: PlanStatus) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.noPlan, .noPlan),
             (.completed, .completed):
            return true
        case (.ready(let lhsPlan), .ready(let rhsPlan)):
            return lhsPlan.id == rhsPlan.id
        case (.error, .error):
            return true // 簡化比較，不比較具體錯誤
        default:
            return false
        }
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 TrainingPlanViewModel 工廠
    @MainActor
    static func makeTrainingPlanViewModel() -> TrainingPlanViewModel {
        return TrainingPlanViewModel()
    }
}
