import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @State private var weeklyPlan: WeeklyPlan?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showUserProfile = false
    @State private var showOnboardingConfirmation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Weekly Plan Section
                    Group {
                        if isLoading {
                            ProgressView("載入訓練計劃中...")
                                .foregroundColor(.gray)
                                .frame(height: 200)
                        } else if let plan = weeklyPlan {
                            weeklyPlanContent(plan)
                        } else if let error = error {
                            VStack {
                                Text("載入失敗")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .foregroundColor(.red)
                                Button("重試") {
                                    Task {
                                        await refreshWeeklyPlan()
                                    }
                                }
                                .foregroundColor(.blue)
                                .padding()
                            }
                            .padding()
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black)
            .refreshable {
                await refreshWeeklyPlan()
            }
            .navigationTitle("第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.white)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showUserProfile = true
                        }) {
                            Label("用戶資訊", systemImage: "person.circle")
                        }
                        Button(action: {
                            showOnboardingConfirmation = true
                        }) {
                            Label("重新OnBoarding", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .confirmationDialog(
                "確定要重新開始OnBoarding流程嗎？",
                isPresented: $showOnboardingConfirmation,
                titleVisibility: .visible
            ) {
                Button("確定", role: .destructive) {
                    hasCompletedOnboarding = false
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這將會重置您的所有訓練設置，需要重新設定您的訓練偏好。")
            }
        }
        .task {
            await loadWeeklyPlan()
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
    }
    
    @ViewBuilder
    private func weeklyPlanContent(_ plan: WeeklyPlan) -> some View {
        VStack(spacing: 20) {
            // Week Overview Section
            VStack(alignment: .leading, spacing: 16) {
                Text("本週概覽")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                HStack(alignment: .center, spacing: 16) {
                    // Circular progress indicator
                    CircularProgressView(
                        progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks),
                        currentWeek: plan.weekOfPlan,
                        totalWeeks: plan.totalWeeks
                    )
                    .frame(width: 100, height: 100)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("週目標")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Text(plan.purpose)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .cornerRadius(12)
            }
            
            // Daily Training Section
            VStack(alignment: .leading, spacing: 16) {
                Text("每日訓練")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                ForEach(plan.days) { day in
                    dailyTrainingCard(day)
                }
            }
        }
    }
    
    private func dailyTrainingCard(_ day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text(weekdayName(for: day.dayIndex))
                        .font(.headline)
                        .foregroundColor(.white)
                    if isToday(dayIndex: day.dayIndex) {
                        Text("今天")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                if day.isTrainingDay {
                    Text({
                        switch day.type {
                        case .easyRun, .easy: return "輕鬆"
                        case .interval: return "間歇"
                        case .tempo: return "節奏"
                        case .longRun: return "長跑"
                        case .race: return "比賽"
                        case .rest: return "休息"
                        case .crossTraining: return "交叉訓練"
                        }
                    }())
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor({
                        switch day.type {
                        case .easyRun, .easy: return Color.green
                        case .interval, .tempo: return Color.orange
                        case .longRun: return Color.blue
                        case .race: return Color.red
                        case .rest: return Color.gray
                        case .crossTraining: return Color.purple
                        }
                    }())
                    .background({
                        switch day.type {
                        case .easyRun, .easy: return Color.green.opacity(0.2)
                        case .interval, .tempo: return Color.orange.opacity(0.2)
                        case .longRun: return Color.blue.opacity(0.2)
                        case .race: return Color.red.opacity(0.2)
                        case .rest: return Color.gray.opacity(0.2)
                        case .crossTraining: return Color.purple.opacity(0.2)
                        }
                    }())
                    .cornerRadius(8)
                }
            }
            
            Text(day.dayTarget)
                .font(.body)
                .foregroundColor(.white)
            
            if day.isTrainingDay, let trainingItems = day.trainingItems {
                // For interval training, show a special header with repeats info
                if day.type == .interval, trainingItems.count > 0, let repeats = trainingItems[0].goals.times {
                    HStack {
                        Text("間歇訓練")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(repeats) × 重複")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                
                // Show each training item
                ForEach(trainingItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(day.type == .interval ? .medium : .regular)
                                .foregroundColor(day.type == .interval ? .orange : .blue)
                            
                            if day.type == .interval, let times = item.goals.times {
                                Text("× \(times)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.leading, -4)
                            }
                            
                            Spacer()
                            
                            // Show the pace and distance in a pill for all training types
                            HStack(spacing: 2) {
                                if let pace = item.goals.pace {
                                    Text(pace)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(day.type == .interval ? .orange : .blue)
                                }
                                if let distance = item.goals.distanceKm {
                                    Text("/ \(String(format: "%.1f", distance)) km")
                                        .font(.caption)
                                        .foregroundColor(day.type == .interval ? .orange : .blue)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                            .cornerRadius(12)
                            .opacity((item.goals.pace != nil || item.goals.distanceKm != nil) ? 1 : 0)
                        }
                    }
                    
                    Text(item.runDetails)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // We now display pace and distance in a consistent pill UI for all training types
                }
            }
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
    }
    
    private func loadWeeklyPlan() async {
        isLoading = true
        defer { isLoading = false }
        
        // 直接從儲存載入週計劃
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan() {
            weeklyPlan = savedPlan
            error = nil
        } else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法載入週訓練計劃"])
        }
    }
    
    private func refreshWeeklyPlan() async {
        do {
            let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
            weeklyPlan = newPlan
            error = nil
        } catch {
            self.error = error
            print("刷新訓練計劃失敗: \(error)")
        }
    }
    
    private func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return "星期" + weekdays[index - 1]
    }
    
    private func isToday(dayIndex: Int) -> Bool {
        // API使用星期一為1，星期日為7
        // Calendar使用星期日為1，星期六為7
        let today = Calendar.current.component(.weekday, from: Date())
        let adjustedToday = today == 1 ? 7 : today - 1
        return dayIndex == adjustedToday
    }
}

struct TrainingPlanView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingPlanView()
    }
}
