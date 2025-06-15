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
        let selected = plan.weekOfPlan
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
            Logger.info("current: \(currentTrainingWeek), selected: \(plan.weekOfPlan), noWeeklyPlanAvailable: \(viewModel.noWeeklyPlanAvailable)")
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
                        Text("取得\(viewModel.getLastWeekRangeString())訓練回顧")
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
            Text("辛苦了！您的訓練週期已結束。別忘了在訓練回顧後，設定下一個訓練目標喔！！")
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
                        Text("設定新目標")
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
                        Text("取得\(viewModel.getLastWeekRangeString())訓練回顧")
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
    
    // 添加一個計時器來刷新訓練記錄
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 使用 ZStack 來疊加 loading 狀態
                    ZStack {
                        mainContentView
                            .opacity(viewModel.planStatus == .loading ? 0.3 : 1.0)
                        
                        if viewModel.planStatus == .loading {
                            ProgressView("載入訓練計劃中...")
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
                // 下拉刷新：直接更新 weekPlan 資料
                await viewModel.refreshWeeklyPlan(healthKitManager: healthKitManager)
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
            if hasCompletedOnboarding {
                await viewModel.loadAllInitialData(healthKitManager: healthKitManager)
            }
        }
        .onReceive(timer) { _ in
            refreshWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            Logger.debug("收到 onboardingCompleted 通知，刷新本週跑量")
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
        .onAppear {
            if hasCompletedOnboarding {
                Logger.debug("視圖 onAppear: 已完成 Onboarding，刷新本週跑量")
                refreshWorkouts()
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
            .id(viewModel.currentWeek)
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
                Text("")
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
        Logger.debug("刷新訓練記錄與本週跑量")
        Task {
            await viewModel.loadCurrentWeekDistance(healthKitManager: healthKitManager)
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

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
