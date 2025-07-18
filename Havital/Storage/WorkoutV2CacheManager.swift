import Foundation

// MARK: - Workout V2 Cache Manager
class WorkoutV2CacheManager {
    static let shared = WorkoutV2CacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Cache Keys
    private let workoutListCacheKey = "workout_v2_list_cache"
    private let workoutDetailCachePrefix = "workout_v2_detail_"
    private let workoutStatsCacheKey = "workout_v2_stats_cache"
    private let lastSyncTimestampKey = "workout_v2_last_sync"
    private let cacheMetadataKey = "workout_v2_cache_metadata"
    
    // Cache Configuration
    private let maxWorkoutListSize = 1000 // 增加最多快取運動記錄數量
    
    // TTL Configuration
    private let workoutListTTL: TimeInterval = 7 * 24 * 60 * 60 // 7天
    private let workoutDetailTTL: TimeInterval = 24 * 60 * 60   // 24小時
    private let workoutStatsTTL: TimeInterval = 6 * 60 * 60     // 6小時
    private let maxDataRetentionMonths = 3                      // 3個月
    
    private init() {
        // 建立快取目錄
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("WorkoutV2Cache")
        
        // 確保快取目錄存在
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // 在背景清理過期快取
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.cleanupExpiredWorkoutDetailCache(maxAge: self?.workoutDetailTTL ?? 24 * 60 * 60)
            self?.cleanupOldWorkoutData()
        }
    }
    
    // MARK: - Workout List Cache
    
    /// 快取運動列表
    /// - Parameter workouts: 運動列表
    func cacheWorkoutList(_ workouts: [WorkoutV2]) {
        do {
            let data = try JSONEncoder().encode(workouts)
            userDefaults.set(data, forKey: workoutListCacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: lastSyncTimestampKey)
            
            // 更新快取元數據
            updateCacheMetadata(for: .workoutList, count: workouts.count)
            
            Logger.firebase(
                "Workout V2 列表快取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_list"
                ],
                jsonPayload: [
                    "workouts_count": workouts.count,
                    "cache_size_bytes": data.count
                ]
            )
        } catch {
            Logger.firebase(
                "快取運動列表失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_list"
                ]
            )
        }
    }
    
    /// 獲取快取的運動列表
    /// - Returns: 快取的運動列表，如果過期或不存在則返回 nil
    func getCachedWorkoutList() -> [WorkoutV2]? {
        // 檢查是否過期
        if isWorkoutListExpired() {
            return nil
        }
        
        guard let data = userDefaults.data(forKey: workoutListCacheKey),
              let workouts = try? JSONDecoder().decode([WorkoutV2].self, from: data) else {
            return nil
        }
        
        Logger.firebase(
            "從快取載入運動列表",
            level: .info,
            labels: [
                "module": "WorkoutV2CacheManager",
                "action": "load_cached_workout_list"
            ],
            jsonPayload: [
                "workouts_count": workouts.count
            ]
        )
        
        return workouts
    }
    
    /// 增量更新運動列表快取（新增新的運動記錄）
    /// - Parameter newWorkouts: 新的運動記錄
    func appendWorkoutsToCache(_ newWorkouts: [WorkoutV2]) {
        var existingWorkouts = getCachedWorkoutList() ?? []
        
        // 去重：移除已存在的運動記錄
        let newUniqueWorkouts = newWorkouts.filter { newWorkout in
            !existingWorkouts.contains { $0.id == newWorkout.id }
        }
        
        if !newUniqueWorkouts.isEmpty {
            existingWorkouts.append(contentsOf: newUniqueWorkouts)
            
            // 按時間排序並限制數量
            existingWorkouts.sort { workout1, workout2 in
                (workout1.startDate ?? Date.distantPast) > (workout2.startDate ?? Date.distantPast)
            }
            
            if existingWorkouts.count > maxWorkoutListSize {
                existingWorkouts = Array(existingWorkouts.prefix(maxWorkoutListSize))
            }
            
            cacheWorkoutList(existingWorkouts)
        }
    }
    
    // MARK: - Workout Detail Cache
    
    /// 快取運動詳細資料
    /// - Parameters:
    ///   - workoutId: 運動 ID
    ///   - detail: 運動詳細資料
    func cacheWorkoutDetail(workoutId: String, detail: WorkoutV2Detail) {
        let fileName = "\(workoutDetailCachePrefix)\(workoutId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            let cacheData = WorkoutDetailCacheData(
                detail: detail,
                cachedAt: Date()
            )
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: fileURL)
            
            // 更新快取元數據
            updateCacheMetadata(for: .workoutDetail(workoutId), count: 1)
            
            Logger.firebase(
                "運動詳情快取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_detail"
                ],
                jsonPayload: [
                    "workout_id": workoutId,
                    "cache_size_bytes": data.count
                ]
            )
        } catch {
            Logger.firebase(
                "快取運動詳情失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_detail"
                ],
                jsonPayload: [
                    "workout_id": workoutId
                ]
            )
        }
    }
    
    /// 獲取快取的運動詳細資料
    /// - Parameters:
    ///   - workoutId: 運動 ID
    ///   - maxAge: 最大快取時間（秒），預設使用 workoutDetailTTL（24 小時）
    /// - Returns: 快取的運動詳細資料，如果過期或不存在則返回 nil
    func getCachedWorkoutDetail(workoutId: String, maxAge: TimeInterval? = nil) -> WorkoutV2Detail? {
        let actualMaxAge = maxAge ?? workoutDetailTTL
        let fileName = "\(workoutDetailCachePrefix)\(workoutId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        // 嘗試使用新的快取格式（含時間戳）
        if let cacheData = try? JSONDecoder().decode(WorkoutDetailCacheData.self, from: data) {
            // 檢查是否過期
            if Date().timeIntervalSince(cacheData.cachedAt) > actualMaxAge {
                // 快取已過期，清除檔案
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
            
            Logger.firebase(
                "從快取載入運動詳情",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "load_cached_workout_detail"
                ],
                jsonPayload: [
                    "workout_id": workoutId,
                    "cache_age_seconds": Date().timeIntervalSince(cacheData.cachedAt)
                ]
            )
            
            return cacheData.detail
        }
        
        // 嘗試使用舊的快取格式（向後兼容）
        if let detail = try? JSONDecoder().decode(WorkoutV2Detail.self, from: data) {
            Logger.firebase(
                "從舊格式快取載入運動詳情",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "load_cached_workout_detail_legacy"
                ],
                jsonPayload: [
                    "workout_id": workoutId
                ]
            )
            
            // 重新儲存為新格式
            cacheWorkoutDetail(workoutId: workoutId, detail: detail)
            
            return detail
        }
        
        return nil
    }
    
    // MARK: - Workout Stats Cache
    
    /// 快取運動統計數據
    /// - Parameter stats: 運動統計數據
    func cacheWorkoutStats(_ stats: WorkoutStatsResponse) {
        do {
            let cacheData = WorkoutStatsCacheData(
                stats: stats,
                cachedAt: Date()
            )
            let data = try JSONEncoder().encode(cacheData)
            userDefaults.set(data, forKey: workoutStatsCacheKey)
            
            Logger.firebase(
                "運動統計快取成功",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_stats"
                ],
                jsonPayload: [
                                    "total_workouts": stats.data.totalWorkouts,
                "period_days": stats.data.periodDays
                ]
            )
        } catch {
            Logger.firebase(
                "快取運動統計失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cache_workout_stats"
                ]
            )
        }
    }
    
    /// 獲取快取的運動統計數據
    /// - Parameter maxAge: 最大快取時間（秒），預設使用 workoutStatsTTL（6 小時）
    /// - Returns: 快取的運動統計數據，如果過期或不存在則返回 nil
    func getCachedWorkoutStats(maxAge: TimeInterval? = nil) -> WorkoutStatsResponse? {
        let actualMaxAge = maxAge ?? workoutStatsTTL
        guard let data = userDefaults.data(forKey: workoutStatsCacheKey),
              let cacheData = try? JSONDecoder().decode(WorkoutStatsCacheData.self, from: data),
              Date().timeIntervalSince(cacheData.cachedAt) < actualMaxAge else {
            return nil
        }
        
        Logger.firebase(
            "從快取載入運動統計",
            level: .info,
            labels: [
                "module": "WorkoutV2CacheManager",
                "action": "load_cached_workout_stats"
            ]
        )
        
        return cacheData.stats
    }
    
    // MARK: - Cache Management
    
    /// 清除所有快取
    func clearAllCache() {
        // 清除 UserDefaults 快取
        userDefaults.removeObject(forKey: workoutListCacheKey)
        userDefaults.removeObject(forKey: workoutStatsCacheKey)
        userDefaults.removeObject(forKey: lastSyncTimestampKey)
        userDefaults.removeObject(forKey: cacheMetadataKey)
        
        // 清除檔案快取
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            
            Logger.firebase(
                "所有 Workout V2 快取已清除",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "clear_all_cache"
                ]
            )
        } catch {
            Logger.firebase(
                "清除快取失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "clear_all_cache"
                ]
            )
        }
    }
    
    /// 清除特定運動的詳細資料快取
    /// - Parameter workoutId: 運動 ID
    func clearWorkoutDetailCache(workoutId: String) {
        let fileName = "\(workoutDetailCachePrefix)\(workoutId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            Logger.firebase(
                "清除運動詳情快取失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "clear_workout_detail_cache"
                ],
                jsonPayload: [
                    "workout_id": workoutId
                ]
            )
        }
    }
    
    /// 清除所有過期的運動詳情快取
    /// - Parameter maxAge: 最大快取時間（秒），預設使用 workoutDetailTTL（24 小時）
    func cleanupExpiredWorkoutDetailCache(maxAge: TimeInterval? = nil) {
        let actualMaxAge = maxAge ?? workoutDetailTTL
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var expiredCount = 0
            
            for fileURL in fileURLs {
                let fileName = fileURL.lastPathComponent
                if fileName.hasPrefix(workoutDetailCachePrefix) {
                    guard let data = try? Data(contentsOf: fileURL) else { continue }
                    
                    // 檢查是否為新格式（含時間戳）
                    if let cacheData = try? JSONDecoder().decode(WorkoutDetailCacheData.self, from: data) {
                        if Date().timeIntervalSince(cacheData.cachedAt) > actualMaxAge {
                            try fileManager.removeItem(at: fileURL)
                            expiredCount += 1
                        }
                    } else {
                        // 舊格式檔案，假設已過期
                        try fileManager.removeItem(at: fileURL)
                        expiredCount += 1
                    }
                }
            }
            
            if expiredCount > 0 {
                Logger.firebase(
                    "清除過期運動詳情快取成功",
                    level: .info,
                    labels: [
                        "module": "WorkoutV2CacheManager",
                        "action": "cleanup_expired_cache"
                    ],
                    jsonPayload: [
                        "expired_count": expiredCount
                    ]
                )
            }
        } catch {
            Logger.firebase(
                "清除過期快取失敗: \(error.localizedDescription)",
                level: .error,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cleanup_expired_cache"
                ]
            )
        }
    }
    
    /// 獲取快取大小資訊
    /// - Returns: 快取大小（位元組）
    func getCacheSize() -> Int {
        var totalSize = 0
        
        // UserDefaults 快取大小（估算）
        if let data = userDefaults.data(forKey: workoutListCacheKey) {
            totalSize += data.count
        }
        if let data = userDefaults.data(forKey: workoutStatsCacheKey) {
            totalSize += data.count
        }
        
        // 檔案快取大小
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in fileURLs {
                if let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += fileSize
                }
            }
        } catch {
            Logger.warn("無法計算快取大小: \(error.localizedDescription)")
        }
        
        return totalSize
    }
    
    /// 檢查是否有緩存的運動記錄
    /// - Returns: 是否有緩存數據
    func hasCachedWorkouts() -> Bool {
        guard let data = userDefaults.data(forKey: workoutListCacheKey),
              let workouts = try? JSONDecoder().decode([WorkoutV2].self, from: data) else {
            return false
        }
        return !workouts.isEmpty
    }
    
    /// 獲取緩存的運動記錄數量
    /// - Returns: 緩存中的運動記錄數量
    func getCachedWorkoutsCount() -> Int {
        return getCachedWorkoutList()?.count ?? 0
    }
    
    /// 獲取最後同步時間
    /// - Returns: 最後同步時間
    func getLastSyncTime() -> Date? {
        let timestamp = userDefaults.double(forKey: lastSyncTimestampKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    /// 檢查緩存是否需要刷新（基於時間）
    /// - Parameter intervalSinceLastSync: 距離上次同步的最小間隔（秒），預設 300 秒（5 分鐘）
    /// - Returns: 是否需要刷新
    func shouldRefreshCache(intervalSinceLastSync: TimeInterval = 300) -> Bool {
        guard let lastSync = getLastSyncTime() else {
            return true // 沒有同步記錄，需要刷新
        }
        return Date().timeIntervalSince(lastSync) > intervalSinceLastSync
    }
    
    /// 合併新的運動記錄到現有緩存
    /// - Parameter newWorkouts: 新的運動記錄
    /// - Returns: 合併後的運動記錄數量
    @discardableResult
    func mergeWorkoutsToCache(_ newWorkouts: [WorkoutV2]) -> Int {
        var existingWorkouts = getCachedWorkoutList() ?? []
        var mergedCount = 0
        
        // 去重並合併新的運動記錄
        for newWorkout in newWorkouts {
            if !existingWorkouts.contains(where: { $0.id == newWorkout.id }) {
                existingWorkouts.append(newWorkout)
                mergedCount += 1
            }
        }
        
        if mergedCount > 0 {
            // 按時間排序並限制數量
            existingWorkouts.sort { workout1, workout2 in
                (workout1.startDate ?? Date.distantPast) > (workout2.startDate ?? Date.distantPast)
            }
            
            if existingWorkouts.count > maxWorkoutListSize {
                existingWorkouts = Array(existingWorkouts.prefix(maxWorkoutListSize))
            }
            
            cacheWorkoutList(existingWorkouts)
            
            Logger.firebase(
                "合併運動記錄到緩存",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "merge_workouts"
                ],
                jsonPayload: [
                    "new_workouts": mergedCount,
                    "total_workouts": existingWorkouts.count
                ]
            )
        }
        
        return mergedCount
    }
    
    // MARK: - Private Methods
    
    /// 檢查運動列表是否過期
    /// - Returns: 是否過期
    private func isWorkoutListExpired() -> Bool {
        guard let lastSync = getLastSyncTime() else {
            return true // 沒有同步記錄，視為過期
        }
        return Date().timeIntervalSince(lastSync) > workoutListTTL
    }
    
    /// 清理超過保留期限的舊運動數據
    private func cleanupOldWorkoutData() {
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -maxDataRetentionMonths, to: Date()) ?? Date()
        
        // 直接從 UserDefaults 讀取，避免觸發過期檢查
        guard let data = userDefaults.data(forKey: workoutListCacheKey),
              var workouts = try? JSONDecoder().decode([WorkoutV2].self, from: data) else {
            return
        }
        
        let originalCount = workouts.count
        
        // 移除超過保留期限的運動記錄
        workouts = workouts.filter { workout in
            return workout.startDate > cutoffDate
        }
        
        if workouts.count < originalCount {
            cacheWorkoutList(workouts)
            
            Logger.firebase(
                "清理舊運動數據",
                level: .info,
                labels: [
                    "module": "WorkoutV2CacheManager",
                    "action": "cleanup_old_workout_data"
                ],
                jsonPayload: [
                    "removed_count": originalCount - workouts.count,
                    "remaining_count": workouts.count,
                    "cutoff_date": cutoffDate.timeIntervalSince1970
                ]
            )
        }
    }
    
    /// 更新快取元數據
    private func updateCacheMetadata(for cacheType: CacheType, count: Int) {
        var metadata = getCacheMetadata()
        metadata[cacheType.key] = CacheMetadata(
            lastUpdated: Date(),
            itemCount: count
        )
        
        do {
            let data = try JSONEncoder().encode(metadata)
            userDefaults.set(data, forKey: cacheMetadataKey)
        } catch {
            Logger.warn("更新快取元數據失敗: \(error.localizedDescription)")
        }
    }
    
    /// 獲取快取元數據
    private func getCacheMetadata() -> [String: CacheMetadata] {
        guard let data = userDefaults.data(forKey: cacheMetadataKey),
              let metadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) else {
            return [:]
        }
        return metadata
    }
}

