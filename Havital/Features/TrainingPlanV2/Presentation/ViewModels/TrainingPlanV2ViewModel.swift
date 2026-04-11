import Foundation
import SwiftUI
import Combine

// MARK: - TrainingPlanV2 ViewModel
/// V2 版本的訓練計畫 ViewModel
/// 負責協調 PlanOverview、WeeklyPlan 和訓練記錄的載入
@MainActor
final class TrainingPlanV2ViewModel: ObservableObject, TaskManageable {

    // MARK: - Dependencies

    private let repository: TrainingPlanV2Repository
    private let workoutRepository: WorkoutRepository
    private let versionRouter: TrainingVersionRouter

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Published State

    /// 計畫狀態（統一管理 UI 狀態）
    @Published var planStatus: PlanStatusV2 = .loading

    /// Plan Status API 回應（儲存後端計算的狀態資訊）
    @Published var planStatusResponse: PlanStatusV2Response?

    /// Plan Overview 資料
    @Published var planOverview: PlanOverviewV2?

    /// 當前週課表資料
    @Published var weeklyPlan: WeeklyPlanV2?

    /// 當前週數（根據計畫建立時間計算）
    @Published var currentWeek: Int = 1

    /// 選擇的週數（用於切換週次）
    @Published var selectedWeek: Int = 1

    /// 訓練計畫名稱（顯示在 NavigationTitle）
    @Published var trainingPlanName: String = "訓練計畫"

    /// 本週已完成的訓練記錄（按天分組）
    @Published var workoutsByDay: [Int: [WorkoutV2]] = [:]

    /// 本週跑量統計
    @Published var currentWeekDistance: Double = 0.0

    /// 本週強度分配統計
    @Published var currentWeekIntensity: TrainingIntensityManager.IntensityMinutes = .init(low: 0, medium: 0, high: 0)

    /// 網路錯誤（用於顯示錯誤提示）
    @Published var networkError: Error?

    /// 成功提示訊息
    @Published var successToast: String?

    /// 所有週的摘要列表（用於顯示各週是否有課表/回顧）
    @Published var weeklySummaries: [WeeklySummaryItem] = []

    /// 週摘要狀態
    @Published var weeklySummary: ViewState<WeeklySummaryV2> = .loading

    /// 是否顯示週摘要 sheet
    @Published var showWeeklySummary = false

    /// 是否正在產生週摘要（用於 noWeeklyPlan 狀態的 loading）
    @Published var isGeneratingSummary = false

    /// 是否顯示 loading 動畫（全屏）
    @Published var isLoadingAnimation = false

    /// 是否正在載入週摘要（用於決定 loading 動畫類型）
    @Published var isLoadingWeeklySummary = false

    /// 週訓練預覽資料（用於週骨架預覽 UI）
    @Published var weeklyPreview: WeeklyPreviewV2?

    /// 可用方法論列表（用於方法論切換 UI）
    @Published var availableMethodologies: [MethodologyV2] = []

    /// 付費牆觸發（nil 表示未觸發）
    @Published var paywallTrigger: PaywallTrigger?

    /// 是否顯示 Rizo 配額超出 Banner
    @Published var showRizoQuotaExceededBanner: Bool = false

    // MARK: - Computed Properties

    /// 是否正在載入
    var isLoading: Bool {
        return planStatus == .loading
    }

    /// 總週數
    var totalWeeks: Int {
        return planOverview?.totalWeeks ?? 0
    }

    /// 從當前週起算的未來四週預覽（最多 4 週，不足則取到最後一週）
    var upcomingWeeks: [WeekPreview] {
        guard let preview = weeklyPreview else { return [] }
        return Array(
            preview.weeks
                .filter { $0.week >= currentWeek }
                .sorted { $0.week < $1.week }
                .prefix(4)
        )
    }

    // MARK: - Subscribers

    private var cancellables = Set<AnyCancellable>()

    /// 防止重複初始化的鎖
    private var isInitializing = false

    // MARK: - Initialization

