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

    /// 「往前補史已到底」水位（持久化）。
    /// ⚠️ 只由 ensureMonthLoaded 的「往前補史」在後端回 hasMore=false 時設定 true；
    ///    「刷新頂端」(cursor:nil) 永遠回 hasMore=true，碰不到此水位 —— 否則會把「已到底」洗掉、
    ///    導致比第一筆訓練還舊的空月份每次都重抓到底。登出 clearAll 時重置。
    private let backfillReachedEndKey = "workout_backfill_reached_end"
    private var backfillReachedEnd: Bool {
        get { UserDefaults.standard.bool(forKey: backfillReachedEndKey) }
        set { UserDefaults.standard.set(newValue, forKey: backfillReachedEndKey) }
    }

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

    func getLatestWorkout() async throws -> WorkoutV2? {
        // 有緩存 → 直接讀最新一筆（不打 API、不動緩存）。
        if let cached = localDataSource.getWorkouts(), !cached.isEmpty {
            return cached.sorted { $0.endDate > $1.endDate }.first
        }
        // 冷緩存 → 抓「合理整頁」種子緩存（20 筆），絕不只存 1 筆污染列表。
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: 20, cursor: nil)
        localDataSource.upsertWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)
        return page.workouts.sorted { $0.endDate > $1.endDate }.first
    }

    /// 確保某月已補滿（訓練日曆修缺口）—— 第一性原理版：
    /// 1) 近期月份：刷新最新一頁（catch 新；不動補史水位）。單次錯誤 → 下次開自動重試。
    /// 2) 過去月份：只在「未涵蓋且未到底」時一次性往前補史；補滿（API 時間驗證）或到底（hasMore=false）後不再抓。
    /// 覆蓋只用可驗證事實宣告（緩存最舊 < 月初 / 後端 hasMore=false）→ 單次錯誤絕不造成永久缺口。
    func ensureMonthLoaded(year: Int, month: Int) async {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let monthStart = Calendar.current.date(from: comps) else { return }

        func oldestCachedDate() -> Date? {
            localDataSource.getWorkouts()?.map { $0.endDate }.min()
        }

        // 冷緩存：先抓最新一頁種子（建立緩存與 frontier 游標）。
        if localDataSource.getWorkouts()?.isEmpty ?? true {
            await refreshTopPage(seedFrontier: true)
        }

        // 近期月份（近 45 天內）：永遠刷新最新一頁抓新；不依賴覆蓋判斷，確保剛同步的訓練不漏。
        let recentThreshold = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? monthStart
        if monthStart >= recentThreshold {
            await refreshTopPage(seedFrontier: false)
            return
        }

        // 過去月份：
        if backfillReachedEnd { return }                                  // 補史已到底 → 緩存即全部
        if let oldest = oldestCachedDate(), oldest < monthStart { return } // 該月已連續涵蓋（API 時間驗證）

        // 一次性往前補史：從 frontier 游標往舊分頁 upsert，直到涵蓋月初或到底；上限 30 頁保護。
        var guardCount = 0
        while guardCount < 30 {
            if let oldest = oldestCachedDate(), oldest < monthStart { break }
            guard let cursor = localDataSource.getPagination()?.nextCursor else { break }
            guardCount += 1
            do {
                let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: 50, cursor: cursor)
                localDataSource.upsertWorkouts(page.workouts)
                localDataSource.savePagination(page.pagination)   // 推進 frontier（成功才推進）
                paginationSubject.send(page.pagination)
                if !page.pagination.hasMore {
                    backfillReachedEnd = true                     // 權威「沒有更舊」→ 記錄到底，永不重抓
                    break
                }
            } catch {
                // 單次錯誤：不推進水位、不標記涵蓋 → 下次開該月自動重試（upsert 冪等，安全、不漏）。
                Logger.error("[WorkoutRepositoryImpl] ensureMonthLoaded 補史失敗，下次重試: \(error.localizedDescription)")
                break
            }
        }
        refreshSubject.send()
    }

    /// 刷新最新一頁（cursor:nil）→ upsert。catch 新資料、冪等可重跑。
    /// seedFrontier=true（冷緩存種子）才寫 pagination 當 frontier；否則不動補史 frontier。
    private func refreshTopPage(seedFrontier: Bool) async {
        do {
            let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: 50, cursor: nil)
            localDataSource.upsertWorkouts(page.workouts)
            if seedFrontier {
                localDataSource.savePagination(page.pagination)
                paginationSubject.send(page.pagination)
            }
            refreshSubject.send()
        } catch {
            Logger.debug("[WorkoutRepositoryImpl] refreshTopPage 失敗（下次重試）: \(error.localizedDescription)")
        }
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
        localDataSource.upsertWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        return page.workouts
    }

    func refreshWorkouts() async throws -> [WorkoutV2] {
        Logger.debug("[WorkoutRepositoryImpl] refreshWorkouts - 強制刷新")

        // 強制刷新：跳過緩存，直接從 API 獲取（連同後端分頁狀態一起存）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: nil, cursor: nil)
        localDataSource.upsertWorkouts(page.workouts)
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
        localDataSource.upsertWorkouts(page.workouts)
        localDataSource.savePagination(page.pagination)
        paginationSubject.send(page.pagination)

        Logger.debug("[WorkoutRepositoryImpl] loadInitialWorkouts - 完成，數量: \(page.workouts.count)，has_more: \(page.pagination.hasMore)")
        return page
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int = 10) async throws -> WorkoutListResponse {
        Logger.debug("[WorkoutRepositoryImpl] loadMoreWorkouts - afterCursor: \(afterCursor), pageSize: \(pageSize)")

        // Fetch from API（含後端真實分頁狀態）
        let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: afterCursor)

        // upsert（依 id 合併）— 補上更舊的分頁，不重複累積、不縮小既有緩存。
        localDataSource.upsertWorkouts(page.workouts)

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
        localDataSource.upsertWorkouts(page.workouts)
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
        backfillReachedEnd = false               // 緩存清空 → 補史水位歸零

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
        backfillReachedEnd = false               // 緩存清空 → 補史水位歸零，允許重新補史
    }

    func preloadData() async {
        Logger.debug("[WorkoutRepositoryImpl] preloadData - 預載入最近訓練")

        do {
            let recentWorkouts = try await remoteDataSource.fetchRecentWorkouts(pageSize: 20)
            localDataSource.upsertWorkouts(recentWorkouts)
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

        // Track B：抓整頁（含後端分頁狀態）→ upsert（依 id 合併），不覆蓋。
        // upsert 確保 limit:1 之類的小請求不會把共用列表壓小（主畫面就只剩最近一筆）。
        do {
            let page = try await remoteDataSource.fetchWorkoutsPage(pageSize: pageSize, cursor: nil)
            localDataSource.upsertWorkouts(page.workouts)
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
