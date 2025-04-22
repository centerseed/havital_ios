import SwiftUI
import HealthKit
import Combine

// 新的子視圖
struct WeekPlanContentView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan
    let currentTrainingWeek: Int
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        Group {
            if currentTrainingWeek > plan.totalWeeks {
                FinalWeekPromptView(viewModel: viewModel)
            } else if plan.weekOfPlan < currentTrainingWeek {
                // 顯示舊的週計劃
                WeekOverviewCard(viewModel: viewModel, plan: plan)
                
                NewWeekPromptView(
                    viewModel: viewModel,
                    currentTrainingWeek: currentTrainingWeek
                )
            } else {
                // 顯示當前週計劃
                WeekOverviewCard(viewModel: viewModel, plan: plan)
                
                // 每日訓練區塊
                DailyTrainingListView(viewModel: viewModel, plan: plan)
            }
        }
        .onAppear {
            // 除錯 log
            print("[WeekPlan] plan.weekOfPlan=\(plan.weekOfPlan), currentTrainingWeek=\(currentTrainingWeek)")
        }
    }
}

// 拆分新週提示視圖
struct NewWeekPromptView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let currentTrainingWeek: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text("目前訓練進度已進入第 \(currentTrainingWeek) 週")
                .font(.headline)
                .multilineTextAlignment(.center)
                
            Text("Paceriz會依照您的訓練狀況，產生為您專屬設計的週課表。讓我們來查看這週訓練狀況，並且產生新的課表吧！")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 顯示不同狀態的按鈕
            if viewModel.isLoadingWeeklySummary {
                // 正在加載訓練回顧時顯示載入狀態
                WeeklySummaryLoadingView()
            } else if let error = viewModel.weeklySummaryError {
                // 加載失敗時顯示錯誤視圖
                WeeklySummaryErrorView(error: error) {
                    Task {
                        await viewModel.fetchWeeklySummary()
                    }
                }
            } else if viewModel.showWeeklySummary, let summary = viewModel.weeklySummary {
                // 成功獲取訓練回顧後顯示回顧內容
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary
                ) {
                    // 產生下週課表的回調
                    Task {
                        // 清除訓練回顧
                        viewModel.clearWeeklySummary()
                        // 產生新的週課表
                        await viewModel.generateNextWeekPlan(targetWeek: currentTrainingWeek)
                    }
                }
            } else {
                // 未獲取回顧時，顯示取得回顧按鈕
                Button(action: {
                    Task {
                        await viewModel.fetchWeeklySummary()
                    }
                }) {
                    HStack {
                        Image(systemName: "warninglight")
                        Text("取得\(viewModel.getLastTwoWeeksRange())訓練回顧")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 拆分每日訓練列表視圖
struct DailyTrainingListView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 添加標題
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
    }
}

// 結束週回顧並重設 Onboarding 的視圖
struct FinalWeekPromptView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("您的訓練週期已結束")
                .font(.headline)
                .multilineTextAlignment(.center)

            if viewModel.isLoadingWeeklySummary {
                WeeklySummaryLoadingView()
            } else if let error = viewModel.weeklySummaryError {
                WeeklySummaryErrorView(error: error) {
                    Task { await viewModel.fetchWeeklySummary() }
                }
            } else if viewModel.showWeeklySummary, let summary = viewModel.weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary
                ) {
                    Task {
                        viewModel.clearWeeklySummary()
                        AuthenticationService.shared.resetOnboarding()
                    }
                }
            } else {
                Button(action: {
                    Task { await viewModel.fetchWeeklySummary() }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("取得\(viewModel.getLastTwoWeeksRange())訓練回顧")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showUserProfile = false
    @State private var showOnboardingConfirmation = false
    @State private var showTrainingOverview = false
    @State private var showDebugView = false
    @State private var showModifications = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // 添加一個計時器來刷新訓練記錄
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    mainContentView
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
            }
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.primary)
            .toolbar {
                toolbarContent
            }
            .confirmationDialog(
                "確定要重新開始OnBoarding流程嗎？",
                isPresented: $showOnboardingConfirmation,
                titleVisibility: .visible
            ) {
                dialogButtons
            } message: {
                Text("這將會重置您的所有訓練設置，需要重新設定您的訓練偏好。")
            }
        }
        .task {
            await viewModel.loadAllInitialData(healthKitManager: healthKitManager)
        }
        .onReceive(timer) { _ in
            refreshWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshWorkouts()
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
        .sheet(isPresented: $showTrainingOverview) {
            trainingOverviewSheet
        }
        .sheet(isPresented: $showModifications) {
            ModificationsView(viewModel: viewModel)
                .environmentObject(healthKitManager)
        }
        .onAppear {
            // 初始載入與檢查移至 ViewModel
        }
    }
    
    // 拆分主內容視圖
    private var mainContentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("載入訓練計劃中...")
                    .foregroundColor(.gray)
                    .frame(height: 200)
            } else if let plan = viewModel.weeklyPlan, let currentTrainingWeek = viewModel.calculateCurrentTrainingWeek() {
                WeekPlanContentView(
                    viewModel: viewModel,
                    plan: plan,
                    currentTrainingWeek: currentTrainingWeek
                )
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task {
                        await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
                    }
                }
            }
        }
    }
    
    // 工具欄內容
    private var toolbarContent: some ToolbarContent {
        Group {
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
                    /*
                    Button(action: {
                        showModifications = true
                    }) {
                        Label("修改課表", systemImage: "slider.horizontal.3")
                    }
                    /* 測試onboarding再打開*/
                    Button(action: {
                        showOnboardingConfirmation = true
                    }) {
                        Label("重新OnBoarding", systemImage: "arrow.clockwise")
                    }*/
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // 對話框按鈕
    private var dialogButtons: some View {
        Group {
            Button("確定", role: .destructive) {
                AuthenticationService.shared.resetOnboarding()
            }
            Button("取消", role: .cancel) {}
        }
    }
    
    // 訓練概覽視圖
    private var trainingOverviewSheet: some View {
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
    }
    
    // 錯誤視圖
    private struct ErrorView: View {
        let error: Error
        let retryAction: () -> Void
        
        var body: some View {
            VStack {
                Text("載入失敗")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.red)
                Button("重試", action: retryAction)
                    .foregroundColor(.blue)
                    .padding()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // 刷新訓練記錄
    private func refreshWorkouts() {
        print("刷新訓練記錄")
        Task {
            await viewModel.loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
        }
    }
    
    // 檢查更新
    private func checkForUpdates() {
        if let lastUpdateTime = UserDefaults.standard.object(forKey: "last_weekly_plan_update") as? Date {
            let hoursSinceLastUpdate = Calendar.current.dateComponents([.hour], from: lastUpdateTime, to: Date()).hour ?? 0
            if hoursSinceLastUpdate >= 1 {
                Task {
                    await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
                }
            }
        }
    }
}
