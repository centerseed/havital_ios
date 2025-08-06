import SwiftUI
import HealthKit
import UserNotifications

class TrainingRecordViewModel: ObservableObject, TaskManageable {
    // MARK: - Published Properties
    @Published var workouts: [WorkoutV2] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var hasMoreData = true
    @Published var hasNewerData = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let workoutService = WorkoutV2Service.shared
    private let cacheManager = WorkoutV2CacheManager.shared
    
    // 分頁狀態
    private var newestId: String?
    private var oldestId: String?
    private var currentPageSize = 10
    
    // TaskManageable
    let taskRegistry = TaskRegistry()
    
    // MARK: - Initialization
    
    init() {
        loadCachedWorkouts()
    }
    
    // MARK: - Main Loading Methods
    
    /// 初次載入運動記錄 - 優先從快取載入，背景更新
    func loadWorkouts(healthKitManager: HealthKitManager? = nil) async {
        await executeTask(id: TaskID("load_workouts")) {
            // 如果快取中有資料，直接在背景更新，不顯示 loading
            if !self.workouts.isEmpty {
                await self.performBackgroundUpdate()
            } else {
                // 只有在沒有快取資料時才顯示 loading 狀態
                await self.performInitialLoad()
            }
        }
    }
    
    /// 下拉刷新 - 載入最新資料
    func refreshWorkouts(healthKitManager: HealthKitManager? = nil) async {
        await executeTask(id: TaskID("refresh_workouts")) {
            await self.performRefresh()
        }
    }
    
    /// 載入更多記錄 - 向下滾動
    func loadMoreWorkouts() async {
        await executeTask(id: TaskID("load_more_workouts")) {
            await self.performLoadMore()
        }
    }
    
    // MARK: - Private Implementation
    
