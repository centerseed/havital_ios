import SwiftUI
import HealthKit

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showingUserPreference = false
    @State private var showingDatePicker = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
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
                                    Task {
                                        await viewModel.generateWeeklySummary()
                                    }
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
            .navigationTitle("第一週訓練")
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
