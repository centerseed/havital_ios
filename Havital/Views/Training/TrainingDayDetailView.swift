import SwiftUI
import HealthKit

class TrainingDayDetailViewModel: ObservableObject {
    @Published var heartRates: [(Date, Double)] = []
    @Published var averageHeartRate: Double = 0
    @Published var showingAuthorizationError = false
    @Published var workouts: [HKWorkout] = []
    
    private var day: TrainingDay
    private var healthKitManager: HealthKitManager
    private var trainingPlanViewModel: TrainingPlanViewModel
    
    init(day: TrainingDay, healthKitManager: HealthKitManager, trainingPlanViewModel: TrainingPlanViewModel) {
        self.day = day
        self.healthKitManager = healthKitManager
        self.trainingPlanViewModel = trainingPlanViewModel
    }
    
    func updateDependencies(healthKitManager: HealthKitManager, trainingPlanViewModel: TrainingPlanViewModel) {
        self.healthKitManager = healthKitManager
        self.trainingPlanViewModel = trainingPlanViewModel
    }
    
    func updateDay(_ updatedDay: TrainingDay) {
        self.day = updatedDay
        // 重新加載數據
        Task {
            await loadWorkoutData()
        }
    }
    
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
            let fetchedWorkouts = try await healthKitManager.fetchWorkoutsForDateRange(start: dayStart, end: dayEnd)
            
            // 更新 workouts
            await MainActor.run {
                self.workouts = fetchedWorkouts
                self.heartRates = []
            }
            
