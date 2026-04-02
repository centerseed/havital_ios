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
        case methodologySelection
        case trainingWeeksSetup
        case maintenanceRaceDistance
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
            case .methodologySelection: return NSLocalizedString("onboarding.methodology_nav_title", comment: "Training Methodology")
            case .trainingWeeksSetup: return NSLocalizedString("onboarding.training_weeks_nav_title", comment: "Training Duration")
            case .maintenanceRaceDistance: return "目標賽事"
            case .trainingDays: return "Training Days"
            case .trainingOverview: return "Training Overview"
            case .dataSync: return "Data Sync"
            }
        }
    }

    // MARK: - Constants

    static let startStageUserDefaultsKey = "selectedStartStage"

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

    /// 訓練計劃概覽（生成後暫存）- V1
    @Published var trainingPlanOverview: TrainingPlanOverview?

    /// 訓練計劃概覽（生成後暫存）- V2
    @Published var trainingPlanOverviewV2: PlanOverviewV2?

    /// 選擇的起始階段
    @Published var selectedStartStage: String?

    /// 選擇的目標類型 ID（用於方法論選擇）
    @Published var selectedTargetTypeId: String?

    /// 選擇的方法論 ID（V2 流程）
    @Published var selectedMethodologyId: String?

    /// 訓練週數（V2 流程，非賽事目標使用）
    @Published var trainingWeeks: Int?

    /// 預期目標賽事距離（maintenance 流程使用，單位 km，nil 表示不確定）
    @Published var intendedRaceDistanceKm: Int?

    /// 每週可訓練天數（V2 流程）
    @Published var availableDays: Int?

    /// 剩餘週數（用於起始階段選擇）
    @Published var weeksRemaining: Int = 12

    /// Race V2 流程：方法論選擇後是否需要先進入起始階段選擇
    @Published var shouldNavigateToStartStageAfterMethodology: Bool = false

    /// 是否為 re-onboarding 模式
    @Published var isReonboarding: Bool = false

    /// Re-onboarding 的起始步驟（用於判斷 Back 按鈕行為）
    private var reonboardingStartStep: Step?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    /// ✅ Clean Architecture: Use Case for completing onboarding
    private lazy var completeOnboardingUseCase: CompleteOnboardingUseCase = {
        DependencyContainer.shared.makeCompleteOnboardingUseCase()
    }()

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
    /// ✅ Clean Architecture: 使用 CompleteOnboardingUseCase 執行完成流程
    /// 支持 V1 (legacy) 和 V2 (new) 訓練計畫 API
    func completeOnboarding() async {
        isCompleting = true
        error = nil

        do {
            // ✅ Clean Architecture: 使用 UseCase 執行完成流程
            print("[OnboardingCoordinator] 開始執行 CompleteOnboardingUseCase...")

            // ✅ 直接從 AuthenticationViewModel 讀取 isReonboardingMode
            // 這是唯一的狀態源，不需要在 Coordinator 維護重複狀態
            let isReonboardingMode = AuthenticationViewModel.shared.isReonboardingMode

            // 判斷是否為 V2 流程
            let isV2Flow = selectedTargetTypeId != nil
            print("[OnboardingCoordinator] - isV2Flow: \(isV2Flow)")
            print("[OnboardingCoordinator] - targetTypeId: \(selectedTargetTypeId ?? "nil")")
            print("[OnboardingCoordinator] - methodologyId: \(selectedMethodologyId ?? "nil")")
            print("[OnboardingCoordinator] - targetId: \(selectedTargetId ?? "nil")")

            // V2 weekly generation should align with the created overview to avoid context mismatch.
            let resolvedMethodologyId = trainingPlanOverviewV2?.methodologyId ?? selectedMethodologyId
            if let overviewMethodologyId = trainingPlanOverviewV2?.methodologyId,
               let selectedMethodologyId,
               overviewMethodologyId != selectedMethodologyId {
                Logger.warn("[OnboardingCoordinator] Methodology mismatch detected. Using overview methodology: \(overviewMethodologyId), selected: \(selectedMethodologyId)")
            }

            let effectiveStartStage = selectedTargetTypeId == "race_run" ? selectedStartStage : nil
            let input = CompleteOnboardingUseCase.Input(
                startFromStage: effectiveStartStage,
                isBeginner: isBeginner,
                isReonboarding: isReonboardingMode,
                // V2 Parameters
                targetTypeId: selectedTargetTypeId,
                targetId: selectedTargetId,
                methodologyId: resolvedMethodologyId,
                trainingWeeks: trainingWeeks,
                availableDays: availableDays
            )

            let output = try await completeOnboardingUseCase.execute(input: input)

            print("[OnboardingCoordinator] ✅ CompleteOnboardingUseCase 執行成功")
            if output.usedV2API {
                print("[OnboardingCoordinator] - 使用 V2 API")
                print("[OnboardingCoordinator] - 創建的 V2 週計畫 ID: \(output.weeklyPlanV2?.id ?? "nil")")
            } else {
                print("[OnboardingCoordinator] - 使用 V1 API")
                print("[OnboardingCoordinator] - 創建的 V1 週計畫 ID: \(output.weeklyPlan?.id ?? "nil")")
            }

            // 關閉 loading 動畫
            isCompleting = false
            print("[OnboardingCoordinator] Loading 動畫已關閉")

            // 清理 UI 狀態
            if output.wasReonboarding {
                // Re-onboarding 模式：關閉 sheet 並通知所有訂閱者刷新資料
                print("[OnboardingCoordinator] Re-onboarding 完成，關閉 sheet 並發布 onboardingCompleted 事件")
                AuthenticationViewModel.shared.isReonboardingMode = false
                CacheEventBus.shared.publish(.onboardingCompleted)
            } else {
                // 新用戶 onboarding：重置所有狀態並發布事件
                reset()
                print("[OnboardingCoordinator] 新用戶 onboarding 完成，發布 onboardingCompleted 事件")
                CacheEventBus.shared.publish(.onboardingCompleted)
            }

        } catch is CancellationError {
            isCompleting = false
        } catch let onboardingError as OnboardingError {
            self.error = onboardingError.localizedDescription
            self.isCompleting = false
            print("[OnboardingCoordinator] ❌ OnboardingError: \(onboardingError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.isCompleting = false
            print("[OnboardingCoordinator] ❌ 完成 onboarding 失敗: \(error.localizedDescription)")
        }
    }

    /// 重置所有狀態
    func reset() {
        navigationPath.removeAll()
        targetDistance = 21.0975
        selectedTargetId = nil
        isBeginner = false
        trainingPlanOverview = nil
        trainingPlanOverviewV2 = nil
        selectedStartStage = nil
        UserDefaults.standard.removeObject(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
        selectedTargetTypeId = nil
        selectedMethodologyId = nil
        trainingWeeks = nil
        intendedRaceDistanceKm = nil
        availableDays = nil
        weeksRemaining = 12
        shouldNavigateToStartStageAfterMethodology = false
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
        case .methodologySelection:
            // MethodologySelectionView 會處理導航邏輯
            return nil
        case .trainingWeeksSetup:
            // TrainingWeeksSetupView 會處理導航邏輯（根據方法論數量決定）
            return nil
        case .maintenanceRaceDistance:
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
