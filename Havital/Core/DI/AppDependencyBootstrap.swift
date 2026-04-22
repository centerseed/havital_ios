import Foundation

// MARK: - App Dependency Bootstrap
/// 集中管理所有模組的 DI 註冊
/// 確保依賴以正確的順序初始化
struct AppDependencyBootstrap {

    // MARK: - Bootstrap All Modules

    /// 註冊所有模組依賴
    /// 呼叫順序: Core → Domain → Feature
    static func registerAllModules() {
        Logger.debug("[Bootstrap] 開始註冊所有模組依賴")

        // Step 1: Core Layer (已在 DependencyContainer.init() 自動註冊)
        // - HTTPClient
        // - APIParser

        // Step 2: Analytics (early — singletons use lazy resolve, but register before any tracking)
        registerAnalyticsModule()

        // Step 3: Feature Modules (按依賴順序註冊)
        registerFeatureModules()

        Logger.debug("[Bootstrap] ✅ 所有模組依賴註冊完成")
    }

    // MARK: - Feature Modules Registration

    /// 註冊所有功能模組
    private static func registerFeatureModules() {
        // 1. Authentication 模組 (核心，無外部依賴)
        registerAuthenticationModule()

        // 2. Workout 模組 (基礎數據，無外部依賴)
        registerWorkoutModule()

        // 3. MonthlyStats 模組 (獨立模組，用於訓練日曆)
        registerMonthlyStatsModule()

        // 4. UserProfile 模組 (依賴 Workout)
        registerUserProfileModule()

        // 5. Target 模組 (獨立模組)
        registerTargetModule()

        // 5.5 TrainingVersionRouter (依賴 UserProfile)
        // 必須在 V1 模組前註冊，因為 V1RepositoryGuardDecorator 需要 router
        registerTrainingVersionRouterModule()

        // 6. TrainingPlan V1 模組 (依賴 Workout, Target, TrainingVersionRouter)
        registerTrainingPlanModule()

        // 7. TrainingPlanV2 模組 (依賴 UserProfile)
        registerTrainingPlanV2Module()

        // 8. Subscription 模組 (Authentication 之後)
        registerSubscriptionModule()

        // 9. Announcement 模組 (獨立模組)
        registerAnnouncementModule()

        // 10. Race 模組 (獨立模組，目標編輯與 onboarding 共用)
        registerRaceModule()
    }

    // MARK: - Individual Module Registration