    init(
        repository: TrainingPlanV2Repository,
        workoutRepository: WorkoutRepository,
        versionRouter: TrainingVersionRouter
    ) {
        self.repository = repository
        self.workoutRepository = workoutRepository
        self.versionRouter = versionRouter

        setupEventSubscriptions()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        let container = DependencyContainer.shared

        // 確保 V2 模組已註冊
        if !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        let repository: TrainingPlanV2Repository = container.resolve()
        let workoutRepository: WorkoutRepository = container.resolve()
        let versionRouter: TrainingVersionRouter = container.resolve()

        self.init(
            repository: repository,
            workoutRepository: workoutRepository,
            versionRouter: versionRouter
        )
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Setup

    /// 設置事件訂閱
    private func setupEventSubscriptions() {
        // ✅ 訂閱 Onboarding 完成事件
        CacheEventBus.shared.subscribe(for: "onboardingCompleted") { [weak self] in
            guard let self = self else { return }
            Logger.debug("[TrainingPlanV2VM] 收到 onboardingCompleted 事件，清除快取並重新初始化")
            await self.repository.clearOverviewCache()
            await self.repository.clearWeeklyPlanCache(weekOfTraining: nil)
            await self.initialize()
        }

        // ✅ 訂閱用戶登出事件
        CacheEventBus.shared.subscribe(for: "userLogout") { [weak self] in
            guard let self = self else { return }
            Logger.debug("[TrainingPlanV2VM] 收到 userLogout 事件，清除所有狀態")
            await self.repository.clearOverviewCache()
            await self.repository.clearWeeklyPlanCache(weekOfTraining: nil)
            await MainActor.run {
                self.planStatus = .loading
                self.planOverview = nil
                self.weeklyPlan = nil
                self.workoutsByDay = [:]
                self.currentWeekDistance = 0.0
            }
        }

        // ✅ 訂閱訓練計畫更新事件（例如從 EditSchedule 修改課表）
        CacheEventBus.shared.subscribe(for: "dataChanged.trainingPlanV2") { [weak self] in
            guard let self = self else { return }
            Logger.debug("[TrainingPlanV2VM] 收到 dataChanged.trainingPlanV2 事件，刷新課表")
            await self.refreshWeeklyPlan()
        }
    }

    // MARK: - Public Methods - Initialization

    /// 初始化載入所有資料（整合 status API）
    func initialize() async {
        // 防止重複初始化
        guard !isInitializing else {
            Logger.debug("[TrainingPlanV2VM] ⏭️ 初始化已在進行中，跳過本次調用")
            return
        }

        isInitializing = true
        defer { isInitializing = false }

        Logger.debug("[TrainingPlanV2VM] 🚀 開始初始化（整合 status API）...")

        planStatus = .loading

        // ⭐ Step 1: 載入 Plan Status（決定後續流程）
        await loadPlanStatus()
        selectedWeek = currentWeek  // 初始化時跟隨 currentWeek

        guard let status = planStatusResponse else {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Status 載入失敗，無法繼續")
            planStatus = .noPlan
            return
        }

        // ⭐ Step 2: 載入 Plan Overview（所有 nextAction 都需要）
        await loadPlanOverview()

        guard planOverview != nil else {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview 載入失敗")
            planStatus = .noPlan
            return
        }

        // ⭐ Step 3: 根據 nextAction 決定下一步
        await handleNextAction(status.nextAction, planId: status.currentWeekPlanId)

        Logger.debug("[TrainingPlanV2VM] ✅ 初始化完成")
    }

    // MARK: - Data Loading

    /// ⭐ 載入 Plan Status
    private func loadPlanStatus() async {
        Logger.debug("[TrainingPlanV2VM] 載入 Plan Status...")

        do {
            let status = try await repository.getPlanStatus()

            await MainActor.run {
                self.planStatusResponse = status
                self.currentWeek = status.currentWeek  // 使用後端計算的週數
                // 不再覆蓋 selectedWeek — 由呼叫方決定
            }

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

        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] Plan Status 載入被取消，忽略")
        } catch let error as DomainError {
            if case .notFound = error {
                Logger.debug("[TrainingPlanV2VM] 無活躍計畫")
                await MainActor.run {
                    self.planStatus = .noPlan
                }
            } else {
                Logger.error("[TrainingPlanV2VM] ❌ Plan Status 載入失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.networkError = error
                }
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ Plan Status 載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.networkError = error
            }
        }
    }

