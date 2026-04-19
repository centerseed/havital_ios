import Foundation
import Observation

// MARK: - WeeklyPlanLoader

/// Owns all data-loading state for the training plan.
/// The parent TrainingPlanV2ViewModel keeps only orchestration state
/// (toasts, paywall, generator methods) and delegates all loading here.
@MainActor
@Observable
final class WeeklyPlanLoader {

    // MARK: - Observable State

    var planStatus: PlanStatusV2 = .loading
    var planStatusResponse: PlanStatusV2Response?
    var planOverview: PlanOverviewV2?
    var weeklyPlan: WeeklyPlanV2?
    var currentWeek: Int = 1
    var selectedWeek: Int = 1
    var trainingPlanName: String = "訓練計畫"
    var weeklyPreview: WeeklyPreviewV2?
    var workoutsByDay: [Int: [WorkoutV2]] = [:]
    var currentWeekDistance: Double = 0.0
    var currentWeekIntensity: TrainingIntensityManager.IntensityMinutes = .init(low: 0, medium: 0, high: 0)

    // MARK: - Private State

    private var isRefreshing: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let repository: TrainingPlanV2Repository
    @ObservationIgnored private let workoutRepository: WorkoutRepository
    @ObservationIgnored private let shouldSuppressError: (DomainError, String, (() -> Void)?) -> Bool
    @ObservationIgnored private let onNetworkError: (Error) -> Void

    // MARK: - Init

    init(
        repository: TrainingPlanV2Repository,
        workoutRepository: WorkoutRepository,
        shouldSuppressError: @escaping (DomainError, String, (() -> Void)?) -> Bool,
        onNetworkError: @escaping (Error) -> Void
    ) {
        self.repository = repository
        self.workoutRepository = workoutRepository
        self.shouldSuppressError = shouldSuppressError
        self.onNetworkError = onNetworkError

        setupEventSubscriptions()
    }

    // MARK: - Event Subscriptions

    private func setupEventSubscriptions() {
        CacheEventBus.shared.subscribe(for: "onboardingCompleted.loader") { [weak self] in
            guard let self else { return }
            Logger.debug("[WeeklyPlanLoader] 收到 onboardingCompleted 事件，清除快取並重新初始化")
            await self.repository.clearOverviewCache()
            await self.repository.clearWeeklyPlanCache(weekOfTraining: nil)
            await self.initialize()
        }

        CacheEventBus.shared.subscribe(for: "userLogout.loader") { [weak self] in
            guard let self else { return }
            Logger.debug("[WeeklyPlanLoader] 收到 userLogout 事件，清除所有狀態")
            await self.repository.clearOverviewCache()
            await self.repository.clearWeeklyPlanCache(weekOfTraining: nil)
            self.planStatus = .loading
            self.planOverview = nil
            self.weeklyPlan = nil
            self.workoutsByDay = [:]
            self.currentWeekDistance = 0.0
        }

        CacheEventBus.shared.subscribe(for: "dataChanged.trainingPlanV2.loader") { [weak self] in
            guard let self else { return }
            Logger.debug("[WeeklyPlanLoader] 收到 dataChanged.trainingPlanV2 事件，刷新課表")
            await self.refreshWeeklyPlan()
        }
    }

    // MARK: - Public Methods - Initialization

    /// 初始化載入所有資料
    /// Phase 1: 同步快取恢復（零 await，即時顯示）
    /// Phase 2: 背景 API 刷新（靜默更新，資料變化時才刷 UI）
    func initialize() async {
        guard !isRefreshing else {
            Logger.debug("[WeeklyPlanLoader] ⏭️ 刷新進行中，跳過")
            return
        }

        // Phase 1: 同步快取恢復 — 無 await，SwiftUI 沒機會渲染 .loading
        restoreFromCacheSync()

        // Phase 2: 背景 API 刷新
        await refreshFromAPI()
    }

