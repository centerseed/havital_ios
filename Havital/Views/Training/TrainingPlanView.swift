import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @State private var weeklyPlan: WeeklyPlan?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showUserProfile = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入訓練計劃中...")
                } else if let plan = weeklyPlan {
                    List {
                        Section(header: Text("本週概覽")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("週目標")
                                    .font(.headline)
                                Text(plan.purpose)
                                    .font(.body)
                                
                                Text("訓練提示")
                                    .font(.headline)
                                Text(plan.tips)
                                    .font(.body)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Section(header: Text("每日訓練")) {
                            ForEach(plan.days) { day in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text(weekdayName(for: day.dayIndex))
                                                .font(.headline)
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
                                                case .easy: return "輕鬆"
                                                case .strength: return "強度"
                                                case .rest: return "休息"
                                                }
                                            }())
                                                .font(.subheadline)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background({
                                                    switch day.type {
                                                    case .easy: return Color.green.opacity(0.2)
                                                    case .strength: return Color.orange.opacity(0.2)
                                                    case .rest: return Color.gray.opacity(0.2)
                                                    }
                                                }())
                                                .cornerRadius(8)
                                        }
                                    }
                                    
                                    Text(day.dayTarget)
                                        .font(.body)
                                    
                                    if day.isTrainingDay, let trainingItems = day.trainingItems {
                                        ForEach(trainingItems.indices, id: \.self) { index in
                                            let item = trainingItems[index]
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                                
                                                if let details = item.runDetails {
                                                    Text(details)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                if let goals = item.goals {
                                                    if let pace = goals.pace {
                                                        Text("配速: \(pace) /km")
                                                            .font(.caption)
                                                    }
                                                    if let distance = goals.distanceKm {
                                                        Text("距離: \(String(format: "%.1f", distance))公里")
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                } else if let error = error {
                    VStack {
                        Text("載入失敗")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundColor(.red)
                        Button("重試") {
                            Task {
                                await loadWeeklyPlan()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showUserProfile = true
                        }) {
                            Label("用戶資訊", systemImage: "person.circle")
                        }
                        Button(action: {
                            hasCompletedOnboarding = false
                        }) {
                            Label("重新OnBoarding", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
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
