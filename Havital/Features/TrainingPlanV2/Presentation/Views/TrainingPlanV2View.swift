import SwiftUI
import Observation

/// V2 訓練計畫主頁面
/// 設計原則：與 V1 保持一致的 UI/UX，使用 V2 的資料模型
struct TrainingPlanV2View: View {
    @State private var viewModel: TrainingPlanV2ViewModel
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlanOverview = false
    @State private var showUserProfile = false
    @State private var showEditSchedule = false
    @State private var editScheduleVM: EditScheduleV2ViewModel?
    @State private var showContactPaceriz = false
    @State private var showFeedbackReport = false
    @State private var showWeekSelector = false
    @State private var showMessageCenter = false
    @StateObject private var userProfileViewModel = UserProfileFeatureViewModel()
    @StateObject private var announcementViewModel = AnnouncementViewModel(
        repository: DependencyContainer.shared.resolve()
    )

    // MARK: - Initialization

    init(viewModel: TrainingPlanV2ViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: DependencyContainer.shared.makeTrainingPlanV2ViewModel())
        }
    }

    private var userProfileMenuTitle: String {
        switch LanguageManager.shared.currentLanguage {
        case .traditionalChinese:
            return "個人資料"
        case .english:
            return "Profile"
        case .japanese:
            return "プロフィール"
        }
    }

    static func shouldShowNextWeekButton(
        nextWeekInfo: NextWeekInfoV2?,
        selectedWeek: Int,
        currentWeek: Int
    ) -> Bool {
        guard let nextWeekInfo,
              nextWeekInfo.canGenerate,
              !nextWeekInfo.hasPlan,
              selectedWeek == currentWeek else {
            return false
        }

        return true
    }

    private var shouldShowNextWeekButton: Bool {
        Self.shouldShowNextWeekButton(
            nextWeekInfo: viewModel.loader.planStatusResponse?.nextWeekInfo,
            selectedWeek: viewModel.loader.selectedWeek,
            currentWeek: viewModel.loader.currentWeek
        )
    }

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.loader.planStatus {
                    case .ready(let weeklyPlan):
                        // 1️⃣ 訓練進度卡片（與 V1 相同）
                        TrainingProgressCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 2️⃣ 週總覽卡片（與 V1 相同）
                        WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 3️⃣ 週時間軸
                        WeekTimelineViewV2(viewModel: viewModel, plan: weeklyPlan)


                    case .noWeeklyPlan:
                        GenerateWeeklyPlanPromptView(
                            isWeekOne: viewModel.loader.currentWeek == 1,
                            isGeneratingSummary: viewModel.summary.isGeneratingSummary
                        ) {
                            Task {
                                await viewModel.generator.generateCurrentWeekPlan()
                            }
                        }

                    case .needsWeeklySummary:
                        GenerateWeeklySummaryPromptView(
                            weekToSummarize: viewModel.loader.currentWeek - 1,
                            isGenerating: viewModel.summary.isGeneratingSummary
                        ) {
                            Task {
                                // 產生上週回顧後，自動顯示 sheet
                                await viewModel.summary.createWeeklySummaryAndShow(week: viewModel.loader.currentWeek - 1)
                            }
                        }

                    case .noPlan:
                        NoPlanPromptView()

                    case .completed:
                        TrainingCompletedView(onSetNewGoal: {
                            authViewModel.startReonboarding()
                        })

                    case .loading:
                        ProgressView()
                            .padding(.top, 100)

                    case .error(let error):
                        ErrorView(error: error, retryAction: {
                            Task {
                                await viewModel.refreshWeeklyPlan()
                            }
                        })
                    }

                    // 🆕 產生下週課表按鈕（週六日顯示，或 DEV 環境可提前產生）
                    if shouldShowNextWeekButton,
                       let nextWeekInfo = viewModel.loader.planStatusResponse?.nextWeekInfo {
                        GenerateNextWeekButtonV2(viewModel: viewModel, nextWeekInfo: nextWeekInfo)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.loader.selectedWeek != viewModel.loader.currentWeek {
                    Button {
                        Task { await viewModel.loader.switchToWeek(viewModel.loader.currentWeek) }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text(String(format: NSLocalizedString("training_plan.back_to_current_week", comment: "返回本週 (Week %d)"), viewModel.loader.currentWeek))
                        }
                        .font(AppFont.subheadline())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .refreshable {
                await viewModel.refreshWeeklyPlan()
            }
            .navigationTitle(viewModel.loader.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左側：訊息中心鈴鐺（含未讀 badge）
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showMessageCenter = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .foregroundColor(.primary)
                                .padding(.trailing, 6)
                                .padding(.top, 4)
                            if announcementViewModel.unreadCount > 0 {
                                Text(announcementViewModel.unreadCount > 99 ? "99+" : "\(announcementViewModel.unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .accessibilityIdentifier("TrainingPlan_BellButton")
                }

                // 右側選單
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showUserProfile = true }) {
                            Label(userProfileMenuTitle, systemImage: "person.circle")
                        }
                        .accessibilityIdentifier("TrainingPlan_Menu_Profile")

                        Button(action: { showPlanOverview = true }) {
                            Label(NSLocalizedString("training.plan_overview", comment: "Plan Overview"), systemImage: "doc.text.below.ecg")
                        }

                        Button(action: {
                            viewModel.summary.summaryFlowPhase = .showingSummary
                            viewModel.summary.summaryFlowActive = true
                        }) {
                            Label(NSLocalizedString("training.weekly_summary", comment: "週摘要"), systemImage: "chart.bar.doc.horizontal")
                        }

                        // 編輯週課表（只在有課表時顯示）
                        if case .ready = viewModel.loader.planStatus {
                            Button(action: { openEditSchedule() }) {
                                Label(NSLocalizedString("training.edit_schedule", comment: "編輯週課表"), systemImage: "pencil")
                            }
                        }

                        Button(action: { showWeekSelector = true }) {
                            Label(NSLocalizedString("training.switch_week", comment: "切換週數"), systemImage: "list.number")
                        }

                        Divider()

                        Button(action: {
                            showContactPaceriz = true
                        }) {
                            Label(NSLocalizedString("training.contact_paceriz", comment: "Contact Paceriz"), systemImage: "envelope.circle")
                        }

                        // Debug 選單
                        #if DEBUG
                        Divider()

                        Menu {
                            Button(action: {
                                Task {
                                    await viewModel.debugGenerateWeeklySummary()
                                }
                            }) {
                                Label("🐛 產生週回顧", systemImage: "note.text.badge.plus")
                            }

                            Button(role: .destructive, action: {
                                Task {
                                    await viewModel.debugDeleteCurrentWeekPlan()
                                }
                            }) {
                                Label("🗑️ 刪除當前週課表", systemImage: "trash")
                            }

                            Button(role: .destructive, action: {
                                Task {
                                    await viewModel.debugDeleteCurrentWeeklySummary()
                                }
                            }) {
                                Label("🗑️ 刪除當前週回顧", systemImage: "trash")
                            }
                        } label: {
                            Label("🐛 Debug 工具", systemImage: "hammer.circle")
                        }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityIdentifier("TrainingPlan_MenuButton")
                }
            }
            .sheet(isPresented: $showPlanOverview) {
                PlanOverviewSheetV2(viewModel: viewModel)
            }
            .sheet(isPresented: $showMessageCenter) {
                NavigationStack {
                    MessageCenterView(viewModel: announcementViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("關閉") { showMessageCenter = false }
                            }
                        }
                }
            }
            // ✅ Standalone Loading（updateOverview / debug 等非 summary flow）
            .sheet(isPresented: $bindableViewModel.isLoadingAnimation) {
                LoadingAnimationView(type: .generatePlan, totalDuration: 12.0)
                    .ignoresSafeArea()
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showUserProfile) {
                NavigationView {
                    UserProfileView(isShowing: $showUserProfile)
                }
            }
            .onChange(of: authViewModel.isReonboardingMode) { newValue in
                if newValue {
                    showUserProfile = false
                }
            }
            .sheet(isPresented: $showEditSchedule, onDismiss: {
                // 編輯 sheet 關閉後，套用儲存結果（避免 @Observable sheet 重建問題）
                if let savedPlan = editScheduleVM?.savedPlan {
                    viewModel.loader.weeklyPlan = savedPlan
                    viewModel.loader.planStatus = .ready(savedPlan)
                }
                editScheduleVM = nil
            }) {
                if let editVM = editScheduleVM {
                    EditScheduleViewV2(
                        editViewModel: editVM,
                        planViewModel: viewModel
                    )
                }
            }
            // ✅ 合併 Sheet：loading review → summary → loading plan（零閃爍）
            .sheet(isPresented: $bindableViewModel.summary.summaryFlowActive) {
                let weekToShow: Int = {
                    if case .loaded(let loadedSummary) = viewModel.summary.weeklySummary {
                        return loadedSummary.weekOfTraining
                    }
                    if let requested = viewModel.summary.lastRequestedSummaryWeek {
                        return requested
                    }
                    return max(1, viewModel.loader.currentWeek - 1)
                }()

                let isTrainingCompleted = viewModel.loader.planStatus == .completed ||
                    viewModel.loader.planStatusResponse?.nextAction == "training_completed"

                switch viewModel.summary.summaryFlowPhase {
                case .loadingReview:
                    LoadingAnimationView(type: .generateReview, totalDuration: 30.0)
                        .ignoresSafeArea()
                        .interactiveDismissDisabled(true)

                case .showingSummary:
                    NavigationStack {
                        WeeklySummaryV2View(
                            viewModel: viewModel,
                            weekOfPlan: weekToShow,
                            onGenerateNextWeek: isTrainingCompleted ? nil : {
                                viewModel.summary.summaryFlowPhase = .loadingPlan
                                Task {
                                    let success = await viewModel.summary.applySelectedAdjustments(weekOfPlan: weekToShow)
                                    guard success else {
                                        // 回到 summary phase 讓 error banner 可見，不要靜默關閉 sheet
                                        viewModel.summary.summaryFlowPhase = .showingSummary
                                        return
                                    }
                                    let weekToGenerate = await viewModel.generator.resolveWeekToGenerateAfterSummary(summaryWeek: weekToShow)
                                    await viewModel.generator.generateWeeklyPlanDirectly(
                                        weekNumber: weekToGenerate,
                                        managedLoadingExternally: true
                                    )
                                    viewModel.summary.summaryFlowActive = false
                                }
                            },
                            onSetNewGoal: isTrainingCompleted ? {
                                viewModel.summary.summaryFlowActive = false
                                authViewModel.startReonboarding()
                            } : nil
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(NSLocalizedString("common.close", comment: "Close")) {
                                    viewModel.summary.summaryFlowActive = false
                                }
                            }
                        }
                    }

                case .loadingPlan:
                    LoadingAnimationView(type: .generatePlan, totalDuration: 12.0)
                        .ignoresSafeArea()
                        .interactiveDismissDisabled(true)
                }
            }
        } // ZStack
        }
        .sheet(isPresented: $showWeekSelector) {
            WeekSelectorSheetV2(viewModel: viewModel, isPresented: $showWeekSelector)
        }
        .confirmationDialog(
            NSLocalizedString("contact.paceriz", comment: "Contact Paceriz"),
            isPresented: $showContactPaceriz,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("feedback.title", comment: "Feedback")) {
                if userProfileViewModel.userData == nil {
                    userProfileViewModel.fetchUserProfile()
                }
                showFeedbackReport = true
            }

            if isChineseLanguage {
                Button("FB 粉絲團") {
                    if let url = URL(string: "https://www.facebook.com/profile.php?id=61574822777267") {
                        UIApplication.shared.open(url)
                    }
                }

                Button("Threads") {
                    if let url = URL(string: "https://www.threads.net/@paceriz_official") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
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
        .sheet(item: $bindableViewModel.paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .sheet(item: $announcementViewModel.currentPopup) { announcement in
            AnnouncementPopupView(
                announcement: announcement,
                onCTA: { announcementViewModel.handlePopupCTA(announcement) },
                onDismiss: { announcementViewModel.dismissCurrentPopup() }
            )
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.loader.initialize()
            if authViewModel.hasCompletedOnboarding && !authViewModel.isReonboardingMode {
                announcementViewModel.loadAnnouncementsIfNeeded()
            }
        }
        // 成功訊息 Toast
        .overlay(alignment: .top) {
            if let successMessage = viewModel.successToast {
                VStack {
                    Text(successMessage)
                        .font(AppFont.bodySmall())
                        .padding()
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 60)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.clearSuccessToast()
                            }
                        }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.successToast)
            }
        }
        // 錯誤訊息 Toast
        .overlay(alignment: .top) {
            if let error = viewModel.networkError {
                VStack {
                    Text("❌ \(error.localizedDescription)")
                        .font(AppFont.bodySmall())
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 60)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.clearError()
                            }
                        }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.networkError as? NSError)
            }
        }
        // Rizo 配額超出 Banner
        .overlay(alignment: .top) {
            if viewModel.showRizoQuotaExceededBanner {
                VStack {
                    Text(NSLocalizedString("rizo.quota_exceeded_banner", comment: "Rizo AI quota exceeded"))
                        .font(AppFont.bodySmall())
                        .padding()
                        .background(Color.orange.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 60)
                        .accessibilityIdentifier("RizoQuota_Banner")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                viewModel.showRizoQuotaExceededBanner = false
                            }
                        }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.showRizoQuotaExceededBanner)
            }
        }
    }

    // MARK: - Helpers

    private func openEditSchedule() {
        guard case .ready(let weeklyPlan) = viewModel.loader.planStatus else { return }
        let startDate: Date = {
            if let overview = viewModel.loader.planOverview, let createdAt = overview.createdAt {
                let formatter = ISO8601DateFormatter()
                let str = formatter.string(from: createdAt)
                return WeekDateService.weekDateInfo(
                    createdAt: str,
                    weekNumber: viewModel.loader.selectedWeek
                )?.startDate ?? Date()
            }
            return Date()
        }()
        editScheduleVM = EditScheduleV2ViewModel(weeklyPlan: weeklyPlan, startDate: startDate)
        showEditSchedule = true
    }

    private var isChineseLanguage: Bool {
        guard let lang = Bundle.main.preferredLocalizations.first else { return false }
        return lang.hasPrefix("zh")
    }
}

