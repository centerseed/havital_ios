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
    }
}
