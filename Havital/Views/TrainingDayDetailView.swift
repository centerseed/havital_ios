import SwiftUI
import HealthKit

class TrainingDayDetailViewModel: ObservableObject {
    @Published var heartRates: [(Date, Double)] = []
    @Published var averageHeartRate: Double = 0
    @Published var showingAuthorizationError = false
    
    private let healthKitManager: HealthKitManager
    private let trainingPlanViewModel: TrainingPlanViewModel
    private let day: TrainingDay
    
    init(day: TrainingDay, healthKitManager: HealthKitManager, trainingPlanViewModel: TrainingPlanViewModel) {
        self.day = day
        self.healthKitManager = healthKitManager
        self.trainingPlanViewModel = trainingPlanViewModel
    }
    
    @MainActor
    func requestAuthorization() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await loadWorkoutData()
            } catch {
                showingAuthorizationError = true
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
        do {
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: dayStart, end: dayEnd)
            
            // 清空之前的心率數據
            await MainActor.run {
                self.heartRates = []
            }
            
            // 對於每個訓練項目，檢查是否有心率目標並計算完成率
            for workout in workouts {
                if let avgHeartRate = try await healthKitManager.fetchSleepHeartRateAverage(for: dayStart) {
                    await MainActor.run {
                        self.heartRates.append((dayStart, avgHeartRate))
                    }
                }
            }
            
            // 計算心率目標完成率
            if !self.heartRates.isEmpty {
                await calculateHeartRateGoalCompletions()
            }
        } catch {
            print("Error loading workouts: \(error)")
        }
    }
    
    private func calculateHeartRateGoalCompletions() async {
        // 排序心率數據並移除最低的25%
        let sortedHeartRates = heartRates.map { $0.1 }.sorted()
        let startIndex = max(0, Int(Double(sortedHeartRates.count) * 0.25))
        let validHeartRates = Array(sortedHeartRates[startIndex...])
        
        // 計算平均心率
        let avgHeartRate = validHeartRates.reduce(0, +) / Double(validHeartRates.count)
        
        print("平均心率：\(avgHeartRate)") // 添加調試輸出
        
        await MainActor.run {
            self.averageHeartRate = avgHeartRate
        }
        
        // 更新每個訓練項目的目標完成率
        var updatedDay = day
        for (itemIndex, item) in day.trainingItems.enumerated() {
            for goal in item.goals where goal.type == "heart_rate" {
                let targetHeartRate = Double(goal.value)
                var completionRate = (avgHeartRate / targetHeartRate) * 100
                
                print("目標心率：\(targetHeartRate), 完成率：\(completionRate)") // 添加調試輸出
                
                // 根據規則調整完成率
                if completionRate >= 80 {
                    completionRate = 100
                } else if completionRate < 50 {
                    completionRate = 50
                }
                
                // 更新完成率
                updatedDay.trainingItems[itemIndex].goalCompletionRates["heart_rate"] = completionRate
            }
        }
        
        // 更新存儲
        do {
            try await trainingPlanViewModel.updateTrainingDay(updatedDay)
        } catch {
            print("更新目標完成率失敗：\(error)")
        }
    }
}

struct TrainingDayDetailView: View {
    let day: TrainingDay
    @StateObject private var viewModel: TrainingDayDetailViewModel
    @EnvironmentObject private var trainingPlanViewModel: TrainingPlanViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    init(day: TrainingDay) {
        self.day = day
        self._viewModel = StateObject(wrappedValue: TrainingDayDetailViewModel(
            day: day,
            healthKitManager: HealthKitManager(),
            trainingPlanViewModel: TrainingPlanViewModel()
        ))
    }
    
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
            
            if !viewModel.heartRates.isEmpty {
                Section("訓練成果") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("平均心率：\(Int(viewModel.averageHeartRate)) bpm")
                                .font(.headline)
                        }
                        
                        if viewModel.heartRates.count >= 2 {
                            Text("最高心率：\(Int(viewModel.heartRates.map { $0.1 }.max() ?? 0)) bpm")
                                .font(.subheadline)
                            Text("最低心率：\(Int(viewModel.heartRates.map { $0.1 }.min() ?? 0)) bpm")
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
        .navigationTitle(DateFormatterUtil.formatDate(timestamp: day.startTimestamp))
        .alert("需要健康資料權限", isPresented: $viewModel.showingAuthorizationError) {
            Button("確定") {}
        } message: {
            Text("請在設定中允許應用程序讀取健康資料，以便追蹤訓練目標的完成情況。")
        }
        .task {
            await viewModel.requestAuthorization()
        }
    }
}

struct GoalView: View {
    let goal: Goal
    let completionRate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            HStack {
                Text("\(Int(completionRate))%")
                    .font(.caption)
                    .foregroundColor(completionRate >= 100 ? .green : .orange)
                
                ProgressView(value: min(completionRate, 100), total: 100)
                    .tint(completionRate >= 100 ? .green : .orange)
            }
        }
    }
}

#Preview {
    TrainingDayDetailView(
        day: TrainingDay(
            id: "test",
            startTimestamp: Int(Date().timeIntervalSince1970),
            purpose: "測試目的",
            isCompleted: false,
            tips: "測試提示",
            trainingItems: []
        )
    )
    .environmentObject(TrainingPlanViewModel())
    .environmentObject(HealthKitManager())
}
