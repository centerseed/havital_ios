import SwiftUI
import HealthKit
import Combine

// 新的子視圖
struct WeekPlanContentView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan
    let currentTrainingWeek: Int
    
    var body: some View {
        let _ = plan.weekOfPlan  // 移除未使用的變數
        let current = currentTrainingWeek
        VStack {
            if viewModel.isFinalWeek {
                FinalWeekPromptView(viewModel: viewModel)
            } else if viewModel.isNewWeekPromptNeeded {
                NewWeekPromptView(viewModel: viewModel, currentTrainingWeek: current)
            } else {
                // 已有課表：不論過去或當前週，顯示概覽與每日清單
                WeekOverviewCard(viewModel: viewModel, plan: plan)
                DailyTrainingListView(viewModel: viewModel, plan: plan)
            }
        }
        .onAppear {
            // 除錯 log
            Logger.info("current: \(currentTrainingWeek), selected: \(viewModel.selectedWeek), planWeek: \(plan.weekOfPlan), noWeeklyPlanAvailable: \(viewModel.noWeeklyPlanAvailable)")
        }
    }
}

// 拆分新週提示視圖
struct NewWeekPromptView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let currentTrainingWeek: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("training.current_week_progress", comment: "Current training progress has entered week") + " \(currentTrainingWeek) " + NSLocalizedString("date.week", comment: "Week"))
                .font(.headline)
                .multilineTextAlignment(.center)
                
            Text(NSLocalizedString("training.paceriz_plan_description", comment: "Paceriz will generate a personalized weekly schedule based on your training condition. Let's check this week's training status and generate a new schedule!"))
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
                        await viewModel.createWeeklySummary()
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
                        await viewModel.createWeeklySummary()
                    }
                }) {
                    HStack {
                        Image(systemName: "warninglight")
                        Text(NSLocalizedString("training.get_weekly_review", comment: "Get Weekly Review") + "\(viewModel.getLastWeekRangeString())")
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
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 16)
                
                Spacer()
                
                if viewModel.isLoadingWorkouts {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 4)
            
            // 顯示今天的訓練
            if let todayTraining = plan.days.first(where: { viewModel.isToday(dayIndex: $0.dayIndexInt, planWeek: plan.weekOfPlan) }) {
                DailyTrainingCard(viewModel: viewModel, day: todayTraining, isToday: true)
            }
            
            // 顯示其他日的訓練
            ForEach(plan.days.filter { !viewModel.isToday(dayIndex: $0.dayIndexInt, planWeek: plan.weekOfPlan) }) { day in
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
            Text(NSLocalizedString("training.cycle_completed_message", comment: "Great job! Your training cycle is complete. Don't forget to set your next training goal after reviewing your training!"))
                .font(.headline)
                .multilineTextAlignment(.center)

            if viewModel.isLoadingWeeklySummary {
                WeeklySummaryLoadingView()
            } else if let error = viewModel.weeklySummaryError {
                WeeklySummaryErrorView(error: error) {
                    Task { await viewModel.createWeeklySummary() }
                }
            } else if viewModel.showWeeklySummary, let summary = viewModel.weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary,
                    onGenerateNextWeek: nil // 移除 WeeklySummaryView 內部的按鈕
                )

                // 新增「設定新目標」按鈕
                Button(action: {
                    Task {
                        viewModel.clearWeeklySummary() // 清除當前回顧狀態
                        AuthenticationService.shared.startReonboarding() // 觸發重新 Onboarding
                    }
                }) {
                    HStack {
                        Image(systemName: "target") // 可以換一個更合適的圖示
                        Text(NSLocalizedString("training.set_new_goal", comment: "Set New Goal"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green) // 使用醒目的顏色
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.vertical)
            } else {
                Button(action: {
                    Task { await viewModel.createWeeklySummary() }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text(NSLocalizedString("training.get_weekly_review", comment: "Get Weekly Review") + "\(viewModel.getLastWeekRangeString())")
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
    @State private var showTrainingOverview = false
    @State private var showDebugView = false
    private let loadingDuration: Double = 20 // 加載動畫持續時間（秒）
    @State private var showModifications = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekSelector = false
    @State private var showTrainingProgress = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 使用 ZStack 來疊加 loading 狀態
                    ZStack {
                        mainContentView
                            .opacity(viewModel.planStatus == .loading ? 0.3 : 1.0)
                        
                        if viewModel.planStatus == .loading {
                            ProgressView(NSLocalizedString("training.loading_plan", comment: "Loading training plan..."))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(UIColor.systemBackground).opacity(0.8))
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
                        }
                    }
                    .frame(minHeight: 200)
                }
                .padding(.horizontal)
            }
            .transaction { $0.disablesAnimations = true }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                // 下拉刷新：手動刷新，跳過所有快取
                await viewModel.refreshWeeklyPlan(isManualRefresh: true)
            }
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.primary)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showWeekSelector) {
                WeekSelectorSheet(viewModel: viewModel, isPresented: $showWeekSelector)
            }
        }
        .task {
            // 初始化已在 TrainingPlanViewModel.init() 中自動執行
            // 不需要手動調用 loadAllInitialData
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            Logger.debug("Received onboardingCompleted notification, refreshing weekly volume")
            refreshWorkouts()
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView()
            }
        }
        .sheet(isPresented: $viewModel.isLoadingAnimation) {
            if viewModel.isLoadingWeeklySummary {
                LoadingAnimationView(type: .generateReview, totalDuration: loadingDuration)
                    .ignoresSafeArea()
            } else {
                LoadingAnimationView(type: .generatePlan, totalDuration: loadingDuration)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showTrainingOverview) {
            trainingOverviewSheet
        }
        .sheet(isPresented: $showTrainingProgress) {
            TrainingProgressView(viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage = shareImage {
                ActivityViewController(activityItems: [shareImage])
            }
        }
        .alert(NSLocalizedString("error.network", comment: "Network Connection Error"), isPresented: $viewModel.showNetworkErrorAlert) {
            Button(NSLocalizedString("common.retry", comment: "Retry")) {
                Task {
                    await viewModel.retryNetworkRequest()
                }
            }
            Button(NSLocalizedString("common.later", comment: "Later"), role: .cancel) {
                viewModel.showNetworkErrorAlert = false
            }
        } message: {
            Text(viewModel.networkError?.localizedDescription ?? NSLocalizedString("error.network_connection_failed", comment: "Network connection failed, please try again later"))
        }
        .networkErrorToast(
            isPresented: $viewModel.showNetworkErrorToast,
            message: NSLocalizedString("toast.network_error", comment: "Network error, showing cached data")
        )
        .onAppear {
            if hasCompletedOnboarding {
                Logger.debug("View onAppear: Onboarding completed")
                // 只在數據尚未載入時才刷新，避免不必要的重新載入
                if viewModel.planStatus == .loading || viewModel.weeklyPlan == nil {
                    refreshWorkouts()
                }
            }
        }
    }
    
    // 拆分主內容視圖
    @ViewBuilder private var mainContentView: some View {
        switch viewModel.planStatus {
        case .noPlan:
            // 尚未生成本週計畫
            NewWeekPromptView(viewModel: viewModel, currentTrainingWeek: viewModel.currentWeek)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
        case .ready(let plan):
            WeekPlanContentView(
                viewModel: viewModel,
                plan: plan,
                currentTrainingWeek: viewModel.currentWeek
            )
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
        case .completed:
            FinalWeekPromptView(viewModel: viewModel)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
        case .error(let error):
            ErrorView(error: error) {
                Task { await viewModel.loadWeeklyPlan() }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
        case .loading:
            // 空的佔位視圖，實際的 loading 狀態在 ZStack 中處理
            EmptyView()
        }
    }
    
    // 工具欄內容
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showTrainingOverview = true
                }) {
                    Image(systemName: "doc.text.below.ecg")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        shareTrainingPlan()
                    }) {
                        if isGeneratingScreenshot {
                            Label(NSLocalizedString("common.generating", comment: "Generating..."), systemImage: "arrow.2.squarepath")
                        } else {
                            Label(NSLocalizedString("training.share_schedule", comment: "Share Schedule"), systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isGeneratingScreenshot || viewModel.planStatus == .loading)
                    
                    Divider()
                    
                    Button(action: {
                        showUserProfile = true
                    }) {
                        Label(NSLocalizedString("profile.title", comment: "Profile"), systemImage: "person.circle")
                    }
                    
                    Button(action: {
                        showTrainingOverview = true
                    }) {
                        Label(NSLocalizedString("training.overview", comment: "Training Overview"), systemImage: "doc.text.below.ecg")
                    }
                    
                    Button(action: {
                        showTrainingProgress = true
                    }) {
                        Label(NSLocalizedString("training.progress", comment: "Training Progress"), systemImage: "chart.line.uptrend.xyaxis")
                    }
                    /*
                    Button(action: {
                        showModifications = true
                    }) {
                        Label(NSLocalizedString("training.modify_schedule", comment: "Modify Schedule"), systemImage: "slider.horizontal.3")
                    }
                    */
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // 訓練概覽視圖
    private var trainingOverviewSheet: some View {
        NavigationView {
            if let overview = viewModel.trainingOverview {
                TrainingPlanOverviewDetailView(overview: overview)
            } else {
                VStack(spacing: 20) {
                    Text(NSLocalizedString("training.cannot_load_overview", comment: "Unable to load training plan overview"))
                        .font(.headline)
                    
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        showTrainingOverview = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .navigationTitle(NSLocalizedString("training.plan_title", comment: "Training Plan"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("common.close", comment: "Close")) {
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
            VStack(spacing: 20) {
                // 錯誤圖示
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    // 主要錯誤訊息
                    Text(NSLocalizedString("training.cannot_load_plan", comment: "Unable to load training plan"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // 詳細說明文字
                    Text(NSLocalizedString("error.network_or_server_error", comment: "Network connection or server error, please check your network connection and reload"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
                
                // 重試按鈕
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(NSLocalizedString("common.reload", comment: "Reload"))
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 4)
        }
    }
    
    // 刷新訓練記錄
    private func refreshWorkouts() {
        Logger.debug("Refreshing training records and weekly volume")
        Task {
            // 使用統一的刷新方法
            await viewModel.refreshWeeklyPlan()
            
            // 只有當沒有週課表時才載入，避免不必要的重新載入
            if viewModel.weeklyPlan == nil {
                await viewModel.loadWeeklyPlan()
            }
            
            await viewModel.loadCurrentWeekDistance()
            await viewModel.loadWorkoutsForCurrentWeek()
        }
    }
    
    // 分享訓練課表
    private func shareTrainingPlan() {
        isGeneratingScreenshot = true
        
        LongScreenshotCapture.captureView(
            VStack(spacing: 24) {
                // 標題部分
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.trainingPlanName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let plan = viewModel.weeklyPlan {
                        Text(NSLocalizedString("training.week_schedule", comment: "Week Schedule") + " \(plan.weekOfPlan)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 8)
                
                // 根據當前狀態顯示內容
                switch viewModel.planStatus {
                case .ready(let plan):
                    // 週概覽卡片
                    WeekOverviewCard(viewModel: viewModel, plan: plan)
                    
                    // 每日訓練列表
                    DailyTrainingListView(viewModel: viewModel, plan: plan)
                    
                case .noPlan:
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text(NSLocalizedString("training.no_schedule_generated", comment: "This week's schedule has not been generated yet"))
                            .font(.headline)
                        
                        Text(NSLocalizedString("training.generate_review_first", comment: "Please generate a weekly review first to get personalized training recommendations"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                case .completed:
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text(L10n.TrainingPlan.cycleCompleted.localized)
                            .font(.headline)

                        Text(L10n.TrainingPlan.congratulations.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                case .loading, .error:
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text(L10n.TrainingPlan.loadingSchedule.localized)
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        ) { image in
            DispatchQueue.main.async {
                self.isGeneratingScreenshot = false
                self.shareImage = image
                self.showShareSheet = true
            }
        }
    }
    
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
