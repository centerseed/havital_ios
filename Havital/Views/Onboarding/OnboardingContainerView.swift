import SwiftUI

/// Onboarding 流程的統一容器視圖
/// 使用 NavigationStack 管理整個 onboarding 流程的導航
struct OnboardingContainerView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel
    @StateObject private var userProfileViewModel = UserProfileFeatureViewModel()
    @StateObject private var viewModel: OnboardingFeatureViewModel

    // 從外部傳入模式，確保初始化時就能決定正確的根視圖，避免 Race Condition
    let isReonboarding: Bool

    init(isReonboarding: Bool) {
        self.isReonboarding = isReonboarding
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            Group {
                if isReonboarding {
                    // Re-onboarding: PersonalBest 作為根視圖
                    PersonalBestView(targetDistance: coordinator.targetDistance)
                } else {
                    // 正常 onboarding: Intro 作為根視圖
                    OnboardingIntroView()
                }
            }
            .navigationDestination(for: OnboardingCoordinator.Step.self) { step in
                destinationView(for: step)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Progress bar pinned below the navigation bar, full-width, 4pt tall.
                // Wrapped in a VStack so the safeAreaInset has a defined size.
                VStack(spacing: 0) {
                    OnboardingProgressBar(progress: coordinator.currentProgress)
                }
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            coordinator.trackOnboardingStart()
        }
        .fullScreenCover(isPresented: $coordinator.isCompleting) {
            LoadingAnimationView(messages: [
                NSLocalizedString("onboarding.analyzing_preferences", comment: "正在分析您的訓練偏好"),
                NSLocalizedString("onboarding.calculating_intensity", comment: "計算最佳訓練強度中"),
                NSLocalizedString("onboarding.almost_ready", comment: "就要完成了！正在為您準備專屬課表")
            ], totalDuration: 20)
        }
        .alert(NSLocalizedString("common.error", comment: "Error"), isPresented: .constant(coordinator.error != nil)) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
                coordinator.error = nil
            }
        } message: {
            if let error = coordinator.error {
                Text(error)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingCoordinator.Step) -> some View {
        switch step {
        case .intro:
            OnboardingIntroView()
        case .dataSource:
            DataSourceSelectionView()
        case .heartRateZone:
            HeartRateZoneInfoView(mode: .onboarding(targetDistance: coordinator.targetDistance))
        case .backfillPrompt:
            BackfillPromptContentView(
                dataSource: userProfileViewModel.currentDataSource,
                targetDistance: coordinator.targetDistance
            )
        case .personalBest:
            PersonalBestView(targetDistance: coordinator.targetDistance)
        case .weeklyDistance:
            WeeklyDistanceSetupView(targetDistance: coordinator.targetDistance)
        case .goalType:
            GoalTypeSelectionView()
        case .raceSetup:
            OnboardingView()
        case .raceEventList:
            RaceEventListView(dataSource: viewModel)
        case .startStage:
            StartStageSelectionView(
                weeksRemaining: coordinator.weeksRemaining,
                targetDistanceKm: coordinator.targetDistance
            )
        case .methodologySelection:
            MethodologySelectionView()
        case .trainingWeeksSetup:
            TrainingWeeksSetupView()
        case .maintenanceRaceDistance:
            MaintenanceRaceDistanceView()
        case .trainingDays:
            TrainingDaysSetupView(isBeginner: coordinator.isBeginner)
        case .trainingOverview:
            TrainingOverviewView(
                mode: .preview,
                trainingOverview: coordinator.trainingPlanOverview,
                isBeginner: coordinator.isBeginner
            )
        case .dataSync:
            DataSyncView(
                dataSource: userProfileViewModel.currentDataSource,
                mode: .onboarding,
                onboardingTargetDistance: coordinator.targetDistance
            )
        }
    }
}
