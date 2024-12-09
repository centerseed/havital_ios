import SwiftUI
import HealthKit

struct TrainingPlanView: View {
    @State private var plan: TrainingPlan?
    @State private var showingUserPreference = false
    @StateObject private var userPrefManager = UserPreferenceManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .onAppear(perform: loadPlan)
    }
    
    private var mainContent: some View {
        Group {
            if let plan = plan {
                List {
                    Section("本週目標") {
                        Text(plan.purpose)
                            .font(.headline)
                    }
                    
                    Section("訓練提示") {
                        Text(plan.tips)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Section("每日計劃") {
                        ForEach(plan.days) { day in
                            DayView(day: day, isToday: isToday(timestamp: day.startTimestamp))
                                .environmentObject(healthKitManager)
                        }
                    }
                }
            } else {
                ProgressView("載入訓練計劃中...")
            }
        }
        .navigationTitle("第一週訓練")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingUserPreference) {
            UserPreferenceView(preference: userPrefManager.currentPreference)
        }
    }
    
    private var toolbarContent: some View {
        Menu {
            Button(action: {
                showingUserPreference = true
            }) {
                Label("個人資料", systemImage: "person.circle")
            }
            
            Button(action: generateNewPlan) {
                Label("重新生成計劃", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.primary)
        }
    }
    
    private func loadPlan() {
        plan = TrainingPlanStorage.shared.loadPlan()
        if plan == nil {
            generateNewPlan()
        }
    }
    
    private func generateNewPlan() {
        let jsonString = """
        {"purpose": "第一週訓練目標：循序漸進建立規律運動習慣，提升心肺耐力。", "tips": "本週訓練以超慢跑為主，建議選擇舒適的環境和服裝，專注於呼吸和感受身體的律動。如有任何不適，請立即停止運動。", "days": [{"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "休息", "training_items": [{"name": "rest"}]}]}
        """
        
        if let jsonData = jsonString.data(using: .utf8),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            do {
                plan = try TrainingPlanStorage.shared.generateAndSaveNewPlan(from: jsonDict)
            } catch {
                print("Error generating plan: \(error)")
            }
        }
    }
    
    private func isToday(timestamp: Int) -> Bool {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Calendar.current.isDateInToday(date)
    }
}

struct DayView: View {
    let day: TrainingDay
    let isToday: Bool
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workouts: [HKWorkout] = []
    @State private var isCompleted: Bool
    
    init(day: TrainingDay, isToday: Bool) {
        self.day = day
        self.isToday = isToday
        self._isCompleted = State(initialValue: day.isCompleted)
    }
    
    var body: some View {
        NavigationLink(destination: TrainingDayDetailView(day: day).environmentObject(healthKitManager)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formatDate(timestamp: day.startTimestamp))
                        .font(.headline)
                        .foregroundColor(isToday ? .blue : .primary)
                    
                    if isToday {
                        Text("今天")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Text(day.purpose)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !day.trainingItems.isEmpty {
                    HStack {
                        ForEach(day.trainingItems) { item in
                            Text(item.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .task {
            await checkCompletion()
        }
    }
    
    private func checkCompletion() async {
        // 獲取當天的開始和結束時間
        let dayStart = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        // 檢查是否是未來的日期
        let now = Date()
        guard dayStart <= now else {
            // 如果是未來的日期，確保設置為未完成
            if isCompleted {
                isCompleted = false
                try? TrainingPlanStorage.shared.updateDayCompletion(day.id, isCompleted: false)
            }
            return
        }
        
        // 獲取當天的運動記錄
        let workouts = await healthKitManager.fetchWorkoutsForDateRange(start: dayStart, end: dayEnd)
        
        // 計算總運動時間（分鐘）
        let totalDuration = workouts.reduce(0) { $0 + $1.duration / 60 }
        
        // 計算所需的運動時間（所有訓練項目的時間總和）
        let requiredDuration = day.trainingItems.reduce(0) { $0 + $1.durationMinutes }
        
        // 如果總運動時間超過要求時間的 60%，標記為完成
        let completed = totalDuration >= Double(requiredDuration) * 0.6
        
        if completed != isCompleted {
            isCompleted = completed
            // 更新存儲
            do {
                try TrainingPlanStorage.shared.updateDayCompletion(day.id, isCompleted: completed)
            } catch {
                print("更新訓練完成狀態失敗：\(error)")
            }
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

struct TrainingItemView: View {
    let item: TrainingItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("\(item.durationMinutes) 分鐘")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                ForEach(item.goals, id: \.type) { goal in
                    Text(formatGoal(goal))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatGoal(_ goal: Goal) -> String {
        switch goal.type {
        case "heart_rate":
            return "心率: \(goal.value) bpm"
        case "times":
            return "次數: \(goal.value)"
        default:
            return ""
        }
    }
}

struct UserPreferenceView: View {
    let preference: UserPreference?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("基本資料") {
                    InfoRow(title: "姓名", value: preference?.userName ?? "未設定")
                    InfoRow(title: "信箱", value: preference?.userEmail ?? "未設定")
                    InfoRow(title: "年齡", value: "\(preference?.age ?? 0)歲")
                }
                
                Section("身體數據") {
                    InfoRow(title: "身高", value: String(format: "%.1f cm", preference?.bodyHeight ?? 0))
                    InfoRow(title: "體重", value: String(format: "%.1f kg", preference?.bodyWeight ?? 0))
                    InfoRow(title: "體脂率", value: String(format: "%.1f%%", preference?.bodyFat ?? 0))
                }
                
                Section("運動能力評估") {
                    LevelRow(title: "有氧運動能力", level: preference?.aerobicsLevel ?? 0)
                    LevelRow(title: "肌力訓練程度", level: preference?.strengthLevel ?? 0)
                    LevelRow(title: "生活忙碌程度", level: preference?.busyLevel ?? 0)
                    LevelRow(title: "運動主動性", level: preference?.proactiveLevel ?? 0)
                }
            }
            .navigationTitle("個人資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct LevelRow: View {
    let title: String
    let level: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(index < level ? .primary : Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                }
            }
        }
    }
}

#Preview {
    TrainingPlanView()
}
