import SwiftUI
import HealthKit
import UserNotifications

/// TrainingRecordViewModel - Clean Architecture Presentation Layer
/// 依賴 WorkoutRepository Protocol，負責分頁邏輯和 UI 狀態管理
/// Phase 3 重構：使用 ViewState 統一狀態管理，整合 CacheEventBus
class TrainingRecordViewModel: ObservableObject, TaskManageable {

    // MARK: - ViewState (主要狀態)

    @Published private(set) var state: ViewState<[WorkoutV2]> = .loading

    // MARK: - Published Properties (分頁與輔助狀態)

    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var hasMoreData = true
    @Published var hasNewerData = false
    @Published var errorMessage: String?

    // MARK: - Backward Compatibility Computed Properties

    /// 訓練記錄列表（向後兼容）
    var workouts: [WorkoutV2] {
        state.data ?? []
    }

    /// 是否正在載入（向後兼容）
    var isLoading: Bool {
        state.isLoading
    }

    // MARK: - Dependencies

    private let repository: WorkoutRepository

    // MARK: - Private Properties

    // 分頁狀態
    private var newestId: String?
    private var oldestId: String?
    private var currentPageSize = 10

    // TaskManageable
    let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    init(repository: WorkoutRepository = WorkoutRepositoryImpl.shared) {
        self.repository = repository

        syncFromRepository()
        setupObservers()
        Logger.debug("[TrainingRecordViewModel] 初始化完成 - Clean Architecture 模式")
    }
    
    // MARK: - Main Loading Methods

