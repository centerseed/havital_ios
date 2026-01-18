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

    // MARK: - Memory Cache (Clean Architecture: ViewModel 層緩存)

    /// ✅ ViewModel 記憶體緩存：保存完整的 workout 列表
    /// 目的：避免每次都從 Repository 讀取，模仿重構前 UnifiedWorkoutManager 的行為
    /// 生命週期：與 ViewModel 相同（@StateObject 管理，不會被 iOS 清除）
    private var cachedAllWorkouts: [WorkoutV2] = []

    func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        return String(format: "%.0f", distance)
    }

    /// 獲取指定週計畫（Legacy Proxy）
    func fetchWeekPlan(week: Int) async {
        Logger.debug("[TrainingPlanVM] Fetching week plan for week \(week)")

        // 顯示 loading 狀態
        planStatus = .loading

        // ✅ 修復：先刷新 plan status 以更新 currentWeek，避免 selectWeek 的 guard 失敗
        // 這確保了 weeklyPlanVM.currentWeek 反映最新的週數
        Logger.debug("[TrainingPlanVM] 先刷新 plan status 以確保 currentWeek 正確")
        await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)

        // 切換週次
        await weeklyPlanVM.selectWeek(week)

        // ✅ 切換週次後，重新載入訓練記錄
        await loadWorkoutsForCurrentWeek()

        // ✅ 所有數據準備完畢後，使用 helper 更新 planStatus
        updatePlanStatus(from: weeklyPlanVM.state)
        Logger.debug("[TrainingPlanVM] ✅ Week \(week) plan status updated")
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

        // ✅ 修復：使用 selectedWeek 而非 currentWeek，以顯示正確的週日期
        // 配合 trainingOverview.createdAt（計畫起始日期）計算實際日期範圍
        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            Logger.error("[TrainingPlanVM] Failed to calculate week date info for week \(selectedWeek)")
            return nil
        }

        let date = weekInfo.daysMap[dayIndex]
        Logger.debug("[TrainingPlanVM] getDateForDay(\(dayIndex)) for week \(selectedWeek) -> \(date?.description ?? "nil")")
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

    /// 強制從 API 刷新 workout 數據（用於 App 從背景回到前景時）
    /// ✅ 修復：重構後遺失的 API 刷新邏輯（重構前由 UnifiedWorkoutManager.refreshWorkouts() 處理）
    /// - Returns: 是否刷新成功
    @discardableResult
    func forceRefreshWorkouts() async -> Bool {
        Logger.debug("[TrainingPlanVM] forceRefreshWorkouts - 強制從 API 刷新 workout 數據")

        do {
            // ✅ 從 API 獲取最新數據並更新緩存
            let workouts = try await workoutRepository.refreshWorkouts()
            Logger.debug("[TrainingPlanVM] ✅ 強制刷新完成，獲得 \(workouts.count) 筆記錄")

            // ✅ Clean Architecture: 更新 ViewModel 記憶體緩存（關鍵修復！）
            await MainActor.run {
                self.cachedAllWorkouts = workouts
            }
            Logger.debug("[TrainingPlanVM] ✅ 記憶體緩存已更新，共 \(workouts.count) 筆記錄")

            // ✅ 手動發送通知，確保所有訂閱者收到更新
            // （修復：Repository 層目前沒有發送通知，我們在這裡補上）
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .workoutsDidUpdate,
                    object: ["reason": "force_refresh", "count": workouts.count]
                )
            }

            Logger.debug("[TrainingPlanVM] ✅ 已發送 .workoutsDidUpdate 通知")
            return true

        } catch is CancellationError {
            Logger.debug("[TrainingPlanVM] 強制刷新任務被取消")
            return false
        } catch {
            Logger.error("[TrainingPlanVM] ⚠️ 強制刷新失敗: \(error.localizedDescription)")
            Logger.error("[TrainingPlanVM] 錯誤詳情: \(error)")

            // ✅ API 失敗時，使用 Stale-While-Revalidate 策略
            // LocalDataSource 已修改為即使過期也返回舊數據
            Logger.debug("[TrainingPlanVM] 將使用緩存的舊數據（如果存在）")
            return false
        }
    }

    /// 刷新記憶體緩存（從 Repository 載入所有 workouts）
    /// ✅ Clean Architecture: 當收到外部通知時，重新載入記憶體緩存
    private func refreshMemoryCache() async {
        Logger.debug("[TrainingPlanVM] refreshMemoryCache - 從 Repository 載入所有 workouts")

        do {
            let workouts = try await workoutRepository.getAllWorkouts()

            await MainActor.run {
                self.cachedAllWorkouts = workouts
            }

            Logger.debug("[TrainingPlanVM] ✅ 記憶體緩存已更新，共 \(workouts.count) 筆記錄")
        } catch {
            Logger.error("[TrainingPlanVM] ❌ 刷新記憶體緩存失敗: \(error.localizedDescription)")
            // 不清空緩存，保留舊數據
        }
    }

    /// 載入當前週的訓練記錄（使用 Use Case）
    func loadWorkoutsForCurrentWeek() async {
        await MainActor.run {
            isLoadingWorkouts = true
        }

        // ✅ 診斷日誌：檢查依賴數據狀態
        Logger.debug("[TrainingPlanVM] loadWorkoutsForCurrentWeek - selectedWeek: \(selectedWeek)")
        Logger.debug("[TrainingPlanVM] loadWorkoutsForCurrentWeek - trainingOverview: \(trainingOverview != nil ? "✅ 存在" : "❌ nil")")
        Logger.debug("[TrainingPlanVM] loadWorkoutsForCurrentWeek - cachedAllWorkouts: \(cachedAllWorkouts.count) 筆")

        if let overview = trainingOverview {
            Logger.debug("[TrainingPlanVM] loadWorkoutsForCurrentWeek - overview.id: \(overview.id), createdAt: \(overview.createdAt)")
        }

        // 使用 selectedWeek 確保日期範圍與顯示的週計畫對齊
        guard let overview = trainingOverview,
              let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            Logger.error("[TrainingPlanVM] ❌ Failed to calculate week dates - trainingOverview 是 nil 或 weekInfo 計算失敗")
            Logger.error("[TrainingPlanVM] 當前狀態診斷：")
            Logger.error("[TrainingPlanVM]   - trainingOverview: \(trainingOverview == nil ? "nil" : "存在")")
            Logger.error("[TrainingPlanVM]   - selectedWeek: \(selectedWeek)")
            Logger.error("[TrainingPlanVM]   - weeklyPlanVM.overviewState: \(weeklyPlanVM.overviewState)")
            await MainActor.run { isLoadingWorkouts = false }
            return
        }

        Logger.debug("[TrainingPlanVM] Loading workouts from \(weekInfo.startDate) to \(weekInfo.endDate)")

        // ✅ Clean Architecture: 優先從 ViewModel 記憶體緩存獲取（模仿重構前行為）
        if !cachedAllWorkouts.isEmpty {
            Logger.debug("[TrainingPlanVM] 使用記憶體緩存過濾 workouts（模仿 UnifiedWorkoutManager）")
            let grouped = groupWorkoutsByDay(cachedAllWorkouts, weekInfo: weekInfo)

            await MainActor.run {
                self.workoutsByDayV2 = grouped
                self.isLoadingWorkouts = false
                self.objectWillChange.send()
            }

            Logger.debug("[TrainingPlanVM] 從記憶體緩存分組完成: \(grouped.keys.sorted())")
            await loadCurrentWeekMetrics()
            return
        }

        // ✅ 記憶體緩存為空時，從 Repository 載入
        Logger.debug("[TrainingPlanVM] 記憶體緩存為空，從 Repository 載入")
        let grouped = await loadWeeklyWorkoutsUseCase.execute(weekInfo: weekInfo)

        await MainActor.run {
            self.workoutsByDayV2 = grouped
            self.isLoadingWorkouts = false
            self.objectWillChange.send()
        }

        Logger.debug("[TrainingPlanVM] Grouped workouts: \(grouped.keys.sorted())")

        // 載入完成後，計算週跑量和強度分布
        await loadCurrentWeekMetrics()
    }

    /// 輔助方法：按天分組 workouts（從記憶體緩存過濾）
    private func groupWorkoutsByDay(_ workouts: [WorkoutV2], weekInfo: WeekDateInfo) -> [Int: [WorkoutV2]] {
        let calendar = Calendar.current
        let activityTypes: Set<String> = ["running", "walking", "hiking", "cross_training"]

        var grouped: [Int: [WorkoutV2]] = [:]

        for workout in workouts {
            // 過濾運動類型
            guard activityTypes.contains(workout.activityType) else {
                continue
            }

            // 檢查是否在週範圍內
            guard workout.startDate >= weekInfo.startDate && workout.startDate <= weekInfo.endDate else {
                continue
            }

            // 找到對應的 dayIndex
            var dayIndex: Int?
            for (index, dateInWeek) in weekInfo.daysMap {
                if calendar.isDate(workout.startDate, inSameDayAs: dateInWeek) {
                    dayIndex = index
                    break
                }
            }

            guard let dayIndex = dayIndex else { continue }

            if grouped[dayIndex] == nil {
                grouped[dayIndex] = []
            }
            grouped[dayIndex]?.append(workout)
        }

        // 排序
        for (dayIndex, workouts) in grouped {
            grouped[dayIndex] = workouts.sorted { $0.endDate > $1.endDate }
        }

        return grouped
    }

    /// 載入當前週的訓練指標（距離和強度）
    private func loadCurrentWeekMetrics() async {
        guard let overview = trainingOverview,
              let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            Logger.error("[TrainingPlanVM] Failed to calculate week dates for metrics")
            return
        }

        Logger.debug("[TrainingPlanVM] Calculating metrics for week \(selectedWeek)")

        // ✅ 使用 Use Case 計算訓練指標（async 版本）
        let metrics = await aggregateWorkoutMetricsUseCase.execute(weekInfo: weekInfo)

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

    /// 獲取當前選擇週的起始日期（週一）
    func getWeekStartDate() -> Date? {
        guard let overview = trainingOverview else {
            return nil
        }

        // ✅ 修復：使用 selectedWeek 而非 currentWeek，以取得正確的週起始日期
        guard let weekInfo = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: selectedWeek) else {
            return nil
        }

        return weekInfo.startDate
    }

    // MARK: - Dependencies

    private let repository: TrainingPlanRepository
    private let workoutRepository: WorkoutRepository
    private let loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase
    private let aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase

    // MARK: - Subscribers

    private var cancellables = Set<AnyCancellable>()

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    init(
        repository: TrainingPlanRepository,
        workoutRepository: WorkoutRepository,
        loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase,
        aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase,
        weeklyPlanVM: WeeklyPlanViewModel? = nil,
        summaryVM: WeeklySummaryViewModel? = nil
    ) {
        self.repository = repository
        self.workoutRepository = workoutRepository
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
        let workoutRepository: WorkoutRepository = container.resolve()
        let loadWeeklyWorkoutsUseCase = container.makeLoadWeeklyWorkoutsUseCase()
        let aggregateWorkoutMetricsUseCase = container.makeAggregateWorkoutMetricsUseCase()

        self.init(
            repository: repository,
            workoutRepository: workoutRepository,
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

        // ✅ 關鍵修復：監聽 weeklyPlanVM.selectedWeek 變更
        // 當 selectedWeek 變更時，需要觸發 objectWillChange 讓 UI 重新渲染
        // 否則 getDateForDay() 等使用 selectedWeek 的計算屬性不會更新顯示
        weeklyPlanVM.$selectedWeek
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newWeek in
                guard let self = self else { return }
                Logger.debug("[TrainingPlanVM] selectedWeek 變更為 \(newWeek)，觸發 UI 更新")
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        // ✅ 關鍵修復：監聽 summaryVM.showSummarySheet 變更
        // 當 showSummarySheet 變更時，需要觸發 objectWillChange 讓 UI 重新渲染
        summaryVM.$showSummarySheet
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showSheet in
                guard let self = self else { return }
                Logger.debug("[TrainingPlanVM] showSummarySheet 變更為 \(showSheet)，觸發 UI 更新")
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        // ✅ 關鍵修復：監聽 summaryVM.summaryState 變更
        // 當 summaryState 變更時（載入完成），需要觸發 objectWillChange 讓 UI 重新渲染
        summaryVM.$summaryState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                Logger.debug("[TrainingPlanVM] summaryState 變更為 \(state.isLoading ? "loading" : state.hasData ? "loaded" : "empty")，觸發 UI 更新")
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

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
                    Logger.debug("[TrainingPlanVM] 初始載入通知，更新記憶體緩存和週 workouts")
                    Task {
                        // ✅ 從 Repository 重新載入數據到記憶體緩存
                        await self.refreshMemoryCache()
                        await self.loadWorkoutsForCurrentWeek()
                    }

                case "background_update", "user_refresh", "new_workout_synced", "background_refresh":
                    // 有新數據時更新記憶體緩存和週數據
                    Logger.debug("[TrainingPlanVM] 發現新運動數據，更新記憶體緩存和週 workouts")
                    Task {
                        await self.refreshMemoryCache()
                        await self.loadWorkoutsForCurrentWeek()
                    }

                case "force_refresh":
                    // ✅ force_refresh 已經在 forceRefreshWorkouts() 中更新了緩存，只需要重新載入本週數據
                    Logger.debug("[TrainingPlanVM] force_refresh 通知，記憶體緩存已更新，重新載入週 workouts")
                    Task {
                        await self.loadWorkoutsForCurrentWeek()
                    }

                default:
                    // 其他情況也更新（保持兼容性）
                    Logger.debug("[TrainingPlanVM] 未知通知原因，執行記憶體緩存和週 workouts 更新")
                    Task {
                        await self.refreshMemoryCache()
                        await self.loadWorkoutsForCurrentWeek()
                    }
                }
            }
            .store(in: &cancellables)

        // ✅ Clean Architecture: 訂閱 Onboarding 完成事件
        // 當用戶完成 Onboarding 時，清除所有緩存並強制重新載入數據
        subscribeToEvent("onboardingCompleted") {
            await self.repository.clearCache()
            await MainActor.run {
                self.cachedAllWorkouts = []
                self.hasInitialized = false
            }
            await self.initialize()
        }

        // ✅ Clean Architecture: 訂閱用戶登出事件
        // 當用戶登出時，清除所有緩存並重置狀態
        subscribeToEvent("userLogout") {
            await self.repository.clearCache()
            await MainActor.run {
                self.cachedAllWorkouts = []
                self.planStatus = .loading
                self.planStatusResponse = nil
                self.workoutsByDayV2 = [:]
                self.currentWeekDistance = 0.0
                self.hasInitialized = false
            }
        }

        // ✅ Clean Architecture: 訂閱訓練計畫修改事件
        // 當訓練計畫被修改時（例如從 EditScheduleView），刷新週計畫
        subscribeToEvent("dataChanged.trainingPlan") {
            await self.weeklyPlanVM.refreshWeeklyPlan()
            await self.loadWorkoutsForCurrentWeek()
        }

        // ✅ Clean Architecture: 訂閱目標更新事件
        // 當用戶修改訓練目標時，可能影響 VDOT 和配速建議
        subscribeToEvent("targetUpdated") {
            await self.weeklyPlanVM.loadOverview()
            await self.loadPlanStatus()
        }

        // ✅ Clean Architecture: 訂閱用戶登入事件
        // 當用戶登入時（已完成 onboarding 的用戶），重新初始化所有數據
        // 修復：登出再登入後 workouts 不顯示的問題
        subscribeToEvent("dataChanged.user") {
            await self.repository.clearCache()
            await MainActor.run {
                self.cachedAllWorkouts = []
                self.hasInitialized = false
            }
            await self.initialize()
        }

        // 監聯歷史週回顧列表狀態，更新 legacy properties
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

    /// Subscribe to CacheEventBus event with standardized logging
    ///
    /// This helper reduces boilerplate in event subscription blocks by:
    /// - Standardizing weak self capture
    /// - Adding consistent debug logging
    /// - Ensuring proper async execution
    ///
    /// - Parameters:
    ///   - eventName: Event identifier string
    ///   - action: Async closure to execute when event fires
    private func subscribeToEvent(
        _ eventName: String,
        action: @escaping () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: eventName) { [weak self] in
            guard let self = self else { return }

            Logger.debug("[TrainingPlanVM] 收到 \(eventName) 事件")
            await action()
            Logger.debug("[TrainingPlanVM] ✅ \(eventName) 事件處理完成")
        }
    }

    // MARK: - Public Methods - Initialization

    /// 初始化載入所有數據
    /// - Parameter force: 是否強制重新初始化（用於 App 從背景回來時）
    func initialize(force: Bool = false) async {
        // 防止重複初始化（除非強制）
        guard force || !hasInitialized else {
            Logger.debug("[TrainingPlanVM] ⚠️ Already initialized, skipping")
            return
        }

        Logger.debug("[TrainingPlanVM] 🚀 Starting initialization\(force ? " (FORCED)" : "")...")

        // 顯示 loading 狀態
        planStatus = .loading

        // ✅ Clean Architecture: 步驟 0 - 確保 Workout 數據已載入
        // 使用 WorkoutRepository 刷新數據，確保保存到 WorkoutLocalDataSource
        // 這樣 LoadWeeklyWorkoutsUseCase 才能讀取到正確的數據
        Logger.debug("[TrainingPlanVM] Step 0: Ensuring workout data is loaded...")
        do {
            let workouts = try await workoutRepository.refreshWorkouts()

            // ✅ Clean Architecture: 保存到 ViewModel 記憶體緩存（模仿重構前 UnifiedWorkoutManager）
            await MainActor.run {
                self.cachedAllWorkouts = workouts
            }

            Logger.debug("[TrainingPlanVM] ✅ Workout data refreshed via WorkoutRepository, cached \(workouts.count) workouts")
        } catch {
            Logger.error("[TrainingPlanVM] ⚠️ Failed to refresh workouts: \(error.localizedDescription)")

            // ✅ API 失敗時，嘗試從 Repository 讀取緩存
            do {
                let cachedWorkouts = try await workoutRepository.getAllWorkouts()
                await MainActor.run {
                    self.cachedAllWorkouts = cachedWorkouts
                }
                Logger.debug("[TrainingPlanVM] ✅ Loaded \(cachedWorkouts.count) workouts from cache")
            } catch {
                Logger.error("[TrainingPlanVM] ❌ Failed to load cached workouts: \(error.localizedDescription)")
                // 繼續流程，cachedAllWorkouts 保持為空
            }
        }

        // 步驟 1: 載入計畫狀態
        Logger.debug("[TrainingPlanVM] Step 1: Loading plan status...")
        // ✅ 初始化時重置 selectedWeek 到 currentWeek
        await loadPlanStatus(shouldResetSelectedWeek: true)

        // 根據 plan status 決定下一步操作
        guard let response = planStatusResponse else {
            Logger.error("[TrainingPlanVM] ❌ No plan status response")
            planStatus = .noPlan
            return
        }
        Logger.debug("[TrainingPlanVM] ✅ Plan status loaded: nextAction=\(response.nextAction)")

        // 步驟 2: 載入訓練概覽
        Logger.debug("[TrainingPlanVM] Step 2: Loading training overview...")
        await weeklyPlanVM.loadOverview()

        // 驗證 overview 已載入
        if let overview = trainingOverview {
            Logger.debug("[TrainingPlanVM] ✅ Training overview loaded: id=\(overview.id)")
        } else {
            Logger.error("[TrainingPlanVM] ❌ Training overview is nil after loadOverview()")
        }

        // 步驟 3: 根據 nextAction 決定是否載入週計畫
        if response.nextAction == .viewPlan {
            Logger.debug("[TrainingPlanVM] Step 3: Loading weekly plan...")
            await weeklyPlanVM.loadWeeklyPlan()

            // ✅ 關鍵修改：立即載入 workouts，在更新 planStatus 之前
            Logger.debug("[TrainingPlanVM] Step 4: Loading workouts for current week...")
            await loadWorkoutsForCurrentWeek()
            Logger.debug("[TrainingPlanVM] ✅ Workouts loaded: \(workoutsByDayV2.values.flatMap { $0 }.count) workouts")

            // ✅ 所有數據準備完畢後，使用 helper 更新 planStatus
            updatePlanStatus(from: weeklyPlanVM.state)
            Logger.debug("[TrainingPlanVM] ✅ All data loaded, UI ready to display")
        } else if response.nextAction == .trainingCompleted {
            // ✅ 訓練計畫已完成，顯示最後一週提示
            weeklyPlanVM.state = .empty
            planStatus = .completed
            Logger.debug("[TrainingPlanVM] Training completed (nextAction: training_completed)")
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

        // ✅ 修復競態條件：主動重新載入 workouts
        // 因為 .workoutsDidUpdate 通知可能在 hasInitialized = true 之前就到達並被跳過
        // 此時 UnifiedWorkoutManager.workouts 應該已經有數據了
        if response.nextAction == .viewPlan {
            Logger.debug("[TrainingPlanVM] Step 5: Re-loading workouts to fix race condition...")
            await loadWorkoutsForCurrentWeek()
            Logger.debug("[TrainingPlanVM] ✅ 競態條件修復：重新載入 workouts 完成，total=\(workoutsByDayV2.values.flatMap { $0 }.count)")
        }
    }

    // MARK: - Plan Status

    /// 載入計畫狀態
    func loadPlanStatus(skipCache: Bool = false, shouldResetSelectedWeek: Bool = false) async {
        Logger.debug("[TrainingPlanVM] Loading plan status (skipCache: \(skipCache), shouldResetSelectedWeek: \(shouldResetSelectedWeek))")

        do {
            let status = skipCache
                ? try await repository.refreshPlanStatus()
                : try await repository.getPlanStatus()

            planStatusResponse = status

            // 更新當前週數
            let oldCurrentWeek = weeklyPlanVM.currentWeek
            weeklyPlanVM.currentWeek = status.currentWeek
            Logger.debug("[TrainingPlanVM] ✅ currentWeek 更新: \(oldCurrentWeek) → \(status.currentWeek)")

            // ✅ 修復：只在必要時才重置 selectedWeek，避免覆蓋用戶手動選擇的週數
            // 只有在明確要求重置（例如初始化）時才更新 selectedWeek
            if shouldResetSelectedWeek {
                weeklyPlanVM.selectedWeek = status.currentWeek
                Logger.debug("[TrainingPlanVM] selectedWeek reset to currentWeek: \(status.currentWeek)")
            } else {
                Logger.debug("[TrainingPlanVM] selectedWeek preserved: \(weeklyPlanVM.selectedWeek)")
            }

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
        } catch is CancellationError {
            Logger.debug("[TrainingPlanVM] Plan status loading cancelled")
        } catch {
            Logger.error("[TrainingPlanVM] Failed to load plan status: \(error.localizedDescription)")
            networkError = error
        }
    }

    // MARK: - Weekly Plan Actions

    /// 刷新週計畫（手動下拉）
    func refreshWeeklyPlan(isManualRefresh: Bool = false) async {
        Logger.debug("[TrainingPlanVM] Refreshing weekly plan (manual: \(isManualRefresh))")

        // ✅ 雙軌緩存策略：只有在無數據時才顯示 loading（避免閃爍）
        let hasData = weeklyPlanVM.state.data != nil
        if !hasData {
            planStatus = .loading
        }

        // 刷新計畫狀態
        await loadPlanStatus(skipCache: isManualRefresh)

        // 刷新週計畫（靜默模式，不顯示 loading）
        await weeklyPlanVM.refreshWeeklyPlan(silent: true)

        // ✅ 刷新訓練記錄
        await loadWorkoutsForCurrentWeek()

        // ✅ 所有數據準備完畢後，使用 helper 更新 planStatus
        updatePlanStatus(from: weeklyPlanVM.state)
        Logger.debug("[TrainingPlanVM] ✅ Weekly plan refreshed (manual: \(isManualRefresh), hadData: \(hasData))")
    }

    /// 產生下週課表
    /// - Parameter forceGenerate: 是否強制產生課表（跳過週回顧顯示）。從週回顧 sheet 點擊按鈕時應設為 true
    func generateNextWeekPlan(targetWeek: Int, forceGenerate: Bool = false) async {
        // 🔍 [DEBUG] Enhanced entry point logging
        Logger.debug("========================================")
        Logger.debug("[TrainingPlanVM] 🎯 generateNextWeekPlan(targetWeek: \(targetWeek), forceGenerate: \(forceGenerate)) 被調用")
        Logger.debug("[TrainingPlanVM] currentWeek: \(currentWeek)")
        Logger.debug("[TrainingPlanVM] selectedWeek: \(selectedWeek)")
        Logger.debug("========================================")

        // ✅ 如果是從週回顧 sheet 點擊的「產生下週課表」按鈕，直接產生課表
        if forceGenerate {
            Logger.debug("[TrainingPlanVM] forceGenerate=true，跳過週回顧檢查，直接產生課表")
        } else {
            // ✅ 檢查是否需要先產生週回顧
            // 後端會自動根據 targetWeek 減1來產生對應的週回顧
            // 例如：要產生第7週課表，傳入 targetWeek=7，後端會自動產生第6週的週回顧
            let requiredSummaryWeek = targetWeek - 1

            // 嘗試獲取週回顧，如果不存在則先產生
            Logger.debug("[TrainingPlanVM] 檢查是否需要先產生第 \(requiredSummaryWeek) 週的週回顧")

            do {
                // ✅ 通過 Repository 檢查週回顧是否存在（符合 Clean Arch）
                let existingSummary = try await repository.getWeeklySummary(weekNumber: requiredSummaryWeek)
                Logger.debug("[TrainingPlanVM] 第 \(requiredSummaryWeek) 週週回顧已存在")

                // ✅ 修復：即使週回顧已存在，也要先顯示給用戶查看
                // 載入週回顧並顯示 sheet
                summaryVM.summaryState = .loaded(existingSummary)
                summaryVM.pendingTargetWeek = targetWeek

                // 檢查並保存調整項目（如果有的話）
                if let adjustments = existingSummary.nextWeekAdjustments.items, !adjustments.isEmpty {
                    summaryVM.pendingAdjustments = adjustments
                    summaryVM.pendingSummaryId = existingSummary.id
                    Logger.debug("[TrainingPlanVM] 有 \(adjustments.count) 個調整項目，先顯示週回顧")
                }

                // 顯示週回顧 sheet
                summaryVM.showSummarySheet = true
                Logger.debug("[TrainingPlanVM] 顯示週回顧給用戶查看")
                isLoadingAnimation = false
                return
            } catch {
                // 週回顧不存在，需要先產生
                Logger.debug("[TrainingPlanVM] 第 \(requiredSummaryWeek) 週週回顧不存在，先產生週回顧")
                Logger.debug("[TrainingPlanVM] 傳入 targetWeek=\(targetWeek)，後端會自動減1產生第 \(requiredSummaryWeek) 週的週回顧")

                // 設置待產生的目標週數
                summaryVM.pendingTargetWeek = targetWeek

                // ✅ 產生週回顧：直接傳入 targetWeek，後端會自動減1
                await summaryVM.createWeeklySummary(weekNumber: targetWeek)

                // 檢查是否有調整項目需要確認
                if !summaryVM.pendingAdjustments.isEmpty {
                    Logger.debug("[TrainingPlanVM] 有 \(summaryVM.pendingAdjustments.count) 個調整項目，等待用戶確認後再產生課表")
                    isLoadingAnimation = false
                    return
                }

                // ✅ 修復：週回顧剛產生時，應該先讓用戶查看，不要自動產生課表
                // 用戶需要從週回顧 sheet 中點擊「產生下週課表」按鈕來手動觸發
                Logger.debug("[TrainingPlanVM] 週回顧已完成，無調整項目，等待用戶查看並手動產生課表")
                isLoadingAnimation = false
                return
            }
        }

        isLoadingAnimation = true

        // ✅ 先設置 selectedWeek 為目標週數，確保日期計算使用正確的週數
        weeklyPlanVM.selectedWeek = targetWeek
        Logger.debug("[TrainingPlanVM] 設置 selectedWeek = \(targetWeek)")

        // ✅ 產生週計畫並載入到 state（generateWeeklyPlan 會設置 state = .loaded(新計畫)）
        await weeklyPlanVM.generateWeeklyPlan(targetWeek: targetWeek)
        Logger.debug("[TrainingPlanVM] 產生第 \(targetWeek) 週計畫完成")

        // 刷新計畫狀態（這會更新 weeklyPlanVM.currentWeek）
        await loadPlanStatus(skipCache: true, shouldResetSelectedWeek: false)

        // ✅ 載入該週的訓練記錄
        // getDateForDay() 使用 trainingOverview.createdAt + selectedWeek 計算正確的日期範圍
        await loadWorkoutsForCurrentWeek()

        // ✅ 使用 helper 更新 planStatus，讓 UI 顯示新課表
        updatePlanStatus(from: weeklyPlanVM.state)
        Logger.debug("[TrainingPlanVM] ✅ Next week plan status updated")

        isLoadingAnimation = false

        if case .ready = planStatus {
            successToast = L10n.Success.planGenerated.localized
        }
    }

    /// 產生下週課表（使用 NextWeekInfo）
    func generateNextWeekPlan(nextWeekInfo: NextWeekInfo) async {
        // ✅ 檢查是否需要先產生當前週回顧
        if nextWeekInfo.requiresCurrentWeekSummary {
            // ✅ 直接傳入下週週數，後端會自動減1產生當前週的週回顧
            // 例如：nextWeekInfo.weekNumber = 4，後端收到後減1，產生第3週的週回顧
            Logger.debug("[TrainingPlanVM] 需要先產生週回顧（傳入 weekNumber: \(nextWeekInfo.weekNumber)，後端會自動減1）")

            // 設置待產生的下週週數（必須在 createWeeklySummary 之前設置）
            summaryVM.pendingTargetWeek = nextWeekInfo.weekNumber

            // 產生當前週回顧（後端會自動減1）
            await summaryVM.createWeeklySummary(weekNumber: nextWeekInfo.weekNumber)

            // 週回顧創建後：
            // - 如果有調整項目 → 顯示調整確認 sheet → 確認後自動調用 confirmAdjustments → 產生下週課表
            // - 如果無調整項目 → 直接顯示週回顧 sheet，但週回顧已經產生完成，可以直接產生下週課表

            // ✅ 檢查是否有調整項目需要確認
            if !summaryVM.pendingAdjustments.isEmpty {
                Logger.debug("[TrainingPlanVM] 有 \(summaryVM.pendingAdjustments.count) 個調整項目，等待用戶確認")
                // 有調整項目，等待用戶確認後會自動產生下週課表
                return
            } else {
                Logger.debug("[TrainingPlanVM] 無調整項目，週回顧已完成，顯示給用戶查看")
                // ✅ 修復：只顯示週回顧，不自動產生下週課表
                // 用戶需要從週回顧 sheet 中點擊「產生下週課表」按鈕來手動觸發
                // 這樣才能確保用戶有機會查看週回顧內容
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
        Logger.debug("[TrainingPlanVM] 檢查是否有待處理的調整項目")
        Logger.debug("========================================")

        // ✅ 修復：檢查是否有待處理的調整項目
        // 如果有，在關閉週回顧後自動顯示調整確認 sheet
        let hasPendingAdjustments = !summaryVM.pendingAdjustments.isEmpty

        if hasPendingAdjustments {
            Logger.debug("[TrainingPlanVM] 有 \(summaryVM.pendingAdjustments.count) 個待處理的調整項目，顯示調整確認 sheet")
            // 關閉週回顧 sheet
            summaryVM.clearSummary()
            // 延遲一點顯示調整確認 sheet，避免 sheet 切換衝突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.summaryVM.showAdjustmentConfirmation = true
            }
        } else {
            Logger.debug("[TrainingPlanVM] 無待處理的調整項目，直接清除 summaryVM 狀態")
            summaryVM.clearSummary()
        }

        // ✅ 刷新計畫狀態，因為產生週回顧後 nextAction 可能已改變
        Task {
            await loadPlanStatus(skipCache: true)
            Logger.debug("[TrainingPlanVM] ✅ Plan status 已刷新（關閉週回顧後）")
        }
    }

    /// 獲取指定週回顧（Legacy Proxy）
    /// 用於查看已存在的歷史週回顧
    func fetchWeeklySummary(weekNumber: Int) async {
        await summaryVM.loadWeeklySummary(weekNumber: weekNumber)
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
        // ✅ 從週回顧/調整確認流程調用，設置 forceGenerate=true 跳過週回顧檢查
        Logger.debug("[TrainingPlanVM] Generating next week plan for week \(targetWeek) (forceGenerate=true)")
        await generateNextWeekPlan(targetWeek: targetWeek, forceGenerate: true)
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