    /// 靜默更新 planStatusResponse（只更新 planStatusResponse 和 currentWeek，不改變 planStatus）
    /// 用於成功操作後需要取得 nextWeekInfo 但不想覆蓋已設定好的 planStatus 的場景
    private func refreshPlanStatusResponse() async {
        do {
            let status = try await repository.getPlanStatus()
            await MainActor.run {
                self.planStatusResponse = status
                self.currentWeek = status.currentWeek
            }
            Logger.debug("[TrainingPlanV2VM] ✅ planStatusResponse 已靜默更新")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] planStatusResponse 更新被取消")
        } catch {
            // 靜默忽略錯誤，不影響當前 planStatus
            Logger.error("[TrainingPlanV2VM] ⚠️ planStatusResponse 更新失敗（已忽略）: \(error)")
        }
    }

    /// ⭐ 根據 nextAction 執行對應動作
    private func handleNextAction(_ nextAction: String, planId: String?) async {
        Logger.debug("[TrainingPlanV2VM] 處理 nextAction: \(nextAction)")

        switch nextAction {
        case "view_plan":
            // 載入當前週課表
            await loadCurrentWeekPlan()
            await loadWorkoutsForCurrentWeek()

        case "create_plan":
            // 顯示「產生週課表」按鈕
            await MainActor.run {
                self.planStatus = .noWeeklyPlan
            }
            Logger.debug("[TrainingPlanV2VM] 等待使用者產生第 \(currentWeek) 週課表")

        case "create_summary":
            // ⭐ 顯示「產生週回顧」按鈕
            await MainActor.run {
                self.planStatus = .needsWeeklySummary
            }
            Logger.debug("[TrainingPlanV2VM] 需先產生第 \(currentWeek - 1) 週回顧")

        case "training_completed":
            // 訓練完成
            await MainActor.run {
                self.planStatus = .completed
            }
            Logger.debug("[TrainingPlanV2VM] 訓練計畫已完成")

        default:
            Logger.error("[TrainingPlanV2VM] ⚠️ 未知的 nextAction: \(nextAction)")
            await MainActor.run {
                self.planStatus = .noPlan
            }
        }
    }

    /// 載入 Plan Overview（雙軌快取）
    private func loadPlanOverview() async {
        Logger.debug("[TrainingPlanV2VM] 載入 Plan Overview...")

        do {
            // Track A: 立即返回快取（如果存在）
            let overview = try await repository.getOverview()

            await MainActor.run {
                self.planOverview = overview
                self.trainingPlanName = overview.targetName ?? "訓練計畫"
                // ❌ 移除前端週數計算，完全信任後端 Status API 的 currentWeek
                // self.calculateCurrentWeek(from: overview)
            }

            Logger.debug("[TrainingPlanV2VM] ✅ Plan Overview 載入成功: \(overview.id)")

            // 載入週訓練預覽
            await loadWeeklyPreview(overviewId: overview.id)

            // Track B: 背景刷新（不影響已顯示的資料）
            Task.detached(priority: .background) {
                await self.backgroundRefreshOverview()
            }

        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] Plan Overview 載入被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview 載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.networkError = error
            }
        }
    }

    /// 背景刷新 Overview（Track B）
    private func backgroundRefreshOverview() async {
        let initialOverviewId = planOverview?.id  // capture before API call
        do {
            let freshOverview = try await repository.refreshOverview()
            Logger.debug("[TrainingPlanV2VM] ✅ Background refresh: Overview updated")

            await MainActor.run {
                // 只在計畫沒有被換掉的情況下更新（防止 stale refresh 蓋掉 re-onboarding 後的新計畫）
                guard self.planOverview?.id == initialOverviewId else {
                    Logger.debug("[TrainingPlanV2VM] Background refresh overview: plan changed, discarding stale result")
                    return
                }
                self.planOverview = freshOverview
                self.trainingPlanName = freshOverview.targetName ?? "訓練計畫"
            }
        } catch {
            Logger.error("[TrainingPlanV2VM] ⚠️ Background refresh failed (ignored): \(error.localizedDescription)")
        }
    }

    /// 載入週訓練預覽（靜默載入，不影響主畫面狀態）
    private func loadWeeklyPreview(overviewId: String) async {
        Logger.debug("[TrainingPlanV2VM] 載入週訓練預覽...")

        do {
            let preview = try await repository.getWeeklyPreview(overviewId: overviewId)
            self.weeklyPreview = preview
            Logger.debug("[TrainingPlanV2VM] ✅ 週訓練預覽載入成功: \(preview.weeks.count) 週")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週訓練預覽載入被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            // 靜默失敗 — 週預覽是輔助資訊，不影響主流程
            Logger.error("[TrainingPlanV2VM] ⚠️ 週訓練預覽載入失敗（已忽略）: \(error.localizedDescription)")
        }
    }

    /// 載入當前週課表（雙軌快取）
    private func loadCurrentWeekPlan() async {
        Logger.debug("[TrainingPlanV2VM] 載入第 \(currentWeek) 週課表...")

        do {
            // Track A: 立即返回快取
            guard let overviewId = planOverview?.id else {
                Logger.error("[TrainingPlanV2VM] ❌ 無法載入週課表：Plan Overview 為 nil")
                self.planStatus = .noWeeklyPlan
                return
            }
            let plan = try await repository.getWeeklyPlan(weekOfTraining: currentWeek, overviewId: overviewId)

            await MainActor.run {
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
            }

            Logger.debug("[TrainingPlanV2VM] ✅ 週課表載入成功: week=\(currentWeek)")

            // Track B: 背景刷新
            Task.detached(priority: .background) {
                await self.backgroundRefreshWeeklyPlan(week: self.currentWeek)
            }

        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週課表載入被取消，忽略")
        } catch let error as DomainError {
            if case .notFound = error {
                Logger.debug("[TrainingPlanV2VM] 週課表尚未生成，等待使用者手動觸發")
                await MainActor.run {
                    self.planStatus = .noWeeklyPlan
                }
            } else {
                Logger.error("[TrainingPlanV2VM] ❌ 週課表載入失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.planStatus = .error(error)
                }
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ 週課表載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.planStatus = .error(error)
            }
        }
    }

    /// 使用者手動產生當前週課表
    func generateCurrentWeekPlan() async {
        Logger.debug("[TrainingPlanV2VM] 使用者觸發產生第 \(selectedWeek) 週課表...")

        // ✅ 全屏 loading 動畫（與 V1 一致）
        isLoadingWeeklySummary = false
        isLoadingAnimation = true

        do {
            let plan = try await repository.generateWeeklyPlan(
                weekOfTraining: selectedWeek,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )

            await MainActor.run {
                self.isLoadingAnimation = false
                self.currentWeek = selectedWeek
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
                self.successToast = "第 \(selectedWeek) 週課表已產生"
            }

            // 載入本週訓練記錄
            await loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanV2VM] ✅ 週課表產生成功: week=\(selectedWeek)")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週課表產生被取消，忽略")
            await MainActor.run { self.isLoadingAnimation = false }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                await MainActor.run { self.isLoadingAnimation = false }
                return
            }
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired:
                self.paywallTrigger = resolvePaywallTrigger()
                self.isLoadingAnimation = false
            case .rizoQuotaExceeded:
                self.showRizoQuotaExceededBanner = true
                self.isLoadingAnimation = false
            default:
                Logger.error("[TrainingPlanV2VM] ❌ 週課表產生失敗: \(error.localizedDescription)")
                self.isLoadingAnimation = false
                self.planStatus = .error(error)
            }
        }
    }

    /// 產生下週課表（完全照搬 V1 流程）
    func generateNextWeekPlan() async {
        guard let nextWeekInfo = planStatusResponse?.nextWeekInfo else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法產生下週課表：缺少 nextWeekInfo")
            return
        }

        Logger.debug("[TrainingPlanV2VM] 🚀 產生第 \(nextWeekInfo.weekNumber) 週課表（照搬 V1 流程）")

        // ✅ 檢查是否需要先產生當前週回顧
        if nextWeekInfo.requiresCurrentWeekSummary == true {
            Logger.debug("[TrainingPlanV2VM] 需要先產生週回顧，再從回顧 sheet 產生下週課表")
            await createWeeklySummaryAndShow(week: currentWeek)
            return
        }

        // ✅ 無需週回顧，直接產生下週課表
        Logger.debug("[TrainingPlanV2VM] 本週回顧已完成，直接產生第 \(nextWeekInfo.weekNumber) 週課表")
        await generateWeeklyPlanDirectly(weekNumber: nextWeekInfo.weekNumber)
    }

    /// 決定「從週回顧 Sheet 產生課表」時應該產生哪一週。
    /// 優先使用後端 Status API 的 nextWeekInfo.weekNumber（source of truth）。
    /// 若短暫拿不到 nextWeekInfo，才退回 summaryWeek + 1。
    func resolveWeekToGenerateAfterSummary(summaryWeek: Int) async -> Int {
        await refreshPlanStatusResponse()
        if let backendWeek = planStatusResponse?.nextWeekInfo?.weekNumber, backendWeek > 0 {
            return backendWeek
        }
        return max(1, summaryWeek + 1)
    }

    /// 直接產生週課表（不檢查週回顧）
    func generateWeeklyPlanDirectly(weekNumber: Int) async {
        Logger.debug("[TrainingPlanV2VM] 開始產生第 \(weekNumber) 週課表...")

        // ✅ 全屏 loading 動畫（與 V1 一致）
        isLoadingWeeklySummary = false
        isLoadingAnimation = true

        do {
            let plan = try await repository.generateWeeklyPlan(
                weekOfTraining: weekNumber,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )

            // 切換到新產生的週
            await MainActor.run {
                self.isLoadingAnimation = false
                self.currentWeek = weekNumber
                self.selectedWeek = weekNumber
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
                self.successToast = "第 \(weekNumber) 週課表已產生"
            }

            // 靜默更新 planStatusResponse 以取得 nextWeekInfo，不覆蓋已設定的 .ready(plan) 狀態
            // 注意：refreshPlanStatusResponse 不會改動 selectedWeek，selectedWeek 已在上方設定完成
            await refreshPlanStatusResponse()

            // 載入本週訓練記錄
            await loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanV2VM] ✅ 週課表產生成功: week=\(weekNumber)")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週課表產生被取消，忽略")
            await MainActor.run { self.isLoadingAnimation = false }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                await MainActor.run { self.isLoadingAnimation = false }
                return
            }
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired:
                self.paywallTrigger = resolvePaywallTrigger()
                self.isLoadingAnimation = false
            case .rizoQuotaExceeded:
                self.showRizoQuotaExceededBanner = true
                self.isLoadingAnimation = false
            default:
                Logger.error("[TrainingPlanV2VM] ❌ 週課表產生失敗: \(error.localizedDescription)")
                self.isLoadingAnimation = false
                self.planStatus = .error(error)
            }
        }
    }

    /// 背景刷新週課表（Track B）
    private func backgroundRefreshWeeklyPlan(week: Int) async {
        do {
            guard let overviewId = planOverview?.id else {
                Logger.debug("[TrainingPlanV2VM] ⚠️ Background refresh skipped: no overview")
                return
            }
            let freshPlan = try await repository.refreshWeeklyPlan(weekOfTraining: week, overviewId: overviewId)
            Logger.debug("[TrainingPlanV2VM] ✅ Background refresh: Weekly plan updated")

            await MainActor.run {
                guard self.planOverview?.id == overviewId else {
                    Logger.debug("[TrainingPlanV2VM] Background refresh: plan changed, discarding stale result")
                    return
                }
                if self.selectedWeek == week {
                    self.weeklyPlan = freshPlan
                    self.planStatus = .ready(freshPlan)
                }
            }
        } catch {
            Logger.error("[TrainingPlanV2VM] ⚠️ Background refresh failed (ignored): \(error.localizedDescription)")
        }
    }

    /// 載入本週訓練記錄
    private func loadWorkoutsForCurrentWeek() async {
        Logger.debug("[TrainingPlanV2VM] 載入本週訓練記錄...")

        guard let overview = planOverview else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法載入訓練記錄：Plan Overview 為 nil")
            return
        }

        // 將 createdAt (Date?) 轉換為 ISO8601 String
        // 必須使用 overview.createdAt 作為 Week 1 的基準點
        // 注意：weeklyPlan.createdAt 是該週課表生成時間，不能作為週日期計算的基準
        guard let createdAt = overview.createdAt else {
            Logger.error("[TrainingPlanV2VM] ❌ Overview createdAt 為 nil，無法載入訓練記錄。請檢查 API 回傳的 createdAt 是否正確解析")
            return
        }

        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: createdAt)
        Logger.debug("[TrainingPlanV2VM] 使用 Overview createdAt: \(createdAtString)")

        guard let weekInfo = WeekDateService.weekDateInfo(
            createdAt: createdAtString,
            weekNumber: selectedWeek
        ) else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法計算週日期範圍，createdAt: \(createdAtString)")
            return
        }

        let allWorkouts = await workoutRepository.getAllWorkoutsAsync()

        // 過濾本週的訓練記錄並按天分組
        let grouped = groupWorkoutsByDay(allWorkouts, weekInfo: weekInfo)

        await MainActor.run {
            self.workoutsByDay = grouped
        }

        // 計算本週跑量和強度
        await calculateWeekMetrics(workouts: allWorkouts, weekInfo: weekInfo)

        Logger.debug("[TrainingPlanV2VM] ✅ 訓練記錄載入完成: \(grouped.values.flatMap { $0 }.count) 筆")
    }

    /// 按天分組訓練記錄
    private func groupWorkoutsByDay(_ workouts: [WorkoutV2], weekInfo: WeekDateInfo) -> [Int: [WorkoutV2]] {
        let calendar = Calendar.current
        let activityTypes: Set<String> = ["running", "walking", "hiking", "cross_training"]

        var grouped: [Int: [WorkoutV2]] = [:]

        for workout in workouts {
            // 只保留跑步相關活動
            guard activityTypes.contains(workout.activityType) else { continue }

            // 只保留本週範圍內的訓練
            guard workout.startDate >= weekInfo.startDate && workout.startDate <= weekInfo.endDate else {
                continue
            }

            // 找到對應的 dayIndex (1-7)
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

        // 排序：最新的在前
        for (dayIndex, workouts) in grouped {
            grouped[dayIndex] = workouts.sorted { $0.endDate > $1.endDate }
        }

        return grouped
    }

    /// 計算本週訓練指標（跑量和強度）
    private func calculateWeekMetrics(workouts: [WorkoutV2], weekInfo: WeekDateInfo) async {
        let weekWorkouts = workouts.filter {
            $0.startDate >= weekInfo.startDate && $0.startDate <= weekInfo.endDate
        }

        // 計算總跑量（從 distanceMeters 轉換為公里）
        let totalDistanceMeters = weekWorkouts.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        let totalDistanceKm = totalDistanceMeters / 1000.0

        // 計算強度分配（從 WorkoutV2 的 advancedMetrics.intensityMinutes 中累加）
        var totalLow: Double = 0.0
        var totalMedium: Double = 0.0
        var totalHigh: Double = 0.0

        for workout in weekWorkouts {
            if let intensityMinutes = workout.advancedMetrics?.intensityMinutes {
                totalLow += intensityMinutes.low ?? 0.0
                totalMedium += intensityMinutes.medium ?? 0.0
                totalHigh += intensityMinutes.high ?? 0.0
            }
        }

        let intensity = TrainingIntensityManager.IntensityMinutes(
            low: totalLow,
            medium: totalMedium,
            high: totalHigh
        )

        await MainActor.run {
            self.currentWeekDistance = totalDistanceKm
            self.currentWeekIntensity = intensity
        }

        Logger.debug("[TrainingPlanV2VM] 本週統計: 跑量=\(totalDistanceKm) km, 強度(低/中/高)=\(totalLow)/\(totalMedium)/\(totalHigh) 分鐘")
    }

    /// 計算當前訓練週數（根據 Plan 建立時間）
    /// ⚠️ 注意：V2 應該完全依賴後端 Status API 的 currentWeek，此方法僅作為降級方案
    private func calculateCurrentWeek(from overview: PlanOverviewV2) {
        guard let startDate = overview.createdAt else {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview createdAt 為 nil，無法計算訓練週數")
            currentWeek = 1
            selectedWeek = 1
            return
        }

        // ✅ 使用與 V1 相同的週數計算邏輯（週一到週一的天數差距）
        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: startDate)

        guard let calculatedWeek = WeekDateService.currentTrainingWeek(createdAt: createdAtString) else {
            Logger.error("[TrainingPlanV2VM] ❌ WeekDateService 計算週數失敗")
            currentWeek = 1
            selectedWeek = 1
            return
        }

        let finalWeek = min(calculatedWeek, overview.totalWeeks)

        currentWeek = finalWeek
        selectedWeek = finalWeek

        Logger.debug("[TrainingPlanV2VM] 當前訓練週數（前端計算）: \(finalWeek) / \(overview.totalWeeks)")
    }

    // MARK: - User Actions

    /// 刷新週課表（下拉刷新）
    func refreshWeeklyPlan() async {
        Logger.debug("[TrainingPlanV2VM] 刷新週課表...")

        // 強制從 API 刷新
        await loadPlanOverview()
        await loadCurrentWeekPlan()
        await loadWorkoutsForCurrentWeek()

        Logger.debug("[TrainingPlanV2VM] ✅ 刷新完成")
    }

    /// 切換到指定週次
    func switchToWeek(_ week: Int) async {
        Logger.debug("[TrainingPlanV2VM] 切換到第 \(week) 週...")

        selectedWeek = week
        planStatus = .loading

        do {
            guard let overviewId = planOverview?.id else {
                Logger.error("[TrainingPlanV2VM] ❌ 無法切換週次：Plan Overview 為 nil")
                self.planStatus = .noWeeklyPlan
                return
            }
            let plan = try await repository.getWeeklyPlan(weekOfTraining: week, overviewId: overviewId)

            await MainActor.run {
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
            }

            await loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanV2VM] ✅ 切換完成")

        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 切換週次被取消，忽略")
        } catch let error as DomainError {
            if case .notFound = error {
                Logger.debug("[TrainingPlanV2VM] 第 \(week) 週課表尚未生成")
                await MainActor.run {
                    self.planStatus = .noWeeklyPlan
                }
            } else {
                Logger.error("[TrainingPlanV2VM] ❌ 切換失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.planStatus = .error(error)
                }
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ 切換失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.planStatus = .error(error)
            }
        }
    }

    // MARK: - Helper Methods

    /// 獲取指定 day 的訓練記錄
    func getWorkouts(for dayIndex: Int) -> [WorkoutV2] {
        return workoutsByDay[dayIndex] ?? []
    }

    /// 獲取指定 day 的日期
    func getDate(for dayIndex: Int) -> Date? {
        guard let overview = planOverview else { return nil }

        // 必須使用 overview.createdAt 作為 Week 1 的基準點
        // 注意：weeklyPlan.createdAt 是該週課表生成時間，不能作為週日期計算的基準
        guard let createdAt = overview.createdAt else {
            Logger.error("[TrainingPlanV2VM] ❌ getDate: Overview createdAt 為 nil")
            return nil
        }

        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: createdAt)

        guard let weekInfo = WeekDateService.weekDateInfo(
            createdAt: createdAtString,
            weekNumber: selectedWeek
        ) else {
            return nil
        }

        return weekInfo.daysMap[dayIndex]
    }

    /// 是否為今天
    func isToday(dayIndex: Int) -> Bool {
        guard let date = getDate(for: dayIndex) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    /// 清除錯誤訊息
    func clearError() {
        networkError = nil
    }

    /// 清除成功提示
    func clearSuccessToast() {
        successToast = nil
    }

    // MARK: - Weekly Summary

    /// 載入週摘要
    func loadWeeklySummary(weekOfPlan: Int) async {
        Logger.debug("[TrainingPlanV2VM] 載入第 \(weekOfPlan) 週摘要...")

        weeklySummary = .loading

        do {
            let summary = try await repository.getWeeklySummary(weekOfPlan: weekOfPlan)
            weeklySummary = .loaded(summary)
            Logger.debug("[TrainingPlanV2VM] ✅ 週摘要載入成功: \(summary.id)")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週摘要載入被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ 週摘要載入失敗: \(error.localizedDescription)")
            if let domainError = error as? DomainError {
                weeklySummary = .error(domainError)
            } else {
                weeklySummary = .error(.networkFailure(error.localizedDescription))
            }
        }
    }

    /// 產生週摘要
    func generateWeeklySummary() async {
        Logger.debug("[TrainingPlanV2VM] 產生第 \(selectedWeek) 週摘要...")

        weeklySummary = .loading

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: selectedWeek, forceUpdate: true)
            weeklySummary = .loaded(summary)
            successToast = "週回顧已產生"
            Logger.info("[TrainingPlanV2VM] ✅ 週摘要產生成功: \(summary.id)")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週摘要產生被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired:
                self.paywallTrigger = resolvePaywallTrigger()
            case .rizoQuotaExceeded:
                self.showRizoQuotaExceededBanner = true
            default:
                Logger.error("[TrainingPlanV2VM] ❌ 週摘要產生失敗: \(error.localizedDescription)")
                weeklySummary = .error(domainError)
            }
        }
    }

    /// 產生週摘要並顯示 sheet（用於 needsWeeklySummary 流程）
    /// Week 2+ 必須先產生 summary，才能產生下週課表
    func createWeeklySummaryAndShow(week: Int) async {
        Logger.debug("[TrainingPlanV2VM] 產生第 \(week) 週摘要並顯示...")

        // ✅ 觸發全屏 loading 動畫（與 V1 一致）
        isGeneratingSummary = true
        isLoadingWeeklySummary = true
        isLoadingAnimation = true

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: week, forceUpdate: false)

            weeklySummary = .loaded(summary)

            // 趁 loading sheet 還在時先更新 planStatusResponse
            await refreshPlanStatusResponse()

            // 關閉 loading sheet，等待 dismiss 動畫完成，再開啟 summary sheet
            stopLoadingAnimation()
            try await Task.sleep(nanoseconds: 600_000_000)

            showWeeklySummary = true

            Logger.info("[TrainingPlanV2VM] ✅ 週摘要產生成功，顯示 sheet")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 週摘要產生被取消，忽略")
            stopLoadingAnimation()
        } catch {
            stopLoadingAnimation()
            if (error as NSError).code == NSURLErrorCancelled { return }
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired:
                self.paywallTrigger = resolvePaywallTrigger()
            case .rizoQuotaExceeded:
                self.showRizoQuotaExceededBanner = true
            default:
                Logger.error("[TrainingPlanV2VM] ❌ 週摘要產生失敗: \(error.localizedDescription)")
                networkError = error
            }
        }
    }

    private func stopLoadingAnimation() {
        isLoadingAnimation = false
        isLoadingWeeklySummary = false
        isGeneratingSummary = false
    }

    /// 獲取所有週摘要列表（共用 V1 endpoint，用於判斷各週是否有課表/回顧）
    func fetchWeeklySummaries() async {
        Logger.debug("[TrainingPlanV2VM] fetchWeeklySummaries...")
        do {
            let items = try await repository.getWeeklySummaries()
            await MainActor.run {
                self.weeklySummaries = items
            }
            Logger.info("[TrainingPlanV2VM] ✅ fetchWeeklySummaries: \(items.count) items")
        } catch {
            Logger.error("[TrainingPlanV2VM] ⚠️ fetchWeeklySummaries failed (non-critical): \(error)")
        }
    }

    /// 查看歷史週回顧（從 Toolbar Menu 觸發）
    /// 用於查看已產生的歷史週回顧，不會重新產生
    func viewHistoricalSummary(week: Int) async {
        Logger.debug("[TrainingPlanV2VM] 查看第 \(week) 週的歷史回顧...")

        do {
            let summary = try await repository.getWeeklySummary(weekOfPlan: week)
            await MainActor.run {
                self.weeklySummary = .loaded(summary)
                self.showWeeklySummary = true
            }
            Logger.info("[TrainingPlanV2VM] ✅ 歷史週回顧載入成功，顯示 sheet")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 歷史週回顧載入被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ 歷史週回顧載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.networkError = error
            }
        }
    }

    // MARK: - Update Overview

    /// 更新訓練計畫概覽（當賽事目標有重要變更時）
    func updateOverview(startFromStage: String? = nil) async {
        Logger.debug("[TrainingPlanV2VM] 更新訓練計畫概覽... startFromStage=\(startFromStage ?? "nil")")

        guard let overviewId = planOverview?.id else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法更新：overview ID 為 nil")
            networkError = NSError(domain: "", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "無法更新訓練計劃"
            ])
            return
        }

        // 顯示 loading 狀態
        await MainActor.run {
            self.isLoadingAnimation = true
            self.isLoadingWeeklySummary = false
        }

        do {
            // 調用 Repository 更新 overview
            let updatedOverview = try await repository.updateOverview(
                overviewId: overviewId,
                startFromStage: startFromStage,
                methodologyId: nil
            )

            await MainActor.run {
                self.planOverview = updatedOverview
                self.isLoadingAnimation = false
                self.successToast = NSLocalizedString("training.plan_regenerated", comment: "訓練計劃已根據最新目標重新產生")
            }

            // 清除快取並重新載入當前週課表
            await repository.clearCache()
            await loadPlanStatus()

            Logger.info("[TrainingPlanV2VM] ✅ 訓練計劃概覽已更新")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 更新被取消，忽略")
            await MainActor.run { self.isLoadingAnimation = false }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                await MainActor.run { self.isLoadingAnimation = false }
                return
            }
            Logger.error("[TrainingPlanV2VM] ❌ 更新訓練計劃概覽失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingAnimation = false
                self.networkError = error
            }
        }
    }

    // MARK: - Methodology

    /// 載入可用方法論列表
    func loadMethodologies() async {
        Logger.debug("[TrainingPlanV2VM] 載入可用方法論列表...")
        do {
            let targetType = planOverview?.targetType
        let methodologies = try await repository.getMethodologies(targetType: targetType)
            await MainActor.run {
                self.availableMethodologies = methodologies
            }
            Logger.info("[TrainingPlanV2VM] ✅ 載入 \(methodologies.count) 個方法論")
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ 載入方法論失敗: \(error.localizedDescription)")
        }
    }

    /// 切換方法論
    func changeMethodology(methodologyId: String, startFromStage: String? = nil) async {
        Logger.debug("[TrainingPlanV2VM] 切換方法論: \(methodologyId), 起始階段: \(startFromStage ?? "nil")")

        guard let overviewId = planOverview?.id else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法切換方法論：overview ID 為 nil")
            return
        }

        do {
            let updatedOverview = try await repository.updateOverview(
                overviewId: overviewId,
                startFromStage: startFromStage,
                methodologyId: methodologyId
            )

            await MainActor.run {
                self.planOverview = updatedOverview
                self.successToast = NSLocalizedString("training.methodology_changed", comment: "方法論已更換")
            }

            // 清除快取並重新載入
            await repository.clearCache()
            await loadPlanStatus()

            Logger.info("[TrainingPlanV2VM] ✅ 方法論已切換至: \(methodologyId)")
        } catch is CancellationError {
            Logger.debug("[TrainingPlanV2VM] 切換方法論被取消，忽略")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            Logger.error("[TrainingPlanV2VM] ❌ 切換方法論失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.networkError = error
            }
        }
    }

    // MARK: - Subscription Helpers

    /// 根據用戶的上次訂閱狀態決定 PaywallTrigger
    /// trial 過期 → .trialExpired（文案更友善）；一般過期 → .apiGated
    private func resolvePaywallTrigger() -> PaywallTrigger {
        if let lastStatus = SubscriptionStateManager.shared.currentStatus,
           lastStatus.status == .trial {
            return .trialExpired
        }
        return .apiGated
    }

    // MARK: - Debug Actions

    /// 在任何時間產生週回顧（Debug）
    /// ⚠️ 週回顧應該產生「上週」的回顧，即 currentWeek - 1
    func debugGenerateWeeklySummary() async {
        let weekToSummarize = max(1, currentWeek - 1)  // 產生上週的回顧
        Logger.debug("[TrainingPlanV2VM] 🐛 [DEBUG] Generating weekly summary for week \(weekToSummarize) (current week: \(currentWeek))")

        // ✅ 顯示全屏 loading 動畫
        await MainActor.run {
            self.isLoadingWeeklySummary = true
            self.isLoadingAnimation = true
        }

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: weekToSummarize, forceUpdate: true)

            await MainActor.run {
                self.isLoadingAnimation = false
                self.isLoadingWeeklySummary = false
                self.weeklySummary = .loaded(summary)
                self.showWeeklySummary = true
                self.successToast = "✅ [DEBUG] 週回顧已產生: week \(weekToSummarize)"
            }

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly summary generated: \(summary.id)")
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] Failed to generate weekly summary: \(error.localizedDescription)")

            await MainActor.run {
                self.isLoadingAnimation = false
                self.isLoadingWeeklySummary = false
                self.networkError = error
            }
        }
    }

    /// 刪除當前週課表（Debug）
    func debugDeleteCurrentWeekPlan() async {
        guard let plan = weeklyPlan else {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] No weekly plan to delete")
            networkError = NSError(domain: "TrainingPlanV2", code: -1, userInfo: [NSLocalizedDescriptionKey: "無週課表可刪除"])
            return
        }

        let planId = plan.effectivePlanId
        Logger.debug("[TrainingPlanV2VM] 🗑️ [DEBUG] Deleting weekly plan: \(planId)")

        do {
            try await repository.deleteWeeklyPlan(planId: planId)

            // 清除本地快取
            await repository.clearWeeklyPlanCache(weekOfTraining: currentWeek)

            self.weeklyPlan = nil
            self.planStatus = .noWeeklyPlan
            self.successToast = "✅ [DEBUG] 週課表已刪除"

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly plan deleted: \(planId)")
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] Failed to delete weekly plan: \(error.localizedDescription)")
            networkError = error
        }
    }

    /// 刪除當前週回顧（Debug）
    func debugDeleteCurrentWeeklySummary() async {
        // 先獲取週摘要以取得 summaryId
        do {
            let summary = try await repository.getWeeklySummary(weekOfPlan: currentWeek)
            let summaryId = summary.id

            Logger.debug("[TrainingPlanV2VM] 🗑️ [DEBUG] Deleting weekly summary: \(summaryId)")

            try await repository.deleteWeeklySummary(summaryId: summaryId)

            // 清除本地快取
            await repository.clearWeeklySummaryCache(weekOfPlan: currentWeek)

            self.weeklySummary = .empty
            self.successToast = "✅ [DEBUG] 週回顧已刪除"

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly summary deleted: \(summaryId)")

        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] Failed to delete weekly summary: \(error.localizedDescription)")

            await MainActor.run {
                self.networkError = error
            }
        }
    }
}

