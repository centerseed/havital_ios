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

        Logger.debug("[CacheRegistrationCoordinator] All cache registrations complete")
    }

    /// Reset registration state for test environments that call registerAllModules() again.
    static func resetForTesting() {
        hasRegistered = false
    }
}
