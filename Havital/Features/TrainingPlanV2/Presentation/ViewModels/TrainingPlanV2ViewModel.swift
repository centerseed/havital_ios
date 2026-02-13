import Foundation
import SwiftUI
import Combine

// MARK: - TrainingPlanV2 ViewModel
/// V2 版本的訓練計畫 ViewModel
/// 負責協調 PlanOverview、WeeklyPlan 和訓練記錄的載入
@MainActor
final class TrainingPlanV2ViewModel: ObservableObject {

    // MARK: - Dependencies

    private let repository: TrainingPlanV2Repository
    private let workoutRepository: WorkoutRepository
    private let versionRouter: TrainingVersionRouter

    // MARK: - Published State

    /// 計畫狀態（統一管理 UI 狀態）
    @Published var planStatus: PlanStatusV2 = .loading

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

    /// 週摘要狀態
    @Published var weeklySummary: ViewState<WeeklySummaryV2> = .loading

    // MARK: - Computed Properties

    /// 是否正在載入
    var isLoading: Bool {
        return planStatus == .loading
    }

    /// 總週數
    var totalWeeks: Int {
        return planOverview?.totalWeeks ?? 0
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

    /// 初始化載入所有資料
    func initialize() async {
        // 防止重複初始化
        guard !isInitializing else {
            Logger.debug("[TrainingPlanV2VM] ⏭️ 初始化已在進行中，跳過本次調用")
            return
        }

        isInitializing = true
        defer { isInitializing = false }

        Logger.debug("[TrainingPlanV2VM] 🚀 開始初始化...")

        planStatus = .loading

        // Step 1: 載入 Plan Overview（雙軌快取）
        await loadPlanOverview()

        guard planOverview != nil else {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview 載入失敗，無法繼續")
            planStatus = .noPlan
            return
        }

        // Step 2: 載入當前週課表（雙軌快取）
        await loadCurrentWeekPlan()

        // Step 3: 載入本週訓練記錄
        await loadWorkoutsForCurrentWeek()

        Logger.debug("[TrainingPlanV2VM] ✅ 初始化完成")
    }

    // MARK: - Data Loading

    /// 載入 Plan Overview（雙軌快取）
    private func loadPlanOverview() async {
        Logger.debug("[TrainingPlanV2VM] 載入 Plan Overview...")

        do {
            // Track A: 立即返回快取（如果存在）
            let overview = try await repository.getOverview()

            await MainActor.run {
                self.planOverview = overview
                self.trainingPlanName = overview.targetName ?? "訓練計畫"
                self.calculateCurrentWeek(from: overview)
            }

            Logger.debug("[TrainingPlanV2VM] ✅ Plan Overview 載入成功: \(overview.id)")

            // Track B: 背景刷新（不影響已顯示的資料）
            Task.detached(priority: .background) {
                await self.backgroundRefreshOverview()
            }

        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview 載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.networkError = error
            }
        }
    }

    /// 背景刷新 Overview（Track B）
    private func backgroundRefreshOverview() async {
        do {
            let freshOverview = try await repository.refreshOverview()
            Logger.debug("[TrainingPlanV2VM] ✅ Background refresh: Overview updated")

            await MainActor.run {
                // 只在資料有變化時更新 UI
                if self.planOverview?.id != freshOverview.id {
                    self.planOverview = freshOverview
                    self.trainingPlanName = freshOverview.targetName ?? "訓練計畫"
                    self.calculateCurrentWeek(from: freshOverview)
                }
            }
        } catch {
            Logger.error("[TrainingPlanV2VM] ⚠️ Background refresh failed (ignored): \(error.localizedDescription)")
        }
    }

    /// 載入當前週課表（雙軌快取）
    private func loadCurrentWeekPlan() async {
        Logger.debug("[TrainingPlanV2VM] 載入第 \(currentWeek) 週課表...")

        do {
            // Track A: 立即返回快取
            let plan = try await repository.getWeeklyPlan(weekOfTraining: currentWeek)

            await MainActor.run {
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
            }

            Logger.debug("[TrainingPlanV2VM] ✅ 週課表載入成功: week=\(currentWeek)")

            // Track B: 背景刷新
            Task.detached(priority: .background) {
                await self.backgroundRefreshWeeklyPlan(week: self.currentWeek)
            }

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
            Logger.error("[TrainingPlanV2VM] ❌ 週課表載入失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.planStatus = .error(error)
            }
        }
    }

