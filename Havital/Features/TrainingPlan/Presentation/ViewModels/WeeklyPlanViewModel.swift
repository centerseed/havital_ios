import Foundation
import SwiftUI

// MARK: - WeeklyPlan ViewModel
/// 負責週計畫的 UI 狀態管理
/// 使用 ViewState<T> 統一狀態，注入 Repository 依賴
@MainActor
final class WeeklyPlanViewModel: ObservableObject {

    // MARK: - Published State (SINGLE SOURCE OF TRUTH)
    @Published var state: ViewState<WeeklyPlan> = .loading
    @Published var selectedWeek: Int = 1
    @Published var currentWeek: Int = 1

    // MARK: - Overview State
    @Published var overviewState: ViewState<TrainingPlanOverview> = .loading

    // MARK: - Dependencies (Protocol Injection)
    private let repository: TrainingPlanRepository

    // MARK: - TaskManageable
    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Computed Properties

    /// 當前顯示的計畫 ID
    var currentPlanId: String? {
        guard case .loaded(let overview) = overviewState else { return nil }
        return "\(overview.id)_\(selectedWeek)"
    }

    /// 可選擇的週數範圍
    var availableWeeks: [Int] {
        return Array(1...currentWeek)
    }

    /// 週計畫數據（如有）
    var weeklyPlan: WeeklyPlan? {
        return state.data
    }

    /// 是否正在載入
    var isLoading: Bool {
        return state.isLoading
    }

    // MARK: - Initialization

