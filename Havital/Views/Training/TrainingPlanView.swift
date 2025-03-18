import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showUserProfile = false
    @State private var showOnboardingConfirmation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView("載入訓練計劃中...")
                                .foregroundColor(.gray)
                                .frame(height: 200)
                        } else if let plan = viewModel.weeklyPlan {
                            // 本週概覽卡片
                            WeekOverviewCard(viewModel: viewModel, plan: plan)
                            
                            // 每日訓練區塊
                            VStack(alignment: .leading, spacing: 16) {
                                Text("每日訓練")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                
                                // 顯示今天的訓練
                                if let todayTraining = plan.days.first(where: { viewModel.isToday(dayIndex: $0.dayIndex, planWeek: plan.weekOfPlan) }) {
                                    DailyTrainingCard(viewModel: viewModel, day: todayTraining, isToday: true)
                                }
                                
                                // 顯示其他日的訓練
                                ForEach(plan.days.filter { !viewModel.isToday(dayIndex: $0.dayIndex, planWeek: plan.weekOfPlan) }) { day in
                                    DailyTrainingCard(viewModel: viewModel, day: day, isToday: false)
                                }
                            }
                        } else if let error = viewModel.error {
                            // 錯誤顯示
                            VStack {
                                Text("載入失敗")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .foregroundColor(.red)
                                Button("重試") {
                                    Task {
                                        await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
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
                await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
            }
            .navigationTitle("第\(viewModel.weeklyPlan?.weekOfPlan ?? 0)週訓練計劃")
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
            await viewModel.loadWeeklyPlan()
            await viewModel.loadVDOTData()
            await viewModel.loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            await viewModel.identifyTodayTraining()
            
            // 如果有計劃，獲取本週跑量
            if let plan = viewModel.weeklyPlan, plan.totalDistance > 0 {
                await viewModel.loadCurrentWeekDistance(healthKitManager: healthKitManager)
            }
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
    }
}
