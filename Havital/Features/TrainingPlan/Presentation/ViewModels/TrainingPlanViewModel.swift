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
        return String(format: "%.1f", distance)
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

            Logger.debug("[TrainingPlanVM] Plan status loaded: week \(status.currentWeek)/\(status.totalWeeks)")
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
        Logger.debug("[TrainingPlanVM] Generating next week plan: \(targetWeek)")

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
        await generateNextWeekPlan(targetWeek: nextWeekInfo.weekNumber)
    }

    // MARK: - Weekly Summary Actions

    /// 創建週回顧
    func createWeeklySummary(weekNumber: Int? = nil) async {
        await summaryVM.createWeeklySummary(weekNumber: weekNumber)
    }

    /// 重試創建週回顧
    func retryCreateWeeklySummary() async {
        await summaryVM.retryCreateWeeklySummary()
    }

    /// 清除週回顧
    func clearWeeklySummary() {
        summaryVM.clearSummary()
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
