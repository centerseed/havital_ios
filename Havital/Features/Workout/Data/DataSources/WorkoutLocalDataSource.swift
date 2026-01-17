import Foundation

// MARK: - Workout Local Data Source
/// 負責本地緩存的 Workout 數據管理
/// Data Layer - Local Data Source
class WorkoutLocalDataSource {

    // MARK: - Properties

    private let cacheManager: BaseCacheManagerTemplate<[WorkoutV2]>
    private let workoutCacheManager: BaseCacheManagerTemplate<WorkoutV2>
    private let detailCacheManager: BaseCacheManagerTemplate<WorkoutV2Detail>

    /// 緩存過期時間（2 小時 - 合理的平衡點）
    /// ✅ 2小時足夠減少 API 請求，又不會讓數據太舊
    private let cacheExpirationInterval: TimeInterval = 2 * 60 * 60 // 2 小時

    // MARK: - Cache Keys

    private enum CacheKey {
        static let workoutsList = "workouts_list"
        static func workout(id: String) -> String {
            return "workout_\(id)"
        }
        static func workoutDetail(id: String) -> String {
            return "workout_detail_\(id)"
        }
    }

    // MARK: - Initialization

    /// 初始化緩存管理器
    /// - Parameter identifierSuffix: 可選的後綴，用於測試時創建獨立的緩存空間，避免並行測試互相干擾
    init(identifierSuffix: String? = nil) {
        let suffix = identifierSuffix ?? ""

        // 初始化訓練列表緩存管理器
        self.cacheManager = BaseCacheManagerTemplate<[WorkoutV2]>(
            identifier: "WorkoutListCache\(suffix)",
            defaultTTL: cacheExpirationInterval
        )

        // 初始化單個訓練緩存管理器
        self.workoutCacheManager = BaseCacheManagerTemplate<WorkoutV2>(
            identifier: "WorkoutDetailCache\(suffix)",
            defaultTTL: cacheExpirationInterval
        )

        // 初始化完整詳情緩存管理器（包含時間序列數據）
        self.detailCacheManager = BaseCacheManagerTemplate<WorkoutV2Detail>(
            identifier: "WorkoutFullDetailCache\(suffix)",
            defaultTTL: cacheExpirationInterval
        )

        Logger.debug("[WorkoutLocalDataSource] 初始化完成，緩存過期時間: \(cacheExpirationInterval / 60) 分鐘")
    }

    // MARK: - Workout List

    /// 獲取緩存的訓練列表
    /// ✅ Clean Architecture: DataSource 永遠返回可用數據，不因 TTL 拒絕返回
    /// - Returns: 訓練列表，只有真的沒有數據時才返回 nil
    func getWorkouts() -> [WorkoutV2]? {
        let workouts = cacheManager.loadFromCache()

        if let workouts = workouts {
            if cacheManager.isExpired() {
                Logger.debug("[WorkoutLocalDataSource] 緩存已過期但仍返回，數量: \(workouts.count)（需背景刷新）")
            } else {
                Logger.debug("[WorkoutLocalDataSource] 緩存有效，數量: \(workouts.count)")
            }
        } else {
            Logger.debug("[WorkoutLocalDataSource] 無緩存數據")
        }

        return workouts
    }

    /// 檢查緩存是否需要刷新（給 Repository 層用）
    /// - Returns: true 表示需要背景刷新，false 表示數據新鮮
    func shouldRefresh() -> Bool {
        return cacheManager.isExpired()
    }

    /// 保存訓練列表到緩存
    /// - Parameter workouts: 訓練列表
    func saveWorkouts(_ workouts: [WorkoutV2]) {
        cacheManager.saveToCache(workouts)
        Logger.debug("[WorkoutLocalDataSource] saveWorkouts - 已保存 \(workouts.count) 條記錄到緩存")
    }

    // MARK: - Single Workout

    /// 獲取緩存的單個訓練
    /// - Parameter id: 訓練 ID
    /// - Returns: 訓練實體，如果緩存不存在或已過期則返回 nil
    func getWorkout(id: String) -> WorkoutV2? {
        if workoutCacheManager.isExpired() {
            Logger.debug("[WorkoutLocalDataSource] getWorkout(\(id)) - 緩存已過期")
            return nil
        }

        guard let workout = workoutCacheManager.loadFromCache() else {
            Logger.debug("[WorkoutLocalDataSource] getWorkout(\(id)) - 緩存未命中")
            return nil
        }

        Logger.debug("[WorkoutLocalDataSource] getWorkout(\(id)) - 緩存命中")
        return workout
    }

    /// 保存單個訓練到緩存
    /// - Parameter workout: 訓練實體
    func saveWorkout(_ workout: WorkoutV2) {
        workoutCacheManager.saveToCache(workout)
        Logger.debug("[WorkoutLocalDataSource] saveWorkout(\(workout.id)) - 已保存到緩存")
    }

    // MARK: - Workout Detail (Full Detail with TimeSeries)

    /// 獲取緩存的完整訓練詳情（包含時間序列數據）
    /// - Parameter id: 訓練 ID
    /// - Returns: 完整訓練詳情，如果緩存不存在或已過期則返回 nil
    func getWorkoutDetail(id: String) -> WorkoutV2Detail? {
        if detailCacheManager.isExpired() {
            Logger.debug("[WorkoutLocalDataSource] getWorkoutDetail(\(id)) - 緩存已過期")
            return nil
        }

        guard let detail = detailCacheManager.loadFromCache() else {
            Logger.debug("[WorkoutLocalDataSource] getWorkoutDetail(\(id)) - 緩存未命中")
            return nil
        }

        // 確認 ID 匹配
        guard detail.id == id else {
            Logger.debug("[WorkoutLocalDataSource] getWorkoutDetail(\(id)) - ID 不匹配，緩存的是 \(detail.id)")
            return nil
        }

        Logger.debug("[WorkoutLocalDataSource] getWorkoutDetail(\(id)) - 緩存命中")
        return detail
    }

