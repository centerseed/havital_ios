import Foundation

// MARK: - Workout Repository Implementation
/// 訓練記錄 Repository 實作
/// Data Layer - 協調雙數據源實現雙軌緩存策略
final class WorkoutRepositoryImpl: WorkoutRepository {

    // MARK: - Singleton (for backwards compatibility)

    static let shared = WorkoutRepositoryImpl()

    // MARK: - Properties

    private let workoutManager: UnifiedWorkoutManager
    private let remoteDataSource: WorkoutRemoteDataSource
    private let localDataSource: WorkoutLocalDataSource

    // MARK: - Initialization

    init(workoutManager: UnifiedWorkoutManager = .shared,
         remoteDataSource: WorkoutRemoteDataSource = WorkoutRemoteDataSource(),
         localDataSource: WorkoutLocalDataSource = WorkoutLocalDataSource()) {
        self.workoutManager = workoutManager
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource

        Logger.debug("[WorkoutRepositoryImpl] 初始化完成（雙數據源模式）")
    }

    // MARK: - WorkoutRepository Protocol

    var workoutsDidUpdateNotification: Notification.Name {
        return .workoutsDidUpdate
    }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        return workoutManager.getWorkoutsInDateRange(startDate: startDate, endDate: endDate)
    }

    func getAllWorkouts() -> [WorkoutV2] {
        return workoutManager.workouts
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

    /// 背景刷新訓練列表
    private func backgroundRefreshWorkouts(pageSize: Int?) async {
        do {
            let workouts = try await remoteDataSource.fetchWorkouts(pageSize: pageSize, cursor: nil)
            localDataSource.saveWorkouts(workouts)
            Logger.debug("[WorkoutRepositoryImpl] Track B - 背景刷新完成，數量: \(workouts.count)")

            // ✅ Clean Architecture: 只使用 CacheEventBus，不使用 NotificationCenter
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutRepositoryImpl] ✅ 發布 CacheEventBus 事件: workouts data changed")
        } catch {
            Logger.error("[WorkoutRepositoryImpl] Track B - 背景刷新失敗: \(error.localizedDescription)")
        }
    }

    /// 背景刷新單個訓練
    private func backgroundRefreshSingleWorkout(id: String) async {
        do {
            let workout = try await remoteDataSource.fetchWorkout(id: id)
            localDataSource.saveWorkout(workout)
            Logger.debug("[WorkoutRepositoryImpl] Track B - 單個訓練背景刷新完成")

            // ✅ Clean Architecture: 只使用 CacheEventBus，不使用 NotificationCenter
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutRepositoryImpl] ✅ 發布 CacheEventBus 事件: workouts data changed")
        } catch {
            Logger.error("[WorkoutRepositoryImpl] Track B - 單個訓練背景刷新失敗: \(error.localizedDescription)")
        }
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