    /// 同步快取恢復：從 UserDefaults 直接讀取，無 await，無 yield，無 loading 閃爍。
    /// 只在 planStatus == .loading（首次進入）時執行。
    private func restoreFromCacheSync() {
        guard case .loading = planStatus else { return }

        guard let cachedStatus = repository.getCachedPlanStatus() else { return }
        let isFirstLoad = planStatusResponse == nil
        planStatusResponse = cachedStatus
        currentWeek = cachedStatus.currentWeek
        if isFirstLoad {
            selectedWeek = cachedStatus.currentWeek
        }

        guard let cachedOverview = repository.getCachedOverview() else { return }
        planOverview = cachedOverview
        trainingPlanName = cachedOverview.targetName ?? "訓練計畫"

        // Plan 實體優先：有當週 cached plan 就直接顯示課表，不看 nextAction。
        // nextAction 是時間敏感 flag；API 回來後 handleNextAction 會重新判定正確狀態。
        if let cachedPlan = repository.getCachedWeeklyPlan(week: cachedStatus.currentWeek) {
            weeklyPlan = cachedPlan
            planStatus = .ready(cachedPlan)
            Logger.debug("[WeeklyPlanLoader] ⚡ 同步快取恢復（plan 優先）: week=\(cachedStatus.currentWeek)")
            return
        }

        // 沒有 cached plan，才依 nextAction 判定狀態
        switch cachedStatus.nextAction {
        case "create_plan":
            planStatus = .noWeeklyPlan
        case "create_summary":
            planStatus = .needsWeeklySummary
        case "training_completed":
            planStatus = .completed
        default:
            break
        }
    }

    /// 背景 API 刷新：status 和 overview 並行拉取，再根據 nextAction 載入後續資料。
    /// 若快取已有資料，API 失敗時靜默忽略，不破壞當前畫面。
    private func refreshFromAPI() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let hadData = planStatusResponse != nil && planOverview != nil

        // status 和 overview 無依賴，並行拉取（各自處理錯誤）
        async let statusFetch: Void = refreshPlanStatusQuietly()
        async let overviewFetch: Void = refreshOverviewQuietly()
        _ = await (statusFetch, overviewFetch)

        // 兩者都需要才能繼續
        guard let status = planStatusResponse, planOverview != nil else {
            if !hadData {
                planStatus = .noPlan
            }
            return
        }

        // 根據 nextAction 載入對應資料
        await handleNextAction(status.nextAction, planId: status.currentWeekPlanId)

