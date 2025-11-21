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
                // 加載失敗時顯示錯誤視圖，使用強制更新模式重試
                WeeklySummaryErrorView(error: error) {
                    TrackedTask("TrainingPlanView: retryCreateWeeklySummary") {
                        await viewModel.retryCreateWeeklySummary()
                    }
                }
            } else {
                // 顯示取得回顧按鈕（週回顧會以 sheet 形式彈出）
                Button(action: {
                    TrackedTask("TrainingPlanView: createWeeklySummary") {
                        await viewModel.createWeeklySummary()
                        // 週回顧會自動以 sheet 形式顯示（由全局 sheet 處理）
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
            // 標題區域（已移除獨立的設計原因按鈕，用戶可通過 WeekOverviewCard 的「本週目標」查看）
            HStack(alignment: .center) {
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if viewModel.isLoadingWorkouts {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.top, 16)
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
                    TrackedTask("FinalWeekPromptView: retryCreateWeeklySummary") {
                        await viewModel.retryCreateWeeklySummary()
                    }
                }
            } else {
                // 取得週回顧按鈕（週回顧會以 sheet 形式彈出）
                Button(action: {
                    TrackedTask("FinalWeekPromptView: createWeeklySummary") {
                        await viewModel.createWeeklySummary()
                    }
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

                // 設定新目標按鈕（訓練完成後）
                Button(action: {
                    TrackedTask("TrainingPlanView: setNewGoal") {
                        viewModel.clearWeeklySummary()
                        AuthenticationService.shared.startReonboarding()
                    }
                }) {
                    HStack {
                        Image(systemName: "target")
                        Text(NSLocalizedString("training.set_new_goal", comment: "Set New Goal"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
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
    @State private var showEditSchedule = false
    @State private var showHeartRateSetup = false
    @State private var showHeartRateSetupFullScreen = false
    @ObservedObject private var userPreferenceManager = UserPreferenceManager.shared
    
    
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
                await TrackedTask("TrainingPlanView: refreshWeeklyPlan") {
                    await viewModel.refreshWeeklyPlan(isManualRefresh: true)
                }.value
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
            // Only refresh if app initialization is complete (avoid duplicate refresh during app launch)
            if AppStateManager.shared.currentState.isReady {
                refreshWorkouts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            Logger.debug("Received onboardingCompleted notification, refreshing weekly volume")
            // Only refresh if app initialization is complete
            if AppStateManager.shared.currentState.isReady {
                refreshWorkouts()
            }
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
        .sheet(isPresented: $showEditSchedule) {
            EditScheduleView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAdjustmentConfirmation) {
            AdjustmentConfirmationView(
                initialItems: viewModel.pendingAdjustments, // 可以是空陣列
                summaryId: viewModel.pendingSummaryId ?? "unknown", // 提供預設值
                onConfirm: { selectedItems in
                    TrackedTask("TrainingPlanView: confirmAdjustments") {
                        await viewModel.confirmAdjustments(selectedItems)
                    }
                },
                onCancel: {
                    viewModel.cancelAdjustmentConfirmation()
                }
            )
        }
        // 🆕 全局週回顧顯示（統一處理所有週回顧顯示邏輯）
        .sheet(isPresented: $viewModel.showWeeklySummary) {
            if let summary = viewModel.weeklySummary {
                NavigationView {
                    // ✅ 檢查訓練是否完成，決定是否顯示「產生下週課表」按鈕
                    let isTrainingCompleted = viewModel.planStatus == .completed ||
                                             viewModel.planStatusResponse?.nextAction == .trainingCompleted

                    WeeklySummaryView(
                        summary: summary,
                        weekNumber: viewModel.lastFetchedWeekNumber,
                        isVisible: $viewModel.showWeeklySummary,
                        // ⚠️ 訓練完成時不傳回調，不顯示「產生下週課表」按鈕
                        onGenerateNextWeek: isTrainingCompleted ? nil : {
                            // 產生下週課表的回調
                            TrackedTask("TrainingPlanView: generateNextWeek") {
                                // 先保存目標週數（避免被 clearWeeklySummary 清除）
                                let hasPendingWeek = viewModel.pendingTargetWeek != nil
                                let targetWeekToProduce = viewModel.pendingTargetWeek ?? viewModel.currentWeek

                                // 關閉週回顧
                                viewModel.showWeeklySummary = false

                                // 根據流程選擇對應方法
                                if hasPendingWeek {
                                    // next_week_info 流程：產生指定週數
                                    await viewModel.confirmAdjustmentsAndGenerateNextWeek(targetWeek: targetWeekToProduce)
                                } else {
                                    // 一般流程：產生當前週+1
                                    await viewModel.generateNextWeekPlan(targetWeek: targetWeekToProduce)
                                }
                            }
                        },
                        // 🆕 訓練完成時傳遞「設定新目標」回調
                        onSetNewGoal: isTrainingCompleted ? {
                            viewModel.clearWeeklySummary()
                            viewModel.showWeeklySummary = false
                            AuthenticationService.shared.startReonboarding()
                        } : nil
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("關閉") {
                                viewModel.clearWeeklySummary()
                            }
                        }
                    }
                }
            }
        }
        .alert(NSLocalizedString("error.network", comment: "Network Connection Error"), isPresented: $viewModel.showNetworkErrorAlert) {
            Button(NSLocalizedString("common.retry", comment: "Retry")) {
                TrackedTask("TrainingPlanView: retryNetworkRequest") {
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
        // 🆕 成功 Toast（產生課表成功）
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                SuccessToast(message: viewModel.successMessage, isPresented: $viewModel.showSuccessToast)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.showSuccessToast)
                    .onAppear {
                        // 3秒後自動消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.clearSuccessToast()
                        }
                    }
            }
        }
        .onAppear {
            Logger.debug("[TrainingPlanView] onAppear - hasCompletedOnboarding: \(hasCompletedOnboarding), isReady: \(AppStateManager.shared.currentState.isReady)")

            // 打印心率设置调试信息
            #if DEBUG
            HeartRateDebugHelper.printAllHeartRateSettings()
            #endif

            if hasCompletedOnboarding && AppStateManager.shared.currentState.isReady {
                Logger.debug("[TrainingPlanView] ✅ 條件符合，開始檢查")

                // 檢查用戶是否設定了心率，如果未設定則顯示提示
                checkAndShowHeartRateSetup()

                // 在訓練計劃載入後檢查評分提示
                TrackedTask("TrainingPlanView: checkAppRating") {
                    // 延遲 5 秒確保用戶數據和訓練計劃都已完全載入
                    await AppRatingManager.shared.checkOnAppLaunch(delaySeconds: 5)
                }
            } else {
                Logger.debug("[TrainingPlanView] ❌ 條件不符，跳過檢查")
            }
        }
        .sheet(isPresented: $showHeartRateSetup) {
            HeartRateSetupAlertView {
                // 點擊「立即設定」時，顯示滿版心率設置頁面
                showHeartRateSetupFullScreen = true
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showHeartRateSetupFullScreen) {
            // HeartRateZoneInfoView 內部已有 NavigationView，不需要再包裝
            HeartRateZoneInfoView(mode: .profile)
        }
    }
    
    // 拆分主內容視圖 - 使用方案二：時間軸式設計 + 焦點模式
    @ViewBuilder private var mainContentView: some View {
        VStack(spacing: 20) {
            // 🆕 返回本週按鈕（查看未來週時顯示）
            if viewModel.selectedWeek > viewModel.currentWeek {
                ReturnToCurrentWeekButton(viewModel: viewModel)
                    .padding(.horizontal)
            }

            // 主內容
            switch viewModel.planStatus {
            case .noPlan:
                // 尚未生成本週計畫
                NewWeekPromptView(viewModel: viewModel, currentTrainingWeek: viewModel.currentWeek)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
            case .ready(let plan):
                // ✨ 階層式佈局：訓練進度 → 週總覽 → 日
                VStack(spacing: 16) {
                    // 1. 訓練進度（獨立卡片，不收折）
                    TrainingProgressCard(viewModel: viewModel, plan: plan)

                    // 2. 週總覽（週跑量和強度，不收折）
                    WeekOverviewCard(viewModel: viewModel, plan: plan)

                    // 3. 週訓練時間軸
                    WeekTimelineView(viewModel: viewModel, plan: plan)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
            case .completed:
                FinalWeekPromptView(viewModel: viewModel)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
            case .error(let error):
                ErrorView(error: error) {
                    TrackedTask("TrainingPlanView: loadWeeklyPlan") {
                        await viewModel.loadWeeklyPlan()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.planStatus)
            case .loading:
                // 空的佔位視圖，實際的 loading 狀態在 ZStack 中處理
                EmptyView()
            }

            // 🆕 產生下週課表按鈕（週六日顯示）
            if let nextWeekInfo = viewModel.nextWeekInfo,
               nextWeekInfo.canGenerate,
               !nextWeekInfo.hasPlan,
               viewModel.selectedWeek == viewModel.currentWeek {
                GenerateNextWeekButton(viewModel: viewModel, nextWeekInfo: nextWeekInfo)
                    .padding(.horizontal)
                    .transition(.opacity)
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
                    
                    Button(action: {
                        showEditSchedule = true
                    }) {
                        Label(NSLocalizedString("training.edit_schedule", comment: "Edit Schedule"), systemImage: "slider.horizontal.3")
                    }
                    .disabled(viewModel.planStatus == .loading || viewModel.weeklyPlan == nil)
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
    /// 檢查用戶是否設定了心率，如果未設定則顯示提示對話框
    private func checkAndShowHeartRateSetup() {
        Logger.debug("[HeartRatePrompt] 開始檢查心率設置")
        Logger.debug("[HeartRatePrompt] doNotShowHeartRatePrompt: \(userPreferenceManager.doNotShowHeartRatePrompt)")
        Logger.debug("[HeartRatePrompt] maxHeartRate: \(userPreferenceManager.maxHeartRate ?? 0)")
        Logger.debug("[HeartRatePrompt] restingHeartRate: \(userPreferenceManager.restingHeartRate ?? 0)")

        // 如果用戶已經選擇不再顯示，則跳過
        if userPreferenceManager.doNotShowHeartRatePrompt {
            Logger.debug("[HeartRatePrompt] ❌ 用戶已選擇「永不提醒」，跳過")
            return
        }

        // 檢查是否在"明天再提醒"的時間範圍內
        if let nextRemindDate = userPreferenceManager.heartRatePromptNextRemindDate {
            Logger.debug("[HeartRatePrompt] 檢查「明天再提醒」時間：\(nextRemindDate)")
            if Date() < nextRemindDate {
                Logger.debug("[HeartRatePrompt] ❌ 仍在等待期內，跳過（\(nextRemindDate) > 現在）")
                return
            } else {
                // 時間已過期，清除這個標記
                Logger.debug("[HeartRatePrompt] ✅ 等待期已過期，清除標記")
                userPreferenceManager.heartRatePromptNextRemindDate = nil
            }
        }

        // 檢查是否設定了最大心率和靜息心率
        let hasMaxHeartRate = userPreferenceManager.maxHeartRate != nil && (userPreferenceManager.maxHeartRate ?? 0) > 0
        let hasRestingHeartRate = userPreferenceManager.restingHeartRate != nil && (userPreferenceManager.restingHeartRate ?? 0) > 0

        Logger.debug("[HeartRatePrompt] 檢查結果 - hasMaxHeartRate: \(hasMaxHeartRate), hasRestingHeartRate: \(hasRestingHeartRate)")

        // ⚠️ 修正邏輯：只要有一個沒設置就提醒（使用 OR 而不是 AND）
        if !hasMaxHeartRate || !hasRestingHeartRate {
            let missingItems = [
                !hasMaxHeartRate ? "最大心率" : nil,
                !hasRestingHeartRate ? "靜息心率" : nil
            ].compactMap { $0 }

            Logger.debug("[HeartRatePrompt] ✅ 缺少心率數據：\(missingItems.joined(separator: "、"))，3秒後顯示提醒")

            // 延遲 3 秒顯示，確保視圖完全加載且不干擾用戶初始體驗
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                Logger.debug("[HeartRatePrompt] ⏰ 3秒已過，顯示心率設置對話框")
                showHeartRateSetup = true
            }
        } else {
            Logger.debug("[HeartRatePrompt] ❌ 心率數據已完整，跳過（maxHR: \(userPreferenceManager.maxHeartRate ?? 0), restingHR: \(userPreferenceManager.restingHeartRate ?? 0)）")
        }
    }

    private func refreshWorkouts() {
        Logger.debug("Refreshing training records and weekly volume")
        TrackedTask("TrainingPlanView: refreshWorkouts") {
            // 🔄 檢查 plan status（同步訓練計畫狀態）
            await viewModel.loadPlanStatus()

            // 使用統一的刷新方法（內部已調用 loadWeeklyPlan(skipCache: true)）
            await viewModel.refreshWeeklyPlan()

            // ✅ 已移除重複的 loadWeeklyPlan() 調用
            // refreshWeeklyPlan() 內部已經執行 loadWeeklyPlan(skipCache: true)

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

// MARK: - 預覽
#Preview("訓練計畫 - 有課表") {
    TrainingPlanView()
        .environmentObject(HealthKitManager())
}

#Preview("今日焦點卡片") {
    let viewModel = TrainingPlanViewModel()
    let mockDay = TrainingDay(
        dayIndex: "0",
        dayTarget: "結合多種配速與強度訓練整體能力",
        reason: nil,
        tips: nil,
        trainingType: "combination",
        trainingDetails: TrainingDetails(
            description: "組合訓練",
            distanceKm: nil,
            totalDistanceKm: 10.0,
            timeMinutes: nil,
            pace: nil,
            work: nil,
            recovery: nil,
            repeats: nil,
            heartRateRange: nil,
            segments: [
                ProgressionSegment(distanceKm: 3.0, pace: nil, description: "輕鬆開始", heartRateRange: HeartRateRange(min: 141, max: 162)),
                ProgressionSegment(distanceKm: 4.0, pace: "5:25", description: "提速", heartRateRange: HeartRateRange(min: 162, max: 176)),
                ProgressionSegment(distanceKm: 3.0, pace: nil, description: "放鬆結束", heartRateRange: HeartRateRange(min: 141, max: 162))
            ]
        )
    )

    return TodayFocusCard(viewModel: viewModel, todayTraining: mockDay)
        .padding()
}

#Preview("週時間軸") {
    let viewModel = TrainingPlanViewModel()
    let mockPlan = WeeklyPlan(
        id: "preview",
        purpose: "預覽測試",
        weekOfPlan: 35,
        totalWeeks: 39,
        totalDistance: 43.0,
        designReason: ["測試用"],
        days: [
            TrainingDay(dayIndex: "0", dayTarget: "恢復跑", reason: nil, tips: nil, trainingType: "recovery_run",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 6.19, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "1", dayTarget: "間歇訓練", reason: nil, tips: nil, trainingType: "interval",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 4.42, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "4", dayTarget: "組合訓練", reason: nil, tips: nil, trainingType: "combination",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: nil, totalDistanceKm: 10.0, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "2", dayTarget: "輕鬆跑", reason: nil, tips: nil, trainingType: "easy",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 8.0, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil))
        ],
        intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
    )

    return WeekTimelineView(viewModel: viewModel, plan: mockPlan)
        .padding()
}

#Preview("週總覽卡片") {
    WeekOverviewCard(
        viewModel: TrainingPlanViewModel(),
        plan: WeeklyPlan(
            id: "preview",
            purpose: "預覽測試",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 50.0,
            designReason: ["測試用"],
            days: [],
            intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
        )
    )
    .environmentObject(HealthKitManager())
    .padding()
}
