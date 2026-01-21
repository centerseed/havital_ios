// Havital/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    // Clean Architecture: Use AuthenticationViewModel
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject private var appStateManager = AppStateManager.shared

    // 訓練版本路由狀態
    @State private var trainingVersion: String = "v1"
    @State private var isCheckingVersion: Bool = true

    var body: some View {
        let _ = print("📱 [ContentView] body 重新評估 - isAuth=\(authViewModel.isAuthenticated), hasOnboarding=\(authViewModel.hasCompletedOnboarding), isReOnboarding=\(authViewModel.isReonboardingMode), loading=\(appStateManager.shouldShowLoadingScreen)")

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
                    }
                    .sheet(isPresented: Binding(
                        get: { authViewModel.isReonboardingMode },
                        set: { newValue in
                            if !newValue {
                                // 當 sheet 關閉時，確保模式已關閉並重置狀態
                                authViewModel.isReonboardingMode = false
                                OnboardingCoordinator.shared.reset()
                            }
                        }
                    )) {
                        // Re-onboarding 使用 OnboardingContainerView，從 personalBest 步驟開始
                        OnboardingContainerView(isReonboarding: true)
                            .environmentObject(authViewModel)
                            .environmentObject(FeatureFlagManager.shared)
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
            // 移除 fullScreenCover 相關邏輯
        }
    }

    // 抽取主應用內容，方便管理
    @ViewBuilder
    private func mainAppContent() -> some View {
        // 從 HavitalApp.swift 遷移過來的 TabView
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
        .alert(L10n.ContentView.dataSourceRequired.localized, isPresented: $appViewModel.showDataSourceNotBoundAlert) {
            Button(L10n.ContentView.goToSettings.localized) {
                // TODO: 導航到設定頁面的數據源選擇
                appViewModel.showDataSourceNotBoundAlert = false
            }
            Button(L10n.ContentView.later.localized, role: .cancel) {
                appViewModel.showDataSourceNotBoundAlert = false
            }
        } message: {
            Text(L10n.ContentView.dataSourceRequiredMessage.localized)
        }
        .garminReconnectionAlert() // 添加 Garmin 重新連接警告
    }



    // MARK: - Training Version Routing

    /// 訓練計劃 Tab - 根據版本動態選擇 V1 或 V2
    @ViewBuilder
    private func trainingPlanTab() -> some View {
        if isCheckingVersion {
            // 正在檢查版本時顯示載入指示器
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if trainingVersion == "v2" {
            // V2 版本
            TrainingPlanV2View()
        } else {
            // V1 版本（預設）
            TrainingPlanView()
        }
    }

    /// 檢查訓練版本
    private func checkTrainingVersion() {
        Task {
            let container = DependencyContainer.shared

            // 確保 TrainingVersionRouter 已註冊
            if !container.isRegistered(TrainingVersionRouter.self) {
                container.registerTrainingVersionRouter()
            }

            let router: TrainingVersionRouter = container.resolve()
            let version = await router.getTrainingVersion()

            await MainActor.run {
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
