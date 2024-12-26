import Foundation
import SwiftUI

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var plan: TrainingPlan?
    @Published var trainingDays: [TrainingDay] = []
    @Published var showingAuthorizationError = false
    @Published var selectedStartDate = Date()
    
    private let storage: TrainingPlanStorage
    private let healthKitManager: HealthKitManager
    
    init(storage: TrainingPlanStorage = TrainingPlanStorage.shared, healthKitManager: HealthKitManager = HealthKitManager()) {
        self.storage = storage
        self.healthKitManager = healthKitManager
        loadTrainingPlan()
    }
    
    func loadTrainingPlan() {
        if let plan = storage.loadPlan() {
            self.plan = plan
            self.trainingDays = plan.days
            // 檢查過去日期的完成狀態
            Task {
                await checkPastDaysCompletion()
            }
        } else {
            generateNewPlan()
        }
    }
    
    func requestAuthorization() async {
        do {
            try await healthKitManager.requestAuthorization()
        } catch {
            showingAuthorizationError = true
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
            var mutableDict = jsonDict
            // 使用選擇的日期作為起始日期
            mutableDict["startDate"] = selectedStartDate.timeIntervalSince1970
            
            // 生成新計劃
            do {
                let newPlan = try storage.generateAndSaveNewPlan(from: mutableDict)
                self.plan = newPlan
                self.trainingDays = newPlan.days
                
                // 立即檢查過去日期的完成狀態
                Task {
                    await checkPastDaysCompletion()
                }
            } catch {
                print("Error generating plan: \(error)")
            }
        }
    }
    
    private func checkPastDaysCompletion() async {
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
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            do {
                let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startOfDay, end: endOfDay)
                
                // 計算總運動時間（分鐘）
                let totalMinutes = workouts.reduce(0.0) { total, workout in
                    total + workout.duration / 60.0 // 轉換秒為分鐘
                }
                
                // 如果達到目標時間的 80%，標記為完成
                if totalMinutes >= targetMinutes {
                    markDayAsCompleted(at: index)
                }
            } catch {
                print("Error fetching workouts: \(error)")
            }
        }
        
        // 更新存儲
        if let plan = plan {
            var updatedPlan = plan
            updatedPlan.days = trainingDays
            do {
                try storage.savePlan(updatedPlan)
            } catch {
                print("Error saving plan: \(error)")
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
            do {
                try storage.savePlan(currentPlan)
                self.plan = currentPlan
            } catch {
                print("Error saving plan: \(error)")
            }
        }
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) {
        if let index = trainingDays.firstIndex(where: { $0.id == updatedDay.id }) {
            trainingDays[index] = updatedDay
            if var currentPlan = plan {
                currentPlan.days[index] = updatedDay
                do {
                    try storage.savePlan(currentPlan)
                    self.plan = currentPlan
                } catch {
                    print("Error saving plan: \(error)")
                }
            }
        }
    }
}
