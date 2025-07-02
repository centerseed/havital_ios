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
    private let cacheExpiryDuration: TimeInterval = 3600 // 1 hour
    private let maxWorkoutListSize = 500 // 最多快取 500 筆運動記錄
    
    private init() {
        // 建立快取目錄
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("WorkoutV2Cache")
        
        // 確保快取目錄存在
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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
        guard let data = userDefaults.data(forKey: workoutListCacheKey),
              let workouts = try? JSONDecoder().decode([WorkoutV2].self, from: data),
              !isCacheExpired(for: .workoutList) else {
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
            let data = try JSONEncoder().encode(detail)
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
    /// - Parameter workoutId: 運動 ID
    /// - Returns: 快取的運動詳細資料，如果不存在則返回 nil
    func getCachedWorkoutDetail(workoutId: String) -> WorkoutV2Detail? {
        let fileName = "\(workoutDetailCachePrefix)\(workoutId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let detail = try? JSONDecoder().decode(WorkoutV2Detail.self, from: data) else {
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
                "workout_id": workoutId
            ]
        )
        
        return detail
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
    /// - Parameter maxAge: 最大快取時間（秒），預設 1800 秒（30 分鐘）
    /// - Returns: 快取的運動統計數據，如果過期或不存在則返回 nil
    func getCachedWorkoutStats(maxAge: TimeInterval = 1800) -> WorkoutStatsResponse? {
        guard let data = userDefaults.data(forKey: workoutStatsCacheKey),
              let cacheData = try? JSONDecoder().decode(WorkoutStatsCacheData.self, from: data),
              Date().timeIntervalSince(cacheData.cachedAt) < maxAge else {
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
    
    /// 檢查快取是否過期
    /// - Parameter cacheType: 快取類型
    /// - Returns: 是否過期
    func isCacheExpired(for cacheType: CacheType) -> Bool {
        let lastSyncTime = userDefaults.double(forKey: lastSyncTimestampKey)
        let currentTime = Date().timeIntervalSince1970
        return (currentTime - lastSyncTime) > cacheExpiryDuration
    }
    
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
    
    // MARK: - Private Methods
    
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

// MARK: - Cache Extensions

extension WorkoutV2CacheManager {
    
    /// 批量快取運動詳細資料
    /// - Parameter details: 運動詳細資料字典 [workoutId: detail]
    func batchCacheWorkoutDetails(_ details: [String: WorkoutV2Detail]) {
        for (workoutId, detail) in details {
            cacheWorkoutDetail(workoutId: workoutId, detail: detail)
        }
    }
    
    /// 檢查特定運動詳情是否已快取
    /// - Parameter workoutId: 運動 ID
    /// - Returns: 是否已快取
    func isWorkoutDetailCached(workoutId: String) -> Bool {
        let fileName = "\(workoutDetailCachePrefix)\(workoutId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
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