        Logger.debug("[WeeklyPlanLoader] ✅ 初始化完成")
    }

    /// 靜默拉取 Plan Status（錯誤不破壞 UI）
    private func refreshPlanStatusQuietly() async {
        do {
            let status = try await repository.getPlanStatus(forceRefresh: true)
            let isFirstLoad = self.planStatusResponse == nil
            self.planStatusResponse = status
            self.currentWeek = status.currentWeek
            // 只在首次載入時跟隨 currentWeek，避免覆蓋使用者正在查看的週數
            if isFirstLoad {
                self.selectedWeek = status.currentWeek
            }

            Logger.info("[WeeklyPlanLoader] 📊 Status: week \(status.currentWeek)/\(status.totalWeeks), nextAction=\(status.nextAction)")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "Plan Status 刷新", nil) { return }
            if case .notFound = domainError {
                self.planStatus = .noPlan
                self.planStatusResponse = nil
            }
            Logger.error("[WeeklyPlanLoader] ❌ Plan Status 刷新失敗: \(domainError.localizedDescription)")
        }
    }

    /// 靜默拉取 Plan Overview（錯誤不破壞 UI）
    private func refreshOverviewQuietly() async {
        do {
            let overview = try await repository.getOverview()
            self.planOverview = overview
            self.trainingPlanName = overview.targetName ?? "訓練計畫"

            // Side effects: 週預覽 + 背景刷新
            await loadWeeklyPreview(overviewId: overview.id)
            Task.detached(priority: .background) {
                await self.backgroundRefreshOverview()
            }

            Logger.debug("[WeeklyPlanLoader] ✅ Plan Overview 刷新成功: \(overview.id)")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "Plan Overview 刷新", nil) { return }
            Logger.error("[WeeklyPlanLoader] ❌ Plan Overview 刷新失敗: \(domainError.localizedDescription)")
        }
    }

    // MARK: - Data Loading

    /// 載入 Plan Status
    func loadPlanStatus() async {
        Logger.debug("[WeeklyPlanLoader] 載入 Plan Status...")

        do {
            let status = try await repository.getPlanStatus()
            planStatusResponse = status
            currentWeek = status.currentWeek

            Logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Logger.info("📊 PLAN STATUS API 回應")
            Logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Logger.info("🔢 當前週數: \(status.currentWeek) / \(status.totalWeeks)")
            Logger.info("🎯 下一步動作: \(status.nextAction)")
            Logger.info("⭐️ 可產生下週課表: \(status.canGenerateNextWeek ? "YES ✅" : "NO ❌")")
            Logger.info("📝 當前週 Plan ID: \(status.currentWeekPlanId ?? "無")")
            Logger.info("📋 上週 Summary ID: \(status.previousWeekSummaryId ?? "無")")
            if let nextWeekInfo = status.nextWeekInfo {
                Logger.info("📅 下週資訊:")
                Logger.info("   - 週數: \(nextWeekInfo.weekNumber)")
                Logger.info("   - 已有課表: \(nextWeekInfo.hasPlan ? "是" : "否")")
                Logger.info("   - 可產生: \(nextWeekInfo.canGenerate ? "是" : "否")")
            }
            Logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(
                domainError,
                "Plan Status 載入",
                {
                    if self.planStatusResponse == nil {
                        self.planStatus = .noPlan
                    }
                }
            ) { return }

            if case .notFound = domainError {
                Logger.debug("[WeeklyPlanLoader] 無活躍計畫")
                planStatus = .noPlan
            } else {
                Logger.error("[WeeklyPlanLoader] ❌ Plan Status 載入失敗: \(domainError.localizedDescription)")
                onNetworkError(domainError)
            }
        }
    }

    /// 靜默更新 planStatusResponse（只更新 planStatusResponse 和 currentWeek，不改變 planStatus）
    func refreshPlanStatusResponse() async {
        do {
            let status = try await repository.getPlanStatus(forceRefresh: true)
            planStatusResponse = status
            currentWeek = status.currentWeek
            Logger.debug("[WeeklyPlanLoader] ✅ planStatusResponse 已靜默更新")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "planStatusResponse 更新", nil) { return }
            Logger.error("[WeeklyPlanLoader] ⚠️ planStatusResponse 更新失敗（已忽略）: \(domainError.localizedDescription)")
        }
    }

    /// 根據 nextAction 執行對應動作
    private func handleNextAction(_ nextAction: String, planId: String?) async {
        Logger.debug("[WeeklyPlanLoader] 處理 nextAction: \(nextAction)")

        switch nextAction {
        case "view_plan":
            await loadCurrentWeekPlan()
            await loadWorkoutsForCurrentWeek()

        case "create_plan":
            planStatus = .noWeeklyPlan
            Logger.debug("[WeeklyPlanLoader] 等待使用者產生第 \(currentWeek) 週課表")

        case "create_summary":
            planStatus = .needsWeeklySummary
            Logger.debug("[WeeklyPlanLoader] 需先產生第 \(currentWeek - 1) 週回顧")

        case "training_completed":
            planStatus = .completed
            Logger.debug("[WeeklyPlanLoader] 訓練計畫已完成")

        default:
            Logger.error("[WeeklyPlanLoader] ⚠️ 未知的 nextAction: \(nextAction)")
            planStatus = .noPlan
        }
    }

    /// 背景刷新 Overview（Track B）
    private func backgroundRefreshOverview() async {
        let initialOverviewId = planOverview?.id
        do {
            let freshOverview = try await repository.refreshOverview()
            Logger.debug("[WeeklyPlanLoader] ✅ Background refresh: Overview updated")

            guard planOverview?.id == initialOverviewId else {
                Logger.debug("[WeeklyPlanLoader] Background refresh overview: plan changed, discarding stale result")
                return
            }
            planOverview = freshOverview
            trainingPlanName = freshOverview.targetName ?? "訓練計畫"
        } catch {
            Logger.error("[WeeklyPlanLoader] ⚠️ Background refresh failed (ignored): \(error.localizedDescription)")
        }
    }

    /// 載入週訓練預覽（靜默載入，不影響主畫面狀態）
    private func loadWeeklyPreview(overviewId: String) async {
        Logger.debug("[WeeklyPlanLoader] 載入週訓練預覽...")

        do {
            let preview = try await repository.getWeeklyPreview(overviewId: overviewId)
            self.weeklyPreview = preview
            Logger.debug("[WeeklyPlanLoader] ✅ 週訓練預覽載入成功: \(preview.weeks.count) 週")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "週訓練預覽載入", nil) { return }
            Logger.error("[WeeklyPlanLoader] ⚠️ 週訓練預覽載入失敗（已忽略）: \(domainError.localizedDescription)")
        }
    }

    /// 載入當前週課表（雙軌快取）
    func loadCurrentWeekPlan() async {
        Logger.debug("[WeeklyPlanLoader] 載入第 \(currentWeek) 週課表...")

        do {
            guard let overviewId = planOverview?.id else {
                Logger.error("[WeeklyPlanLoader] ❌ 無法載入週課表：Plan Overview 為 nil")
                self.planStatus = .noWeeklyPlan
                return
            }
            let plan = try await repository.getWeeklyPlan(weekOfTraining: currentWeek, overviewId: overviewId)

            weeklyPlan = plan
            planStatus = .ready(plan)

            Logger.debug("[WeeklyPlanLoader] ✅ 週課表載入成功: week=\(currentWeek)")

            Task.detached(priority: .background) {
                await self.backgroundRefreshWeeklyPlan(week: self.currentWeek)
            }

        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "週課表載入", { self.planStatus = .noWeeklyPlan }) { return }
            if case .notFound = domainError {
                Logger.debug("[WeeklyPlanLoader] 週課表尚未生成，等待使用者手動觸發")
                planStatus = .noWeeklyPlan
            } else {
                Logger.error("[WeeklyPlanLoader] ❌ 週課表載入失敗: \(domainError.localizedDescription)")
                planStatus = .error(domainError)
            }
        }
    }

    private func refreshDisplayedWeekPlan(week: Int) async {
        do {
            guard let overviewId = planOverview?.id else {
                Logger.error("[WeeklyPlanLoader] ❌ 無法刷新週課表：Plan Overview 為 nil")
                planStatus = .noWeeklyPlan
                return
            }

            let plan = try await repository.refreshWeeklyPlan(weekOfTraining: week, overviewId: overviewId)
            weeklyPlan = plan
            planStatus = .ready(plan)
            selectedWeek = week

            Logger.debug("[WeeklyPlanLoader] ✅ 已強制刷新第 \(week) 週課表")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "刷新第 \(week) 週課表", { self.planStatus = .noWeeklyPlan }) { return }
            if case .notFound = domainError {
                Logger.debug("[WeeklyPlanLoader] 第 \(week) 週課表尚未生成")
                planStatus = .noWeeklyPlan
            } else {
                Logger.error("[WeeklyPlanLoader] ❌ 刷新第 \(week) 週課表失敗: \(domainError.localizedDescription)")
                planStatus = .error(domainError)
            }
        }
    }

    /// 背景刷新週課表（Track B）
    private func backgroundRefreshWeeklyPlan(week: Int) async {
        do {
            guard let overviewId = planOverview?.id else {
                Logger.debug("[WeeklyPlanLoader] ⚠️ Background refresh skipped: no overview")
                return
            }
            let freshPlan = try await repository.refreshWeeklyPlan(weekOfTraining: week, overviewId: overviewId)
            Logger.debug("[WeeklyPlanLoader] ✅ Background refresh: Weekly plan updated")

            guard planOverview?.id == overviewId else {
                Logger.debug("[WeeklyPlanLoader] Background refresh: plan changed, discarding stale result")
                return
            }
            if selectedWeek == week {
                weeklyPlan = freshPlan
                planStatus = .ready(freshPlan)
            }
        } catch {
            Logger.error("[WeeklyPlanLoader] ⚠️ Background refresh failed (ignored): \(error.localizedDescription)")
        }
    }

    /// 載入本週訓練記錄
    func loadWorkoutsForCurrentWeek() async {
        Logger.debug("[WeeklyPlanLoader] 載入本週訓練記錄...")

        guard let overview = planOverview else {
            Logger.error("[WeeklyPlanLoader] ❌ 無法載入訓練記錄：Plan Overview 為 nil")
            return
        }

        guard let createdAt = overview.createdAt else {
            Logger.error("[WeeklyPlanLoader] ❌ Overview createdAt 為 nil，無法載入訓練記錄。請檢查 API 回傳的 createdAt 是否正確解析")
            return
        }

        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: createdAt)
        Logger.debug("[WeeklyPlanLoader] 使用 Overview createdAt: \(createdAtString)")

        guard let weekInfo = WeekDateService.weekDateInfo(
            createdAt: createdAtString,
            weekNumber: selectedWeek
        ) else {
            Logger.error("[WeeklyPlanLoader] ❌ 無法計算週日期範圍，createdAt: \(createdAtString)")
            return
        }

        let allWorkouts = await workoutRepository.getAllWorkoutsAsync()

        let grouped = WeekMetricsCalculator.groupWorkoutsByDay(allWorkouts, weekInfo: weekInfo)
        let weekMetrics = WeekMetricsCalculator.metrics(for: allWorkouts, weekInfo: weekInfo)

        workoutsByDay = grouped
        currentWeekDistance = weekMetrics.totalDistanceKm
        currentWeekIntensity = weekMetrics.intensity

        Logger.debug("[WeeklyPlanLoader] ✅ 訓練記錄載入完成: \(grouped.values.flatMap { $0 }.count) 筆")
    }

    // MARK: - Switch Week

    /// 切換到指定週次並載入該週課表
    func switchToWeek(_ week: Int) async {
        Logger.debug("[WeeklyPlanLoader] 切換到第 \(week) 週...")

        selectedWeek = week

        do {
            guard let overviewId = planOverview?.id else {
                Logger.error("[WeeklyPlanLoader] ❌ 無法切換週次：Plan Overview 為 nil")
                self.planStatus = .noWeeklyPlan
                return
            }
            let plan = try await repository.getWeeklyPlan(weekOfTraining: week, overviewId: overviewId)
            weeklyPlan = plan
            planStatus = .ready(plan)

            await loadWorkoutsForCurrentWeek()

            Logger.debug("[WeeklyPlanLoader] ✅ 切換完成")

        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "切換週次", { self.planStatus = .noWeeklyPlan }) { return }
            if case .notFound = domainError {
                Logger.debug("[WeeklyPlanLoader] 第 \(week) 週課表尚未生成")
                planStatus = .noWeeklyPlan
            } else {
                Logger.error("[WeeklyPlanLoader] ❌ 切換失敗: \(domainError.localizedDescription)")
                planStatus = .error(domainError)
            }
        }
    }

    // MARK: - Public Refresh

    /// 刷新週課表（下拉刷新 / userLogout event）
    func refreshWeeklyPlan() async {
        let weekToRefresh = selectedWeek
        Logger.debug("[WeeklyPlanLoader] 刷新週課表（顯示中週數: \(weekToRefresh)，當前週數: \(currentWeek)）...")

        await refreshPlanStatusResponse()
        await refreshDisplayedWeekPlan(week: weekToRefresh)
        await loadWorkoutsForCurrentWeek()

        Logger.debug("[WeeklyPlanLoader] ✅ 刷新完成")
    }
}