    /// 保存完整訓練詳情到緩存
    /// - Parameter detail: 完整訓練詳情
    func saveWorkoutDetail(_ detail: WorkoutV2Detail) {
        detailCacheManager.saveToCache(detail)
        Logger.debug("[WorkoutLocalDataSource] saveWorkoutDetail(\(detail.id)) - 已保存到緩存")
    }

    /// 清除指定訓練的詳情緩存
    /// - Parameter id: 訓練 ID
    func clearWorkoutDetailCache(id: String) {
        detailCacheManager.clearCache()
        Logger.debug("[WorkoutLocalDataSource] clearWorkoutDetailCache(\(id)) - 已清除詳情緩存")
    }

    /// 從列表緩存中查找單個訓練
    /// - Parameter id: 訓練 ID
    /// - Returns: 訓練實體，如果不存在則返回 nil
    func findWorkoutInList(id: String) -> WorkoutV2? {
        guard let workouts = getWorkouts() else { return nil }
        return workouts.first { $0.id == id }
    }

    // MARK: - Delete

    /// 刪除單個訓練緩存
    /// - Parameter id: 訓練 ID
    func deleteWorkout(id: String) {
        workoutCacheManager.clearCache()
        detailCacheManager.clearCache()
        Logger.debug("[WorkoutLocalDataSource] deleteWorkout(\(id)) - 已從詳情緩存刪除")

        // 直接從緩存讀取，不經過過期檢查，確保列表緩存正確更新
        if var workouts = cacheManager.loadFromCache() {
            workouts.removeAll { $0.id == id }
            cacheManager.saveToCache(workouts)
            Logger.debug("[WorkoutLocalDataSource] deleteWorkout(\(id)) - 已從列表緩存刪除，剩餘: \(workouts.count)")
        }
    }

    // MARK: - Cache Management

    /// 清空所有訓練緩存
    func clearAll() {
        cacheManager.clearCache()
        workoutCacheManager.clearCache()
        detailCacheManager.clearCache()
        Logger.debug("[WorkoutLocalDataSource] clearAll - 所有緩存已清空")
    }

    /// 獲取緩存統計信息
    func getCacheStats() -> (listCacheSize: Int, detailCacheSize: Int, totalSize: Int) {
        let listSize = cacheManager.getCacheSize()
        let detailSize = workoutCacheManager.getCacheSize()
        return (listSize, detailSize, listSize + detailSize)
    }

    // MARK: - Compatibility Methods (for UnifiedWorkoutManager migration)

    /// 合併新的訓練數據到緩存（兼容 WorkoutV2CacheManager.mergeWorkoutsToCache）
    /// - Parameter newWorkouts: 新的訓練列表
    /// - Returns: 新增的訓練數量
    func mergeWorkoutsToCache(_ newWorkouts: [WorkoutV2]) -> Int {
        guard !newWorkouts.isEmpty else { return 0 }

        // 獲取現有緩存（即使過期也要讀取，以便合併）
        let existingWorkouts = cacheManager.loadFromCache() ?? []
        let existingIds = Set(existingWorkouts.map { $0.id })

        // 找出新的訓練（不在現有緩存中的）
        let trulyNewWorkouts = newWorkouts.filter { !existingIds.contains($0.id) }

        if trulyNewWorkouts.isEmpty {
            Logger.debug("[WorkoutLocalDataSource] mergeWorkoutsToCache - 沒有新數據需要合併")
            return 0
        }

        // 合併並保存
        let mergedWorkouts = (existingWorkouts + trulyNewWorkouts).sorted { $0.endDate > $1.endDate }
        saveWorkouts(mergedWorkouts)

        Logger.debug("[WorkoutLocalDataSource] mergeWorkoutsToCache - 合併了 \(trulyNewWorkouts.count) 條新記錄，總計 \(mergedWorkouts.count)")
        return trulyNewWorkouts.count
    }

    /// 檢查是否有緩存的訓練數據（兼容 WorkoutV2CacheManager.hasCachedWorkouts）
    func hasCachedWorkouts() -> Bool {
        return getWorkouts() != nil
    }

    /// 獲取最後同步時間（兼容 WorkoutV2CacheManager.getLastSyncTime）
    /// 注意：LocalDataSource 不追蹤同步時間，返回 nil
    func getLastSyncTime() -> Date? {
        // LocalDataSource 不追蹤同步時間
        // 如果需要，可以在未來添加 UserDefaults 來存儲
        return nil
    }

    /// 檢查緩存是否需要刷新（兼容 WorkoutV2CacheManager.shouldRefreshCache）
    func shouldRefreshCache() -> Bool {
        return cacheManager.isExpired()
    }
}

// MARK: - Cacheable Protocol Conformance
extension WorkoutLocalDataSource: Cacheable {

    var cacheIdentifier: String {
        return "WorkoutLocalDataSource"
    }

    func clearCache() {
        clearAll()
    }

    func getCacheSize() -> Int {
        return cacheManager.getCacheSize() + workoutCacheManager.getCacheSize()
    }

    func isExpired() -> Bool {
        // 檢查兩個緩存管理器是否都過期
        return cacheManager.isExpired() && workoutCacheManager.isExpired()
    }
}
