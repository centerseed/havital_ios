import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel
    @StateObject private var calendarManager = CalendarManager()
    @State private var showingUserPreference = false
    @State private var showingDatePicker = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showingAnalysis = false
    @StateObject private var userPrefManager = UserPreferenceManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    
    init() {
        // 在 MainActor 上創建 ViewModel
        let viewModel = TrainingPlanViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
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
                                    showingAnalysis = true
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
            .navigationTitle("本週訓練計劃")
            .toolbar {
                Menu {
                    Button(action: {
                        showingUserPreference = true
                    }) {
                        Label("個人資料", systemImage: "person.circle")
                    }
                    
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        Label("修改計劃開始日期", systemImage: "arrow.clockwise")
                    }

                    Button(action: {
                        viewModel.showingCalendarSetup = true
                    }) {
                        Label("同步至行事曆", systemImage: "calendar.badge.plus")
                    }
                    
                    Button(action: {
                        isLoggedIn = false
                    }) {
                        Label("登入畫面", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingUserPreference) {
                UserPreferenceView(preference: userPrefManager.currentPreference)
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    DatePicker(
                        "選擇開始日期",
                        selection: $viewModel.selectedStartDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .navigationTitle("選擇開始日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("確定") {
                                viewModel.updatePlanStartDate(viewModel.selectedStartDate)
                                showingDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAnalysis) {
                WeeklyAnalysisView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingCalendarSetup) {
                CalendarSyncSetupView(isPresented: $viewModel.showingCalendarSetup) { preference in
                    viewModel.syncToCalendar(preference: preference)
                }
                .environmentObject(calendarManager)
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
