import SwiftUI
import HealthKit

class TrainingDayDetailViewModel: ObservableObject {
    @Published var heartRates: [(Date, Double)] = []
    @Published var averageHeartRate: Double = 0
    @Published var heartRateGoalCompletionRate: Double = 0
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
            }
            
            // 從 day 中獲取心率數據
            if let stats = day.heartRateStats {
                await MainActor.run {
                    self.heartRates = stats.heartRateTuples
                    self.averageHeartRate = stats.averageHeartRate
                    self.heartRateGoalCompletionRate = stats.goalCompletionRate
                }
            }
        } catch {
            print("Error loading workouts: \(error)")
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
            updatedDay.purpose = "讓身體從上一次疲勞中恢複"
        } else {
            updatedDay.trainingItems = []
            updatedDay.tips = ""
            updatedDay.purpose = ""
        }
        
        do {
            try await trainingPlanViewModel.updateTrainingDay(updatedDay)
            trainingItems = updatedDay.trainingItems
            tips = updatedDay.tips
        } catch {
            print("更新訓練日失敗：\(error)")
        }
    }
    
    private func formatPaceValue(_ value: Int) -> String {
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatGoalValue(_ goal: Goal) -> String {
        switch goal.type {
        case "heart_rate":
            return "\(goal.value) bpm"
        case "times":
            return "\(goal.value) 次"
        case "pace":
            return "\(formatPaceValue(goal.value))/公里"
        default:
            return "\(goal.value)"
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
                Section("訓練項目") {
                    ForEach(trainingItems.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: TrainingItemStyle.icon(for: trainingItems[index].name))
                                    .foregroundColor(TrainingItemStyle.color(for: trainingItems[index].name))
                                Text(trainingItems[index].displayName)
                                Spacer()
                                Text("\(trainingItems[index].durationMinutes)分鐘")
                            }
                            
                            if !trainingItems[index].goals.isEmpty {
                                ForEach(trainingItems[index].goals.indices, id: \.self) { goalIndex in
                                    Text(formatGoalValue(trainingItems[index].goals[goalIndex]))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        trainingItems.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        trainingItems.move(fromOffsets: from, toOffset: to)
                    }
                    
                    Button {
                        showingItemSheet = true
                    } label: {
                        Label("添加訓練項目", systemImage: "plus.circle.fill")
                    }
                }
                
                Section {
                    TextField("訓練目標", text: $purpose)
                    TextField("訓練提示", text: $tips)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    var updatedDay = day
                    updatedDay.trainingItems = trainingItems
                    updatedDay.purpose = purpose
                    updatedDay.tips = tips
                    onSave(updatedDay)
                }
            }
        }
        .sheet(isPresented: $showingItemSheet) {
            NavigationView {
                EditTrainingItemView(
                    onSave: { item in
                        trainingItems.append(item)
                        showingItemSheet = false
                    },
                    onCancel: {
                        showingItemSheet = false
                    }
                )
            }
        }
    }
}

struct EditTrainingItemView: View {
    let onSave: (TrainingItem) -> Void
    let onCancel: () -> Void
    
    @State private var editedItem: TrainingItem
    @State private var definitions: [TrainingItemDefinition] = []
    @State private var selectedDefinition: TrainingItemDefinition?
    @State private var showingGoalWheel = false
    @State private var selectedGoalIndex: Int? = nil
    @EnvironmentObject private var trainingPlanViewModel: TrainingPlanViewModel
    
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
    
    private var shouldShowGoals: Bool {
        let name = editedItem.name.lowercased()
        return name != "cooldown" && name != "warmup" && name != "rest"
    }
    
    private var availableGoalTypes: [String] {
        let name = editedItem.name.lowercased()
        var types = ["heart_rate"]  // 所有運動項目都可以設定心率
        
        switch name {
        case "jump_rope":
            types.append("times")
        case "running":
            types.append("pace")
        default:
            break
        }
        
        return types
    }
    
    private var availableGoalDisplayNames: [String] {
        return availableGoalTypes.map { getGoalDisplayName(type: $0) }
    }
    
    private var hasAvailableGoals: Bool {
        let currentGoalTypes = Set(editedItem.goals.map { $0.type })
        let availableTypes = Set(availableGoalTypes)
        return !availableTypes.subtracting(currentGoalTypes).isEmpty
    }
    
    private func getGoalDisplayName(type: String) -> String {
        switch type {
        case "heart_rate":
            return "心率"
        case "times":
            return "次數"
        case "pace":
            return "配速"
        default:
            return type
        }
    }
    
    private func getGoalUnit(for type: String) -> String {
        switch type {
        case "heart_rate":
            return "bpm"
        case "times":
            return "次"
        case "pace":
            return "分鐘/公里"
        default:
            return ""
        }
    }
    
