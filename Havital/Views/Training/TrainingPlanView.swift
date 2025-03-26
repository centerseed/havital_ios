import SwiftUI
import HealthKit
import Combine

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showUserProfile = false
    @State private var showOnboardingConfirmation = false
    @State private var showTrainingOverview = false
    @State private var showDebugView = false // 新增狀態變量控制調試視圖顯示
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // 添加一個計時器來刷新訓練記錄
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
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
                                // 添加刷新按鈕
                                HStack {
                                    Text("每日訓練")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if viewModel.isLoadingWorkouts {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }
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
                                    .foregroundColor(.primary)
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
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
            }
            // 使用 trainingPlanName 作為導航標題
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showTrainingOverview = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.primary)
                    }
                }
                
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
                        /*
                        // 新增進入調試視圖的按鈕
                        Button(action: {
                            showDebugView = true
                        }) {
                            Label("健身記錄同步測試", systemImage: "wrench.and.screwdriver")
                        }*/
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
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
        // 當視圖出現時載入數據
        .task {
            await viewModel.loadWeeklyPlan()
            await viewModel.loadTrainingOverview()
            await viewModel.loadVDOTData()
            await viewModel.loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            await viewModel.identifyTodayTraining()
            
            // 如果有計劃，獲取本週跑量
            if let plan = viewModel.weeklyPlan, plan.totalDistance > 0 {
                await viewModel.loadCurrentWeekDistance(healthKitManager: healthKitManager)
            }
        }
        // 每分鐘刷新訓練記錄
        .onReceive(timer) { _ in
            print("定時刷新訓練記錄")
            Task {
                await viewModel.loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            }
        }
        // 當應用進入前台時刷新訓練記錄
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("應用進入前台，刷新訓練記錄")
            Task {
                await viewModel.loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            }
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
        // 顯示訓練計劃概覽
        .sheet(isPresented: $showTrainingOverview) {
            NavigationView {
                if let overview = viewModel.trainingOverview {
                    TrainingPlanOverviewDetailView(overview: overview)
                } else {
                    VStack(spacing: 20) {
                        Text("無法載入訓練計劃概覽")
                            .font(.headline)
                        
                        Button("關閉") {
                            showTrainingOverview = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .navigationTitle("訓練計劃")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("關閉") {
                                showTrainingOverview = false
                            }
                        }
                    }
                }
            }
        }.onAppear {
            // 檢查最後更新時間，如果距離上次更新超過一定時間（例如1小時），則自動刷新
            if let lastUpdateTime = UserDefaults.standard.object(forKey: "last_weekly_plan_update") as? Date {
                let hoursSinceLastUpdate = Calendar.current.dateComponents([.hour], from: lastUpdateTime, to: Date()).hour ?? 0
                if hoursSinceLastUpdate >= 1 {
                    Task {
                        await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
                    }
                }
            }
        }
        
        /*
        // 新增調試視圖的顯示
        .sheet(isPresented: $showDebugView) {
            NavigationStack {
                WorkoutSyncDebugView()
                    .environmentObject(healthKitManager)
                    .navigationTitle("健身記錄同步測試")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("關閉") {
                                showDebugView = false
                            }
                        }
                    }
            }
        }*/
    }
}
