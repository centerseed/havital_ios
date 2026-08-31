import Combine
import Foundation

// MARK: - CacheRegistrationCoordinator
/// App-layer composition root for CacheEventBus registrations.
///
/// Architecture rationale:
/// - Data/Domain objects must NOT call CacheEventBus.shared.register/subscribe in their
///   own init — that couples inner layers to the bus and violates the inward-only
///   dependency rule.
/// - This coordinator lives in Core/DI (App layer) and wires all registrations in one
///   place, called exactly once during app startup (from AppDependencyBootstrap).
///
/// Execution guarantee:
/// - registerAll() is called inside AppDependencyBootstrap.registerAllModules(), which
///   is invoked in HavitalApp.init() before any StateObject or ViewModel is created,
///   and before any CacheEventBus invalidation event can be fired (no user interaction
///   is possible during init). This ensures registrations happen before any cache-clear
///   event reaches the bus.
///
/// LocalDataSource instances created here are dedicated coordinator-owned instances
/// used solely for cache invalidation. The bus uses cacheIdentifier for deduplication,
/// so concurrent instances in RepositoryImpl share the same identifier and the bus
/// forwards clearCache() to whichever was registered first (always this coordinator's
/// instance, since registerAll() runs before any RepositoryImpl is resolved).
enum CacheRegistrationCoordinator {

    // MARK: - Coordinator-owned instances (retained for the app lifetime)
    // These are separate from the instances held by RepositoryImpl; the bus deduplicates
    // by cacheIdentifier so only this coordinator's instance receives clearCache() calls.

    private static let subscriptionLocalDS = SubscriptionLocalDataSource()
    private static let targetLocalDS = TargetLocalDataSource()
    private static let trainingPlanV2LocalDS = TrainingPlanV2LocalDataSource()
    private static let userProfileLocalDS = UserProfileLocalDataSource()

    private static var hasRegistered = false
    private static var cancellables = Set<AnyCancellable>()

    // MARK: - Entry point

    /// Register all Data/Domain cacheables and subscriptions with CacheEventBus.
    /// Idempotent: safe to call more than once (e.g. from test resets), but only the
    /// first call performs work.
    static func registerAll() {
        guard !hasRegistered else {
            Logger.debug("[CacheRegistrationCoordinator] Already registered — skipping")
            return
        }
        hasRegistered = true

        // 1. Register LocalDataSource cacheables
        CacheEventBus.shared.register(subscriptionLocalDS)
        CacheEventBus.shared.register(targetLocalDS)
        CacheEventBus.shared.register(trainingPlanV2LocalDS)
        CacheEventBus.shared.register(userProfileLocalDS)

        // 2. Register VDOTManager singleton (has in-memory state — must use .shared)
        CacheEventBus.shared.register(VDOTManager.shared)

        // 3. Wire SubscriptionStateManager logout reset via identifier-based subscription.
        // Task { @MainActor in } is required: the bus calls handlers on an arbitrary thread,
        // but SubscriptionStateManager is @MainActor.
        CacheEventBus.shared.subscribe(forIdentifier: "SubscriptionStateManager") { reason in
            if case .userLogout = reason {
                Task { @MainActor in
                    SubscriptionStateManager.shared.applyLogoutReset()
                }
            }
        }

        // 4. 2.0 冷啟快照（`App2FileSnapshotStore`）的失效。
        //
        // **刻意不註冊成 `Cacheable`。** `invalidateAllCaches()` 會被
        // `.dataChanged(.user)` 帶到，而那條事件每次啟動 auth 狀態變化就會發 ——
        // 註冊進去等於每次冷啟前先把快照清光，這支功能就沒有了
        // （這正是 `CacheEventBus` 為 `TrainingPlanV2LocalDataSource` 開 preserved
        // 名單的同一個坑）。這裡逐事件明列要清哪幾個 key。
        CacheEventBus.shared.subscribe(forIdentifier: "App2FileSnapshotStore") { reason in
            let keys: Set<App2SnapshotKey>
            switch reason {
            case .userLogout, .manualClear, .onboardingCompleted, .reonboardingCompleted:
                // 登出／換帳號／首次或重新完成目標設定：全清。
                // 重設目標實際發的是 `.reonboardingCompleted`（`OnboardingCoordinator`），
                // 舊註解以為它共用 `.onboardingCompleted`——漏在名單外＝重設完快照不清，
                // 首頁目標卡要重開 app 才換（2026-08-28 用戶實機回報）。
                keys = Set(App2SnapshotKey.allCases)
            case .dataChanged(.targets):
                // 目標變更會重生課表與狀態敘事，整組都不能再用。
                keys = Set(App2SnapshotKey.allCases)
            case .dataChanged(.trainingPlanV2), .dataChanged(.trainingPlan):
                // 課表存檔（`EditScheduleV2ViewModel.saveEdits()` 成功後發這條）。
                // **這裡已經沒有課表的快照可清**（2026-08-26 架構收斂：plan status／週課表
                // 回到 `TrainingPlanV2LocalDataSource`），而那一份由存檔路徑本身
                // （`TrainingPlanV2Repository.updateWeeklyPlan` 寫回快取）就地更新，
                // 不靠這條事件失效。
                return
            case .dataChanged(.workouts):
                keys = [.recentWorkouts, .homeRecentWorkouts, .workoutStats, .stateToday]
            default:
                return
            }
            App2FileSnapshotStore.shared.invalidate(keys)
        }

        // 5. workout 推播抵達 → 失效 workout 快取（T-0355）。推播＝後端資料已就緒，
        // 沒這條時用戶收到推播、畫面停在舊清單，要重開 app 才更新（2026-08-31 實機）。
        // domain 只發事實（Combine publisher），bus 的 publish 收在這個 composition root。
        WorkoutBackgroundManager.shared.workoutPushReceived
            .sink { CacheEventBus.shared.publish(.dataChanged(.workouts)) }
            .store(in: &cancellables)

        // 6. 指標詳情 session 快取（T-0357）。指標全部從 workouts／health 導出，
        // 相關事件一律全清（session 級、重抓便宜，不做逐 key 精算）。
        CacheEventBus.shared.subscribe(forIdentifier: "App2MetricDetailCache") { reason in
            switch reason {
            case .userLogout, .manualClear, .onboardingCompleted, .reonboardingCompleted,
                 .dataChanged(.workouts), .dataChanged(.user), .dataChanged(.targets),
                 .dataChanged(.healthData), .dataChanged(.hrv), .dataChanged(.vdot):
                Task { @MainActor in
                    App2MetricDetailCache.shared.removeAll()
                }
            default:
                break
            }
        }

        Logger.debug("[CacheRegistrationCoordinator] All cache registrations complete")
    }

    /// Reset registration state for test environments that call registerAllModules() again.
    static func resetForTesting() {
        hasRegistered = false
    }
}
