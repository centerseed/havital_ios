import Foundation

class WeeklySummaryStorage {
    static let shared = WeeklySummaryStorage()
    private let defaults = UserDefaults.standard
    private let summaryKey = "weekly_summary"
    private let lastFetchedWeekKey = "last_fetched_week_number"
    
    // 新增週總結列表快取 keys
    private let summaryListKey = "weekly_summary_list"
    private let listLastUpdatedKey = "weekly_summary_list_last_updated"
    
    private init() {}
    
    func saveWeeklySummary(_ summary: WeeklyTrainingSummary, weekNumber: Int? = nil) {
        do {
            let data = try JSONEncoder().encode(summary)
            defaults.set(data, forKey: summaryKey)
            
            if let weekNumber = weekNumber {
                defaults.set(weekNumber, forKey: lastFetchedWeekKey)
            }
            
            defaults.synchronize()
            print("已儲存週訓練回顧")
        } catch {
            print("儲存週訓練回顧時出錯：\(error)")
        }
    }
    
    func loadWeeklySummary() -> WeeklyTrainingSummary? {
        guard let data = defaults.data(forKey: summaryKey) else {
            return nil
        }
        
        do {
            let summary = try JSONDecoder().decode(WeeklyTrainingSummary.self, from: data)
            return summary
        } catch {
            print("讀取週訓練回顧時出錯：\(error)")
            return nil
        }
    }
    
    func getLastFetchedWeekNumber() -> Int? {
        return defaults.object(forKey: lastFetchedWeekKey) as? Int
    }
    
    func clearSavedWeeklySummary() {
        defaults.removeObject(forKey: summaryKey)
        defaults.removeObject(forKey: lastFetchedWeekKey)
        defaults.synchronize()
        print("已清除儲存的週訓練回顧")
    }
    
    func getCacheSize() -> Int {
        var totalSize = 0
        
        // 計算 UserDefaults 中快取項目的大小
        if let data = defaults.data(forKey: summaryKey) {
            totalSize += data.count
        }
        
        // 新增週總結列表的快取大小
        if let listData = defaults.data(forKey: summaryListKey) {
            totalSize += listData.count
        }
        
        return totalSize
    }
    
    // MARK: - 週總結列表管理 (支援 distance_km 欄位)
    
    /// 保存週總結列表（包含 distance_km 欄位）
    func saveWeeklySummaryList(_ summaries: [WeeklySummaryItem]) {
        do {
            let data = try JSONEncoder().encode(summaries)
            defaults.set(data, forKey: summaryListKey)
            defaults.set(Date(), forKey: listLastUpdatedKey)
            defaults.synchronize()
            
            Logger.firebase(
                "已儲存週總結列表",
                level: .debug,
                jsonPayload: [
                    "count": summaries.count,
                    "has_distance_data": summaries.contains { $0.distanceKm != nil }
                ]
            )
        } catch {
            Logger.firebase(
                "儲存週總結列表時出錯",
                level: .error,
                jsonPayload: ["error": error.localizedDescription]
            )
        }
    }
    
    /// 載入週總結列表
    func loadWeeklySummaryList() -> [WeeklySummaryItem]? {
        guard let data = defaults.data(forKey: summaryListKey) else {
            return nil
        }
        
        do {
            let summaries = try JSONDecoder().decode([WeeklySummaryItem].self, from: data)
            
            Logger.firebase(
                "成功載入週總結列表",
                level: .debug,
                jsonPayload: [
                    "count": summaries.count,
                    "distance_entries": summaries.compactMap { $0.distanceKm }.count
                ]
            )
            
            return summaries
        } catch {
            Logger.firebase(
                "讀取週總結列表時出錯，清除損壞的快取",
                level: .warn,
                jsonPayload: ["error": error.localizedDescription]
            )
            clearWeeklySummaryList()
            return nil
        }
    }
    
    /// 獲取週總結列表最後更新時間
    func getWeeklySummaryListLastUpdated() -> Date? {
        return defaults.object(forKey: listLastUpdatedKey) as? Date
    }
    
    /// 清除週總結列表快取
    func clearWeeklySummaryList() {
        defaults.removeObject(forKey: summaryListKey)
        defaults.removeObject(forKey: listLastUpdatedKey)
        defaults.synchronize()
        
        Logger.firebase(
            "已清除週總結列表快取",
            level: .info,
            labels: ["module": "WeeklySummaryStorage"]
        )
    }
    
    /// 檢查週總結列表是否過期
    func isWeeklySummaryListExpired(ttl: TimeInterval = 3600) -> Bool {
        guard let lastUpdated = getWeeklySummaryListLastUpdated() else {
            return true // 沒有更新時間，視為已過期
        }
        
        return Date().timeIntervalSince(lastUpdated) > ttl
    }
}

// MARK: - Cacheable 協議實作
extension WeeklySummaryStorage: Cacheable {
    var cacheIdentifier: String { "weekly_summary" }
    
    func clearCache() {
        clearSavedWeeklySummary()
        clearWeeklySummaryList()
    }
    
    func isExpired() -> Bool {
        return false // 週總結不自動過期
    }
}
