import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel
    @StateObject private var calendarManager = CalendarManager()
    @State private var showingUserPreference = false
    @State private var showingDatePicker = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingAnalysis = false
    @StateObject private var userPrefManager = UserPreferenceManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var showingPurpose = false
    @State private var showingTips = false
    @State private var showingOverview = false
    
    enum ActiveSheet: Identifiable {
        case purpose
        case tips
        case overview
        case userPreference
        case datePicker
        case analysis
        case calendarSetup
        
        var id: Int {
            switch self {
            case .purpose: return 1
            case .tips: return 2
            case .overview: return 3
            case .userPreference: return 4
            case .datePicker: return 5
            case .analysis: return 6
            case .calendarSetup: return 7
            }
        }
        
        var title: String {
            switch self {
            case .purpose:
                return "本週目標"
            case .tips:
                return "訓練提示"
            case .overview:
                return "計劃總覽"
            case .userPreference:
                return "個人資料"
            case .datePicker:
                return "選擇開始日期"
            case .analysis:
                return "週分析"
            case .calendarSetup:
                return "行事曆同步"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    
    init() {
        let viewModel = TrainingPlanViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private func showInfo(type: TrainingInfoView.InfoType) {
        guard let plan = viewModel.plan else {
            print("Error: plan is nil")
            return
        }
        
        if type == .purpose {
            activeSheet = .purpose
        } else if type == .tips {
            activeSheet = .tips
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let plan = viewModel.plan {
                    List {
                        Section("訓練進度") {
                            if let overview = TrainingPlanStorage.shared.loadTrainingPlanOverview(),
                               let totalWeeks = overview["total_weeks"] as? Int {
                                let currentWeek = userPrefManager.currentPreference?.weekOfPlan ?? 1
                                //print("在入訓練進度：第\()週")
                                
                                // Calculate weekly progress
                                let completedDays = viewModel.trainingDays.filter { $0.isCompleted && $0.isTrainingDay }.count
                                let totalDays =  viewModel.trainingDays.filter { $0.isTrainingDay }.count
                                
                                VStack(spacing: 16) {
                                    HStack(alignment: .center, spacing: 24) {
                                        // Progress circles
                                        HStack(alignment: .center, spacing: 24) {
                                             CircularProgressView(
                                                progress: Double(currentWeek) / Double(totalWeeks),
                                                title: "\(currentWeek)/\(totalWeeks)",
                                                subtitle: "總進度",
                                                color: .blue
                                            )
                                            
                                            CircularProgressView(
                                                progress: totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0,
                                                title: "\(completedDays)/\(totalDays)",
                                                subtitle: "本週完成",
                                                color: .green
                                            )
                                        }
                                        
                                        // Info buttons
                                        VStack(spacing: 8) {
                                            InfoButtonView(
                                                iconName: "target",
                                                title: "本週目標",
                                                color: .blue
                                            ) {
                                                print("TrainingPlanView: 點擊本週目標按鈕")
                                                // 先關閉其他 sheet
                                                showingTips = false
                                                showingOverview = false
                                                // 最後打開目標的 sheet
                                                DispatchQueue.main.async {
                                                    showingPurpose = true
                                                }
                                            }
                                            
                                            InfoButtonView(
                                                iconName: "lightbulb",
                                                title: "訓練提示",
                                                color: .orange
                                            ) {
                                                print("TrainingPlanView: 點擊訓練提示按鈕")
                                                // 先關閉其他 sheet
                                                showingPurpose = false
                                                showingOverview = false
                                                // 最後打開提示的 sheet
                                                DispatchQueue.main.async {
                                                    showingTips = true
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    
                                    // Overview Button
                                    Button {
                                        print("TrainingPlanView: 點擊計劃概覽按鈕")
                                        // 先關閉其他 sheet
                                        showingPurpose = false
                                        showingTips = false
                                        // 最後打開概覽的 sheet
                                        DispatchQueue.main.async {
                                            showingOverview = true
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .foregroundColor(.blue)
                                            Text("計劃概覽")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        Section("每日計劃") {
                            ForEach(viewModel.trainingDays) { day in
                                let isToday = Calendar.current.isDateInToday(Date(timeIntervalSince1970: TimeInterval(day.startTimestamp)))
                                NavigationLink(destination: TrainingDayDetailView(day: day)
                                    .environmentObject(viewModel)
                                    .environmentObject(healthKitManager)) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(DateFormatterUtil.formatDate(timestamp: day.startTimestamp))
                                                .font(.headline)
                                                .foregroundColor(isToday ? .blue : .primary)
                                            
                                            Spacer()
                                            
                                            if isToday {
                                                Text("今天")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue)
                                                    .cornerRadius(8)
                                            }
                                            
                                            if day.isCompleted {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        
                                        ForEach(day.trainingItems) { item in
                                            HStack {
                                                Image(systemName: TrainingItemStyle.icon(for: item.name))
                                                    .foregroundColor(TrainingItemStyle.color(for: item.name))
                                                Text(item.displayName)
                                                    .foregroundColor(.secondary)
                                                if item.durationMinutes > 0 && (item.name != "warmup" && item.name != "cooldown"){
                                                    Text("(\(item.durationMinutes)分鐘)")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if viewModel.isLastDayOfPlan() {
                            Section {
                                Button(action: {
                                    activeSheet = .analysis
                                }) {
                                    HStack {
                                        Image(systemName: "chart.bar.doc.horizontal")
                                        Text("查看本週成果")
                                    }.padding(20)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                } else {
                    ProgressView("載入訓練計劃中...")
                }
            }
            .navigationTitle(TrainingPlanStorage.shared.loadTrainingPlanOverview()?["training_plan_name"] as? String ?? "訓練計劃")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 確保資料已經載入
                if let plan = viewModel.plan {
                    print("Training plan loaded: \(plan.purpose), \(plan.tips)")
                }
            }
            .toolbar {
                Menu {
                    Button(action: {
                        activeSheet = .userPreference
                    }) {
                        Label("個人資料", systemImage: "person.circle")
                    }
                    Button(action: {
                        activeSheet = .datePicker
                    }) {
                        Label("修改計劃開始日期", systemImage: "arrow.clockwise")
                    }
                    Button(action: {
                        viewModel.showingCalendarSetup = true
                        activeSheet = .calendarSetup
                    }) {
                        Label("同步至行事曆", systemImage: "calendar.badge.plus")
                    }
                    Button(action: {
                        hasCompletedOnboarding = false
                        UserPreferenceManager.shared.currentPreference?.weekOfPlan = 1
                    }) {
                        Label("重新OnBoarding", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingPurpose) {
                if let plan = viewModel.plan {
                    NavigationView {
                        ScrollView {
                            Text(plan.purpose)
                                .font(.body)
                                .padding()
                        }
                        .navigationTitle("本週目標")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingPurpose = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showingTips) {
                if let plan = viewModel.plan {
                    NavigationView {
                        ScrollView {
                            Text(plan.tips)
                                .font(.body)
                                .padding()
                        }
                        .navigationTitle("訓練提示")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("完成") {
                                    showingTips = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showingOverview) {
                if let overview = TrainingPlanStorage.shared.loadTrainingPlanOverview() {
                    TrainingPlanOverviewDetailView(overview: overview)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                Group {
                    switch sheet {
                    case .purpose:
                        if let plan = viewModel.plan {
                            NavigationView {
                                ScrollView {
                                    Text(plan.purpose)
                                        .font(.body)
                                        .padding()
                                }
                                .navigationTitle(sheet.title)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("完成") {
                                            activeSheet = nil
                                        }
                                    }
                                }
                            }
                            .presentationDetents([.medium])
                        }
                        
                    case .tips:
                        if let plan = viewModel.plan {
                            NavigationView {
                                ScrollView {
                                    Text(plan.tips)
                                        .font(.body)
                                        .padding()
                                }
                                .navigationTitle(sheet.title)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("完成") {
                                            activeSheet = nil
                                        }
                                    }
                                }
                            }
                            .presentationDetents([.medium])
                        }
                        
                    case .overview:
                        if let overview = TrainingPlanStorage.shared.loadTrainingPlanOverview() {
                            TrainingPlanOverviewDetailView(overview: overview)
                        }
                        
                    case .userPreference:
                        UserPreferenceView(preference: userPrefManager.currentPreference)
                        
                    case .datePicker:
                        NavigationView {
                            DatePicker(
                                "選擇開始日期",
                                selection: $viewModel.selectedStartDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .navigationTitle(sheet.title)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("確定") {
                                        viewModel.updatePlanStartDate(viewModel.selectedStartDate)
                                        activeSheet = nil
                                    }
                                }
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("取消") {
                                        activeSheet = nil
                                    }
                                }
                            }
                        }
                        
                    case .analysis:
                        WeeklyAnalysisView(viewModel: viewModel)
                        
                    case .calendarSetup:
                        CalendarSyncSetupView(isPresented: $viewModel.showingCalendarSetup) { preference in
                            viewModel.syncToCalendar(preference: preference)
                        }
                        .environmentObject(calendarManager)
                    }
                }
                .onAppear {
                    print("顯示 sheet: \(sheet.title)")
                }
            }
            .alert("錯誤", isPresented: .constant(viewModel.error != nil)) {
                Button("確定") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .task {
                viewModel.loadTrainingPlan()
            }
        }
        .onAppear {
            // 每次視圖出現時檢查完成狀態
            Task { @MainActor in
                print("TrainingPlanView出現，檢查訓練完成狀態")
                await viewModel.checkPastDaysCompletion()
                print("TrainingPlanView完成檢查訓練完成狀態")
            }
        }
    }
}

struct DayView: View {
    let day: TrainingDay
    let isToday: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(timestamp: day.startTimestamp))
                    .font(.headline)
                
                if isToday {
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
                        Text(item.displayName)
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
    
    private func formatDate(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

struct TrainingPlanView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingPlanView()
    }
}
