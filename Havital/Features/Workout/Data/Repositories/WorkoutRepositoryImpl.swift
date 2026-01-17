import Foundation

// MARK: - Workout Repository Implementation
/// 訓練記錄 Repository 實作
/// Data Layer - 協調雙數據源實現雙軌緩存策略
/// ✅ Clean Architecture: 完全使用 RemoteDataSource + LocalDataSource，不依賴 UnifiedWorkoutManager
final class WorkoutRepositoryImpl: WorkoutRepository {

    // MARK: - Singleton (for backwards compatibility)

    static let shared = WorkoutRepositoryImpl()

    // MARK: - Properties

    private let remoteDataSource: WorkoutRemoteDataSource
    private let localDataSource: WorkoutLocalDataSource

    // MARK: - Initialization

    init(remoteDataSource: WorkoutRemoteDataSource = WorkoutRemoteDataSource(),
         localDataSource: WorkoutLocalDataSource = WorkoutLocalDataSource()) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource

        Logger.debug("[WorkoutRepositoryImpl] 初始化完成（雙數據源模式）")
    }

    // MARK: - WorkoutRepository Protocol

    var workoutsDidUpdateNotification: Notification.Name {
        return .workoutsDidUpdate
    }

    // ⚠️ DEPRECATED - NOW USES LocalDataSource for consistency
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] ⚠️ getWorkoutsInDateRange (deprecated) - migrate to async version")

        // ✅ NOW USES LocalDataSource instead of UnifiedWorkoutManager
        guard let allWorkouts = localDataSource.getWorkouts() else {
            return []
        }

        return allWorkouts.filter { workout in
            workout.startDate >= startDate && workout.startDate <= endDate
        }.sorted { $0.endDate > $1.endDate }
    }

    // ⚠️ DEPRECATED - NOW USES LocalDataSource for consistency
    func getAllWorkouts() -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] ⚠️ getAllWorkouts (deprecated) - migrate to async version")

        // ✅ NOW USES LocalDataSource instead of UnifiedWorkoutManager
        return localDataSource.getWorkouts()?.sorted { $0.endDate > $1.endDate } ?? []
    }

    // MARK: - Async Query (LocalDataSource as Single Source of Truth)

    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] getWorkoutsInDateRangeAsync - from \(startDate) to \(endDate)")

        // ✅ Use LocalDataSource as single source
        guard let allWorkouts = localDataSource.getWorkouts() else {
            Logger.debug("[WorkoutRepositoryImpl] No cached workouts, returning empty")
            return []
        }

        // Filter by date range
        let filtered = allWorkouts.filter { workout in
            workout.startDate >= startDate && workout.startDate <= endDate
        }.sorted { $0.endDate > $1.endDate }

        Logger.debug("[WorkoutRepositoryImpl] Found \(filtered.count) workouts in date range")
        return filtered
    }

    func getAllWorkoutsAsync() async -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] getAllWorkoutsAsync")

        // ✅ Use LocalDataSource as single source
        guard let allWorkouts = localDataSource.getWorkouts() else {
            Logger.debug("[WorkoutRepositoryImpl] No cached workouts, returning empty")
            return []
        }

        return allWorkouts.sorted { $0.endDate > $1.endDate }
    }

    // MARK: - Workout List (雙軌緩存策略)

    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] getWorkouts - limit: \(String(describing: limit)), offset: \(String(describing: offset))")

        // Track A: 立即返回緩存（快速顯示）
        if let cachedWorkouts = localDataSource.getWorkouts() {
            Logger.debug("[WorkoutRepositoryImpl] Track A - 返回緩存數據，數量: \(cachedWorkouts.count)")

            // Track B: 背景刷新 API（保持新鮮）
            Task.detached(priority: .background) { [weak self] in
                await self?.backgroundRefreshWorkouts(pageSize: limit)
            }

            return cachedWorkouts
        }

        // 沒有緩存時，直接從 API 載入
        Logger.debug("[WorkoutRepositoryImpl] 無緩存，從 API 載入")
        let workouts = try await remoteDataSource.fetchWorkouts(pageSize: limit, cursor: nil)
        localDataSource.saveWorkouts(workouts)

        return workouts
    }

    func refreshWorkouts() async throws -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] refreshWorkouts - 強制刷新")

        // 強制刷新：跳過緩存，直接從 API 獲取
        let workouts = try await remoteDataSource.fetchWorkouts(pageSize: nil, cursor: nil)
        localDataSource.saveWorkouts(workouts)

        Logger.debug("[WorkoutRepositoryImpl] refreshWorkouts - 完成，數量: \(workouts.count)")
        return workouts
    }

    // MARK: - Pagination (Migrated from UnifiedWorkoutManager)

    func loadInitialWorkouts(pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] loadInitialWorkouts - pageSize: \(pageSize)")

        // Fetch from API
        let workouts = try await remoteDataSource.fetchWorkouts(pageSize: pageSize, cursor: nil)

        // Update cache
        localDataSource.saveWorkouts(workouts)

        // Construct pagination info
        let pagination = PaginationInfo(
            nextCursor: workouts.last?.id,
            prevCursor: nil,
            hasMore: workouts.count >= pageSize,
            hasNewer: false,
            oldestId: workouts.last?.id,
            newestId: workouts.first?.id,
            totalItems: workouts.count,
            pageSize: pageSize
        )

        Logger.debug("[WorkoutRepositoryImpl] loadInitialWorkouts - 完成，數量: \(workouts.count)")
        return WorkoutListResponse(workouts: workouts, pagination: pagination)
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] loadMoreWorkouts - afterCursor: \(afterCursor), pageSize: \(pageSize)")

        // Fetch from API
        let workouts = try await remoteDataSource.fetchWorkouts(pageSize: pageSize, cursor: afterCursor)

        // Merge with existing cache
        if var cachedWorkouts = localDataSource.getWorkouts() {
            cachedWorkouts.append(contentsOf: workouts)
            localDataSource.saveWorkouts(cachedWorkouts)
            Logger.debug("[WorkoutRepositoryImpl] Merged with cache, total: \(cachedWorkouts.count)")
        } else {
            localDataSource.saveWorkouts(workouts)
        }

        // Construct pagination info
        let pagination = PaginationInfo(
            nextCursor: workouts.last?.id,
            prevCursor: afterCursor,
            hasMore: workouts.count >= pageSize,
            hasNewer: false,
            oldestId: workouts.last?.id,
            newestId: workouts.first?.id,
            totalItems: workouts.count,
            pageSize: pageSize
        )

        Logger.debug("[WorkoutRepositoryImpl] loadMoreWorkouts - 完成，返回: \(workouts.count)")
        return WorkoutListResponse(workouts: workouts, pagination: pagination)
    }

    func refreshLatestWorkouts(beforeCursor: String? = nil, pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] refreshLatestWorkouts - beforeCursor: \(String(describing: beforeCursor)), pageSize: \(pageSize)")

        // Fetch from API
        let workouts = try await remoteDataSource.fetchWorkouts(pageSize: pageSize, cursor: nil)

        // Replace cache (not merge)
        localDataSource.saveWorkouts(workouts)

        // Construct pagination info
        let pagination = PaginationInfo(
            nextCursor: workouts.last?.id,
            prevCursor: nil,
            hasMore: workouts.count >= pageSize,
            hasNewer: false,
            oldestId: workouts.last?.id,
            newestId: workouts.first?.id,
            totalItems: workouts.count,
            pageSize: pageSize
        )

        Logger.debug("[WorkoutRepositoryImpl] refreshLatestWorkouts - 完成，數量: \(workouts.count)")
        return WorkoutListResponse(workouts: workouts, pagination: pagination)
    }

    // MARK: - Single Workout

    func getWorkout(id: String) async throws -> WorkoutV2 {
        Logger.debug("[WorkoutRepositoryImpl] getWorkout - id: \(id)")

        // Track A: 先檢查詳細緩存
        if let cachedWorkout = localDataSource.getWorkout(id: id) {
            Logger.debug("[WorkoutRepositoryImpl] Track A - 返回詳細緩存")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.backgroundRefreshSingleWorkout(id: id)
            }

            return cachedWorkout
        }

        // 檢查列表緩存中是否存在
        if let workoutInList = localDataSource.findWorkoutInList(id: id) {
            Logger.debug("[WorkoutRepositoryImpl] 從列表緩存找到")

            // 保存到詳細緩存
            localDataSource.saveWorkout(workoutInList)

            // 背景刷新完整數據
            Task.detached(priority: .background) { [weak self] in
                await self?.backgroundRefreshSingleWorkout(id: id)
            }

            return workoutInList
        }

        // 沒有緩存，從 API 獲取
        Logger.debug("[WorkoutRepositoryImpl] 無緩存，從 API 載入")
        let workout = try await remoteDataSource.fetchWorkout(id: id)
        localDataSource.saveWorkout(workout)

        return workout
    }

    // MARK: - Workout Detail (Full Detail with TimeSeries)

    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        Logger.debug("[WorkoutRepositoryImpl] getWorkoutDetail - id: \(id)")

        // Track A: 先檢查詳情緩存
        if let cachedDetail = localDataSource.getWorkoutDetail(id: id) {
            Logger.debug("[WorkoutRepositoryImpl] Track A - 返回詳情緩存")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.backgroundRefreshWorkoutDetail(id: id)
            }

            return cachedDetail
        }

        // 沒有緩存，從 API 獲取
        Logger.debug("[WorkoutRepositoryImpl] 無詳情緩存，從 API 載入")
        let detail = try await remoteDataSource.fetchWorkoutDetail(id: id)
        localDataSource.saveWorkoutDetail(detail)

        return detail
    }

    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        Logger.debug("[WorkoutRepositoryImpl] refreshWorkoutDetail - id: \(id)")

        // 強制刷新：跳過緩存，直接從 API 獲取
        let detail = try await remoteDataSource.fetchWorkoutDetail(id: id)
        localDataSource.saveWorkoutDetail(detail)

        Logger.debug("[WorkoutRepositoryImpl] refreshWorkoutDetail - 完成")
        return detail
    }

    func clearWorkoutDetailCache(id: String) async {
        Logger.debug("[WorkoutRepositoryImpl] clearWorkoutDetailCache - id: \(id)")
        localDataSource.clearWorkoutDetailCache(id: id)
    }

    // MARK: - Sync & Upload

    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 {
        Logger.debug("[WorkoutRepositoryImpl] syncWorkout - id: \(workout.id)")

        // 將 WorkoutV2 轉換為上傳請求
        let uploadRequest = WorkoutMapper.toUploadRequest(from: workout)

        // 上傳到 API
        let uploadResponse = try await remoteDataSource.uploadWorkout(uploadRequest)

        // 從 API 獲取完整的訓練數據
        let syncedWorkout = try await remoteDataSource.fetchWorkout(id: uploadResponse.id)

        // 更新緩存
        localDataSource.saveWorkout(syncedWorkout)

        // 清空列表緩存，強制下次重新載入
        localDataSource.clearAll()

        Logger.debug("[WorkoutRepositoryImpl] syncWorkout - 完成")
        return syncedWorkout
    }

    func updateTrainingNotes(id: String, notes: String) async throws {
        Logger.debug("[WorkoutRepositoryImpl] updateTrainingNotes - id: \(id)")

        let body: [String: Any] = ["training_notes": notes]
        try await remoteDataSource.updateWorkout(id: id, body: body)

        // 成功後，清除詳情緩存，強制下次重新載入
        localDataSource.clearWorkoutDetailCache(id: id)

        Logger.debug("[WorkoutRepositoryImpl] updateTrainingNotes - 完成")
    }

    // MARK: - Delete

    func deleteWorkout(id: String) async throws {
        Logger.debug("[WorkoutRepositoryImpl] deleteWorkout - id: \(id)")

        // 從 API 刪除
        try await remoteDataSource.deleteWorkout(id: id)

        // 從緩存刪除
        localDataSource.deleteWorkout(id: id)

        Logger.debug("[WorkoutRepositoryImpl] deleteWorkout - 完成")
    }

    // MARK: - Cache Management

    func clearCache() async {
        Logger.debug("[WorkoutRepositoryImpl] clearCache")
        localDataSource.clearAll()
    }

    func preloadData() async {
        Logger.debug("[WorkoutRepositoryImpl] preloadData - 預載入最近訓練")

        do {
            let recentWorkouts = try await remoteDataSource.fetchRecentWorkouts(pageSize: 20)
            localDataSource.saveWorkouts(recentWorkouts)
            Logger.debug("[WorkoutRepositoryImpl] preloadData - 完成，數量: \(recentWorkouts.count)")
        } catch {
            Logger.error("[WorkoutRepositoryImpl] preloadData - 失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Background Refresh Helpers

    /// Generic background refresh helper
    ///
    /// Implements the dual-track caching pattern's Track B (background refresh).
    /// This helper standardizes the background refresh logic across different entity types.
    ///
    /// - Parameters:
    ///   - taskName: Descriptive name for logging (e.g., "workouts", "workout detail")
    ///   - fetch: Async closure that fetches data from remote API
    ///   - save: Closure that saves fetched data to local storage
    ///
    /// **Pattern**:
    /// 1. Fetch data from remote API
    /// 2. Save to local data source
    /// 3. Publish CacheEventBus event
    /// 4. Log success or error
    private func backgroundRefresh<T>(
        taskName: String,
        fetch: () async throws -> T,
        save: (T) -> Void
    ) async {
        do {
            let data = try await fetch()
            save(data)
            Logger.debug("[WorkoutRepositoryImpl] Track B - \(taskName) 背景刷新完成")

            // ✅ Clean Architecture: 只使用 CacheEventBus，不使用 NotificationCenter
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutRepositoryImpl] ✅ 發布 CacheEventBus 事件: \(taskName) refreshed")
        } catch {
            Logger.error("[WorkoutRepositoryImpl] Track B - \(taskName) 背景刷新失敗: \(error.localizedDescription)")
        }
    }

    /// 背景刷新訓練列表
    private func backgroundRefreshWorkouts(pageSize: Int?) async {
        await backgroundRefresh(
            taskName: "訓練列表",
            fetch: { try await self.remoteDataSource.fetchWorkouts(pageSize: pageSize, cursor: nil) },
            save: { workouts in self.localDataSource.saveWorkouts(workouts) }
        )
    }

    /// 背景刷新單個訓練
    private func backgroundRefreshSingleWorkout(id: String) async {
        await backgroundRefresh(
            taskName: "單個訓練",
            fetch: { try await self.remoteDataSource.fetchWorkout(id: id) },
            save: { workout in self.localDataSource.saveWorkout(workout) }
        )
    }

    /// 背景刷新訓練詳情
    private func backgroundRefreshWorkoutDetail(id: String) async {
        await backgroundRefresh(
            taskName: "訓練詳情",
            fetch: { try await self.remoteDataSource.fetchWorkoutDetail(id: id) },
            save: { detail in self.localDataSource.saveWorkoutDetail(detail) }
        )
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {

    /// 註冊 Workout 模組依賴
    func registerWorkoutModule() {
        // 檢查是否已註冊
        guard !isRegistered(WorkoutRepository.self) else {
            return
        }

        // 註冊 Repository
        let repository = WorkoutRepositoryImpl.shared
        register(repository as WorkoutRepository, forProtocol: WorkoutRepository.self)

        Logger.debug("[DI] Workout module registered")
    }
}
