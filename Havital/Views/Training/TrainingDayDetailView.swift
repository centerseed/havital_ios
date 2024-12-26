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
    @State private var isRestDay: Bool
    @State private var purpose: String
    @State private var tips: String
    @State private var trainingItems: [TrainingItem]
    
    init(day: TrainingDay, trainingPlanViewModel: TrainingPlanViewModel, onSave: @escaping (TrainingDay) -> Void) {
        self.day = day
        self.trainingPlanViewModel = trainingPlanViewModel
        self.onSave = onSave
        
        // 判斷是否為休息日：只有一個訓練項目且名稱為"rest"
        let isRest = day.trainingItems.count == 1 && day.trainingItems[0].name.lowercased() == "rest"
        _isRestDay = State(initialValue: isRest)
        _purpose = State(initialValue: day.purpose)
        _tips = State(initialValue: day.tips)
        _trainingItems = State(initialValue: day.trainingItems)
    }
    
    private func updateDayTarget() {
        // 如果不是休息日，找出主要訓練項目（非熱身和放鬆）的名稱
        if !isRestDay {
            let mainItems = trainingItems.filter { item in
                let name = item.name.lowercased()
                return name != "warmup" && name != "cooldown"
            }
            if let firstMainItem = mainItems.first {
                purpose = firstMainItem.name
            }
        }
    }
    
    var body: some View {
        Form {
            Toggle("休息日", isOn: $isRestDay)
                .onChange(of: isRestDay) { newValue in
                    if newValue {
                        // 如果切換為休息日，清空所有訓練項目並添加rest
                        trainingItems = [
                            TrainingItem(
                                id: UUID().uuidString,
                                type: "6",
                                name: "rest",
                                resource: "",
                                durationMinutes: 0,
                                subItems: [],
                                goals: [],
                                goalCompletionRates: [:]
                            )
                        ]
                        purpose = "休息"
                        tips = "好好休息"
                    } else {
                        // 如果切換為訓練日，清空rest項目
                        if trainingItems.count == 1 && trainingItems[0].name.lowercased() == "rest" {
                            trainingItems = []
                        }
                        tips = ""
                    }
                }
            
            if !isRestDay {
                TextField("訓練目標", text: $purpose)
                TextField("訓練要點", text: $tips)
                
                Section("訓練項目") {
                    List {
                        ForEach($trainingItems) { $item in
                            NavigationLink {
                                EditTrainingItemView(item: $item)
                                    .onChange(of: item.name) { _ in
                                        updateDayTarget()
                                    }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(item.displayName)
                                    if item.durationMinutes > 0 {
                                        Text("\(item.durationMinutes)分鐘")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            trainingItems.remove(atOffsets: indexSet)
                            updateDayTarget()
                        }
                        .onMove { from, to in
                            trainingItems.move(fromOffsets: from, toOffset: to)
                            updateDayTarget()
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                    
                    Button {
                        trainingItems.append(TrainingItem(
                            id: UUID().uuidString,
                            type: "0",
                            name: "",
                            resource: "",
                            durationMinutes: 30,
                            subItems: [],
                            goals: [],
                            goalCompletionRates: [:]
                        ))
                    } label: {
                        Label("添加訓練項目", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("編輯訓練日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    var updatedDay = day
                    updatedDay.purpose = purpose
                    updatedDay.tips = tips
                    updatedDay.trainingItems = trainingItems
                    onSave(updatedDay)
                    dismiss()
                }
            }
        }
    }
}

struct EditTrainingItemView: View {
    @Binding var item: TrainingItem
    @State private var selectedDefinition: TrainingItemDefinition?
    private let definitions = TrainingDefinitions.load()?.trainingItemDefs ?? []
    
    private var shouldShowHeartRateGoal: Bool {
        let name = item.name.lowercased()
        return name != "cooldown" && name != "warmup" && name != "rest"
    }
    
    var body: some View {
        Form {
            Section {
                Picker("訓練類型", selection: $selectedDefinition) {
                    Text("自定義").tag(nil as TrainingItemDefinition?)
                    ForEach(definitions) { def in
                        Text(def.displayName).tag(def as TrainingItemDefinition?)
                    }
                }
                .onChange(of: selectedDefinition) { newValue in
                    if let def = newValue {
                        item.name = def.name
                        // 如果是需要心率目標的訓練項目，自動添加目標
                        if shouldShowHeartRateGoal {
                            if item.goals.isEmpty {
                                item.goals.append(Goal(type: "heart_rate", value: 120))
                            }
                        } else {
                            item.goals.removeAll()
                        }
                    }
                }
                
                if selectedDefinition == nil {
                    TextField("名稱", text: Binding(
                        get: { item.name },
                        set: { item.name = $0 }
                    ))
                }
                
                Stepper("時長: \(item.durationMinutes) 分鐘", value: Binding(
                    get: { item.durationMinutes },
                    set: { item.durationMinutes = $0 }
                ), in: 0...240)
            }
            
            if shouldShowHeartRateGoal {
                Section("目標") {
                    ForEach(item.goals.indices, id: \.self) { index in
                        HStack {
                            Text("目標心率")
                            Spacer()
                            TextField("心率", value: Binding(
                                get: { item.goals[index].value },
                                set: { item.goals[index].value = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            Text("bpm")
                        }
                    }
                    .onDelete { indexSet in
                        item.goals.remove(atOffsets: indexSet)
                    }
                    
                    if item.goals.isEmpty {
                        Button {
                            item.goals.append(Goal(type: "heart_rate", value: 120))
                        } label: {
                            Label("添加心率目標", systemImage: "plus")
                        }
                    }
                }
            }
            
            Section("訓練要點") {
                ForEach(item.subItems.indices, id: \.self) { index in
                    TextField("要點", text: Binding(
                        get: { item.subItems[index].name },
                        set: { item.subItems[index].name = $0 }
                    ))
                }
                .onDelete { indexSet in
                    item.subItems.remove(atOffsets: indexSet)
                }
                
                Button {
                    item.subItems.append(SubItem(id: UUID().uuidString, name: ""))
                } label: {
                    Label("添加要點", systemImage: "plus")
                }
            }
        }
        .onAppear {
            // 根據當前item.name找到對應的定義
            selectedDefinition = definitions.first(where: { $0.name == item.name })
            
            // 如果是需要心率目標的訓練項目且沒有目標，自動添加目標
            if shouldShowHeartRateGoal && item.goals.isEmpty {
                item.goals.append(Goal(type: "heart_rate", value: 120))
            }
        }
    }
}

private struct TrainingDayContentView: View {
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
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                    Text(item.displayName)
                        .font(.headline)
                    
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
