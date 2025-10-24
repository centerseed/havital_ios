import Foundation

/// Local storage for Training Readiness data
class TrainingReadinessStorage {
    static let shared = TrainingReadinessStorage()

    private let defaults = UserDefaults.standard
    private let readinessDataKey = "training_readiness_data"
    private let readinessLastFetchTimeKey = "training_readiness_last_fetch_time"

    private init() {}

    // MARK: - Save & Load

    /// Save training readiness data to local storage
    func saveReadinessData(_ response: TrainingReadinessResponse) {
        do {
            let encodedData = try JSONEncoder().encode(response)
            defaults.set(encodedData, forKey: readinessDataKey)

            // Save fetch timestamp
            defaults.set(Date().timeIntervalSince1970, forKey: readinessLastFetchTimeKey)

            // Log detailed metrics
            print("[TrainingReadinessStorage] 💾 保存數據到本地:")
            print("[TrainingReadinessStorage]   - 日期: \(response.date)")
            print("[TrainingReadinessStorage]   - 整體分數: \(response.overallScore ?? 0)")
            if let speed = response.metrics?.speed {
                print("[TrainingReadinessStorage]   - 速度分數: \(speed.score)")
            }
            if let endurance = response.metrics?.endurance {
                print("[TrainingReadinessStorage]   - 耐力分數: \(endurance.score)")
            }
            if let raceFitness = response.metrics?.raceFitness {
                print("[TrainingReadinessStorage]   - 比賽適能分數: \(raceFitness.score)")
            }
            if let trainingLoad = response.metrics?.trainingLoad {
                print("[TrainingReadinessStorage]   - 訓練負荷分數: \(trainingLoad.score)")
            }
        } catch {
            print("[TrainingReadinessStorage] ❌ 保存數據失敗: \(error.localizedDescription)")
        }
    }

    /// Load training readiness data from local storage
    func loadReadinessData() -> TrainingReadinessResponse? {
        guard let data = defaults.data(forKey: readinessDataKey) else {
            print("[TrainingReadinessStorage] ⚠️ 無緩存數據")
            return nil
        }

        do {
            let response = try JSONDecoder().decode(TrainingReadinessResponse.self, from: data)

            // Log detailed metrics
            print("[TrainingReadinessStorage] 📂 載入緩存數據:")
            print("[TrainingReadinessStorage]   - 日期: \(response.date)")
            print("[TrainingReadinessStorage]   - 整體分數: \(response.overallScore ?? 0)")
            if let speed = response.metrics?.speed {
                print("[TrainingReadinessStorage]   - 速度分數: \(speed.score)")
            }
            if let endurance = response.metrics?.endurance {
                print("[TrainingReadinessStorage]   - 耐力分數: \(endurance.score)")
            }
            if let raceFitness = response.metrics?.raceFitness {
                print("[TrainingReadinessStorage]   - 比賽適能分數: \(raceFitness.score)")
            }
            if let trainingLoad = response.metrics?.trainingLoad {
                print("[TrainingReadinessStorage]   - 訓練負荷分數: \(trainingLoad.score)")
            }

            return response
        } catch {
            print("[TrainingReadinessStorage] ❌ 解析緩存數據失敗: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cache Management

    /// Get last fetch time
    func getLastFetchTime() -> Date? {
        let timestamp = defaults.double(forKey: readinessLastFetchTimeKey)
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    /// Check if cache should be refreshed
    /// - Parameter cacheTimeInSeconds: Cache validity duration (default: 1800 seconds = 30 minutes)
    /// - Returns: True if cache is expired or doesn't exist
    func shouldRefreshData(cacheTimeInSeconds: Double = 1800) -> Bool {
        guard let lastFetchTime = getLastFetchTime() else {
            // No cache exists, should refresh
            return true
        }

        let currentTime = Date()
        let timeSinceLastFetch = currentTime.timeIntervalSince(lastFetchTime)

        // Refresh if cache is older than specified duration
        return timeSinceLastFetch > cacheTimeInSeconds
    }

    /// Clear all cached data
    func clearReadinessData() {
        defaults.removeObject(forKey: readinessDataKey)
        defaults.removeObject(forKey: readinessLastFetchTimeKey)
        print("[TrainingReadinessStorage] 已清除所有緩存數據")
    }

    // MARK: - Cache Status

    /// Check if cache exists
    var hasCachedData: Bool {
        return defaults.data(forKey: readinessDataKey) != nil
    }

    /// Get cache age in seconds
    var cacheAge: TimeInterval? {
        guard let lastFetchTime = getLastFetchTime() else { return nil }
        return Date().timeIntervalSince(lastFetchTime)
    }

    /// Get formatted cache status
    var cacheStatusDescription: String {
        guard let age = cacheAge else {
            return "無緩存"
        }

        let minutes = Int(age / 60)
        if minutes < 1 {
            return "剛剛更新"
        } else if minutes < 60 {
            return "\(minutes) 分鐘前更新"
        } else {
            let hours = minutes / 60
            return "\(hours) 小時前更新"
        }
    }
}