            // 獲取每個運動的心率數據
            for workout in fetchedWorkouts {
                do {
                    let heartRates = try await healthKitManager.fetchHeartRateData(for: workout)
                    await MainActor.run {
                        self.heartRates.append(contentsOf: heartRates)
                    }
                } catch {
                    print("無法獲取運動 \(workout.uuid) 的心率數據：\(error)")
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
        // 排序心率數據並保留最高的75%
        let sortedHeartRates = heartRates.map { $0.1 }.sorted(by: >)  // 降序排列
        let endIndex = Int(Double(sortedHeartRates.count) * 0.75)
        let validHeartRates = Array(sortedHeartRates[..<endIndex])
        
        // 計算平均心率
        let avgHeartRate = validHeartRates.reduce(0, +) / Double(validHeartRates.count)
        
        print("心率數據數量：\(heartRates.count)")
        print("有效心率數據數量：\(validHeartRates.count)")
        print("最高心率：\(sortedHeartRates.first ?? 0)")
        print("最低有效心率：\(validHeartRates.last ?? 0)")
        print("平均心率：\(avgHeartRate)")
        
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
                if completionRate >= 100 {
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
    @State private var showingEditSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentDay: TrainingDay
    
    init(day: TrainingDay) {
        self.day = day
        self._currentDay = State(initialValue: day)
        self._viewModel = StateObject(wrappedValue: TrainingDayDetailViewModel(
            day: day,
            healthKitManager: HealthKitManager(),
            trainingPlanViewModel: TrainingPlanViewModel()
        ))
    }
    
    var body: some View {
        TrainingDayContentView(day: currentDay, viewModel: viewModel)
            .navigationTitle(DateFormatterUtil.formatDate(timestamp: currentDay.startTimestamp))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                NavigationView {
                    EditTrainingDayView(
                        day: currentDay,
                        trainingPlanViewModel: trainingPlanViewModel
                    ) { updatedDay in
                        Task {
                            do {
                                try await trainingPlanViewModel.updateTrainingDay(updatedDay)
                                await MainActor.run {
                                    showingEditSheet = false
                                    currentDay = updatedDay
                                    viewModel.updateDay(updatedDay)
                                }
                            } catch {
                                print("更新訓練日失敗：\(error)")
                            }
                        }
                    }
                    .navigationTitle("編輯訓練")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .alert("需要健康資料權限", isPresented: $viewModel.showingAuthorizationError) {
                Button("確定") {}
            } message: {
                Text("請在設定中允許應用程序讀取健康資料，以便追蹤訓練目標的完成情況。")
            }
            .onAppear {
                self.viewModel.updateDependencies(
                    healthKitManager: healthKitManager,
                    trainingPlanViewModel: trainingPlanViewModel
                )
                Task {
                    await viewModel.requestAuthorization()
                }
            }
    }
}

struct EditTrainingDayView: View {
    let day: TrainingDay
    let trainingPlanViewModel: TrainingPlanViewModel
    let onSave: (TrainingDay) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var purpose: String
    @State private var tips: String
    @State private var isRestDay: Bool
    @State private var trainingItems: [TrainingItem]
    @State private var showingItemSheet = false
    @State private var newItem: TrainingItem?
    
    init(day: TrainingDay, trainingPlanViewModel: TrainingPlanViewModel, onSave: @escaping (TrainingDay) -> Void) {
        self.day = day
        self.trainingPlanViewModel = trainingPlanViewModel
        self.onSave = onSave
        
        _purpose = State(initialValue: day.purpose)
        _tips = State(initialValue: day.tips)
        _isRestDay = State(initialValue: day.trainingItems.count == 1 && day.trainingItems[0].name.lowercased() == "rest")
        _trainingItems = State(initialValue: day.trainingItems)
    }
    
    private func updateDay(isRest: Bool) async {
        var updatedDay = day
        if isRest {
            updatedDay.trainingItems = [
                TrainingItem(
                    id: UUID().uuidString,
                    type: "rest",
                    name: "rest",
                    resource: "",
                    durationMinutes: 0,
                    subItems: [],
                    goals: [],
                    goalCompletionRates: [:]
                )
            ]
            updatedDay.tips = "好好休息"
        } else {
            updatedDay.trainingItems = []
            updatedDay.tips = ""
        }
        
        do {
            try await trainingPlanViewModel.updateTrainingDay(updatedDay)
            trainingItems = updatedDay.trainingItems
            tips = updatedDay.tips
        } catch {
            print("更新訓練日失敗：\(error)")
        }
    }
    
    var body: some View {
        Form {
            Toggle("休息日", isOn: $isRestDay)
                .onChange(of: isRestDay) { newValue in
                    Task {
                        await updateDay(isRest: newValue)
                    }
                }
            
            if !isRestDay {
                Section {
                    ForEach(trainingItems) { item in
                        HStack {
                            Image(systemName: TrainingItemStyle.icon(for: item.displayName))
                                .foregroundColor(TrainingItemStyle.color(for: item.displayName))
         
                            Text(item.displayName)
                            Spacer()
                            Text("\(item.durationMinutes)分鐘")
                        }
                    }
                    .onDelete { indexSet in
                        trainingItems.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        trainingItems.move(fromOffsets: from, toOffset: to)
                    }
                    
                    Button("添加訓練項目") {
                        showingItemSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingItemSheet) {
            NavigationView {
                EditTrainingItemView(onSave: { updatedItem in
                    Task {
                        if !updatedItem.name.isEmpty {
                            trainingItems.append(updatedItem)
                            purpose = updatedItem.displayName  // 更新 purpose 為訓練名稱
                            do {
                                var updatedDay = day
                                updatedDay.trainingItems = trainingItems
                                updatedDay.purpose = updatedItem.displayName  // 同時更新 day 的 purpose
                                try await trainingPlanViewModel.updateTrainingDay(updatedDay)
                            } catch {
                                print("保存訓練項目失敗：\(error)")
                            }
                        }
                        showingItemSheet = false
                    }
                }, onCancel: {
                    showingItemSheet = false
                })
            }
        }
        .navigationTitle("編輯訓練日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    var updatedDay = day
                    updatedDay.purpose = purpose
                    updatedDay.tips = ""
                    
                    if !isRestDay && !trainingItems.isEmpty {
                        let warmup = TrainingItem(
                            id: UUID().uuidString,
                            type: "warmup",
                            name: "warmup",
                            resource: "",
                            durationMinutes: 0,
                            subItems: [],
                            goals: [],
                            goalCompletionRates: [:]
                        )
                        
                        let cooldown = TrainingItem(
                            id: UUID().uuidString,
                            type: "cooldown",
                            name: "cooldown",
                            resource: "",
                            durationMinutes: 0,
                            subItems: [],
                            goals: [],
                            goalCompletionRates: [:]
                        )
                        
                        updatedDay.trainingItems = [warmup] + trainingItems + [cooldown]
                    } else {
                        updatedDay.trainingItems = trainingItems
                    }
                    
                    onSave(updatedDay)
                    dismiss()
                }
            }
        }
    }
}

struct EditTrainingItemView: View {
    let onSave: (TrainingItem) -> Void
    let onCancel: () -> Void
    
    @State private var selectedDefinition: TrainingItemDefinition?
    @State private var editedItem: TrainingItem
    @State private var definitions: [TrainingItemDefinition] = []
    @EnvironmentObject private var trainingPlanViewModel: TrainingPlanViewModel
    
    init(onSave: @escaping (TrainingItem) -> Void, onCancel: @escaping () -> Void) {
        print("EditTrainingItemView init...")
        self.onSave = onSave
        self.onCancel = onCancel
        _editedItem = State(initialValue: TrainingItem(
            id: UUID().uuidString,
            type: "",
            name: "",
            resource: "",
            durationMinutes: 30,
            subItems: [],
            goals: [],
            goalCompletionRates: [:]
        ))
    }
    
    private var shouldShowHeartRateGoal: Bool {
        let name = editedItem.name.lowercased()
        return name != "cooldown" && name != "warmup" && name != "rest"
    }
    
    private func loadDefinitions() {
        print("loadDefinitions...")
        if let defs = TrainingDefinitions.load()?.trainingItemDefs {
            // 過濾掉特殊項目
            let filteredDefs = defs.filter { def in
                let name = def.name.lowercased()
                return name != "cooldown" && name != "warmup" && name != "rest"
            }
            
            definitions = filteredDefs
            
            // 如果還沒有選擇定義，選擇第一個
            if selectedDefinition == nil, let firstDef = filteredDefs.first {
                selectedDefinition = firstDef
                editedItem.name = firstDef.name
                editedItem.type = firstDef.name
                
                // 設置默認時長
                switch firstDef.name {
                case "super_slow_run", "running":
                    editedItem.durationMinutes = 20
                case "jump_rope":
                    editedItem.durationMinutes = 8
                case "hiit":
                    editedItem.durationMinutes = 4
                default:
                    editedItem.durationMinutes = 30
                }
                
                // 設置默認目標
                if shouldShowHeartRateGoal {
                    editedItem.goals = [Goal(type: "heart_rate", value: 120)]
                }
            }
        }
    }
    
    private func getExistingGoals(for itemName: String) -> [Goal] {
        guard let plan = trainingPlanViewModel.plan else { return [] }
        
        for day in plan.days {
            for trainingItem in day.trainingItems where trainingItem.name == itemName {
                if !trainingItem.goals.isEmpty {
                    return trainingItem.goals
                }
            }
        }
        return []
    }
    
    var body: some View {
        Form {
            Section {
                Picker("訓練類型", selection: $selectedDefinition) {
                    ForEach(definitions) { def in
                        Text(def.displayName).tag(Optional(def))
                    }
                }
                .onChange(of: selectedDefinition) { newValue in
                    if let def = newValue {
                        editedItem.name = def.name
                        editedItem.type = def.name
                        
                        // 獲取現有目標
                        let existingGoals = getExistingGoals(for: def.name)
                        if !existingGoals.isEmpty {
                            editedItem.goals = existingGoals
                        } else if shouldShowHeartRateGoal {
                            editedItem.goals = [Goal(type: "heart_rate", value: 120)]
                        }
                        
                        // 設置默認時長
                        switch def.name {
                        case "super_slow_run", "running":
                            editedItem.durationMinutes = 20
                        case "jump_rope":
                            editedItem.durationMinutes = 8
                        case "hiit":
                            editedItem.durationMinutes = 4
                        default:
                            editedItem.durationMinutes = 30
                        }
                    }
                }
                
                Stepper("時長: \(editedItem.durationMinutes) 分鐘", value: $editedItem.durationMinutes, in: 0...240)
            }
            
            if shouldShowHeartRateGoal {
                Section("目標") {
                    ForEach(editedItem.goals.indices, id: \.self) { index in
                        HStack {
                            Text("目標心率")
                            Spacer()
                            TextField("心率", value: $editedItem.goals[index].value, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("bpm")
                        }
                    }
                    .onDelete { indexSet in
                        editedItem.goals.remove(atOffsets: indexSet)
                    }
                    
                    if editedItem.goals.isEmpty {
                        Button("添加心率目標") {
                            editedItem.goals.append(Goal(type: "heart_rate", value: 120))
                        }
                    }
                }
            }
        }
        .navigationTitle("添加訓練項目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    onSave(editedItem)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    onCancel()
                }
            }
        }
        .onAppear {
            loadDefinitions()
        }
    }
}

struct TrainingDayContentView: View {
    let day: TrainingDay
    @ObservedObject var viewModel: TrainingDayDetailViewModel
    
    var body: some View {
        List {
            TrainingPurposeSection(purpose: day.purpose)
            TrainingTipsSection(tips: day.tips)
            
            if !viewModel.heartRates.isEmpty {
                TrainingResultsSection(averageHeartRate: Int(viewModel.averageHeartRate))
            }
            
            TrainingItemsSection(items: day.trainingItems)
            
            if !viewModel.workouts.isEmpty {
                WorkoutsSection(workouts: viewModel.workouts)
            }
        }
    }
}

private struct TrainingPurposeSection: View {
    let purpose: String
    
    var body: some View {
        Section("訓練目標") {
            Text(purpose)
                .font(.headline)
        }
    }
}
private struct TrainingTipsSection: View {
    let tips: String
    
    var body: some View {
        Section("訓練提示") {
            Text(tips)
        }
    }
}


private struct WorkoutsSection: View {
    let workouts: [HKWorkout]
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        Section("今日運動") {
            ForEach(workouts, id: \.uuid) { workout in
                NavigationLink(destination: WorkoutDetailView(
                    workout: workout,
                    healthKitManager: healthKitManager,
                    initialHeartRateData: []
                )) {
                    WorkoutRowView(workout: workout)
                }
            }
        }
    }
}

private struct TrainingResultsSection: View {
    let averageHeartRate: Int
    
    var body: some View {
        Section("訓練成果") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("運動平均心率：\(Int(averageHeartRate)) bpm")
                        .font(.headline)
                }
            }
        }
    }
}

private struct TrainingItemsSection: View {
    let items: [TrainingItem]
    
    var body: some View {
        Section("訓練項目") {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: TrainingItemStyle.icon(for: item.displayName))
                            .foregroundColor(TrainingItemStyle.color(for: item.displayName))
                        
                        Text(item.displayName)
                            .font(.headline)
                    }
                    
                    if !item.goals.isEmpty {
                        ForEach(item.goals, id: \.type) { goal in
                            HStack {
                                if goal.type == "heart_rate" {
                                    Text("目標心率：\(goal.value) bpm")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let completionRate = item.goalCompletionRates["heart_rate"] {
                                        Text(String(format: "完成率：%.1f%%", completionRate))
                                            .font(.subheadline)
                                            .foregroundColor(completionRate >= 100 ? .green : .orange)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !item.subItems.isEmpty {
                        Text("訓練要點：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(item.subItems, id: \.id) { subItem in
                            Text("• \(subItem.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct GoalView: View {
    let goal: Goal
    let completionRate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(goal.type): \(goal.value)")
                .font(.caption)
            
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