    /// 初次載入運動記錄 - 使用 Repository 雙軌緩存策略
    func loadWorkouts(healthKitManager: HealthKitManager? = nil) async {
        Logger.debug("[TrainingRecordViewModel] loadWorkouts - 使用 Repository 雙軌緩存")

        await executeTask(id: TaskID("load_workouts")) {
            do {
                // ✅ Track A: 先嘗試從 Repository 獲取數據（會優先返回緩存）
                let cachedWorkouts = await MainActor.run { self.workouts }

                if cachedWorkouts.isEmpty {
                    // 無緩存時，設置 loading 狀態
                    await MainActor.run {
                        self.state = .loading
                        self.errorMessage = nil
                    }
                }

                // 從 Repository 獲取數據（雙軌緩存策略由 Repository 實現）
                let workouts = try await self.repository.getWorkouts(limit: self.currentPageSize, offset: nil)

                await MainActor.run {
                    if workouts.isEmpty {
                        self.state = .empty
                    } else {
                        self.state = .loaded(workouts.sorted { $0.endDate > $1.endDate })
                        self.updatePaginationState()
                    }
                    Logger.debug("[TrainingRecordViewModel] 載入完成，數量: \(workouts.count)")
                }

            } catch is CancellationError {
                Logger.debug("[TrainingRecordViewModel] 載入任務被取消")
            } catch {
                await MainActor.run {
                    self.state = .error(error.toDomainError())
                    self.errorMessage = error.localizedDescription
                }
                Logger.error("[TrainingRecordViewModel] 載入失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 下拉刷新 - 使用 Repository 強制刷新
    func refreshWorkouts(healthKitManager: HealthKitManager? = nil) async {
        await executeTask(id: TaskID("refresh_workouts")) {
            await MainActor.run {
                self.isRefreshing = true
                self.errorMessage = nil
            }

            do {
                // 強制刷新（跳過緩存）
                let workouts = try await self.repository.refreshWorkouts()

                await MainActor.run {
                    if workouts.isEmpty {
                        self.state = .empty
                    } else {
                        self.state = .loaded(workouts.sorted { $0.endDate > $1.endDate })
                        self.updatePaginationState()
                    }
                    self.isRefreshing = false
                    Logger.debug("[TrainingRecordViewModel] 刷新完成，數量: \(workouts.count)")
                }

            } catch is CancellationError {
                Logger.debug("[TrainingRecordViewModel] 刷新任務被取消")
                await MainActor.run { self.isRefreshing = false }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRefreshing = false
                }
                Logger.error("[TrainingRecordViewModel] 刷新失敗: \(error.localizedDescription)")
            }
        }
    }
    
    /// 載入更多記錄 - 使用分頁API
    func loadMoreWorkouts() async {
        await executeTask(id: TaskID("load_more_workouts")) {
            await self.performLoadMore()
        }
    }
    
    // MARK: - Private Implementation

    /// 簡化的分頁載入更多邏輯 - 使用 Repository 的分頁API
    private func performLoadMore() async {
        Logger.debug("[TrainingRecordViewModel] performLoadMore - hasMoreData: \(hasMoreData), oldestId: \(oldestId ?? "nil")")

        guard hasMoreData, let oldestId = oldestId else {
            Logger.debug("[TrainingRecordViewModel] 載入更多條件不滿足")
            return
        }

        await MainActor.run {
            isLoadingMore = true
            errorMessage = nil
        }

        do {
            // ✅ 使用 Repository 的分頁 API（已遷移）
            let response = try await repository.loadMoreWorkouts(
                afterCursor: oldestId,
                pageSize: currentPageSize
            )

            await MainActor.run {
                let newWorkouts = response.workouts

                if !newWorkouts.isEmpty {
                    // 獲取當前的 workouts
                    let currentWorkouts = self.workouts

                    // 新資料附加到底端
                    let mergedWorkouts = self.mergeWorkouts(existing: currentWorkouts, new: newWorkouts, insertAtTop: false)
                    self.state = .loaded(mergedWorkouts.sorted { $0.endDate > $1.endDate })

                    // 更新分頁狀態
                    self.updatePaginationState(from: response.pagination)

                    Logger.debug("[TrainingRecordViewModel] 載入更多完成：\(newWorkouts.count) 筆記錄，總計 \(self.workouts.count) 筆")
                } else {
                    Logger.debug("[TrainingRecordViewModel] 載入更多：沒有新記錄")
                }

                self.isLoadingMore = false
            }

        } catch is CancellationError {
            Logger.debug("[TrainingRecordViewModel] 載入更多任務被取消")
            await MainActor.run {
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingMore = false
            }
            Logger.error("[TrainingRecordViewModel] 載入更多失敗: \(error.localizedDescription)")
        }
    }
    
    /// 使用 Repository 的數據作為初始狀態（同步版本 - 用於 init）
    private func syncFromRepository() {
        let repositoryWorkouts = repository.getAllWorkouts()

        guard !repositoryWorkouts.isEmpty else {
            Logger.debug("[TrainingRecordViewModel] Repository 沒有緩存數據，使用預設狀態")
            state = .loading
            return
        }

        // 更新狀態
        state = .loaded(repositoryWorkouts.sorted { $0.endDate > $1.endDate })

        // 更新分頁狀態
        updatePaginationState()

        Logger.debug("[TrainingRecordViewModel] 已從 Repository 同步 \(repositoryWorkouts.count) 筆記錄")
    }

    /// 異步版本 - 從 Repository 同步數據
    private func syncFromRepositoryAsync() async {
        await MainActor.run {
            let repositoryWorkouts = self.repository.getAllWorkouts()

            if repositoryWorkouts.isEmpty {
                Logger.debug("[TrainingRecordViewModel] Repository 沒有緩存數據")
                return
            }

            // 更新狀態
            self.state = .loaded(repositoryWorkouts.sorted { $0.endDate > $1.endDate })

            // 更新分頁狀態
            self.updatePaginationState()

            Logger.debug("[TrainingRecordViewModel] [Async] 已從 Repository 同步 \(repositoryWorkouts.count) 筆記錄")
        }
    }
    
    // MARK: - Helper Methods
    
    /// 合併運動記錄並去重
    private func mergeWorkouts(existing: [WorkoutV2], new: [WorkoutV2], insertAtTop: Bool = false) -> [WorkoutV2] {
        let allWorkouts = insertAtTop ? new + existing : existing + new
        return removeDuplicateWorkouts(allWorkouts)
    }
    
    /// 去除重複的運動記錄（基於 ID）
    private func removeDuplicateWorkouts(_ workouts: [WorkoutV2]) -> [WorkoutV2] {
        var uniqueWorkouts: [WorkoutV2] = []
        var seenIds: Set<String> = []
        
        for workout in workouts {
            if !seenIds.contains(workout.id) {
                seenIds.insert(workout.id)
                uniqueWorkouts.append(workout)
            }
        }
        
        return uniqueWorkouts
    }
    
    /// 更新分頁狀態
    private func updatePaginationState(from pagination: PaginationInfo? = nil) {
        if let pagination = pagination {
            hasMoreData = pagination.hasMore
            hasNewerData = pagination.hasNewer
        }
        
        // 更新游標
        if !workouts.isEmpty {
            newestId = workouts.first?.id
            oldestId = workouts.last?.id
        }
    }
    
    // MARK: - Computed Properties
    
    /// 運動記錄總數
    var totalWorkoutsCount: Int {
        return workouts.count
    }
    
    /// 是否有運動記錄
    var hasWorkouts: Bool {
        return !workouts.isEmpty
    }
    
    /// 最新的運動記錄
    var latestWorkout: WorkoutV2? {
        return workouts.first
    }
    
    // MARK: - Utility Methods
    
    /// 獲取指定日期範圍的運動記錄
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        return workouts.filter { workout in
            let workoutStartDate = workout.startDate
            return workoutStartDate >= startDate && workoutStartDate <= endDate
        }.sorted { $0.endDate > $1.endDate }
    }
    
    /// 獲取特定類型的運動記錄
    func getWorkoutsByType(_ activityType: String) -> [WorkoutV2] {
        return workouts.filter { $0.activityType == activityType }
            .sorted { $0.endDate > $1.endDate }
    }
    
    /// 計算總距離
    func getTotalDistance(for activityType: String? = nil) -> Double {
        let filteredWorkouts = activityType != nil ? getWorkoutsByType(activityType!) : workouts
        return filteredWorkouts.compactMap { $0.distance }.reduce(0, +)
    }
    
    /// 計算總時長
    func getTotalDuration(for activityType: String? = nil) -> TimeInterval {
        let filteredWorkouts = activityType != nil ? getWorkoutsByType(activityType!) : workouts
        return filteredWorkouts.map { $0.duration }.reduce(0, +)
    }
    
    // MARK: - Event Observers

    /// 設置觀察者（NotificationCenter + CacheEventBus）
    private func setupObservers() {
        // 監聽 Repository 的數據更新（使用 NotificationCenter）
        NotificationCenter.default.addObserver(
            forName: repository.workoutsDidUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { [weak self] in
                // 檢查是否包含已刪除的 workout ID
                if let deletedWorkoutId = notification.userInfo?["deletedWorkoutId"] as? String {
                    Logger.debug("[TrainingRecordViewModel] 收到刪除通知 - 移除 workout: \(deletedWorkoutId)")
                    await self?.removeDeletedWorkout(id: deletedWorkoutId)
                } else {
                    // 一般數據更新，從 Repository 同步
                    await self?.syncFromRepositoryViaNotification()
                }
            }
        }

        // 監聽 CacheEventBus 事件
        setupCacheEventBusObservers()
    }

    /// 設置 CacheEventBus 事件訂閱
    private func setupCacheEventBusObservers() {
        // 訂閱 Onboarding 完成事件
        CacheEventBus.shared.subscribe(forIdentifier: cacheIdentifier) { [weak self] event in
            guard let self = self else { return }

            switch event {
            case .onboardingCompleted:
                Logger.debug("[TrainingRecordViewModel] 收到 Onboarding 完成事件，清除緩存並重新載入")
                Task { @MainActor in
                    await self.repository.clearCache()
                    await self.loadWorkouts()
                }

            case .userLogout:
                Logger.debug("[TrainingRecordViewModel] 收到用戶登出事件，清除數據")
                Task { @MainActor in
                    await self.repository.clearCache()
                    self.state = .empty
                    self.hasMoreData = true
                    self.hasNewerData = false
                    self.newestId = nil
                    self.oldestId = nil
                }

            case .dataChanged(let dataType) where dataType == .workouts:
                Logger.debug("[TrainingRecordViewModel] 收到 Workout 數據變更事件，刷新列表")
                Task {
                    await self.syncFromRepositoryAsync()
                }

            default:
                break
            }
        }
    }

    /// CacheEventBus 訂閱標識符
    private var cacheIdentifier: String {
        return "TrainingRecordViewModel"
    }

    /// 立即移除已刪除的 workout（不需要重新刷新）
    /// - Parameter id: 要移除的 workout ID
    private func removeDeletedWorkout(id: String) async {
        await MainActor.run {
            guard case .loaded(var currentWorkouts) = self.state else { return }

            let beforeCount = currentWorkouts.count
            currentWorkouts.removeAll { $0.id == id }
            let afterCount = currentWorkouts.count

            if beforeCount > afterCount {
                if currentWorkouts.isEmpty {
                    self.state = .empty
                } else {
                    self.state = .loaded(currentWorkouts)
                }
                // 更新分頁狀態
                self.updatePaginationState()
                Logger.debug("[TrainingRecordViewModel] 已從列表中移除 workout，前: \(beforeCount) 筆，後: \(afterCount) 筆")
            } else {
                Logger.debug("[TrainingRecordViewModel] workout 未在列表中找到，可能已被移除")
            }
        }
    }

    /// 從 Repository 同步數據（NotificationCenter 調用版本）
    private func syncFromRepositoryViaNotification() async {
        await MainActor.run {
            let repositoryWorkouts = self.repository.getAllWorkouts()

            if repositoryWorkouts.isEmpty {
                Logger.debug("[TrainingRecordViewModel] [Notification] Repository 沒有數據，跳過同步")
                return
            }

            // 更新狀態
            self.state = .loaded(repositoryWorkouts.sorted { $0.endDate > $1.endDate })

            // 更新分頁狀態
            self.updatePaginationState()

            Logger.debug("[TrainingRecordViewModel] [Notification] 已從 Repository 同步 \(repositoryWorkouts.count) 筆記錄")
        }
    }
    
    // MARK: - Cleanup

    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
        CacheEventBus.shared.unsubscribe(forIdentifier: cacheIdentifier)
        Logger.debug("[TrainingRecordViewModel] 被釋放")
    }
}