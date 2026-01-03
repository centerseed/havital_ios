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
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        // 確保 TrainingPlan 模組已註冊
        if !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) {
            DependencyContainer.shared.registerTrainingPlanModule()
        }
        self.init(repository: DependencyContainer.shared.resolve())
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
        guard let planId = currentPlanId else {
            Logger.debug("[WeeklyPlanVM] No plan ID available")
            state = .empty
            return
        }

        state = .loading

        do {
            let plan = try await repository.getWeeklyPlan(planId: planId)
            state = .loaded(plan)
            Logger.debug("[WeeklyPlanVM] Weekly plan loaded: \(planId)")
        } catch let error as TrainingPlanError {
            if case .weeklyPlanNotFound = error {
                state = .empty
            } else {
                state = .error(error.toDomainError())
            }
        } catch {
            let domainError = error.toDomainError()

            // 取消錯誤不更新 UI
            if case .cancellation = domainError {
                Logger.debug("[WeeklyPlanVM] Task cancelled, ignoring")
                return
            }

            state = .error(domainError)
            Logger.error("[WeeklyPlanVM] Failed to load plan: \(domainError.localizedDescription ?? "")")
        }
    }

    /// 強制刷新週計畫
    func refreshWeeklyPlan() async {
        guard let planId = currentPlanId else { return }

        state = .loading

        do {
            let plan = try await repository.refreshWeeklyPlan(planId: planId)
            state = .loaded(plan)
        } catch let error as TrainingPlanError {
            // ✅ 處理計畫不存在的情況（與 loadWeeklyPlan 一致）
            if case .weeklyPlanNotFound = error {
                state = .empty
                Logger.debug("[WeeklyPlanVM] Weekly plan not found during refresh, setting state to empty")
            } else {
                state = .error(error.toDomainError())
            }
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }
            state = .error(domainError)
        }
    }

    /// 切換到指定週
    func selectWeek(_ week: Int) async {
        guard week >= 1 && week <= currentWeek else { return }

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
            let plan = try await repository.createWeeklyPlan(
                week: targetWeek ?? selectedWeek,
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )
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
        overviewState = .loading

        do {
            let overview = try await repository.getOverview()
            overviewState = .loaded(overview)
            Logger.debug("[WeeklyPlanVM] Overview loaded: \(overview.id)")
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }
            overviewState = .error(domainError)
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
