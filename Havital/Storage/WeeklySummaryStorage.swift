import Foundation

class WeeklySummaryStorage {
    static let shared = WeeklySummaryStorage()
    private let defaults = UserDefaults.standard
    
    private let summaryKey = "weekly_summary"
    private let dateKey = "weekly_summary_date"
    private let planIdKey = "weekly_summary_plan_id"
    
    private init() {}
    
    func saveSummary(_ summary: WeeklyAnalysis, date: Date, planId: String) {
        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: summaryKey)
            defaults.set(date.timeIntervalSince1970, forKey: dateKey)
            defaults.set(planId, forKey: planIdKey)
        }
    }
    
    func loadLatestSummary(forPlanId planId: String) -> WeeklyAnalysis? {
        guard let data = defaults.data(forKey: summaryKey),
              let summary = try? JSONDecoder().decode(WeeklyAnalysis.self, from: data),
              let savedPlanId = defaults.string(forKey: planIdKey),
              savedPlanId == planId
        else {
            return nil
        }
        
        return summary
    }
    
    func clearSavedSummary() {
        defaults.removeObject(forKey: summaryKey)
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: planIdKey)
    }
}