    init(repository: TrainingPlanRepository) {
        self.repository = repository
        setupEventSubscriptions()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        // 確保 TrainingPlan 模組已註冊
        if !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) {
            DependencyContainer.shared.registerTrainingPlanModule()
        }
        self.init(repository: DependencyContainer.shared.resolve())
    }

    // MARK: - Event Subscriptions

    /// 設定事件訂閱
    private func setupEventSubscriptions() {
        // ✅ Clean Architecture: 訂閱用戶登出事件
        CacheEventBus.shared.subscribe(for: "userLogout") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[WeeklyPlanVM] 收到 userLogout 事件，清除緩存")

            // 清除 Repository 緩存
            await self.repository.clearCache()

            // 重置狀態
            await MainActor.run {
                self.state = .loading
                self.overviewState = .loading
                self.selectedWeek = 1
                self.currentWeek = 1
            }

            Logger.debug("[WeeklyPlanVM] ✅ 用戶登出後狀態已重置")
        }

        // ✅ Clean Architecture: 訂閱訓練計畫修改事件
        CacheEventBus.shared.subscribe(for: "dataChanged.trainingPlan") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[WeeklyPlanVM] 收到 dataChanged.trainingPlan 事件，刷新週計畫")

            // 強制刷新當前週計畫
            await self.refreshWeeklyPlan()

            Logger.debug("[WeeklyPlanVM] ✅ 週計畫已刷新")
        }
    }

    // MARK: - Public Methods

    /// 初始化載入（載入 overview 和當前週計畫）
    func initialize() async {
        Logger.debug("[WeeklyPlanVM] Initializing...")

        // 先載入 overview
        await loadOverview()

        // 根據 overview 計算當前週並載入週計畫
        if case .loaded(let overview) = overviewState {
            currentWeek = calculateCurrentWeek(from: overview)
            selectedWeek = currentWeek
            await loadWeeklyPlan()
        }
    }

    /// 載入當前選擇週的計畫
    func loadWeeklyPlan() async {
        Logger.debug("[WeeklyPlanVM] 📤 開始載入週計畫 - selectedWeek: \(selectedWeek), currentWeek: \(currentWeek)")

        guard let planId = currentPlanId else {
            Logger.debug("[WeeklyPlanVM] ❌ No plan ID available - overviewState: \(overviewState)")
            state = .empty
            return
        }

        Logger.debug("[WeeklyPlanVM] 🔄 載入計畫 - planId: \(planId)")

        // ✅ Stale-While-Revalidate: 有數據時不顯示 loading，避免 UI 閃爍
        let hasData = state.data != nil
        if !hasData {
            state = .loading
        }

        do {
            let plan = try await repository.getWeeklyPlan(planId: planId)
            Logger.debug("[WeeklyPlanVM] 📥 收到週計畫 - plan.id: \(plan.id), plan.weekOfPlan: \(plan.weekOfPlan)")
            Logger.debug("[WeeklyPlanVM] 📥 計畫內容 - totalDistance: \(plan.totalDistance), days count: \(plan.days.count)")
            state = .loaded(plan)
            Logger.debug("[WeeklyPlanVM] ✅ Weekly plan loaded: \(planId)")
        } catch let error as TrainingPlanError {
            if case .weeklyPlanNotFound = error {
                Logger.debug("[WeeklyPlanVM] ⚠️ Weekly plan not found: \(planId)")
                state = .empty
            } else {
                // ✅ 有緩存時，錯誤不覆蓋已顯示的數據
                if !hasData {
                    Logger.error("[WeeklyPlanVM] ❌ Error: \(error)")
                    state = .error(error.toDomainError())
                } else {
                    Logger.warn("[WeeklyPlanVM] ⚠️ Load failed but keeping cached data: \(error)")
                }
            }
        } catch {
            let domainError = error.toDomainError()

            // 取消錯誤不更新 UI
            if case .cancellation = domainError {
                Logger.debug("[WeeklyPlanVM] ⚠️ Task cancelled, ignoring")
                return
            }

            // ✅ 有緩存時，錯誤不覆蓋已顯示的數據（503 等暫時性錯誤）
            if !hasData {
                state = .error(domainError)
                Logger.error("[WeeklyPlanVM] ❌ Failed to load plan: \(domainError.localizedDescription ?? "")")
            } else {
                Logger.warn("[WeeklyPlanVM] ⚠️ Load failed but keeping cached data: \(domainError.localizedDescription ?? "")")
            }
        }
    }

    /// 強制刷新週計畫
    /// - Parameter silent: 是否靜默刷新（默認 true）。靜默模式下，有緩存時不顯示 loading，避免閃爍
    func refreshWeeklyPlan(silent: Bool = true) async {
        guard let planId = currentPlanId else { return }

        // ✅ 雙軌緩存策略：只有在無數據時才顯示 loading
        let hasData = state.data != nil
        if !hasData && !silent {
            state = .loading
        }

        do {
            let plan = try await repository.refreshWeeklyPlan(planId: planId)
            state = .loaded(plan)
            Logger.debug("[WeeklyPlanVM] Successfully refreshed plan (silent: \(silent), hadData: \(hasData))")
        } catch let error as TrainingPlanError {
            // ✅ 處理計畫不存在的情況（與 loadWeeklyPlan 一致）
            if case .weeklyPlanNotFound = error {
                state = .empty
                Logger.debug("[WeeklyPlanVM] Weekly plan not found during refresh, setting state to empty")
            } else {
                // ✅ 有緩存時，刷新失敗不改變 state（保持顯示舊數據）
                if !hasData {
                    state = .error(error.toDomainError())
                } else {
                    Logger.warn("[WeeklyPlanVM] Refresh failed but keeping cached data: \(error.localizedDescription)")
                }
            }
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }

            // ✅ 有緩存時，刷新失敗不改變 state（保持顯示舊數據）
            if !hasData {
                state = .error(domainError)
            } else {
                Logger.warn("[WeeklyPlanVM] Refresh failed but keeping cached data: \(domainError.localizedDescription ?? "Unknown")")
            }
        }
    }

    /// 切換到指定週
    func selectWeek(_ week: Int) async {
        Logger.debug("[WeeklyPlanVM] selectWeek(\(week)) 被調用 - currentWeek: \(currentWeek), selectedWeek: \(selectedWeek)")

        // ✅ 修復:允許查看任何已產生的週計畫,包括未來週
        // 只檢查週數 >= 1,計畫是否存在由 loadWeeklyPlan 處理
        guard week >= 1 else {
            Logger.error("[WeeklyPlanVM] ❌ selectWeek 失敗 - week(\(week)) 必須 >= 1")
            return
        }

        Logger.debug("[WeeklyPlanVM] ✅ selectWeek 驗證通過,準備載入第 \(week) 週計畫")
        selectedWeek = week
        await loadWeeklyPlan()
    }

    /// 創建新的週計畫
    func generateWeeklyPlan(
        targetWeek: Int? = nil,
        startFromStage: String? = nil,
        isBeginner: Bool = false
    ) async {
        state = .loading

        do {
            let week = targetWeek ?? selectedWeek
            Logger.debug("[WeeklyPlanVM] 📤 請求產生週計畫 - week: \(week), targetWeek: \(targetWeek?.description ?? "nil"), selectedWeek: \(selectedWeek)")

            let plan = try await repository.createWeeklyPlan(
                week: week,
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            Logger.debug("[WeeklyPlanVM] 📥 收到週計畫 - plan.id: \(plan.id), plan.weekOfPlan: \(plan.weekOfPlan)")
            Logger.debug("[WeeklyPlanVM] 📥 計畫內容 - totalDistance: \(plan.totalDistance), days count: \(plan.days.count)")

            state = .loaded(plan)
            Logger.debug("[WeeklyPlanVM] Weekly plan generated: \(plan.id)")
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }
            state = .error(domainError)
        }
    }

    /// 修改週計畫
    func modifyWeeklyPlan(_ updatedPlan: WeeklyPlan) async {
        guard let planId = currentPlanId else { return }

        do {
            let plan = try await repository.modifyWeeklyPlan(
                planId: planId,
                updatedPlan: updatedPlan
            )
            state = .loaded(plan)
            Logger.debug("[WeeklyPlanVM] Weekly plan modified: \(planId)")
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }
            state = .error(domainError)
        }
    }

    // MARK: - Overview Methods

    /// 載入訓練概覽
    func loadOverview() async {
        // ✅ Stale-While-Revalidate: 有數據時不顯示 loading，避免 UI 閃爍
        let hasData = overviewState.data != nil
        if !hasData {
            overviewState = .loading
        }

        do {
            let overview = try await repository.getOverview()
            overviewState = .loaded(overview)
            Logger.debug("[WeeklyPlanVM] Overview loaded: \(overview.id)")
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }

            // ✅ 有緩存時，錯誤不覆蓋已顯示的數據
            if !hasData {
                overviewState = .error(domainError)
            } else {
                Logger.warn("[WeeklyPlanVM] Overview load failed but keeping cached data: \(domainError.localizedDescription ?? "")")
            }
        }
    }

    // MARK: - Private Methods

    /// 計算當前訓練週數
    private func calculateCurrentWeek(from overview: TrainingPlanOverview) -> Int {
        // TODO: 實作基於日期的週數計算
        // 目前簡單返回 1
        return 1
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 WeeklyPlanViewModel 工廠
    @MainActor
    static func makeWeeklyPlanViewModel() -> WeeklyPlanViewModel {
        return WeeklyPlanViewModel()
    }
}
