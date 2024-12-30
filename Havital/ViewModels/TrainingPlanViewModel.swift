import Foundation
import HealthKit
import SwiftUI

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var plan: TrainingPlan? {
        didSet {
            // 只在計劃 ID 改變時清除分析
            if plan?.id != oldValue?.id {
                weeklyAnalysis = nil
                summaryStorage.clearSavedSummary()
            }
            
            // 更新訓練日
            if let plan = plan {
                trainingDays = plan.days
            } else {
                trainingDays = []
            }
        }
    }
    @Published var trainingDays: [TrainingDay] = []
    @Published var showingAuthorizationError = false
    @Published var selectedStartDate = Date()
    @Published var selectedDay: TrainingDay?
    @Published var weeklyAnalysis: WeeklyAnalysis?
    @Published var isGeneratingAnalysis = false
    @Published var analysisError: Error?
    
    private let storage: TrainingPlanStorage
    private let healthKitManager: HealthKitManager
    private let summaryStorage = WeeklySummaryStorage.shared
    
    init(storage: TrainingPlanStorage = TrainingPlanStorage.shared, healthKitManager: HealthKitManager = HealthKitManager()) {
        self.storage = storage
        self.healthKitManager = healthKitManager
        
        // 從存儲加載計劃
        if let savedPlan = try? storage.loadPlan() {
            self.plan = savedPlan
            self.trainingDays = savedPlan.days
            
            // 嘗試加載保存的分析
            if let savedAnalysis = summaryStorage.loadLatestSummary(forPlanId: savedPlan.id) {
                self.weeklyAnalysis = savedAnalysis
            }
        }
    }
    
    func loadTrainingPlan() {
        if let savedPlan = try? storage.loadPlan() {
            self.plan = savedPlan
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
        let lastDayDate = Date(timeIntervalSince1970: TimeInterval(lastDay.startTimestamp))
        return today >= Calendar.current.startOfDay(for: lastDayDate)
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
    
    private func generateWeeklySummary() async -> String {
        guard let currentPlan = plan else { return "" }
        
        // 獲取計劃的開始和結束時間
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let workoutDays = trainingDays.filter { day in
            !day.trainingItems.isEmpty && !day.trainingItems.contains { $0.name == "rest" }
        }
        
        guard let firstDay = workoutDays.min(by: { $0.startTimestamp < $1.startTimestamp }),
              let lastDay = workoutDays.max(by: { $0.startTimestamp < $1.startTimestamp }) else {
            return "{}"
        }
        
        let startDate = Date(timeIntervalSince1970: TimeInterval(firstDay.startTimestamp))
        let endDate = Date(timeIntervalSince1970: TimeInterval(lastDay.startTimestamp))
        
        var daySummaries: [WeeklySummary.DaySummary] = []
        
        for day in workoutDays.sorted(by: { $0.startTimestamp < $1.startTimestamp }) {
            let dayDate = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
            
            // 計算實際運動時間
            var totalMinutes = 0.0
            if let heartRateStats = day.heartRateStats,
               !heartRateStats.heartRates.isEmpty {
                let startTime = heartRateStats.heartRates.first!.timestamp
                let endTime = heartRateStats.heartRates.last!.timestamp
                totalMinutes = endTime.timeIntervalSince(startTime) / 60.0
            }
            
            for item in day.trainingItems where item.name != "warmup" && item.name != "cooldown" {
                var goals: [WeeklySummary.DaySummary.GoalSummary] = []
                
                // 心率目標
                if let heartRateStats = day.heartRateStats,
                   let heartRateGoal = item.goals.first(where: { $0.type == "heart_rate" }) {
                    goals.append(.init(
                        type: "heart_rate",
                        target: heartRateGoal.value,
                        completionRate: heartRateStats.goalCompletionRate
                    ))
                }
                
                let daySummary = WeeklySummary.DaySummary(
                    date: dateFormatter.string(from: dayDate),
                    name: item.name,
                    plannedDuration: item.durationMinutes,
                    actualDuration: Int(totalMinutes),
                    goals: goals
                )
                
                daySummaries.append(daySummary)
            }
        }
        
        let summary = WeeklySummary(
            startDate: dateFormatter.string(from: startDate),
            endDate: dateFormatter.string(from: endDate),
            days: daySummaries
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        guard let jsonData = try? encoder.encode(summary),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    func generateAnalysis() async {
        guard let currentPlan = plan else { return }
        
        // 如果已經有分析結果，直接返回
        if weeklyAnalysis != nil {
            return
        }
        
        // 檢查是否已有保存的分析
        if let savedAnalysis = summaryStorage.loadLatestSummary(forPlanId: currentPlan.id) {
            weeklyAnalysis = savedAnalysis
            return
        }
        
        isGeneratingAnalysis = true
        analysisError = nil
        
        do {
            let summary = await generateWeeklySummary()
            let geminiInput = ["weekly_summary": summary]
            
            let result = try await GeminiService.shared.generateContent(
                withPromptFiles: ["prompt_summary"],
                input: geminiInput,
                schema: summarySchema
            )
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: result),
               let analysis = try? JSONDecoder().decode(WeeklyAnalysis.self, from: jsonData) {
                weeklyAnalysis = analysis
                // 保存分析結果
                summaryStorage.saveSummary(analysis, date: Date(), planId: currentPlan.id)
            }
        } catch {
            analysisError = error
        }
        
        isGeneratingAnalysis = false
    }
}
