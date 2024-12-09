import SwiftUI
import HealthKit

struct TrainingDayDetailView: View {
    @State var day: TrainingDay
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workouts: [HKWorkout] = []
    @State private var heartRates: [(Date, Double)] = []
    @State private var showingAuthorizationError = false
    @State private var averageHeartRate: Double = 0
    
    var body: some View {
        List {
            Section("訓練目標") {
                Text(day.purpose)
                    .font(.headline)
            }
            
            Section("訓練提示") {
                Text(day.tips)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !heartRates.isEmpty {
                Section("訓練成果") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("平均心率：\(Int(averageHeartRate)) bpm")
                                .font(.headline)
                        }
                        
                        if heartRates.count >= 2 {
                            Text("最高心率：\(Int(heartRates.map { $0.1 }.max() ?? 0)) bpm")
                                .font(.subheadline)
                            Text("最低心率：\(Int(heartRates.map { $0.1 }.min() ?? 0)) bpm")
                                .font(.subheadline)
                        }
                        
                    }
                }
            }
            
            Section("訓練項目") {
                ForEach(day.trainingItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.headline)
                        
                        if item.durationMinutes > 0 {
                            Text("時長：\(item.durationMinutes) 分鐘")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.goals.isEmpty {
                            ForEach(item.goals, id: \.type) { goal in
                                GoalView(goal: goal, completionRate: item.goalCompletionRates[goal.type] ?? 0)
                            }
                        }
                        
                        if !item.subItems.isEmpty {
                            Text("訓練要點：")
                                .font(.subheadline)
                                .padding(.top, 4)
                            
                            ForEach(item.subItems) { subItem in
                                Text("• \(subItem.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(formatDate(timestamp: day.startTimestamp))
        .alert("需要健康資料權限", isPresented: $showingAuthorizationError) {
            Button("確定") {}
        } message: {
            Text("請在設定中允許應用程序讀取健康資料，以便追蹤訓練目標的完成情況。")
        }
        .task {
            // 請求 HealthKit 授權
            healthKitManager.requestAuthorization { success in
                if !success {
                    showingAuthorizationError = true
                    return
                }
                // 只有在授權成功後才載入數據
                Task {
                    await loadWorkoutData()
                }
            }
        }
    }
    
    private func loadWorkoutData() async {
        // 獲取當天的開始和結束時間
        let dayStart = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        // 檢查是否是未來的日期
        let now = Date()
        guard dayStart <= now else { return }
        
        // 獲取當天的運動記錄
        let workouts = await healthKitManager.fetchWorkoutsForDateRange(start: dayStart, end: dayEnd)
        self.workouts = workouts
        
        // 對於每個訓練項目，檢查是否有心率目標並計算完成率
        for workout in workouts {
            let heartRates = await healthKitManager.fetchHeartRateData(for: workout)
            self.heartRates.append(contentsOf: heartRates)
        }
        
        // 計算心率目標完成率
        await calculateHeartRateGoalCompletions()
    }
    
    private func calculateHeartRateGoalCompletions() async {
        // 只有當有心率數據時才進行計算
        guard !heartRates.isEmpty else { return }
        
        // 排序心率數據並移除最低的25%
        let sortedHeartRates = heartRates.map { $0.1 }.sorted()
        let startIndex = Int(Double(sortedHeartRates.count) * 0.25)
        let validHeartRates = Array(sortedHeartRates[startIndex...])
        
        // 計算平均心率
        self.averageHeartRate = validHeartRates.reduce(0, +) / Double(validHeartRates.count)
        
        // 更新每個訓練項目的目標完成率
        for (itemIndex, item) in day.trainingItems.enumerated() {
            for goal in item.goals where goal.type == "heart_rate" {
                let targetHeartRate = Double(goal.value)
                var completionRate = (averageHeartRate / targetHeartRate) * 100
                
                // 根據規則調整完成率
                if completionRate >= 80 {
                    completionRate = 100
                } else if completionRate < 50 {
                    completionRate = 50
                }
                
                // 更新完成率
                day.trainingItems[itemIndex].goalCompletionRates["heart_rate"] = completionRate
            }
        }
        
        // 更新存儲
        do {
            try await TrainingPlanStorage.shared.updateTrainingDay(day)
        } catch {
            print("更新目標完成率失敗：\(error)")
        }
    }
    
    private func formatDate(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

struct GoalView: View {
    let goal: Goal
    let completionRate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goalText)
                    .font(.subheadline)
                
                Spacer()
                
                Text(String(format: "%.0f%%", completionRate))
                    .font(.subheadline)
                    .foregroundColor(completionRate >= 100 ? .green : .orange)
            }
            
            ProgressView(value: completionRate, total: 100)
                .tint(completionRate >= 100 ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
    
    private var goalText: String {
        switch goal.type {
        case "heart_rate":
            return "目標心率：\(goal.value) bpm"
        default:
            return "目標：\(goal.value)"
        }
    }
}

#Preview {
    TrainingDayDetailView(day: TrainingDay(
        id: "1",
        startTimestamp: Int(Date().timeIntervalSince1970),
        purpose: "測試訓練",
        isCompleted: false,
        tips: "測試提示",
        trainingItems: []
    ))
}
