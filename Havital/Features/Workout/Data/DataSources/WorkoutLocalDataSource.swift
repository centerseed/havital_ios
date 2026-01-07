import Foundation

// MARK: - Workout Local Data Source
/// 負責本地緩存的 Workout 數據管理
/// Data Layer - Local Data Source
final class WorkoutLocalDataSource {

    // MARK: - Properties

    private let cacheManager: BaseCacheManagerTemplate<[WorkoutV2]>
    private let workoutCacheManager: BaseCacheManagerTemplate<WorkoutV2>

    /// 緩存過期時間（30 分鐘）
    private let cacheExpirationInterval: TimeInterval = 30 * 60

    // MARK: - Cache Keys

    private enum CacheKey {
        static let workoutsList = "workouts_list"
        static func workout(id: String) -> String {
            return "workout_\(id)"
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

        Logger.debug("[WorkoutLocalDataSource] 初始化完成，緩存過期時間: \(cacheExpirationInterval / 60) 分鐘")
    }

    // MARK: - Workout List

    /// 獲取緩存的訓練列表
    /// - Returns: 訓練列表，如果緩存不存在或已過期則返回 nil
    func getWorkouts() -> [WorkoutV2]? {
        if cacheManager.isExpired() {
            Logger.debug("[WorkoutLocalDataSource] getWorkouts - 緩存已過期")
            return nil
        }

        guard let workouts = cacheManager.loadFromCache() else {
            Logger.debug("[WorkoutLocalDataSource] getWorkouts - 緩存未命中")
            return nil
        }

        Logger.debug("[WorkoutLocalDataSource] getWorkouts - 緩存命中，數量: \(workouts.count)")
        return workouts
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
        Logger.debug("[WorkoutLocalDataSource] clearAll - 所有緩存已清空")
    }

    /// 獲取緩存統計信息
    func getCacheStats() -> (listCacheSize: Int, detailCacheSize: Int, totalSize: Int) {
        let listSize = cacheManager.getCacheSize()
        let detailSize = workoutCacheManager.getCacheSize()
        return (listSize, detailSize, listSize + detailSize)
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
