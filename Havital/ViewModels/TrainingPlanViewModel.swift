import Foundation
import HealthKit
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
            updatePlanStartDate(selectedStartDate)
        }
    }
    
    func requestAuthorization() async {
        do {
            try await healthKitManager.requestAuthorization()
        } catch {
            showingAuthorizationError = true
        }
    }
    
    @MainActor
    func generateNewPlan(plan: String? = nil) {
        // 刪除原有計劃
        storage.deletePlan()
        
        if let jsonData = plan?.data(using: .utf8),
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
        
        // 按照時間戳排序天數
        let sortedDays = trainingDays.enumerated().sorted { a, b in
            a.element.startTimestamp < b.element.startTimestamp
        }
        
        for (index, day) in sortedDays {
            // 獲取當前訓練日的日期
            let dayDate = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
            
            //如果是未來的日期，跳過
            if dayDate > today {
                continue
            }
            
            // 檢查是否是休息日
            if isRestDay(day) && dayDate < today {
                print("第 \(index + 1) 天是休息日，標記為完成")
                markDayAsCompleted(at: index)
                continue
            }
            
            // 獲取實際運動時間
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            do {
                let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startOfDay, end: endOfDay)
                
                // 計算心率數據
                if !workouts.isEmpty && dayDate <= today {
                    await calculateHeartRateStats(for: index, workouts: workouts)
                }
                
                // 計算運動時間達成率
                let totalMinutes = workouts.reduce(0.0) { total, workout in
                    total + workout.duration / 60.0
                }
                
                // 計算預定運動時間（分鐘），排除暖身和放鬆
                let totalPlannedMinutes = day.trainingItems.reduce(0) { total, item in
                    if item.name == "warmup" || item.name == "cooldown" {
                        return total
                    }
                    return total + item.durationMinutes
                }
                
                let targetMinutes = Double(totalPlannedMinutes) * 0.8
                if totalMinutes >= targetMinutes {
                    print("第 \(index + 1) 天達到目標，標記為完成")
                    markDayAsCompleted(at: index)
                }
            } catch {
                print("Error fetching workouts for day \(index + 1): \(error)")
            }
        }
        
        // 更新存儲
        if let plan = plan {
            var updatedPlan = plan
            updatedPlan.days = trainingDays
            do {
                try storage.savePlan(updatedPlan)
                print("成功保存訓練計劃更新")
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
    
    private func calculateHeartRateStats(for dayIndex: Int, workouts: [HKWorkout]) async {
        var allHeartRates: [(Date, Double)] = []
        
        // 獲取每個運動的心率數據
        for workout in workouts {
            do {
                let heartRates = try await healthKitManager.fetchHeartRateData(for: workout)
                allHeartRates.append(contentsOf: heartRates)
            } catch {
                print("無法獲取運動 \(workout.uuid) 的心率數據：\(error)")
            }
        }
        
        // 如果有心率數據，計算平均值和目標達成率
        if !allHeartRates.isEmpty {
            // 排序心率數據並保留最高的75%
            let sortedHeartRates = allHeartRates.map { $0.1 }.sorted(by: >)  // 降序排列
            let endIndex = Int(Double(sortedHeartRates.count) * 0.75)
            let validHeartRates = Array(sortedHeartRates[..<endIndex])
            
            // 計算平均心率
            let avgHeartRate = validHeartRates.reduce(0, +) / Double(validHeartRates.count)
            
            // 計算目標心率達成率
            var goalCompletionRate = 0.0
            let targetHeartRate = trainingDays[dayIndex].trainingItems.compactMap { item -> Int? in
                item.goals.first { $0.type == "heart_rate" }?.value
            }.first ?? 0
            
            if targetHeartRate > 0 {
                goalCompletionRate = min(100, (avgHeartRate / Double(targetHeartRate)) * 100)
            }
            
            // 更新 TrainingDay 的心率統計數據
            var updatedDay = trainingDays[dayIndex]
            updatedDay.heartRateStats = TrainingDay.HeartRateStats(
                averageHeartRate: avgHeartRate,
                heartRates: allHeartRates,
                goalCompletionRate: goalCompletionRate
            )
            trainingDays[dayIndex] = updatedDay
            
            // 更新 plan 中的數據
            if var currentPlan = plan {
                currentPlan.days[dayIndex] = updatedDay
                plan = currentPlan
                
                // 保存到本地存儲
                do {
                    try storage.savePlan(currentPlan)
                    print("成功保存心率數據 - 平均心率: \(avgHeartRate), 目標心率: \(targetHeartRate), 達成率: \(goalCompletionRate)")
                } catch {
                    print("Error saving plan with heart rate stats: \(error)")
                }
            }
        }
    }
    
    func getHeartRateStats(for day: TrainingDay) -> TrainingDay.HeartRateStats? {
        return day.heartRateStats
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
    
    func isLastDayOfPlan() -> Bool {
        guard let lastDay = trainingDays.sorted(by: { $0.startTimestamp < $1.startTimestamp }).last else {
            return false
        }
        
        let today = Date()
        let calendar = Calendar.current
        return calendar.isDateInToday(Date(timeIntervalSince1970: TimeInterval(lastDay.startTimestamp)))
    }
    
    func updatePlanStartDate(_ newStartDate: Date) {
        guard var currentPlan = plan else { return }
        
        // 獲取當前計劃的第一天的時間戳
        let calendar = Calendar.current
        let startOfNewDate = calendar.startOfDay(for: newStartDate)
        
        // 重置所有天數的完成狀態和心率統計
        for i in 0..<currentPlan.days.count {
            let dayDate = calendar.date(byAdding: .day, value: i, to: startOfNewDate)!
            currentPlan.days[i].startTimestamp = Int(dayDate.timeIntervalSince1970)
            currentPlan.days[i].isCompleted = false
            currentPlan.days[i].heartRateStats = nil
        }
        
        // 保存更新後的計劃
        do {
            try storage.savePlan(currentPlan)
            self.plan = currentPlan
            self.trainingDays = currentPlan.days
            
            // 重新檢查過去日期的完成狀態
            Task {
                await checkPastDaysCompletion()
            }
        } catch {
            print("Error saving plan with new start date: \(error)")
        }
    }
    
    func generateWeeklySummary() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var daySummaries: [WeeklySummary.DaySummary] = []
        
        // 按日期排序訓練日，並排除休息日
        let sortedDays = trainingDays
            .sorted { $0.startTimestamp < $1.startTimestamp }
            .filter { day in
                !day.trainingItems.contains { $0.name == "rest" }
            }
        
        for day in sortedDays {
            let dayDate = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
            
            // 獲取主要訓練項目的名稱（排除暖身和放鬆）
            let mainTrainingItem = day.trainingItems.first { item in
                item.name != "warmup" && item.name != "cooldown"
            }
            let trainingName = mainTrainingItem?.name ?? "Unknown Training"
            
            // 計算計劃時間（排除暖身和放鬆）
            let plannedDuration = day.trainingItems.reduce(0) { total, item in
                if item.name == "warmup" || item.name == "cooldown" {
                    return total
                }
                return total + item.durationMinutes
            }
            
            // 獲取實際運動時間
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            var actualDuration = 0
            do {
                let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startOfDay, end: endOfDay)
                actualDuration = Int(workouts.reduce(0.0) { total, workout in
                    total + workout.duration / 60.0
                })
            } catch {
                print("Error fetching workouts: \(error)")
            }
            
            // 收集目標完成情況
            var goals: [WeeklySummary.DaySummary.GoalSummary] = []
            for item in day.trainingItems {
                for goal in item.goals {
                    var completionRate: Double = 0.0
                    
                    // 如果是心率目標，從 heartRateStats 中獲取完成率
                    if goal.type == "heart_rate" {
                        if let stats = day.heartRateStats {
                            completionRate = stats.goalCompletionRate
                            print("Day \(dateFormatter.string(from: dayDate)) - Heart Rate Stats: \(stats.averageHeartRate), Goal: \(goal.value), Completion Rate: \(completionRate)")
                        }
                    } else {
                        // 其他類型的目標從 goalCompletionRates 中獲取
                        completionRate = item.goalCompletionRates[goal.type] ?? 0.0
                        print("Day \(dateFormatter.string(from: dayDate)) - \(goal.type) Goal: \(goal.value), Completion Rate: \(completionRate)")
                    }
                    
                    goals.append(WeeklySummary.DaySummary.GoalSummary(
                        type: goal.type,
                        target: goal.value,
                        completionRate: completionRate
                    ))
                }
            }
            
            daySummaries.append(WeeklySummary.DaySummary(
                name: trainingName,
                date: dateFormatter.string(from: dayDate),
                plannedDuration: plannedDuration,
                actualDuration: actualDuration,
                goals: goals
            ))
        }
        
        let weeklySummary = WeeklySummary(
            startDate: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(sortedDays.first?.startTimestamp ?? 0))),
            endDate: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(sortedDays.last?.startTimestamp ?? 0))),
            days: daySummaries
        )
        
        // 保存總結
        WeeklySummaryStorage.shared.saveSummary(weeklySummary, date: Date())
        
        // 打印總結
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(weeklySummary)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("=== 本週訓練總結 ===")
                print(jsonString)
                print("==================")
            }
        } catch {
            print("Error encoding weekly summary: \(error)")
        }
    }
    
    func loadSummaries(from startDate: Date, to endDate: Date) -> [WeeklySummary] {
        return WeeklySummaryStorage.shared.loadSummaries(from: startDate, to: endDate)
    }
}