    /// 背景更新資料（不顯示 loading 狀態）
    private func performBackgroundUpdate() async {
        do {
            try Task.checkCancellation()
            
            // 如果有資料，先檢查是否有更新的記錄
            if let newestId = newestId {
                let refreshResponse = try await workoutService.refreshLatestWorkouts(
                    beforeCursor: newestId,
                    pageSize: currentPageSize
                )
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    let newWorkouts = refreshResponse.data.workouts
                    
                    if !newWorkouts.isEmpty {
                        // 新資料插入頂端
                        let mergedWorkouts = mergeWorkouts(existing: self.workouts, new: newWorkouts, insertAtTop: true)
                        self.workouts = mergedWorkouts.sorted { $0.endDate > $1.endDate }
                        
                        // 只更新 hasNewerData，保留其他分頁狀態
                        self.hasNewerData = refreshResponse.data.pagination.hasNewer
                        self.updatePaginationState() // 更新游標
                        
                        // 快取資料和分頁資訊
                        let paginationInfo = CachedPaginationInfo(
                            hasMoreData: self.hasMoreData,
                            hasNewerData: self.hasNewerData,
                            newestId: self.newestId,
                            oldestId: self.oldestId
                        )
                        self.cacheManager.cacheWorkoutList(self.workouts, paginationInfo: paginationInfo)
                        
                        print("背景更新完成：\(newWorkouts.count) 筆新記錄，總計 \(self.workouts.count) 筆")
                    } else {
                        print("背景更新：沒有新記錄")
                    }
                }
            } else {
                // 如果沒有游標，執行初次載入
                let response = try await workoutService.loadInitialWorkouts(pageSize: currentPageSize)
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    let newWorkouts = response.data.workouts
                    
                    if !newWorkouts.isEmpty {
                        self.workouts = newWorkouts.sorted { $0.endDate > $1.endDate }
                        self.updatePaginationState(from: response.data.pagination)
                        
                        let paginationInfo = CachedPaginationInfo(
                            hasMoreData: self.hasMoreData,
                            hasNewerData: self.hasNewerData,
                            newestId: self.newestId,
                            oldestId: self.oldestId
                        )
                        self.cacheManager.cacheWorkoutList(self.workouts, paginationInfo: paginationInfo)
                        
                        print("背景初次載入完成：\(newWorkouts.count) 筆記錄")
                    }
                }
            }
            
        } catch is CancellationError {
            print("TrainingRecordViewModel: 背景更新任務被取消")
        } catch {
            print("背景更新失敗: \(error.localizedDescription)")
            // 背景更新失敗不影響 UI 狀態
        }
    }
    
    /// 從快取載入資料
    private func loadCachedWorkouts() {
        if let cachedWorkouts = cacheManager.getCachedWorkoutList(), !cachedWorkouts.isEmpty {
            workouts = removeDuplicateWorkouts(cachedWorkouts).sorted { $0.endDate > $1.endDate }
            updatePaginationState()
            
            // 嘗試載入快取的分頁資訊
            if let cachedPagination = cacheManager.getCachedPaginationInfo() {
                hasMoreData = cachedPagination.hasMoreData
                hasNewerData = cachedPagination.hasNewerData
                newestId = cachedPagination.newestId
                oldestId = cachedPagination.oldestId
                print("TrainingRecordViewModel: 從快取載入分頁資訊")
            } else {
                // 快取載入時，假設還有更多資料（保守估計）
                hasMoreData = workouts.count >= currentPageSize
                hasNewerData = false
            }
            
            print("TrainingRecordViewModel: 從快取載入 \(workouts.count) 筆記錄")
        }
    }
    
    /// 執行初次載入
    private func performInitialLoad() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 檢查是否被取消
            try Task.checkCancellation()
            
            let response = try await workoutService.loadInitialWorkouts(pageSize: currentPageSize)
            
            try Task.checkCancellation()
            
            await MainActor.run {
                let newWorkouts = response.data.workouts
                
                if !newWorkouts.isEmpty {
                    // 與現有資料合併並去重
                    let allWorkouts = mergeWorkouts(existing: self.workouts, new: newWorkouts)
                    self.workouts = allWorkouts.sorted { $0.endDate > $1.endDate }
                    
                    // 更新分頁狀態
                    self.updatePaginationState(from: response.data.pagination)
                    
                    // 快取資料和分頁資訊
                    let paginationInfo = CachedPaginationInfo(
                        hasMoreData: self.hasMoreData,
                        hasNewerData: self.hasNewerData,
                        newestId: self.newestId,
                        oldestId: self.oldestId
                    )
                    self.cacheManager.cacheWorkoutList(self.workouts, paginationInfo: paginationInfo)
                    
                    print("初次載入完成：\(newWorkouts.count) 筆新記錄，總計 \(self.workouts.count) 筆")
                } else {
                    print("初次載入：沒有新資料")
                }
                
                self.isLoading = false
            }
            
        } catch is CancellationError {
            print("TrainingRecordViewModel: 初次載入任務被取消")
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("初次載入失敗: \(error.localizedDescription)")
        }
    }
    
    /// 執行下拉刷新
    private func performRefresh() async {
        await MainActor.run {
            isRefreshing = true
            errorMessage = nil
        }
        
        do {
            try Task.checkCancellation()
            
            let response = try await workoutService.refreshLatestWorkouts(
                beforeCursor: newestId,
                pageSize: currentPageSize
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                let newWorkouts = response.data.workouts
                
                if !newWorkouts.isEmpty {
                    // 新資料插入頂端
                    let mergedWorkouts = mergeWorkouts(existing: self.workouts, new: newWorkouts, insertAtTop: true)
                    self.workouts = mergedWorkouts.sorted { $0.endDate > $1.endDate }
                    
                    // 更新分頁狀態
                    self.updatePaginationState(from: response.data.pagination)
                    
                    // 快取資料和分頁資訊
                    let paginationInfo = CachedPaginationInfo(
                        hasMoreData: self.hasMoreData,
                        hasNewerData: self.hasNewerData,
                        newestId: self.newestId,
                        oldestId: self.oldestId
                    )
                    self.cacheManager.cacheWorkoutList(self.workouts, paginationInfo: paginationInfo)
                    
                    print("刷新完成：\(newWorkouts.count) 筆新記錄，總計 \(self.workouts.count) 筆")
                } else {
                    print("刷新完成：沒有新資料")
                }
                
                self.isRefreshing = false
            }
            
        } catch is CancellationError {
            print("TrainingRecordViewModel: 刷新任務被取消")
            await MainActor.run {
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isRefreshing = false
            }
            print("刷新失敗: \(error.localizedDescription)")
        }
    }
    
    /// 執行載入更多
    private func performLoadMore() async {
        guard hasMoreData, let oldestId = oldestId else { return }
        
        await MainActor.run {
            isLoadingMore = true
            errorMessage = nil
        }
        
        do {
            try Task.checkCancellation()
            
            let response = try await workoutService.loadMoreWorkouts(
                afterCursor: oldestId,
                pageSize: currentPageSize
            )
            
            try Task.checkCancellation()
            
            await MainActor.run {
                let newWorkouts = response.data.workouts
                
                if !newWorkouts.isEmpty {
                    // 新資料附加到底端
                    let mergedWorkouts = mergeWorkouts(existing: self.workouts, new: newWorkouts, insertAtTop: false)
                    self.workouts = mergedWorkouts.sorted { $0.endDate > $1.endDate }
                    
                    // 更新分頁狀態
                    self.updatePaginationState(from: response.data.pagination)
                    
                    // 快取資料和分頁資訊
                    let paginationInfo = CachedPaginationInfo(
                        hasMoreData: self.hasMoreData,
                        hasNewerData: self.hasNewerData,
                        newestId: self.newestId,
                        oldestId: self.oldestId
                    )
                    self.cacheManager.cacheWorkoutList(self.workouts, paginationInfo: paginationInfo)
                    
                    print("載入更多完成：\(newWorkouts.count) 筆記錄，總計 \(self.workouts.count) 筆")
                }
                
                self.isLoadingMore = false
            }
            
        } catch is CancellationError {
            print("TrainingRecordViewModel: 載入更多任務被取消")
            await MainActor.run {
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingMore = false
            }
            print("載入更多失敗: \(error.localizedDescription)")
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
    
    // MARK: - Cleanup
    
    deinit {
        cancelAllTasks()
        print("TrainingRecordViewModel 被釋放")
    }
}