    private func formatPaceValue(_ value: Int) -> String {
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func parsePaceInput(_ input: String) -> Int? {
        let components = input.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]),
              seconds >= 0 && seconds < 60
        else {
            return nil
        }
        return minutes * 60 + seconds
    }
    
    private func loadDefinitions() {
        print("loadDefinitions...")
        if let defs = TrainingDefinitions.load()?.trainingItemDefs {
            // 過濾掉特殊項目
            let filteredDefs = defs.filter { def in
                let name = def.name.lowercased()
                return name != "rest"
            }
            
            definitions = filteredDefs
            
            // 如果還沒有選擇定義，選擇第一個
            if selectedDefinition == nil, let firstDef = filteredDefs.first {
                selectedDefinition = firstDef
                editedItem.name = firstDef.name
                editedItem.type = firstDef.name
                
                // 設置默認時長
                switch firstDef.name {
                case "warmup", "cooldown":
                    editedItem.durationMinutes = 5
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
                if shouldShowGoals {
                    editedItem.goals = []
                    if availableGoalTypes.contains("heart_rate") {
                        editedItem.goals.append(Goal(type: "heart_rate", value: 120))
                    }
                    
                    // 為跑步添加默認配速目標
                    if ["running"].contains(firstDef.name.lowercased()) {
                        editedItem.goals.append(Goal(type: "pace", value: 6 * 60))  // 默認6分鐘/公里
                    }
                }
            }
        }
    }
    
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
                        } else {
                            // 設置默認目標
                            editedItem.goals = []
                            if shouldShowGoals {
                                editedItem.goals.append(Goal(type: "heart_rate", value: 120))
                            }
                        }
                        
                        // 設置默認時長
                        switch def.name {
                        case "warmup", "cooldown":
                            editedItem.durationMinutes = 5
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
            
            if shouldShowGoals {
                Section("目標設定") {
                    ForEach(editedItem.goals.indices, id: \.self) { index in
                        VStack {
                            if editedItem.goals[index].type == "pace" {
                                Button(action: {
                                    selectedGoalIndex = index
                                    showingGoalWheel = true
                                }) {
                                    HStack {
                                        Text("目標配速")
                                        Spacer()
                                        Text(formatPaceValue(editedItem.goals[index].value))
                                        Text("/公里")
                                    }
                                }
                                .foregroundColor(.primary)
                            } else if editedItem.goals[index].type == "heart_rate" {
                                Button(action: {
                                    selectedGoalIndex = index
                                    showingGoalWheel = true
                                }) {
                                    HStack {
                                        Text("目標心率")
                                        Spacer()
                                        Text("\(editedItem.goals[index].value)")
                                        Text("bpm")
                                    }
                                }
                                .foregroundColor(.primary)
                            } else {
                                HStack {
                                    Text("目標\(getGoalDisplayName(type: editedItem.goals[index].type))")
                                    Spacer()
                                    TextField("數值", value: $editedItem.goals[index].value, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                    Text(getGoalUnit(for: editedItem.goals[index].type))
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        editedItem.goals.remove(atOffsets: indexSet)
                    }
                    
                    if hasAvailableGoals {
                        Menu {
                            ForEach(availableGoalTypes, id: \.self) { goalType in
                                if !editedItem.goals.contains(where: { $0.type == goalType }) {
                                    Button(action: {
                                        var defaultValue = 120
                                        switch goalType {
                                        case "times":
                                            defaultValue = 100
                                        case "pace":
                                            defaultValue = 6 * 60  // 6分鐘/公里
                                        default:
                                            break
                                        }
                                        editedItem.goals.append(Goal(type: goalType, value: defaultValue))
                                    }) {
                                        Text("添加\(getGoalDisplayName(type: goalType))目標")
                                    }
                                }
                            }
                        } label: {
                            Label("添加目標", systemImage: "plus.circle.fill")
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
        .sheet(isPresented: $showingGoalWheel, onDismiss: { selectedGoalIndex = nil }) {
            if let index = selectedGoalIndex {
                GoalWheelContainer(
                    goalType: editedItem.goals[index].type,
                    value: $editedItem.goals[index].value
                )
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
                TrainingResultsSection(averageHeartRate: Int(viewModel.averageHeartRate), heartRateGoalCompletionRate: viewModel.heartRateGoalCompletionRate)
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
    let heartRateGoalCompletionRate: Double
    
    var body: some View {
        Section("訓練成果") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("運動平均心率：\(Int(averageHeartRate)) bpm")
                        .font(.headline)
                }
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                    Text("心率目標完成率：\(String(format: "%.1f%%", heartRateGoalCompletionRate))")
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
                        Image(systemName: TrainingItemStyle.icon(for: item.name))
                            .foregroundColor(TrainingItemStyle.color(for: item.name))
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
                                } else if goal.type == "times" {
                                    Text("目標次數：\(goal.value) 次")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if goal.type == "pace" {
                                    Text("目標配速：\(String(format: "%d:%02d", goal.value / 60, goal.value % 60))/公里")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
