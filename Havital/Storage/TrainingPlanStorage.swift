import Foundation

class TrainingPlanStorage {
    static let shared = TrainingPlanStorage()
    private let defaults = UserDefaults.standard
    private let planKey = "training_plan"
    private let planOverviewKey = "training_plan_overview"
    private let weeklyPlanKey = "weekly_plan"
    
    private init() {}
    
    static func saveWeeklyPlan(_ plan: WeeklyPlan) {
        do {
            let data = try JSONEncoder().encode(plan)
            let weekKey = "\(shared.weeklyPlanKey)_week_\(plan.weekOfPlan)"
            UserDefaults.standard.set(data, forKey: weekKey)
            // Also save with the generic key for backward compatibility
            UserDefaults.standard.set(data, forKey: shared.weeklyPlanKey)
        } catch {
            print("Error saving weekly plan: \(error)")
        }
    }
    
    static func loadWeeklyPlan() -> WeeklyPlan? {
        guard let data = UserDefaults.standard.data(forKey: shared.weeklyPlanKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(WeeklyPlan.self, from: data)
        } catch {
            print("Error loading weekly plan: \(error)")
            
            // 記錄詳細的 decode 錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "data_size": data.count,
                "context": "weekly_plan_decode_from_storage",
                "storage_key": shared.weeklyPlanKey
            ]
            
            Logger.firebase("Weekly plan decode failed from UserDefaults storage",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "TrainingPlanStorage", "operation": "loadWeeklyPlan"],
                          jsonPayload: errorDetails)
            
            return nil
        }
    }
    
    static func loadWeeklyPlan(forWeek week: Int) -> WeeklyPlan? {
        let weekKey = "\(shared.weeklyPlanKey)_week_\(week)"
        guard let data = UserDefaults.standard.data(forKey: weekKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(WeeklyPlan.self, from: data)
        } catch {
            print("Error loading weekly plan for week \(week): \(error)")
            
            // 記錄詳細的 decode 錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "data_size": data.count,
                "target_week": week,
                "context": "weekly_plan_decode_from_storage_by_week",
                "storage_key": weekKey
            ]
            
            Logger.firebase("Weekly plan decode failed from UserDefaults storage (by week)",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "TrainingPlanStorage", "operation": "loadWeeklyPlanForWeek"],
                          jsonPayload: errorDetails)
            
            return nil
        }
    }

    static func saveTrainingPlanOverview(_ overview: TrainingPlanOverview) {
        do {
            let data = try JSONEncoder().encode(overview)
            shared.defaults.set(data, forKey: shared.planOverviewKey)
            print("已保存訓練計劃概覽")
        } catch {
            print("保存訓練計劃概覽時出錯：\(error)")
        }
    }
    
    static func loadTrainingPlanOverview() -> TrainingPlanOverview {
        guard let data = shared.defaults.data(forKey: shared.planOverviewKey),
              let overview = try? JSONDecoder().decode(TrainingPlanOverview.self, from: data) else {
            print("無法讀取訓練計劃概覽，返回空的概覽")
            return TrainingPlanOverview(
                id: "",
                mainRaceId: "",
                targetEvaluate: "",
                totalWeeks: 0,
                trainingHighlight: "",
                trainingPlanName: "",
                trainingStageDescription: [],
                createdAt: ""
            )
        }
        return overview
    }
    
    enum StorageError: Error {
        case planNotFound
        case dayNotFound
    }
    
    func clearAll() {
        defaults.removeObject(forKey: planKey)
        defaults.removeObject(forKey: planOverviewKey)
        defaults.removeObject(forKey: weeklyPlanKey)
        
        // Clear all week-specific caches
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(weeklyPlanKey + "_week_") {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    func getCacheSize() -> Int {
        var totalSize = 0
        
        // 計算 UserDefaults 中各個快取項目的大小
        if let data = defaults.data(forKey: planKey) {
            totalSize += data.count
        }
        if let data = defaults.data(forKey: planOverviewKey) {
            totalSize += data.count
        }
        if let data = defaults.data(forKey: weeklyPlanKey) {
            totalSize += data.count
        }
        
        // 計算所有週課表快取的大小
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(weeklyPlanKey + "_week_"), let data = defaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        return totalSize
    }
}

// MARK: - Cacheable 協議實作
extension TrainingPlanStorage: Cacheable {
    var cacheIdentifier: String { "training_plan" }
    
    func clearCache() {
        clearAll()
    }
    
    func isExpired() -> Bool {
        return false // 訓練計劃不自動過期
    }
}