// MARK: - Placeholder Views

/// 佔位用的週時間軸視圖（待實作）
private struct PlaceholderWeekTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)

            Text(NSLocalizedString("training.weekly_schedule_wip", comment: "Weekly schedule feature is in development"))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/// 產生週課表提示視圖
private struct GenerateWeeklyPlanPromptView: View {
    let isWeekOne: Bool
    let isGeneratingSummary: Bool
    let generateAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(AppFont.systemScaled(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text(NSLocalizedString("training.no_weekly_plan_title", comment: "週課表尚未產生"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.no_weekly_plan_description", comment: "點擊下方按鈕產生本週課表"))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: generateAction) {
                if isGeneratingSummary {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                } else {
                    Text(isWeekOne
                        ? NSLocalizedString("training.generate_weekly_plan", comment: "產生週課表")
                        : NSLocalizedString("training.get_weekly_summary", comment: "取得週回顧"))
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                }
            }
            .background(Color.blue)
            .cornerRadius(10)
            .disabled(isGeneratingSummary)
        }
        .padding()
    }
}

/// 無計畫提示視圖
private struct NoPlanPromptView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(AppFont.systemScaled(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text(NSLocalizedString("training.no_plan_title", comment: "No Plan Title"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.no_plan_description", comment: "No Plan Description"))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// ⭐ 產生週回顧提示視圖
private struct GenerateWeeklySummaryPromptView: View {
    let weekToSummarize: Int
    let isGenerating: Bool
    let generateAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(AppFont.systemScaled(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text(NSLocalizedString("training.need_weekly_summary_title", comment: "Need Weekly Summary"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(String(format: NSLocalizedString("training.need_weekly_summary_description", comment: "Need Summary Description"), weekToSummarize))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: generateAction) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                } else {
                    Text(String(format: NSLocalizedString("training.generate_week_summary", comment: "Generate Week Summary"), weekToSummarize))
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 32)
                }
            }
            .background(Color.blue)
            .cornerRadius(10)
            .disabled(isGenerating)
        }
        .padding()
    }
}

/// 訓練完成提示視圖
private struct TrainingCompletedView: View {
    var onSetNewGoal: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppFont.systemScaled(size: 60))
                .foregroundColor(.green)
                .padding(.top, 40)

            Text(NSLocalizedString("training.completed_title", comment: "Training Completed"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(NSLocalizedString("training.completed_description", comment: "Ready for New Plan"))
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let onSetNewGoal {
                Button(action: onSetNewGoal) {
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
    }
}

/// 產生下週課表按鈕（V2 版本，照搬 V1 流程）
private struct GenerateNextWeekButtonV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let nextWeekInfo: NextWeekInfoV2
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 標題
            Text(NSLocalizedString("training.ready_for_next_week_title", comment: "Ready for Next Week"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            // 按鈕
            Button {
                Logger.debug("🖱️ [GenerateNextWeekButtonV2] 按鈕被點擊，顯示確認對話框")
                showConfirmation = true
            } label: {
                VStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("training.generate_week_n_plan", comment: "Generate Week N Plan"), nextWeekInfo.weekNumber))
                        .font(AppFont.headline())

                    // 提示文字
                    if nextWeekInfo.requiresCurrentWeekSummary == true {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                            Text(NSLocalizedString("training.need_complete_current_summary", comment: "Need Complete Summary"))
                        }
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.8))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(NSLocalizedString("training.current_summary_completed", comment: "Summary Completed"))
                        }
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.loader.planStatus == .loading)
            .alert(NSLocalizedString("training.confirm_training_complete", comment: "Confirm Training Complete"), isPresented: $showConfirmation) {
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                    Logger.debug("❌ [GenerateNextWeekButtonV2] 用戶取消產生課表")
                }
                Button(NSLocalizedString("common.confirm", comment: "Confirm")) {
                    Logger.debug("✅ [GenerateNextWeekButtonV2] 用戶確認產生課表")
                    Task {
                        await viewModel.generator.generateNextWeekPlan()
                    }
                }
            } message: {
                Text(NSLocalizedString("training.confirm_training_complete_message", comment: "Confirm Training Complete Message"))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

/// 錯誤視圖
private struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppFont.systemScaled(size: 60))
                .foregroundColor(.orange)
                .padding(.top, 40)

            Text(NSLocalizedString("training.loading_failed", comment: "Loading Failed"))
                .font(AppFont.headline())
                .foregroundColor(.primary)

            Text(error.localizedDescription)
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retryAction) {
                Text(NSLocalizedString("common.retry", comment: "Retry"))
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Week Selector Sheet V2

/// 簡易週選擇器（V2 版本）
private struct WeekSelectorSheetV2: View {
    var viewModel: TrainingPlanV2ViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(1...max(viewModel.totalWeeks, 1), id: \.self) { week in
                Button {
                    Task {
                        await viewModel.loader.switchToWeek(week)
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Text(String(format: NSLocalizedString("training.week_number", comment: "第 %d 週"), week))
                            .font(AppFont.body())
                            .foregroundColor(.primary)

                        Spacer()

                        if week == viewModel.loader.currentWeek {
                            Text(NSLocalizedString("training.current_week_label", comment: "本週"))
                                .font(AppFont.caption())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }

                        if week == viewModel.loader.selectedWeek {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("training.switch_week", comment: "切換週數"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TrainingPlanV2View()
}