// MARK: - Supporting Types

enum CacheType {
    case workoutList
    case workoutDetail(String)
    case workoutStats
    
    var key: String {
        switch self {
        case .workoutList:
            return "workout_list"
        case .workoutDetail(let workoutId):
            return "workout_detail_\(workoutId)"
        case .workoutStats:
            return "workout_stats"
        }
    }
}

struct CacheMetadata: Codable {
    let lastUpdated: Date
    let itemCount: Int
}

struct WorkoutStatsCacheData: Codable {
    let stats: WorkoutStatsResponse
    let cachedAt: Date
}

struct WorkoutDetailCacheData: Codable {
    let detail: WorkoutV2Detail
    let cachedAt: Date
}

// MARK: - Cache Extensions

extension WorkoutV2CacheManager {
    
    /// 批量快取運動詳細資料
    /// - Parameter details: 運動詳細資料字典 [workoutId: detail]
    func batchCacheWorkoutDetails(_ details: [String: WorkoutV2Detail]) {
        for (workoutId, detail) in details {
            cacheWorkoutDetail(workoutId: workoutId, detail: detail)
        }
    }
    
    /// 檢查特定運動詳情是否已快取且未過期
    /// - Parameters:
    ///   - workoutId: 運動 ID
    ///   - maxAge: 最大快取時間（秒），預設使用 workoutDetailTTL（24 小時）
    /// - Returns: 是否已快取且未過期
    func isWorkoutDetailCached(workoutId: String, maxAge: TimeInterval? = nil) -> Bool {
        return getCachedWorkoutDetail(workoutId: workoutId, maxAge: maxAge) != nil
    }
    
    /// 獲取快取統計資訊
    /// - Returns: 快取統計資訊
    func getCacheStats() -> CacheStats {
        let metadata = getCacheMetadata()
        let cacheSize = getCacheSize()
        
        return CacheStats(
            totalSizeBytes: cacheSize,
            workoutListCount: getCachedWorkoutList()?.count ?? 0,
            workoutDetailCount: metadata.filter { $0.key.hasPrefix("workout_detail_") }.count,
            lastSyncTime: Date(timeIntervalSince1970: userDefaults.double(forKey: lastSyncTimestampKey))
        )
    }
}

struct CacheStats {
    let totalSizeBytes: Int
    let workoutListCount: Int
    let workoutDetailCount: Int
    let lastSyncTime: Date
    
    var totalSizeMB: Double {
        Double(totalSizeBytes) / (1024 * 1024)
    }
}

// MARK: - Cacheable 協議實作
extension WorkoutV2CacheManager: Cacheable {
    var cacheIdentifier: String { "workouts_v2" }
    
    func clearCache() {
        clearAllCache()
    }
    
    func isExpired() -> Bool {
        return isWorkoutListExpired()
    }
}