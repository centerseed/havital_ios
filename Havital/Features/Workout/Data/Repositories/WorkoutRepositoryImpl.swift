import Combine
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

    /// Track B cooldown: 背景刷新間隔至少 5 分鐘，避免重複 API 呼叫
    private var lastBackgroundRefreshTime: Date = .distantPast
    private let backgroundRefreshCooldown: TimeInterval = 43200 // 12 小時

    // MARK: - Background Refresh Publisher

    private let refreshSubject = PassthroughSubject<Void, Never>()
    var workoutsDidRefresh: AnyPublisher<Void, Never> {
        refreshSubject.eraseToAnyPublisher()
    }

    private let paginationSubject = PassthroughSubject<PaginationInfo, Never>()
    var workoutsPaginationDidUpdate: AnyPublisher<PaginationInfo, Never> {
        paginationSubject.eraseToAnyPublisher()
    }

    func getCachedPagination() -> PaginationInfo? {
        localDataSource.getPagination()
    }

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
            Task { [weak self] in
                await self?.backgroundRefreshWorkouts(pageSize: limit)
            }

            return cachedWorkouts
        }

        // 沒有緩存時，直接從 API 載入（連同後端分頁狀態一起存）
        Logger.debug("[WorkoutRepositoryImpl] 無緩存，從 API 載入")
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: limit, cursor: nil)
        localDataSource.saveWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        return page.workouts
    }

    func refreshWorkouts() async throws -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] refreshWorkouts - 強制刷新")

        // 強制刷新：跳過緩存，直接從 API 獲取（連同後端分頁狀態一起存）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: nil, cursor: nil)
        localDataSource.saveWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        Logger.debug("[WorkoutRepositoryImpl] refreshWorkouts - 完成，數量: \(page.workouts.count)")
        return page.workouts
    }

    // MARK: - Pagination (Migrated from UnifiedWorkoutManager)

    func loadInitialWorkouts(pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] loadInitialWorkouts - pageSize: \(pageSize)")

        // Fetch from API（含後端真實分頁狀態）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: nil)

        // Update cache（列表 + 分頁）
        localDataSource.saveWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        Logger.debug("[WorkoutRepositoryImpl] loadInitialWorkouts - 完成，數量: \(page.workouts.count)，has_more: \(page.pagination.hasMore)")
        return page
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] loadMoreWorkouts - afterCursor: \(afterCursor), pageSize: \(pageSize)")

        // Fetch from API（含後端真實分頁狀態）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: afterCursor)

        // Merge with existing cache — 依 id 去重，避免重疊分頁/重抓造成同一筆 workout 重複累積
        // （重複會讓 getAllWorkoutsAsync 加總時週里程膨脹）。
        if let cachedWorkouts = localDataSource.getWorkouts() {
            var seen = Set(cachedWorkouts.map { $0.id })
            var merged = cachedWorkouts
            for w in page.workouts where !seen.contains(w.id) {
                seen.insert(w.id)
                merged.append(w)
            }
            localDataSource.saveWorkouts(merged)
            Logger.debug("[WorkoutRepositoryImpl] Merged with cache (deduped), total: \(merged.count)")
        } else {
            localDataSource.saveWorkouts(page.workouts)
        }

        // 分頁狀態以後端為準（has_more 反映「比 afterCursor 更舊的還有沒有」）
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        Logger.debug("[WorkoutRepositoryImpl] loadMoreWorkouts - 完成，返回: \(page.workouts.count)，has_more: \(page.pagination.hasMore)")
        return page
    }

    func refreshLatestWorkouts(beforeCursor: String? = nil, pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] refreshLatestWorkouts - beforeCursor: \(String(describing: beforeCursor)), pageSize: \(pageSize)")

        // Fetch from API（含後端真實分頁狀態）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: nil)

        // Replace cache (not merge)（列表 + 分頁）
        localDataSource.saveWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        Logger.debug("[WorkoutRepositoryImpl] refreshLatestWorkouts - 完成，數量: \(page.workouts.count)")
        return page
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

    func uploadWorkout(_ request: UploadWorkoutRequest) async throws -> UploadWorkoutResponse {
        try await remoteDataSource.uploadWorkout(request)
    }

    func uploadWorkout(_ workoutData: WorkoutData) async throws {
        try await remoteDataSource.uploadWorkout(workoutData)
    }

    func fetchWorkoutSummary(id: String) async throws -> WorkoutSummary {
        try await remoteDataSource.fetchWorkoutSummary(id: id)
    }

    func updateTrainingNotes(id: String, notes: String) async throws {
        Logger.debug("[WorkoutRepositoryImpl] updateTrainingNotes - id: \(id)")

        let body: [String: Any] = ["training_notes": notes]
        try await remoteDataSource.updateWorkout(id: id, body: body)

        // 成功後，清除詳情緩存，強制下次重新載入
        localDataSource.clearWorkoutDetailCache(id: id)

        Logger.debug("[WorkoutRepositoryImpl] updateTrainingNotes - 完成")
    }

    func updateRPE(id: String, rpe: Int?) async throws {
        Logger.debug("[WorkoutRepositoryImpl] updateRPE - id: \(id)")

        let body: [String: Any] = ["rpe": rpe.map { $0 as Any } ?? NSNull()]
        try await remoteDataSource.updateWorkout(id: id, body: body)

        localDataSource.clearWorkoutDetailCache(id: id)

        Logger.debug("[WorkoutRepositoryImpl] updateRPE - 完成")
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

    func invalidateRefreshCooldown() {
        Logger.debug("[WorkoutRepositoryImpl] invalidateRefreshCooldown - 收到推播，重置 cooldown")
        lastBackgroundRefreshTime = .distantPast
    }

    func clearCache() async {
        Logger.debug("[WorkoutRepositoryImpl] clearCache")
        localDataSource.clearAll()
        lastBackgroundRefreshTime = .distantPast // 重置 cooldown，允許下次立即刷新
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
    /// 3. Signal via refreshSubject (ViewModel republishes to EventBus)
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

            refreshSubject.send()
        } catch {
            Logger.error("[WorkoutRepositoryImpl] Track B - \(taskName) 背景刷新失敗: \(error.localizedDescription)")
        }
    }

    /// 背景刷新訓練列表（含 cooldown 保護）
    private func backgroundRefreshWorkouts(pageSize: Int?) async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBackgroundRefreshTime)
        if elapsed < backgroundRefreshCooldown {
            Logger.debug("[WorkoutRepositoryImpl] Track B - 跳過背景刷新（距上次 \(Int(elapsed))s，cooldown \(Int(backgroundRefreshCooldown))s）")
            return
        }
        lastBackgroundRefreshTime = now

        // Track B：抓整頁（含後端分頁狀態），列表 + 分頁一起更新並發訊號。
        do {
            let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: nil)
            localDataSource.saveWorkouts(page.workouts)
            localDataSource.savePagination(page.pagination)
            Logger.debug("[WorkoutRepositoryImpl] Track B - 訓練列表 背景刷新完成，數量: \(page.workouts.count)，has_more: \(page.pagination.hasMore)")
            refreshSubject.send()
            paginationSubject.send(page.pagination)
        } catch {
            Logger.error("[WorkoutRepositoryImpl] Track B - 訓練列表 背景刷新失敗: \(error.localizedDescription)")
        }
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
