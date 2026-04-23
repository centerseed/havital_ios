// Havital/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    // Clean Architecture: Use AuthenticationViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject private var appStateManager = AppStateManager.shared
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @ObservedObject private var reminderManager = SubscriptionReminderManager.shared
    @ObservedObject private var interruptCoordinator = InterruptCoordinator.shared

    // 訓練版本路由狀態
    // A-3b: 初始值改為 nil，避免 cold start race 期間誤 render V1 TrainingPlanView。
    // 在 `checkTrainingVersion()` 完成前，`trainingPlanTab()` 一律顯示 ProgressView。
    @State private var trainingVersion: String? = nil
    @State private var isCheckingVersion: Bool = true
    // A-3b race guard: 每次 checkTrainingVersion() 遞增此 token。
    // Task 完成時只有 token 仍匹配才寫回 state，避免舊 Task 覆寫新結果（re-onboarding / 快速帳號切換 race）。
    @State private var versionCheckToken: Int = 0
    @State private var showUserProfileForDataSourceBinding = false

    var body: some View {
        // 移除高頻日誌：body 每次重新評估都會觸發

        Group {
            // 如果 App 正在初始化，顯示載入畫面
            if appStateManager.shouldShowLoadingScreen {
                AppLoadingView()
                    .onAppear {
                        Logger.firebase(
                            "顯示 App 載入畫面",
                            level: .info,
                            labels: [
                                "module": "ContentView",
                                "action": "show_loading_screen"
                            ]
                        )
                    }
            }
            // 如果需要強制更新，顯示強制更新畫面（不可關閉）
            else if authViewModel.requiresForceUpdate {
                ForceUpdateView(updateUrl: authViewModel.forceUpdateUrl)
            }
            // 如果用戶未認證，顯示登入畫面
            else if !authViewModel.isAuthenticated {
                LoginView()
                    .environmentObject(authViewModel)
                    .onAppear {
                        Logger.firebase(
                            "顯示登入畫面",
                            level: .info,
                            labels: [
                                "module": "ContentView",
                                "action": "show_login_view",
                                "user_id": authViewModel.currentUser?.uid ?? "none"
                            ],
                            jsonPayload: [
                                "is_authenticated": authViewModel.isAuthenticated,
                                "has_completed_onboarding": authViewModel.hasCompletedOnboarding
                            ]
                        )
                    }
            }
            // 如果用戶未完成引導，顯示引導畫面
            else if !authViewModel.hasCompletedOnboarding && !authViewModel.isReonboardingMode {
                // 首次使用，顯示完整 onboarding 流程（使用新的統一容器）
                OnboardingContainerView(isReonboarding: false)
                    .environmentObject(authViewModel)
                    .environmentObject(FeatureFlagManager.shared)
                    .onAppear {
                        Logger.firebase(
                            "顯示 Onboarding 畫面",
                            level: .warn,
                            labels: [
                                "module": "ContentView",
                                "action": "show_onboarding_view",
                                "user_id": authViewModel.currentUser?.uid ?? "unknown"
                            ],
                            jsonPayload: [
                                "is_authenticated": authViewModel.isAuthenticated,
                                "has_completed_onboarding": authViewModel.hasCompletedOnboarding,
                                "is_reonboarding_mode": authViewModel.isReonboardingMode
                            ]
                        )
                    }
            }
            // Re-onboarding：直接替換 mainAppContent，避免 sheet 衝突
            else if authViewModel.isReonboardingMode {
                OnboardingContainerView(isReonboarding: true)
                    .environmentObject(authViewModel)
                    .environmentObject(FeatureFlagManager.shared)
            }
            // 顯示主要內容
            else {
                mainAppContent()
                    .onAppear {
                        Logger.firebase(
                            "顯示主應用內容",
                            level: .info,
                            labels: [
                                "module": "ContentView",
                                "action": "show_main_content",
                                "user_id": authViewModel.currentUser?.uid ?? "unknown"
                            ],
                            jsonPayload: [
                                "is_authenticated": authViewModel.isAuthenticated,
                                "has_completed_onboarding": authViewModel.hasCompletedOnboarding
                            ]
                        )

                        // 檢查訓練版本
                        checkTrainingVersion()
                        Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            await appViewModel.checkDataSourceBindingReminderIfNeeded(forceRefresh: true)
                        }
                    }
            }
        }
        .onChange(of: authViewModel.hasCompletedOnboarding) { newValue in
            Logger.firebase(
                "hasCompletedOnboarding 狀態變更",
                level: .info,
                labels: [
                    "module": "ContentView",
                    "action": "onboarding_status_changed",
                    "user_id": authViewModel.currentUser?.uid ?? "unknown"
                ],
                jsonPayload: [
                    "new_value": newValue,
                    "is_authenticated": authViewModel.isAuthenticated
                ]
            )
            // 完成或重置 onboarding 時自動關閉 modal
            // 移除 fullScreenCover 相關邏輯
            if newValue && !authViewModel.isReonboardingMode {
                checkTrainingVersion()
                Task {
                    appViewModel.resetDataSourceBindingReminderForFreshOnboarding()
                    // First onboarding completion can land on main content before
                    // later lifecycle hooks re-run; defer slightly so the alert host
                    // is mounted, then force a fresh reminder check.
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await appViewModel.checkDataSourceBindingReminderIfNeeded(forceRefresh: true)
                }
            }
        }
        .onChange(of: authViewModel.isReonboardingMode) { newValue in
            Logger.firebase(
                "isReonboardingMode 狀態變更",
                level: .info,
                labels: [
                    "module": "ContentView",
                    "action": "reonboarding_mode_changed",
                    "user_id": authViewModel.currentUser?.uid ?? "unknown"
                ],
                jsonPayload: [
                    "new_value": newValue
                ]
            )
            // Re-onboarding 開始時隱藏 training tab（避免 V1 VM 在升級中發出 API call）
            // Re-onboarding 結束後重新檢查訓練版本，確保切換到正確的 V1/V2 視圖
            if newValue {
                isCheckingVersion = true
            } else {
                checkTrainingVersion()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            guard authViewModel.isAuthenticated else { return }
            guard authViewModel.hasCompletedOnboarding else { return }
            guard !authViewModel.isReonboardingMode else { return }

            try? await Task.sleep(nanoseconds: 800_000_000)
            appViewModel.resetDataSourceBindingReminderSession()
            await appViewModel.checkDataSourceBindingReminderIfNeeded(forceRefresh: true)
        }
    }

    // 抽取主應用內容，方便管理
    @ViewBuilder
    private func mainAppContent() -> some View {
        // 從 HavitalApp.swift 遷移過來的 TabView
        ZStack {
            TabView {
                // 根據訓練版本顯示對應的訓練計劃視圖
                trainingPlanTab()
                    .tabItem {
                        Image(systemName: "figure.run")
                        Text(L10n.Tab.trainingPlan.localized)
                    }

                TrainingRecordView()
                    // .environmentObject(healthKitManager) // healthKitManager 已在 ContentView 層級注入
                    .tabItem {
                        Image(systemName: "chart.line.text.clipboard")
                        Text(L10n.Tab.trainingRecord.localized)
                    }

                MyAchievementView()
                    // .environmentObject(healthKitManager) // healthKitManager 已在 ContentView 層級注入
                    .tabItem {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        Text(L10n.Tab.performanceData.localized)
                    }
            }

            InterruptHostView(
                coordinator: interruptCoordinator,
                onGoToDataSourceSettings: {
                    showUserProfileForDataSourceBinding = true
                }
            )
        }
        .toolbarBackground(Color(UIColor.systemGroupedBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert(L10n.Error.healthPermission.localized, isPresented: $appViewModel.showHealthKitAlert) {
            Button(L10n.Common.settings.localized, role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.Common.cancel.localized, role: .cancel) { }
        } message: {
            Text(appViewModel.healthKitAlertMessage)
        }
        .alert(NSLocalizedString("alert.garmin_disconnected", comment: "Garmin Connection Interrupted"), isPresented: $appViewModel.showGarminMismatchAlert) {
            Button(NSLocalizedString("alert.reconnect_garmin", comment: "Reconnect Garmin")) {
                appViewModel.reconnectGarmin()
            }
            Button(NSLocalizedString("alert.switch_to_apple_health", comment: "Switch to Apple Health")) {
                appViewModel.switchToAppleHealth()
            }
            Button(NSLocalizedString("common.later", comment: "Later"), role: .cancel) {
                appViewModel.showGarminMismatchAlert = false
            }
        } message: {
            Text(NSLocalizedString("alert.garmin_not_connected_message", comment: "Your account is set to use Garmin data, but is not currently connected to your Garmin account. Please choose to reconnect Garmin or switch back to Apple Health."))
        }
        .sheet(isPresented: $showUserProfileForDataSourceBinding) {
            NavigationStack {
                UserProfileView(isShowing: $showUserProfileForDataSourceBinding)
                    .environmentObject(authViewModel)
                    .environmentObject(FeatureFlagManager.shared)
            }
        }
        .garminReconnectionAlert() // 添加 Garmin 重新連接警告
        // P0-4: 狀態降級非阻斷通知
        .onChange(of: subscriptionState.recentDowngrade) { _, downgrade in
            guard let downgrade else { return }
            Logger.debug("[ContentView] 訂閱狀態降級: \(downgrade.from.rawValue) → \(downgrade.to.rawValue)")
            // 降級通知透過 reminder 系統顯示，觸發 expired 提醒
            reminderManager.checkAndShowReminder(status: subscriptionState.currentStatus)
            subscriptionState.clearDowngrade()
        }
        // P1-9/P1-10: 訂閱到期提醒
        .onAppear {
            reminderManager.checkAndShowReminder(status: subscriptionState.currentStatus)
            syncSubscriptionReminderInterrupt()
        }
        .onChange(of: subscriptionState.currentStatus?.status) { _, _ in
            reminderManager.checkAndShowReminder(status: subscriptionState.currentStatus)
            syncSubscriptionReminderInterrupt()
        }
        .onChange(of: reminderManager.pendingReminder?.id) { _, _ in
            syncSubscriptionReminderInterrupt()
        }
    }

    private func syncSubscriptionReminderInterrupt() {
        guard let reminder = reminderManager.pendingReminder else {
            interruptCoordinator.removeAll(ofType: .subscriptionReminder)
            return
        }

        _ = interruptCoordinator.enqueue(
            .subscriptionReminder(reminder) { reason in
                guard reason != .cancelled else { return }

                let paywallTrigger: PaywallTrigger
                switch reminder {
                case .expired:
                    paywallTrigger = .apiGated
                case .trialExpiring:
                    paywallTrigger = .trialExpired
                }

                reminderManager.dismissReminder()
                if reason == .primaryAction {
                    _ = interruptCoordinator.enqueue(.paywall(paywallTrigger))
                }
            }
        )
    }

    // MARK: - Training Version Routing

    /// 訓練計劃 Tab - 根據版本動態選擇 V1 或 V2
    @ViewBuilder
    private func trainingPlanTab() -> some View {
        if isCheckingVersion || trainingVersion == nil {
            // A-3b: 版本尚未確定（含 cold start 期間 trainingVersion == nil），顯示 loading，
            // 避免 V2 用戶先 mount V1 TrainingPlanView，間接觸發 V1 WeeklyPlanViewModel → /plan/race_run/*
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("TrainingVersionCheck_Loading")
        } else if trainingVersion == "v2" {
            // V2 版本
            TrainingPlanV2View()
        } else {
            // V1 版本（確定為 v1 才走此分支）
            TrainingPlanView()
        }
    }

    /// 檢查訓練版本
    private func checkTrainingVersion() {
        versionCheckToken &+= 1
        let token = versionCheckToken
        Task {
            let container = DependencyContainer.shared

            // 確保 TrainingVersionRouter 已註冊
            if !container.isRegistered(TrainingVersionRouter.self) {
                container.registerTrainingVersionRouter()
            }

            let router: TrainingVersionRouter = container.resolve()
            let version = await router.getTrainingVersion()

            await MainActor.run {
                guard token == self.versionCheckToken else {
                    Logger.debug("[ContentView] Stale training version result discarded (token=\(token), current=\(self.versionCheckToken))")
                    return
                }
                self.trainingVersion = version
                self.isCheckingVersion = false
                Logger.debug("[ContentView] Training version detected: \(version)")
            }
        }
    }

    // 輔助屬性，用於避免在 SwiftUI Previews 中自動彈出 Onboarding
    private var isInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Clean Architecture: Use AuthenticationViewModel for preview
        let authViewModel = AuthenticationViewModel.shared
        let appViewModel = AppViewModel() // 建立一個 AppViewModel 實例供預覽
        // 你可以根據需要設定 authViewModel 和 appViewModel 的狀態來預覽不同場景
        // authViewModel.isAuthenticated = true
        // authViewModel.hasCompletedOnboarding = false
        // appViewModel.showHealthKitAlert = true // 範例

        return ContentView()
            .environmentObject(authViewModel)
            .environmentObject(appViewModel) // 注入 AppViewModel
    }
}
