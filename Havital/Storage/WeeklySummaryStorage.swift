import Foundation

class WeeklySummaryStorage {
    static let shared = WeeklySummaryStorage()
    private let defaults = UserDefaults.standard
    private let summaryKey = "weekly_summary"
    private let lastFetchedWeekKey = "last_fetched_week_number"
    
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
        
        return totalSize
    }
}

// MARK: - Cacheable 協議實作
extension WeeklySummaryStorage: Cacheable {
    var cacheIdentifier: String { "weekly_summary" }
    
    func clearCache() {
        clearSavedWeeklySummary()
    }
    
    func isExpired() -> Bool {
        return false // 週總結不自動過期
    }
}
