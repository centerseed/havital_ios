import SwiftUI
import HealthKit

class TrainingPlanViewModel: ObservableObject {
    @Published var trainingDays: [TrainingDay] = []
    @Published var plan: TrainingPlan?
    
    func loadTrainingPlan() {
        if let plan = TrainingPlanStorage.shared.loadPlan() {
            self.plan = plan
            self.trainingDays = plan.days
        } else {
            // 如果沒有現有計劃，生成新的
            generateNewPlan()
        }
    }
    
    func updateTrainingDay(_ updatedDay: TrainingDay) async throws {
        try await TrainingPlanStorage.shared.updateTrainingDay(updatedDay)
        // 更新本地數據
        if let index = trainingDays.firstIndex(where: { $0.id == updatedDay.id }) {
            trainingDays[index] = updatedDay
        }
    }
    
    func generateNewPlan() {
        let jsonString = """
        {"purpose": "第一週訓練目標：循序漸進建立規律運動習慣，提升心肺耐力。", "tips": "本週訓練以超慢跑為主，建議選擇舒適的環境和服裝，專注於呼吸和感受身體的律動。如有任何不適，請立即停止運動。", "days": [{"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "超慢跑", "training_items": [{"name": "warmup", "duration_minutes": 5}, {"name": "super_slow_run", "duration_minutes": 22, "goals": {"heart_rate": 121}}, {"name": "relax", "duration_minutes": 5}]}, {"target": "休息", "training_items": [{"name": "rest"}]}, {"target": "休息", "training_items": [{"name": "rest"}]}]}
        """
        
        if let jsonData = jsonString.data(using: .utf8),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            do {
                let newPlan = try TrainingPlanStorage.shared.generateAndSaveNewPlan(from: jsonDict)
                self.plan = newPlan
                self.trainingDays = newPlan.days
            } catch {
                print("Error generating plan: \(error)")
            }
        }
    }
}

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showingUserPreference = false
    @StateObject private var userPrefManager = UserPreferenceManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            Group {
                if let plan = viewModel.plan {
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
                            ForEach(viewModel.trainingDays) { day in
                                let isToday = Calendar.current.isDateInToday(Date(timeIntervalSince1970: TimeInterval(day.startTimestamp)))
                                DayView(day: day, isToday: isToday, viewModel: viewModel)
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
                Menu {
                    Button(action: {
                        showingUserPreference = true
                    }) {
                        Label("個人資料", systemImage: "person.circle")
                    }
                    
                    Button(action: {
                        viewModel.generateNewPlan()
                    }) {
                        Label("重新生成計劃", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingUserPreference) {
                UserPreferenceView(preference: userPrefManager.currentPreference)
            }
            .task {
                viewModel.loadTrainingPlan()
            }
        }
    }
}

struct DayView: View {
    let day: TrainingDay
    let isToday: Bool
    let viewModel: TrainingPlanViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workouts: [HKWorkout] = []
    @State private var isCompleted: Bool
    @State private var showingEditSheet = false
    @State private var isFutureDay: Bool = false
    
    init(day: TrainingDay, isToday: Bool, viewModel: TrainingPlanViewModel) {
        self.day = day
        self.isToday = isToday
        self.viewModel = viewModel
        self._isCompleted = State(initialValue: day.isCompleted)
    }
    
    var body: some View {
        NavigationLink(destination: TrainingDayDetailView(day: day)
            .environmentObject(viewModel)
            .environmentObject(healthKitManager)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formatDate(timestamp: day.startTimestamp))
                        .font(.headline)
                        .foregroundColor(isToday ? .blue : .primary)
                    
                    Spacer()
                    
                    if isFutureDay {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    if isToday {
                        Text("今天")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
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
            // 檢查是否為未來日期
            let dayStart = Date(timeIntervalSince1970: TimeInterval(day.startTimestamp))
            isFutureDay = dayStart > Date()
        }
        .sheet(isPresented: $showingEditSheet) {
            TrainingDayEditView(day: day, viewModel: viewModel)
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

struct TrainingDayEditView: View {
    let day: TrainingDay
    let viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: String
    @State private var isUpdating = false
    
    private let trainingTypes = [
        ("超慢跑", [
            TrainingItem(
                id: UUID().uuidString,
                type: "warmup",
                name: "熱身",
                resource: "",
                durationMinutes: 5,
                subItems: [
                    SubItem(id: "1", name: "原地慢跑"),
                    SubItem(id: "2", name: "伸展運動"),
                    SubItem(id: "3", name: "關節活動")
                ],
                goals: [],
                goalCompletionRates: [:]
            ),
            TrainingItem(
                id: UUID().uuidString,
                type: "super_slow_run",
                name: "超慢跑",
                resource: "",
                durationMinutes: 22,
                subItems: [
                    SubItem(id: "1", name: "保持呼吸平穩"),
                    SubItem(id: "2", name: "注意配速"),
                    SubItem(id: "3", name: "維持正確姿勢")
                ],
                goals: [Goal(type: "heart_rate", value: 121)],
                goalCompletionRates: [:]
            ),
            TrainingItem(
                id: UUID().uuidString,
                type: "relax",
                name: "放鬆",
                resource: "",
                durationMinutes: 5,
                subItems: [
                    SubItem(id: "1", name: "緩步走路"),
                    SubItem(id: "2", name: "深呼吸"),
                    SubItem(id: "3", name: "伸展放鬆")
                ],
                goals: [],
                goalCompletionRates: [:]
            )
        ]),
        ("休息", [
            TrainingItem(
                id: UUID().uuidString,
                type: "rest",
                name: "休息",
                resource: "",
                durationMinutes: 0,
                subItems: [
                    SubItem(id: "1", name: "充分休息"),
                    SubItem(id: "2", name: "補充水分"),
                    SubItem(id: "3", name: "適當伸展")
                ],
                goals: [],
                goalCompletionRates: [:]
            )
        ])
    ]
    
    init(day: TrainingDay, viewModel: TrainingPlanViewModel) {
        self.day = day
        self.viewModel = viewModel
        self._selectedType = State(initialValue: day.purpose)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("選擇訓練類型") {
                    ForEach(trainingTypes, id: \.0) { type, items in
                        Button(action: {
                            Task {
                                await updateTrainingDay(type: type, items: items)
                            }
                        }) {
                            HStack {
                                Text(type)
                                Spacer()
                                if type == selectedType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isUpdating)
                    }
                }
            }
            .navigationTitle("調整訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
            }
            .overlay {
                if isUpdating {
                    ProgressView()
                }
            }
        }
    }
    
    private func updateTrainingDay(type: String, items: [TrainingItem]) async {
        isUpdating = true
        defer { isUpdating = false }
        
        // 更新訓練日
        var updatedDay = day
        updatedDay.purpose = type
        updatedDay.trainingItems = items
        
        // 更新提示
        updatedDay.tips = type == "超慢跑" ?
            "保持呼吸平穩，注意配速和姿勢，如果感到不適請立即休息。" :
            "今天是休息日，讓身體充分恢復。可以進行輕度伸展，但避免劇烈運動。"
        
        // 保存更改
        do {
            try await viewModel.updateTrainingDay(updatedDay)
            selectedType = type
            dismiss()
        } catch {
            print("更新訓練日失敗：\(error)")
        }
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
