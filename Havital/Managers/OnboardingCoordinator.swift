import SwiftUI
import Combine

/// Onboarding 流程的統一協調器
/// 負責管理整個 onboarding 流程的狀態和導航
@MainActor
class OnboardingCoordinator: ObservableObject {
    static let shared = OnboardingCoordinator()

    /// Onboarding 步驟枚舉
    enum Step: Int, CaseIterable {
        case intro = 0
        case dataSource
        case heartRateZone
        case backfillPrompt
        case personalBest
        case weeklyDistance
        case goalType
        case raceSetup
        case startStage
        case trainingDays
        case trainingOverview
        case dataSync

        var title: String {
            switch self {
            case .intro: return "Welcome"
            case .dataSource: return "Data Source"
            case .heartRateZone: return "Heart Rate Zone"
            case .backfillPrompt: return "Backfill Prompt"
            case .personalBest: return "Personal Best"
            case .weeklyDistance: return "Weekly Distance"
            case .goalType: return "Goal Type"
            case .raceSetup: return "Race Setup"
            case .startStage: return "Start Stage"
            case .trainingDays: return "Training Days"
            case .trainingOverview: return "Training Overview"
            case .dataSync: return "Data Sync"
            }
        }
    }

    // MARK: - Published Properties

    /// 當前步驟的導航路徑
    @Published var navigationPath: [Step] = []

    /// 是否正在完成 onboarding
    @Published var isCompleting = false

    /// 錯誤訊息
    @Published var error: String?

    // MARK: - Flow Data (跨步驟共享的數據)

    /// 目標賽事距離
    @Published var targetDistance: Double = 21.0975

    /// 目標賽事 ID（如果選擇了已有賽事）
    @Published var selectedTargetId: String?

    /// 是否為新手 5km 計劃
    @Published var isBeginner: Bool = false

    /// 訓練計劃概覽（生成後暫存）
    @Published var trainingPlanOverview: TrainingPlanOverview?

    /// 選擇的起始階段
    @Published var selectedStartStage: String?

    /// 剩餘週數（用於起始階段選擇）
    @Published var weeksRemaining: Int = 12

    /// 是否為 re-onboarding 模式
    @Published var isReonboarding: Bool = false

    /// Re-onboarding 的起始步驟（用於判斷 Back 按鈕行為）
    private var reonboardingStartStep: Step?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 移除原有的監聽器，狀態重置將由 completeOnboarding 或 ContentView 的 sheet logic 統一處理
    }

    // MARK: - Navigation Methods

    /// 導航到下一步
    func navigate(to step: Step) {
        navigationPath.append(step)
        print("[OnboardingCoordinator] 導航到: \(step.title), 路徑深度: \(navigationPath.count)")
    }

    /// 返回上一步
    func goBack() {
        if !navigationPath.isEmpty {
            let removed = navigationPath.removeLast()
            print("[OnboardingCoordinator] 返回，移除: \(removed.title), 路徑深度: \(navigationPath.count)")
        }
    }

    /// 返回到根視圖
    func popToRoot() {
        navigationPath.removeAll()
        print("[OnboardingCoordinator] 返回根視圖")
    }

    // MARK: - Completion

    /// 完成 onboarding 流程
    func completeOnboarding() async {
        isCompleting = true
        error = nil

        do {
            // 生成第一週課表
            print("[OnboardingCoordinator] 開始生成第一週課表...")
            let _ = try await TrainingPlanService.shared.createWeeklyPlan(
                startFromStage: selectedStartStage,
                isBeginner: isBeginner
            )
            print("[OnboardingCoordinator] 第一週課表生成成功")

            if isReonboarding {
                // Re-onboarding: Just close the mode (this triggers sheet dismissal in ContentView)
                AuthenticationService.shared.isReonboardingMode = false
                navigationPath.removeAll()
                
                // ⚠️ 刷新畫面：發送通知讓 TrainingPlanView 等視圖更新資料
                NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                print("[OnboardingCoordinator] 發送 onboardingCompleted 通知以刷新畫面")
            } else {
                // New User Onboarding: Set global completion flags and reset the coordinator
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                AuthenticationService.shared.hasCompletedOnboarding = true
                
                // ⚠️ 刷新畫面
                NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                reset()
            }

        } catch {
            self.error = error.localizedDescription
            print("[OnboardingCoordinator] ❌ 完成 onboarding 失敗: \(error.localizedDescription)")
        }

        isCompleting = false
    }

    /// 重置所有狀態
    func reset() {
        navigationPath.removeAll()
        targetDistance = 21.0975
        selectedTargetId = nil
        isBeginner = false
        trainingPlanOverview = nil
        selectedStartStage = nil
        weeksRemaining = 12
        isCompleting = false
        error = nil
        isReonboarding = false
        reonboardingStartStep = nil
        print("[OnboardingCoordinator] 狀態已重置")
    }

    /// 開始 re-onboarding 流程
    func startReonboarding(from step: Step) {
        reset()
        isReonboarding = true
        reonboardingStartStep = step
        navigate(to: step)
        print("[OnboardingCoordinator] 開始 Re-onboarding，從 \(step.title) 開始")
    }

    // MARK: - Helper Methods

    /// 根據條件決定下一步
    func determineNextStep(from currentStep: Step) -> Step? {
        switch currentStep {
        case .intro:
            return .dataSource
        case .dataSource:
            return .heartRateZone
        case .heartRateZone:
            // 暫時跳過 backfillPrompt，直接進入 personalBest
            // return .backfillPrompt
            return .personalBest
        case .backfillPrompt:
            return .personalBest
        case .dataSync:
            return .personalBest
        case .personalBest:
            return .weeklyDistance
        case .weeklyDistance:
            return .goalType
        case .goalType:
            // 注意：GoalTypeSelectionView 會處理選擇邏輯
            // 如果選 5km，它會直接 navigate 到 .trainingDays (beginner)
            // 如果選 Specific Race，它會 navigate 到 .raceSetup
            return nil 
        case .raceSetup:
            // OnboardingView 會處理邏輯決定去 .startStage 還是 .trainingDays
            return nil
        case .startStage:
            return .trainingDays
        case .trainingDays:
            return .trainingOverview
        case .trainingOverview:
            return nil // 最後一步，完成後調用 completeOnboarding()
        }
    }

    /// 根據資料來源和現有數據決定是否需要顯示 Backfill 提示並執行導航
    func navigateFromHeartRateZone() async {
        // 暫時跳過 backfillPrompt，由流程中拿掉，之後再 debug
        /*
        let dataSource = UserPreferencesManager.shared.dataSourcePreference
        let shouldShow = await OnboardingBackfillCoordinator.shared.shouldShowBackfillPrompt(dataSource: dataSource)

        if shouldShow {
            navigate(to: .backfillPrompt)
        } else {
            navigate(to: .personalBest)
        }
        */
        navigate(to: .personalBest)
    }
}
