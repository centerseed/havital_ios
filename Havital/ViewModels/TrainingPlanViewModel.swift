import Foundation
import SwiftUI

class TrainingPlanViewModel: ObservableObject {
    @Published var plan: TrainingPlan?
    @Published var trainingDays: [TrainingDay] = []
    @Published var selectedStartDate: Date = Date()
    private let storage = TrainingPlanStorage.shared
    private let healthKitManager = HealthKitManager()
    
    init() {
        loadTrainingPlan()
    }
    
    func loadTrainingPlan() {
        if let plan = storage.loadPlan() {
            self.plan = plan
            self.trainingDays = plan.days
            checkPastDaysCompletion()
        } else {
            generateNewPlan()
        }
    }
    
    private func checkPastDaysCompletion() {
        let today = Date()
        let calendar = Calendar.current
        
        for (index, day) in trainingDays.enumerated() {
            let dayDate = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
            
            // 只檢查今天之前的日期
            guard dayDate <= today else { continue }
            
            // 檢查是否是休息日
            if isRestDay(day) {
                markDayAsCompleted(at: index)
                continue
            }
            
            // 計算預定運動時間（分鐘）
            let totalPlannedMinutes = day.trainingItems.reduce(0) { $0 + $1.durationMinutes }
            let targetMinutes = Double(totalPlannedMinutes) * 0.8 // 80% 的目標時間
            
            // 獲取實際運動時間
            Task {
                let startOfDay = calendar.startOfDay(for: dayDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let workouts = await healthKitManager.fetchWorkoutsForDateRange(start: startOfDay, end: endOfDay)
                // 計算總運動時間（分鐘）
                let totalMinutes = workouts.reduce(0.0) { total, workout in
                    total + workout.duration / 60.0 // 轉換秒為分鐘
                }
                
                // 如果達到目標時間的 80%，標記為完成
                if totalMinutes >= targetMinutes {
                    await MainActor.run {
                        markDayAsCompleted(at: index)
                    }
                }
            }
        }
    }
    
    private func isRestDay(_ day: TrainingDay) -> Bool {
        return day.trainingItems.contains { $0.name == "rest" }
    }
    
    private func markDayAsCompleted(at index: Int) {
        guard index < trainingDays.count else { return }
        var updatedDay = trainingDays[index]
        updatedDay.isCompleted = true
        trainingDays[index] = updatedDay
        
        // 更新儲存的計劃
        if var currentPlan = plan {
            currentPlan.days[index] = updatedDay
            try? storage.savePlan(currentPlan)
            plan = currentPlan
        }
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) async throws {
        try await storage.updateTrainingDay(updatedDay)
        // 更新本地數據
        if let index = trainingDays.firstIndex(where: { $0.id == updatedDay.id }) {
            trainingDays[index] = updatedDay
            if var currentPlan = plan {
                currentPlan.days[index] = updatedDay
                plan = currentPlan
            }
        }
    }
    
    func generateNewPlan() {
        // 刪除原有計劃
        storage.deletePlan()
        
        let jsonString = """
        {"purpose": "第一週訓練目標：循序漸進建立規律運動習慣，提升心肺耐力。", "tips": "本週訓練以超慢跑為主，建議選擇舒適的環境和服裝，專注於呼吸和感受身體的律動。如有任何不適，請立即停止運動。", "days": [{"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "休息", "training_items": [{"name": "rest"}]}]}
        """
        
        if let jsonData = jsonString.data(using: .utf8),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            do {
                var mutableDict = jsonDict
                // 使用選擇的日期作為起始日期
                mutableDict["startDate"] = selectedStartDate.timeIntervalSince1970
                
                // 生成新計劃
                let newPlan = try storage.generateAndSaveNewPlan(from: mutableDict)
                
                // 在主線程更新 UI
                DispatchQueue.main.async {
                    self.plan = newPlan
                    self.trainingDays = newPlan.days
                }
            } catch {
                print("Error generating plan: \(error)")
            }
        }
    }
}