// MARK: - PlanStatusV2 Enum

/// 訓練計畫狀態 V2（UI 使用）
enum PlanStatusV2: Equatable {
    case loading
    case noPlan            // 無計畫（顯示 Onboarding 提示）
    case noWeeklyPlan      // 有 Overview 但無週課表（顯示「產生週課表」按鈕）
    case needsWeeklySummary // 需要先產生週回顧才能產生下週課表（顯示「產生週回顧」按鈕）
    case ready(WeeklyPlanV2)  // 有計畫，顯示課表
    case completed         // 訓練完成
    case error(Error)      // 錯誤狀態

    static func == (lhs: PlanStatusV2, rhs: PlanStatusV2) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.noPlan, .noPlan),
             (.noWeeklyPlan, .noWeeklyPlan),
             (.needsWeeklySummary, .needsWeeklySummary),
             (.completed, .completed):
            return true
        case (.ready(let lhsPlan), .ready(let rhsPlan)):
            return lhsPlan.id == rhsPlan.id
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - DependencyContainer Factory

extension DependencyContainer {
    /// 建立 TrainingPlanV2ViewModel 工廠方法
    @MainActor
    func makeTrainingPlanV2ViewModel() -> TrainingPlanV2ViewModel {
        return TrainingPlanV2ViewModel()
    }
}