    /// 註冊 Authentication 模組
    /// 包含: AuthRepository, AuthSessionRepository, OnboardingRepository, DataSources, Cache
    private static func registerAuthenticationModule() {
        guard !DependencyContainer.shared.isRegistered(AuthRepository.self) else {
            Logger.debug("[Bootstrap] Authentication module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerAuthDependencies()
        Logger.debug("[Bootstrap] ✅ Authentication module registered")
    }

    /// 註冊 Workout 模組
    /// 包含: WorkoutRepository, WorkoutLocalDataSource, WorkoutRemoteDataSource
    private static func registerWorkoutModule() {
        guard !DependencyContainer.shared.isRegistered(WorkoutRepository.self) else {
            Logger.debug("[Bootstrap] Workout module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerWorkoutModule()
        Logger.debug("[Bootstrap] ✅ Workout module registered")
    }

    /// 註冊 MonthlyStats 模組
    /// 包含: MonthlyStatsRepository, MonthlyStatsLocalDataSource, MonthlyStatsRemoteDataSource
    private static func registerMonthlyStatsModule() {
        guard !DependencyContainer.shared.isRegistered(MonthlyStatsRepository.self) else {
            Logger.debug("[Bootstrap] MonthlyStats module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerMonthlyStatsModule()
        Logger.debug("[Bootstrap] ✅ MonthlyStats module registered")
    }

    /// 註冊 UserProfile 模組
    /// 包含: UserProfileRepository, DataSources, UseCases
    private static func registerUserProfileModule() {
        guard !DependencyContainer.shared.isRegistered(UserProfileRepository.self) else {
            Logger.debug("[Bootstrap] UserProfile module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerUserProfileModule()
        Logger.debug("[Bootstrap] ✅ UserProfile module registered")
    }

    /// 註冊 Target 模組
    /// 包含: TargetRepository, DataSources, UseCases
    private static func registerTargetModule() {
        guard !DependencyContainer.shared.isRegistered(TargetRepository.self) else {
            Logger.debug("[Bootstrap] Target module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerTargetModule()
        Logger.debug("[Bootstrap] ✅ Target module registered")
    }

    /// 註冊 TrainingVersionRouter（早註冊）
    /// 必須在 V1 模組前，讓 V1RepositoryGuardDecorator 可解析 router
    private static func registerTrainingVersionRouterModule() {
        guard !DependencyContainer.shared.isRegistered(TrainingVersionRouter.self) else {
            Logger.debug("[Bootstrap] TrainingVersionRouter already registered, skipping")
            return
        }

        DependencyContainer.shared.registerTrainingVersionRouter()
        Logger.debug("[Bootstrap] ✅ TrainingVersionRouter registered (early)")
    }

    /// 註冊 TrainingPlan V1 模組
    /// 包含: TrainingPlanRepository, DataSources, UseCases
    private static func registerTrainingPlanModule() {
        guard !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) else {
            Logger.debug("[Bootstrap] TrainingPlan V1 module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerTrainingPlanDependencies()
        Logger.debug("[Bootstrap] ✅ TrainingPlan V1 module registered")
    }

    /// 註冊 TrainingPlanV2 模組
    /// 包含: TrainingPlanV2Repository, DataSources, TrainingVersionRouter
    private static func registerTrainingPlanV2Module() {
        guard !DependencyContainer.shared.isRegistered(TrainingPlanV2Repository.self) else {
            Logger.debug("[Bootstrap] TrainingPlanV2 module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerTrainingPlanV2Dependencies()
        Logger.debug("[Bootstrap] ✅ TrainingPlanV2 module registered")
    }

    /// 註冊 Subscription 模組
    /// 包含: SubscriptionRepository, DataSources
    private static func registerSubscriptionModule() {
        guard !DependencyContainer.shared.isRegistered(SubscriptionRepository.self) else {
            Logger.debug("[Bootstrap] Subscription module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerSubscriptionModule()
        Logger.debug("[Bootstrap] ✅ Subscription module registered")
    }

    // MARK: - Analytics Module Registration

    /// 註冊 Analytics 模組
    private static func registerAnalyticsModule() {
        guard !DependencyContainer.shared.isRegistered(AnalyticsService.self) else {
            Logger.debug("[Bootstrap] Analytics module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerAnalyticsModule()
        Logger.debug("[Bootstrap] ✅ Analytics module registered")
    }

    /// 註冊 Announcement 模組
    /// 包含: AnnouncementRepository, AnnouncementRemoteDataSource
    private static func registerAnnouncementModule() {
        guard !DependencyContainer.shared.isRegistered(AnnouncementRepository.self) else {
            Logger.debug("[Bootstrap] Announcement module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerAnnouncementModule()
        Logger.debug("[Bootstrap] ✅ Announcement module registered")
    }

    /// 註冊 Race 模組
    /// 包含: RaceRepository, RaceRemoteDataSource
    /// 目標編輯 (EditTarget/AddSupportingTarget) 與 Onboarding race picker 共用
    private static func registerRaceModule() {
        guard !DependencyContainer.shared.isRegistered(RaceRepository.self) else {
            Logger.debug("[Bootstrap] Race module already registered, skipping")
            return
        }

        DependencyContainer.shared.registerRaceModule()
        Logger.debug("[Bootstrap] ✅ Race module registered")
    }

    // MARK: - Testing Support

    /// 重置所有依賴並重新註冊（僅用於測試）
    static func resetForTesting() {
        Logger.debug("[Bootstrap] Resetting DI container for testing")

        DependencyContainer.shared.reset()
        registerAllModules()

        Logger.debug("[Bootstrap] ✅ DI container reset complete")
    }
}
