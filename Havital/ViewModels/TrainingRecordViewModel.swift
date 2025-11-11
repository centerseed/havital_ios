import SwiftUI
import HealthKit
import UserNotifications

/// TrainingRecordViewModel - 數據代理模式
/// 作為 UnifiedWorkoutManager 的 UI 層包裝器，負責分頁邏輯和UI狀態管理
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
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared
    
    // 分頁狀態
    private var newestId: String?
    private var oldestId: String?
    private var currentPageSize = 10
    
    // TaskManageable
    let taskRegistry = TaskRegistry()
    
    // MARK: - Initialization
    
    init() {
        syncFromUnifiedWorkoutManager()
        setupUnifiedWorkoutManagerObserver()
        print("🚀 TrainingRecordViewModel 初始化完成 - 使用數據代理模式")
    }
    
    // MARK: - Main Loading Methods
    
    /// 初次載入運動記錄 - 直接委派給 UnifiedWorkoutManager
    func loadWorkouts(healthKitManager: HealthKitManager? = nil) async {
        print("🎯 loadWorkouts 被調用 - 委派給 UnifiedWorkoutManager")

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        await executeTask(id: TaskID("load_workouts")) {
            // ✅ 智能載入邏輯：
            // 1. 先同步現有數據（如果有）
            await self.syncFromUnifiedWorkoutManagerAsync()

            // 2. 如果沒有數據，強制從 API 載入
            if await MainActor.run(body: { self.workouts.isEmpty }) {
                print("🎯 沒有緩存數據，強制從 API 載入")
                await self.unifiedWorkoutManager.forceRefreshFromAPI()
                await self.syncFromUnifiedWorkoutManagerAsync()
            } else {
                print("🎯 已有 \(await MainActor.run(body: { self.workouts.count })) 筆緩存數據")
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    /// 下拉刷新 - 委派給 UnifiedWorkoutManager
    func refreshWorkouts(healthKitManager: HealthKitManager? = nil) async {
        await executeTask(id: TaskID("refresh_workouts")) {
            await MainActor.run {
                self.isRefreshing = true
                self.errorMessage = nil
            }

            // 委派給 UnifiedWorkoutManager 刷新
            await self.unifiedWorkoutManager.refreshWorkouts()

            // 同步數據（使用異步版本）
            await self.syncFromUnifiedWorkoutManagerAsync()

            await MainActor.run {
                self.isRefreshing = false
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
    
    /// 簡化的分頁載入更多邏輯 - 直接使用 UnifiedWorkoutManager 提供的分頁API
    private func performLoadMore() async {
        print("📅 performLoadMore 開始 - hasMoreData: \(hasMoreData), oldestId: \(oldestId ?? "nil")")
        
        guard hasMoreData, let oldestId = oldestId else {
            print("❌ 載入更多條件不滿足 - hasMoreData: \(hasMoreData), oldestId: \(oldestId ?? "nil")")
            return
        }
        
        await MainActor.run {
            isLoadingMore = true
            errorMessage = nil
        }
        
        do {
            // 使用 UnifiedWorkoutManager 的分頁API
            let response = try await unifiedWorkoutManager.loadMoreWorkouts(
                afterCursor: oldestId,
                pageSize: currentPageSize
            )
            
            await MainActor.run {
                let newWorkouts = response.workouts
                
                if !newWorkouts.isEmpty {
                    // 新資料附加到底端
                    let mergedWorkouts = mergeWorkouts(existing: self.workouts, new: newWorkouts, insertAtTop: false)
                    self.workouts = mergedWorkouts.sorted { $0.endDate > $1.endDate }
                    
                    // 更新分頁狀態
                    self.updatePaginationState(from: response.pagination)
                    
                    print("📅 載入更多完成：\(newWorkouts.count) 筆記錄，總計 \(self.workouts.count) 筆")
                } else {
                    print("📅 載入更多：沒有新記錄")
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
    
    /// 使用 UnifiedWorkoutManager 的數據作為初始狀態（同步版本 - 用於 init）
    private func syncFromUnifiedWorkoutManager() {
        let managerWorkouts = unifiedWorkoutManager.workouts

        guard !managerWorkouts.isEmpty else {
            print("🔄 UnifiedWorkoutManager 沒有數據，使用預設狀態")
            return
        }

        // 更新本地數據
        self.workouts = managerWorkouts.sorted { $0.endDate > $1.endDate }

        // 更新分頁狀態
        self.updatePaginationState()

        print("🔄 已從 UnifiedWorkoutManager 同步 \(managerWorkouts.count) 筆記錄")
    }

    /// 異步版本 - 確保在 MainActor 上執行並正確讀取數據
    private func syncFromUnifiedWorkoutManagerAsync() async {
        await MainActor.run {
            let managerWorkouts = self.unifiedWorkoutManager.workouts

            if managerWorkouts.isEmpty {
                print("🔄 UnifiedWorkoutManager 沒有數據")
                return
            }

            // 更新本地數據
            self.workouts = managerWorkouts.sorted { $0.endDate > $1.endDate }

            // 更新分頁狀態
            self.updatePaginationState()

            print("🔄 [Async] 已從 UnifiedWorkoutManager 同步 \(managerWorkouts.count) 筆記錄")
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
    
    // MARK: - UnifiedWorkoutManager Integration
    
    /// 設置 UnifiedWorkoutManager 觀察者
    private func setupUnifiedWorkoutManagerObserver() {
        // 監聽 UnifiedWorkoutManager 的數據更新
        NotificationCenter.default.addObserver(
            forName: .workoutsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { [weak self] in
                // 檢查是否包含已刪除的 workout ID
                if let deletedWorkoutId = notification.userInfo?["deletedWorkoutId"] as? String {
                    print("📝 收到刪除通知 - 移除 workout: \(deletedWorkoutId)")
                    await self?.removeDeletedWorkout(id: deletedWorkoutId)
                } else {
                    // 一般數據更新，從 UnifiedWorkoutManager 同步
                    await self?.syncFromUnifiedWorkoutManagerViaNotification()
                }
            }
        }
    }

    /// 立即移除已刪除的 workout（不需要重新刷新）
    /// - Parameter id: 要移除的 workout ID
    private func removeDeletedWorkout(id: String) async {
        await MainActor.run {
            let beforeCount = self.workouts.count
            self.workouts.removeAll { $0.id == id }
            let afterCount = self.workouts.count

            if beforeCount > afterCount {
                // 更新分頁狀態
                self.updatePaginationState()
                print("✅ 已從列表中移除 workout，前: \(beforeCount) 筆，後: \(afterCount) 筆")
            } else {
                print("⚠️ workout 未在列表中找到，可能已被移除")
            }
        }
    }
    
    /// 從 UnifiedWorkoutManager 同步數據（NotificationCenter 調用版本）
    private func syncFromUnifiedWorkoutManagerViaNotification() async {
        await MainActor.run {
            let managerWorkouts = self.unifiedWorkoutManager.workouts

            if managerWorkouts.isEmpty {
                print("🔄 [Notification] UnifiedWorkoutManager 沒有數據，跳過同步")
                return
            }

            // 更新本地數據
            self.workouts = managerWorkouts.sorted { $0.endDate > $1.endDate }

            // 更新分頁狀態
            self.updatePaginationState()

            print("🔄 [Notification] 已從 UnifiedWorkoutManager 同步 \(managerWorkouts.count) 筆記錄")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
        print("TrainingRecordViewModel 被釋放")
    }
}