    /// 使用者手動產生當前週課表
    func generateCurrentWeekPlan() async {
        Logger.debug("[TrainingPlanV2VM] 使用者觸發產生第 \(selectedWeek) 週課表...")

        planStatus = .generating

        do {
            let plan = try await repository.generateWeeklyPlan(
                weekOfTraining: selectedWeek,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )

            await MainActor.run {
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
            }

            // 載入本週訓練記錄
            await loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanV2VM] ✅ 週課表產生成功: week=\(selectedWeek)")
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ 週課表產生失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.planStatus = .error(error)
            }
        }
    }

    /// 背景刷新週課表（Track B）
    private func backgroundRefreshWeeklyPlan(week: Int) async {
        do {
            let freshPlan = try await repository.refreshWeeklyPlan(weekOfTraining: week)
            Logger.debug("[TrainingPlanV2VM] ✅ Background refresh: Weekly plan updated")

            await MainActor.run {
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
    private func calculateCurrentWeek(from overview: PlanOverviewV2) {
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = overview.createdAt else {
            Logger.error("[TrainingPlanV2VM] ❌ Plan Overview createdAt 為 nil，無法計算訓練週數")
            currentWeek = 1
            selectedWeek = 1
            return
        }

        guard let weekDiff = calendar.dateComponents([.weekOfYear], from: startDate, to: now).weekOfYear else {
            Logger.error("[TrainingPlanV2VM] ❌ 無法計算訓練週數")
            currentWeek = 1
            selectedWeek = 1
            return
        }

        let calculatedWeek = min(max(weekDiff + 1, 1), overview.totalWeeks)

        currentWeek = calculatedWeek
        selectedWeek = calculatedWeek

        Logger.debug("[TrainingPlanV2VM] 當前訓練週數: \(calculatedWeek) / \(overview.totalWeeks)")
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
            let plan = try await repository.getWeeklyPlan(weekOfTraining: week)

            await MainActor.run {
                self.weeklyPlan = plan
                self.planStatus = .ready(plan)
            }

            await loadWorkoutsForCurrentWeek()

            Logger.debug("[TrainingPlanV2VM] ✅ 切換完成")

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
        } catch {
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
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ 週摘要產生失敗: \(error.localizedDescription)")
            if let domainError = error as? DomainError {
                weeklySummary = .error(domainError)
            } else {
                weeklySummary = .error(.networkFailure(error.localizedDescription))
            }
        }
    }

    // MARK: - Debug Actions

    /// 在任何時間產生週回顧（Debug）
    func debugGenerateWeeklySummary() async {
        Logger.debug("[TrainingPlanV2VM] 🐛 [DEBUG] Generating weekly summary for week \(currentWeek)")

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: currentWeek, forceUpdate: true)

            await MainActor.run {
                self.successToast = "✅ [DEBUG] 週回顧已產生: week \(currentWeek)"
            }

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly summary generated: \(summary.id)")
        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] Failed to generate weekly summary: \(error.localizedDescription)")

            await MainActor.run {
                self.networkError = error
            }
        }
    }

    /// 刪除當前週課表（Debug）
    func debugDeleteCurrentWeekPlan() async {
        guard let planId = weeklyPlan?.id else {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] No weekly plan to delete")
            await MainActor.run {
                self.networkError = NSError(domain: "TrainingPlanV2", code: -1, userInfo: [NSLocalizedDescriptionKey: "無週課表可刪除"])
            }
            return
        }

        Logger.debug("[TrainingPlanV2VM] 🗑️ [DEBUG] Deleting weekly plan: \(planId)")

        do {
            try await repository.deleteWeeklyPlan(planId: planId)

            await MainActor.run {
                self.weeklyPlan = nil
                self.planStatus = .loading
                self.successToast = "✅ [DEBUG] 週課表已刪除"
            }

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly plan deleted: \(planId)")

            // 清除本地快取
            await repository.clearWeeklyPlanCache(weekOfTraining: currentWeek)

        } catch {
            Logger.error("[TrainingPlanV2VM] ❌ [DEBUG] Failed to delete weekly plan: \(error.localizedDescription)")

            await MainActor.run {
                self.networkError = error
            }
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

            await MainActor.run {
                self.successToast = "✅ [DEBUG] 週回顧已刪除"
            }

            Logger.info("[TrainingPlanV2VM] ✅ [DEBUG] Weekly summary deleted: \(summaryId)")

            // 清除本地快取
            await repository.clearWeeklySummaryCache(weekOfPlan: currentWeek)

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
    case generating        // 正在生成週課表
    case ready(WeeklyPlanV2)  // 有計畫，顯示課表
    case completed         // 訓練完成
    case error(Error)      // 錯誤狀態

    static func == (lhs: PlanStatusV2, rhs: PlanStatusV2) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.noPlan, .noPlan),
             (.noWeeklyPlan, .noWeeklyPlan),
             (.generating, .generating),
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
