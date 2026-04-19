//
//  WorkoutListViewModel.swift
//  Havital
//
//  Workout List ViewModel
//  Presentation Layer - UI State Management
//

import SwiftUI
import Combine

// MARK: - Workout List ViewModel
/// 訓練列表 ViewModel
/// Presentation Layer - 負責訓練列表的 UI 狀態管理
@MainActor
final class WorkoutListViewModel: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - ViewState (統一狀態管理)

    /// 訓練列表狀態
    @Published private(set) var state: ViewState<[WorkoutV2]> = .loading

    // MARK: - Pagination State

    /// 是否還有更多數據
    @Published private(set) var hasMore: Bool = false

    /// 是否正在載入更多
    @Published private(set) var isLoadingMore: Bool = false

    // MARK: - Dependencies (Use Cases Injection)

    private let getWorkoutsUseCase: GetWorkoutsUseCase
    private let deleteWorkoutUseCase: DeleteWorkoutUseCase
    private let repository: WorkoutRepository

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Subscribers

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization (Constructor Injection)

    init(
        getWorkoutsUseCase: GetWorkoutsUseCase,
        deleteWorkoutUseCase: DeleteWorkoutUseCase,
        repository: WorkoutRepository
    ) {
        self.getWorkoutsUseCase = getWorkoutsUseCase
        self.deleteWorkoutUseCase = deleteWorkoutUseCase
        self.repository = repository

        setupEventSubscriptions()
    }

    // MARK: - Convenience Initializer (DI Container Resolution)

    convenience init() {
        let container = DependencyContainer.shared

        // 確保 Workout 模組已註冊
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        self.init(
            getWorkoutsUseCase: container.makeGetWorkoutsUseCase(),
            deleteWorkoutUseCase: container.makeDeleteWorkoutUseCase(),
            repository: container.resolve()
        )
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Setup

    private func setupEventSubscriptions() {
        // ✅ Clean Architecture: 只訂閱 CacheEventBus 事件（不使用 NotificationCenter）

        // 訂閱 Repository 背景刷新訊號，republish 到 EventBus 讓其他模組也收到
        repository.workoutsDidRefresh
            .receive(on: DispatchQueue.main)
            .sink {
                Logger.debug("[WorkoutListVM] 收到 Repository workoutsDidRefresh → republish EventBus")
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            .store(in: &cancellables)

        // 事件 1: Workout 數據變更 → 直接從緩存讀取並更新 UI
        CacheEventBus.shared.subscribe(for: "dataChanged.workouts") { [weak self] in
            guard let self = self else { return }
            Logger.debug("[WorkoutListVM] 收到 dataChanged.workouts 事件，從緩存更新 UI")

            // 背景刷新完成後，直接從 Use Case 讀取最新數據（會命中更新後的緩存）
            // 不觸發新的背景刷新，避免不必要的 API 調用
            do {
                let workouts = try await self.getWorkoutsUseCase.execute(limit: 50, offset: nil)
                await MainActor.run {
                    self.hasMore = workouts.count >= 50
                    self.state = workouts.isEmpty ? .empty : .loaded(workouts)
                }
                Logger.debug("[WorkoutListVM] ✅ UI 已更新，數量: \(workouts.count)")
            } catch {
                // 背景更新失敗不改變當前狀態，只記錄錯誤
                Logger.debug("[WorkoutListVM] 背景刷新失敗: \(error.localizedDescription)")
            }
        }

        // 事件 2: 用戶登出 → 清除數據
        CacheEventBus.shared.subscribe(for: "userLogout") { [weak self] in
            Logger.debug("[WorkoutListVM] 收到 userLogout 事件，重置狀態")
            await self?.handleUserLogoutEvent()
        }
    }

    // MARK: - Public Methods

    /// 載入訓練列表（初始載入）
    func loadWorkouts(forceRefresh: Bool = false) async {
        Logger.debug("[WorkoutListVM] loadWorkouts - forceRefresh: \(forceRefresh)")

        await executeTask(id: TaskID("load_workouts"), cooldownSeconds: 5) { [weak self] in
            guard let self = self else { return }
            await self.performLoadWorkouts(forceRefresh: forceRefresh)
        }
    }

    /// 刷新訓練列表（下拉刷新）
    func refreshWorkouts() async {
        Logger.debug("[WorkoutListVM] refreshWorkouts - Pull-to-refresh")

        await executeTask(id: TaskID("refresh_workouts"), cooldownSeconds: 2) { [weak self] in
            guard let self = self else { return }
            await self.performRefreshWorkouts()
        }
    }

    /// 刪除訓練記錄
    func deleteWorkout(id: String) async -> Bool {
        Logger.debug("[WorkoutListVM] deleteWorkout - id: \(id)")

        do {
            // 使用 DeleteWorkoutUseCase
            try await deleteWorkoutUseCase.execute(workoutId: id)

            // 通知其他模組 workout 數據已變更（EventBus 屬於 Presentation 層職責）
            CacheEventBus.shared.publish(.dataChanged(.workouts))

            // 從當前狀態中移除已刪除的訓練
            if case .loaded(let currentWorkouts) = state {
                let updatedWorkouts = currentWorkouts.filter { $0.id != id }
                state = updatedWorkouts.isEmpty ? .empty : .loaded(updatedWorkouts)
            }

            Logger.debug("[WorkoutListVM] ✅ Deleted workout: \(id)")
            return true

        } catch is CancellationError {
            Logger.debug("[WorkoutListVM] Delete cancelled")
            return false
        } catch {
            Logger.error("[WorkoutListVM] ❌ Failed to delete: \(error.localizedDescription)")
            return false
        }
    }

    /// 重試載入（錯誤狀態時使用）
    func retryLoad() async {
        await loadWorkouts(forceRefresh: true)
    }

    // MARK: - Private Methods

    /// 執行載入訓練列表
    private func performLoadWorkouts(forceRefresh: Bool) async {
        state = .loading

        do {
            // 使用 GetWorkoutsUseCase 載入數據
            let workouts = try await getWorkoutsUseCase.execute(limit: 50, offset: nil)

            // 更新分頁狀態
            hasMore = workouts.count >= 50

            // 更新 UI 狀態
            if workouts.isEmpty {
                state = .empty
            } else {
                state = .loaded(workouts)
            }

            Logger.debug("[WorkoutListVM] ✅ Loaded \(workouts.count) workouts")

        } catch is CancellationError {
            Logger.debug("[WorkoutListVM] Load cancelled")
            // 不更新狀態，保持當前顯示
        } catch {
            state = .error(error.toDomainError())
            Logger.error("[WorkoutListVM] ❌ Load failed: \(error.localizedDescription)")
        }
    }

    /// 執行刷新（下拉刷新）
    private func performRefreshWorkouts() async {
        // 保持當前數據可見，不顯示 loading 狀態

        do {
            // 使用 GetWorkoutsUseCase 刷新數據
            let workouts = try await getWorkoutsUseCase.execute(limit: 50, offset: nil)

            // 更新分頁狀態
            hasMore = workouts.count >= 50

            // 更新 UI 狀態
            if workouts.isEmpty {
                state = .empty
            } else {
                state = .loaded(workouts)
            }

            Logger.debug("[WorkoutListVM] ✅ Refreshed \(workouts.count) workouts")

        } catch is CancellationError {
            Logger.debug("[WorkoutListVM] Refresh cancelled")
        } catch {
            // 刷新失敗不改變當前狀態，只記錄錯誤
            Logger.error("[WorkoutListVM] ❌ Refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Handlers

    /// 處理用戶登出事件
    private func handleUserLogoutEvent() async {
        Logger.debug("[WorkoutListVM] Handling userLogout event")

        // 重置狀態
        state = .loading
        hasMore = false
    }

    // MARK: - Computed Properties (Backward Compatibility)

    /// 訓練列表（向後兼容）
    var workouts: [WorkoutV2] {
        return state.data ?? []
    }

    /// 是否正在載入
    var isLoading: Bool {
        return state.isLoading
    }

    /// 錯誤訊息
    var error: DomainError? {
        return state.error
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 WorkoutListViewModel（Factory - 每次創建新實例）
    @MainActor
    static func makeWorkoutListViewModel() -> WorkoutListViewModel {
        return WorkoutListViewModel()
    }
}
