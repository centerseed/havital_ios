import SwiftUI
import HealthKit
import Combine

// 拆分新週提示視圖
struct NewWeekPromptView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let currentTrainingWeek: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("training.current_week_progress", comment: "Current training progress has entered week") + " \(currentTrainingWeek) " + NSLocalizedString("date.week", comment: "Week"))
                .font(AppFont.headline())
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
                        // ✅ 直接傳入當前週數，後端會自動減1計算應產生的週回顧
                        // 不需要在前端減1，否則會導致雙重減1的問題
                        let weekNumber = currentTrainingWeek

                        // 🔍 [DEBUG] Entry point logging
                        Logger.debug("========================================")
                        Logger.debug("[TrainingPlanView] 🔵 產生週回顧按鈕被點擊")
                        Logger.debug("[TrainingPlanView] currentTrainingWeek: \(currentTrainingWeek)")
                        Logger.debug("[TrainingPlanView] 傳入的 weekNumber: \(weekNumber)（後端會自動減1）")
                        Logger.debug("[TrainingPlanView] → 調用 createWeeklySummary(weekNumber: \(weekNumber))")
                        Logger.debug("========================================")

                        await viewModel.createWeeklySummary(weekNumber: weekNumber)
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

// 結束週回顧並重設 Onboarding 的視圖
struct FinalWeekPromptView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("training.cycle_completed_message", comment: "Great job! Your training cycle is complete. Don't forget to set your next training goal after reviewing your training!"))
                .font(AppFont.headline())
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
                        // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                        authViewModel.startReonboarding()
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
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
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
    @State private var editViewModel: EditScheduleViewModel? = nil
    @State private var showHeartRateSetup = false
    @State private var showHeartRateSetupFullScreen = false
    @State private var showContactPaceriz = false
    @State private var showFeedbackReport = false
    @ObservedObject private var userPreferenceManager = UserPreferencesManager.shared
    @StateObject private var userProfileViewModel = UserProfileFeatureViewModel()

    // ✅ 防止 .task 重複初始化
    @State private var hasPerformedInitialLoad = false
    
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 使用 ZStack 來疊加 loading 狀態
                    ZStack {
                        mainContentView
                            .opacity(viewModel.planStatus == .loading ? 0.3 : 1.0)
                        
                        if viewModel.planStatus == .loading {
                            HStack(alignment: .center, spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(L10n.Common.loading.localized)
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            }
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
            // ✅ 確保只初始化一次，防止 SwiftUI .task 多次觸發
            guard !hasPerformedInitialLoad else {
                Logger.debug("[TrainingPlanView] ⚠️ 已初始化，跳過重複調用")
                return
            }
            hasPerformedInitialLoad = true
            Logger.debug("[TrainingPlanView] 🚀 首次初始化 ViewModel")

            // 初始化 ViewModel
            await viewModel.initialize()

            // 初始化 VDOTManager（用於 EditScheduleView 配速計算）
            await VDOTManager.shared.initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // ✅ CRITICAL FIX: 總是執行刷新，不檢查 AppStateManager 狀態
            // 原因：記憶體清除後 AppStateManager 可能未就緒，導致刷新被跳過
            Logger.debug("[TrainingPlanView] App 從背景回來，AppStateManager.isReady: \(AppStateManager.shared.currentState.isReady)")
            Logger.debug("[TrainingPlanView] 執行刷新（無條件）")

            // 刷新訓練記錄
            refreshWorkouts()

            // 背景刷新使用者資料（使用雙軌快取策略）
            Task {
                await userProfileViewModel.loadUserProfile(forceRefresh: false)
                Logger.debug("[TrainingPlanView] ✅ User profile background refresh triggered")
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
        .sheet(item: $editViewModel, onDismiss: {
            // 清理 ViewModel，下次打開時重新創建
            Logger.debug("[TrainingPlanView] Sheet dismissed, cleaning up EditScheduleViewModel")
            editViewModel = nil
        }) { editVM in
            EditScheduleView(
                editViewModel: editVM,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: viewModel.showAdjustmentConfirmation) {
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
        .sheet(isPresented: viewModel.showWeeklySummary) {
            if let summary = viewModel.weeklySummary {
                NavigationView {
                    // ✅ 檢查訓練是否完成，決定是否顯示「產生下週課表」按鈕
                    let isTrainingCompleted = viewModel.planStatus == .completed ||
                                             viewModel.planStatusResponse?.nextAction == .trainingCompleted

                    WeeklySummaryView(
                        summary: summary,
                        weekNumber: viewModel.currentWeek,
                        isVisible: viewModel.showWeeklySummary,
                        // ⚠️ 訓練完成時不傳回調，不顯示「產生下週課表」按鈕
                        onGenerateNextWeek: isTrainingCompleted ? nil : {
                            // 產生下週課表的回調
                            TrackedTask("TrainingPlanView: generateNextWeek") {
                                // 🔍 [DEBUG] Entry point logging
                                Logger.debug("========================================")
                                Logger.debug("[TrainingPlanView] 🚀 產生下週課表按鈕被點擊")

                                // ✅ Clean Architecture: 業務邏輯由 ViewModel 處理
                                let targetWeekToProduce = viewModel.determineNextPlanWeek()
                                let hasPendingWeek = viewModel.pendingTargetWeek != nil

                                Logger.debug("[TrainingPlanView] hasPendingWeek: \(hasPendingWeek)")
                                Logger.debug("[TrainingPlanView] targetWeekToProduce: \(targetWeekToProduce)")

                                // 關閉週回顧
                                viewModel.showWeeklySummary.wrappedValue = false

                                // 根據流程選擇對應方法
                                if hasPendingWeek {
                                    Logger.debug("[TrainingPlanView] → 調用 confirmAdjustmentsAndGenerateNextWeek(targetWeek: \(targetWeekToProduce))")
                                    // next_week_info 流程：產生指定週數
                                    await viewModel.confirmAdjustmentsAndGenerateNextWeek(targetWeek: targetWeekToProduce)
                                } else {
                                    Logger.debug("[TrainingPlanView] → 調用 generateNextWeekPlan(targetWeek: \(targetWeekToProduce), forceGenerate: true)")
                                    // ✅ 從週回顧 sheet 點擊按鈕，設置 forceGenerate=true 跳過週回顧檢查
                                    await viewModel.generateNextWeekPlan(targetWeek: targetWeekToProduce, forceGenerate: true)
                                }
                                Logger.debug("========================================")
                            }
                        },
                        // 🆕 訓練完成時傳遞「設定新目標」回調
                        onSetNewGoal: isTrainingCompleted ? {
                            viewModel.clearWeeklySummary()
                            viewModel.showWeeklySummary.wrappedValue = false
                            // Clean Architecture: Use AuthenticationViewModel instead of AuthenticationService
                            authViewModel.startReonboarding()
                        } : nil
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(L10n.Common.close.localized) {
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
            if viewModel.showSuccessToast.wrappedValue {
                SuccessToast(message: viewModel.successMessage, isPresented: viewModel.showSuccessToast)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.showSuccessToast.wrappedValue)
                    .onAppear {
                        // 3秒後自動消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.clearSuccessToast()
                        }
                    }
            }
        }
        // 🆕 生成截圖 Toast（提示用戶等待）
        .overlay(alignment: .top) {
            if isGeneratingScreenshot {
                InfoToast(message: NSLocalizedString("toast.generating_screenshot", comment: "Generating screenshot, please wait..."))
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: isGeneratingScreenshot)
            }
        }
        .onAppear {
            // ✅ 移除重複的初始化調用（已在 .task 中處理）
            // ✅ 只保留 UI 提示相關的邏輯（心率檢查、App 評分）

            #if DEBUG
            HeartRateDebugHelper.printAllHeartRateSettings()
            #endif

            if hasCompletedOnboarding && AppStateManager.shared.currentState.isReady {
                // 檢查用戶是否設定了心率，如果未設定則顯示提示
                checkAndShowHeartRateSetup()

                // 在訓練計劃載入後檢查評分提示
                TrackedTask("TrainingPlanView: checkAppRating") {
                    // 延遲 5 秒確保用戶數據和訓練計劃都已完全載入
                    await AppRatingManager.shared.checkOnAppLaunch(delaySeconds: 5)
                }
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
            NavigationStack {
                HeartRateZoneInfoView(mode: .profile)
            }
        }
        .confirmationDialog(
            NSLocalizedString("contact.paceriz", comment: "Contact Paceriz"),
            isPresented: $showContactPaceriz,
            titleVisibility: .visible
        ) {
            // 問題回報
            Button(NSLocalizedString("feedback.title", comment: "Feedback")) {
                // 確保載入使用者資料
                if userProfileViewModel.userData == nil {
                    userProfileViewModel.fetchUserProfile()
                }
                showFeedbackReport = true
            }

            // 根據語言顯示不同的聯絡方式
            if isChineseLanguage {
                // Facebook
                Button("FB 粉絲團") {
                    if let url = URL(string: "https://www.facebook.com/profile.php?id=61574822777267") {
                        UIApplication.shared.open(url)
                    }
                }

                // Threads
                Button("Threads") {
                    if let url = URL(string: "https://www.threads.net/@paceriz_official") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                // Email
                Button(NSLocalizedString("contact.contact_support", value: "Contact Support", comment: "Contact Support")) {
                    let email = "contact@paceriz.com"
                    if let url = URL(string: "mailto:\(email)") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showFeedbackReport) {
            if let userData = userProfileViewModel.userData {
                FeedbackReportView(userEmail: userData.email ?? "")
            } else {
                FeedbackReportView(userEmail: "")
            }
        }
    }

    // 判斷是否為中文語言
    private var isChineseLanguage: Bool {
        guard let lang = Bundle.main.preferredLocalizations.first else { return false }
        return lang.hasPrefix("zh")
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

            // 🆕 產生下週課表按鈕（週六日顯示，或 DEV 環境可提前產生）
            // 條件：canGenerate=true（後端判斷週六日）或 DEV 環境開啟 allowEarlyNextWeekGeneration
            if let nextWeekInfo = viewModel.nextWeekInfo,
               (nextWeekInfo.canGenerate || FeatureFlagManager.shared.allowEarlyNextWeekGeneration),
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
                        // 創建 EditScheduleViewModel，sheet 會自動顯示（因為使用 .sheet(item:)）
                        if let weeklyPlan = viewModel.weeklyPlan,
                           let weekStartDate = viewModel.getWeekStartDate() {
                            Logger.debug("[TrainingPlanView] Creating EditScheduleViewModel")
                            // 設置 editViewModel 會自動觸發 sheet 顯示
                            editViewModel = EditScheduleViewModel(weeklyPlan: weeklyPlan, startDate: weekStartDate)
                        }
                    }) {
                        Label(NSLocalizedString("training.edit_schedule", comment: "Edit Schedule"), systemImage: "slider.horizontal.3")
                    }
                    .disabled(viewModel.planStatus == .loading || viewModel.weeklyPlan == nil)

                    Divider()

                    Button(action: {
                        showContactPaceriz = true
                    }) {
                        Label(NSLocalizedString("contact.paceriz", comment: "Contact Paceriz"), systemImage: "envelope.circle")
                    }
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
                        .font(AppFont.headline())
                    
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
                    .font(AppFont.dataLarge())
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    // 主要錯誤訊息
                    Text(NSLocalizedString("training.cannot_load_plan", comment: "Unable to load training plan"))
                        .font(AppFont.title2())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // 詳細說明文字
                    Text(NSLocalizedString("error.network_or_server_error", comment: "Network connection or server error, please check your network connection and reload"))
                        .font(AppFont.body())
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
                    .font(AppFont.body())
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
                !hasMaxHeartRate ? L10n.Profile.maxHR.localized : nil,
                !hasRestingHeartRate ? L10n.Profile.restingHR.localized : nil
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
            // ✅ ROOT CAUSE FIX: 強制重新初始化，確保所有依賴數據都有效
            // 問題：loadWorkoutsForCurrentWeek() 依賴 trainingOverview
            // 如果 overview 是 nil，就會直接返回，導致 workoutsByDayV2 不更新
            // 解決：從背景回來時強制執行完整初始化流程（force: true）
            Logger.debug("[TrainingPlanView] 執行強制重新初始化（force: true）...")
            await viewModel.initialize(force: true)
            Logger.debug("[TrainingPlanView] ✅ 強制初始化完成")
        }
    }
    
    // 分享訓練課表
    private func shareTrainingPlan() {
        isGeneratingScreenshot = true

        // ✅ 使用 ImageRenderer (iOS 16+) 生成截圖 - 更簡單可靠
        let shareContent = VStack(spacing: 24) {
                // 標題部分
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.trainingPlanName)
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let plan = viewModel.weeklyPlan {
                        Text(NSLocalizedString("training.week_schedule", comment: "Week Schedule") + " \(plan.weekOfPlan)")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 8)

                // 根據當前狀態顯示內容
                switch viewModel.planStatus {
                case .ready(let plan):
                    // 訓練進度
                    TrainingProgressCard(viewModel: viewModel, plan: plan)

                    // 週概覽卡片
                    WeekOverviewCard(viewModel: viewModel, plan: plan)

                    // 週訓練時間軸（包含所有訓練日）
                    WeekTimelineView(viewModel: viewModel, plan: plan)

            case .noPlan:
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(AppFont.dataMedium())
                        .foregroundColor(.gray)

                    Text(NSLocalizedString("training.no_schedule_generated", comment: "This week's schedule has not been generated yet"))
                        .font(AppFont.headline())

                    Text(NSLocalizedString("training.generate_review_first", comment: "Please generate a weekly review first to get personalized training recommendations"))
                        .font(AppFont.bodySmall())
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
                        .font(AppFont.dataMedium())
                        .foregroundColor(.green)

                    Text(L10n.TrainingPlan.cycleCompleted.localized)
                        .font(AppFont.headline())

                    Text(L10n.TrainingPlan.congratulations.localized)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            case .loading, .error:
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(AppFont.dataMedium())
                        .foregroundColor(.gray)

                    Text(L10n.TrainingPlan.loadingSchedule.localized)
                        .font(AppFont.headline())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(width: UIScreen.main.bounds.width)
        .background(Color(UIColor.systemGroupedBackground))

        // 使用 ImageRenderer 生成圖片（iOS 16+）
        let renderer = ImageRenderer(content: shareContent)
        renderer.scale = UIScreen.main.scale

        // 在背景執行緒生成圖片
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = renderer.uiImage {
                DispatchQueue.main.async {
                    self.isGeneratingScreenshot = false
                    self.shareImage = image
                    self.showShareSheet = true
                }
            } else {
                // 如果生成失敗，重試一次
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let retryImage = renderer.uiImage {
                        self.isGeneratingScreenshot = false
                        self.shareImage = retryImage
                        self.showShareSheet = true
                    } else {
                        self.isGeneratingScreenshot = false
                        Logger.error("無法生成分享截圖")
                    }
                }
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
            ],
            warmup: nil,
            cooldown: nil,
            exercises: nil,
            supplementary: nil
        )
    )

    TodayFocusCard(viewModel: viewModel, todayTraining: mockDay)
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
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 6.19, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil, warmup: nil, cooldown: nil, exercises: nil, supplementary: nil)),
            TrainingDay(dayIndex: "1", dayTarget: "間歇訓練", reason: nil, tips: nil, trainingType: "interval",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 4.42, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil, warmup: nil, cooldown: nil, exercises: nil, supplementary: nil)),
            TrainingDay(dayIndex: "4", dayTarget: "組合訓練", reason: nil, tips: nil, trainingType: "combination",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: nil, totalDistanceKm: 10.0, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil, warmup: nil, cooldown: nil, exercises: nil, supplementary: nil)),
            TrainingDay(dayIndex: "2", dayTarget: "輕鬆跑", reason: nil, tips: nil, trainingType: "easy",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 8.0, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil, warmup: nil, cooldown: nil, exercises: nil, supplementary: nil))
        ],
        intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
    )

    WeekTimelineView(viewModel: viewModel, plan: mockPlan)
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
