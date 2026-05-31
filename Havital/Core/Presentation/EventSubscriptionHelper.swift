import Foundation

// MARK: - Event Subscription Helper
/// Unified helper for CacheEventBus subscriptions in ViewModels.
///
/// This helper consolidates the repetitive event subscription patterns found across ViewModels:
/// - TrainingPlanViewModel
/// - WeeklyPlanViewModel
/// - WorkoutListViewModel
/// - AuthenticationViewModel
///
/// ## Common Subscription Patterns
///
/// 1. **userLogout**: Clear cache and reset state
/// 2. **onboardingCompleted**: Clear cache and reload fresh data
/// 3. **dataChanged.X**: Refresh specific data
///
/// ## Usage
///
/// ```swift
/// // In ViewModel setupBindings():
/// EventSubscriptionHelper.subscribeToUserLogout(viewModelName: "TrainingPlanVM") { [weak self] in
///     await self?.repository.clearCache()
///     self?.state = .loading
/// }
///
/// EventSubscriptionHelper.subscribeToDataChanged(
///     dataType: .workouts,
///     viewModelName: "WorkoutListVM"
/// ) { [weak self] in
///     await self?.refreshFromCache()
/// }
/// ```
enum EventSubscriptionHelper {

    // MARK: - Standard Event Subscriptions

    /// Subscribe to userLogout event.
    ///
    /// This is the standard pattern for handling user logout:
    /// - Clear repository cache
    /// - Reset ViewModel state
    ///
    /// - Parameters:
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribeToUserLogout(
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: .userLogout) {
            Logger.debug("[\(viewModelName)] Received userLogout event")
            await handler()
            Logger.debug("[\(viewModelName)] userLogout event handled")
        }
    }

    /// Subscribe to onboardingCompleted event.
    ///
    /// This is the standard pattern for handling onboarding completion:
    /// - Clear all cache
    /// - Force reload from API
    ///
    /// - Parameters:
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribeToOnboardingCompleted(
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: .onboardingCompleted) {
            Logger.debug("[\(viewModelName)] Received onboardingCompleted event")
            await handler()
            Logger.debug("[\(viewModelName)] onboardingCompleted event handled")
        }
    }

    /// Subscribe to dataChanged event for specific data type.
    ///
    /// - Parameters:
    ///   - dataType: The DataType to listen for (e.g., .workouts, .trainingPlan).
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribeToDataChanged(
        dataType: DataType,
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: .dataChanged(dataType)) {
            Logger.debug("[\(viewModelName)] Received dataChanged.\(dataType) event")
            await handler()
            Logger.debug("[\(viewModelName)] dataChanged.\(dataType) event handled")
        }
    }

    /// Subscribe to reonboardingCompleted event.
    ///
    /// - Parameters:
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribeToReonboardingCompleted(
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: .reonboardingCompleted) {
            Logger.debug("[\(viewModelName)] Received reonboardingCompleted event")
            await handler()
            Logger.debug("[\(viewModelName)] reonboardingCompleted event handled")
        }
    }

    // MARK: - Generic Subscription

    /// Subscribe to any event with standardized logging.
    ///
    /// - Parameters:
    ///   - reason: 事件 enum（編譯期強制配對）。
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribe(
        for reason: CacheInvalidationReason,
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: reason) {
            Logger.debug("[\(viewModelName)] Received \(String(describing: reason)) event")
            await handler()
            Logger.debug("[\(viewModelName)] \(String(describing: reason)) event handled")
        }
    }

}
