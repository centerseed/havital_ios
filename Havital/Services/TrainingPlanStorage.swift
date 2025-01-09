import Foundation

class TrainingPlanStorage {
    static let shared = TrainingPlanStorage()
    private let generator = TrainingPlanGenerator.shared
    private let defaults = UserDefaults.standard
    private let planKey = "training_plan"
    private let planOverviewKey = "training_plan_overview"
    
    private init() {}
    
    func generateAndSaveNewPlan(from jsonDict: [String: Any]) throws -> TrainingPlan {
        let plan = try generator.generatePlan(from: jsonDict)
        try savePlan(plan)
        return plan
    }
    
    func savePlan(_ plan: TrainingPlan) throws {
        let data = try JSONEncoder().encode(plan)
        defaults.set(data, forKey: planKey)
    }
    
    func deletePlan() {
        defaults.removeObject(forKey: planKey)
    }
    
    func loadPlan() -> TrainingPlan? {
        guard let data = defaults.data(forKey: planKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TrainingPlan.self, from: data)
    }
    
    func updateDayCompletion(_ dayId: String, isCompleted: Bool) throws {
        guard var plan = loadPlan() else {
            throw StorageError.planNotFound
        }
        
        plan.updateDayCompletion(dayId, isCompleted: isCompleted)
        try savePlan(plan)
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) async throws {
        guard var plan = loadPlan() else {
            throw StorageError.planNotFound
        }
        
        // 找到並更新對應的訓練日
        if let index = plan.days.firstIndex(where: { $0.id == updatedDay.id }) {
            plan.days[index] = updatedDay
            try savePlan(plan)
        } else {
            throw StorageError.dayNotFound
        }
    }
    
    func saveTrainingPlanOverview(_ overview: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: overview) {
            defaults.set(data, forKey: planOverviewKey)
        }
    }
    
    func loadTrainingPlanOverview() -> [String: Any]? {
        guard let data = defaults.data(forKey: planOverviewKey),
              let overview = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return overview
    }
    
    enum StorageError: Error {
        case planNotFound
        case dayNotFound
    }
}
