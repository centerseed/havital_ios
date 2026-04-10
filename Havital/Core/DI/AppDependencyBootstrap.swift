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

        // Step 2: Feature Modules (按依賴順序註冊)
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

        // 6. TrainingPlan V1 模組 (依賴 Workout, Target)
        registerTrainingPlanModule()

        // 7. TrainingPlanV2 模組 (依賴 UserProfile)
        registerTrainingPlanV2Module()

        // 8. Subscription 模組 (Authentication 之後)
        registerSubscriptionModule()
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

    // MARK: - Testing Support

    /// 重置所有依賴並重新註冊（僅用於測試）
    static func resetForTesting() {
        Logger.debug("[Bootstrap] Resetting DI container for testing")

        DependencyContainer.shared.reset()
        registerAllModules()

        Logger.debug("[Bootstrap] ✅ DI container reset complete")
    }
}
