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
        CacheEventBus.shared.subscribe(for: "userLogout") {
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
        CacheEventBus.shared.subscribe(for: "onboardingCompleted") {
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
        let eventKey = "dataChanged.\(dataType)"
        CacheEventBus.shared.subscribe(for: eventKey) {
            Logger.debug("[\(viewModelName)] Received \(eventKey) event")
            await handler()
            Logger.debug("[\(viewModelName)] \(eventKey) event handled")
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
        CacheEventBus.shared.subscribe(for: "reonboardingCompleted") {
            Logger.debug("[\(viewModelName)] Received reonboardingCompleted event")
            await handler()
            Logger.debug("[\(viewModelName)] reonboardingCompleted event handled")
        }
    }

    // MARK: - Generic Subscription

    /// Subscribe to any event with standardized logging.
    ///
    /// - Parameters:
    ///   - eventKey: Event key string (e.g., "targetUpdated").
    ///   - viewModelName: Name for logging purposes.
    ///   - handler: Async handler to execute.
    static func subscribe(
        for eventKey: String,
        viewModelName: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        CacheEventBus.shared.subscribe(for: eventKey) {
            Logger.debug("[\(viewModelName)] Received \(eventKey) event")
            await handler()
            Logger.debug("[\(viewModelName)] \(eventKey) event handled")
        }
    }

    // MARK: - Batch Subscription

    /// Subscribe to multiple events at once.
    ///
    /// This is useful for ViewModels that need to listen to many events.
    ///
    /// - Parameters:
    ///   - subscriptions: Array of (eventKey, handler) tuples.
    ///   - viewModelName: Name for logging purposes.
    static func subscribeToAll(
        _ subscriptions: [(eventKey: String, handler: @MainActor () async -> Void)],
        viewModelName: String
    ) {
        for subscription in subscriptions {
            subscribe(
                for: subscription.eventKey,
                viewModelName: viewModelName,
                handler: subscription.handler
            )
        }
    }

    // MARK: - Standard ViewModel Event Setup

    /// Setup standard event subscriptions for a typical ViewModel.
    ///
    /// This sets up the most common subscriptions:
    /// - userLogout: Clear cache and reset state
    /// - dataChanged for specific type: Refresh data
    ///
    /// - Parameters:
    ///   - viewModelName: Name for logging purposes.
    ///   - dataType: Optional DataType for dataChanged events.
    ///   - clearCache: Handler to clear cache (called on logout/onboarding).
    ///   - resetState: Handler to reset UI state (called on logout).
    ///   - refreshData: Handler to refresh data (called on dataChanged).
    static func setupStandardSubscriptions(
        viewModelName: String,
        dataType: DataType? = nil,
        clearCache: @escaping @MainActor () async -> Void,
        resetState: @escaping @MainActor () -> Void,
        refreshData: @escaping @MainActor () async -> Void
    ) {
        // User logout - clear cache and reset state
        subscribeToUserLogout(viewModelName: viewModelName) {
            await clearCache()
            resetState()
        }

        // Onboarding completed - clear cache and refresh
        subscribeToOnboardingCompleted(viewModelName: viewModelName) {
            await clearCache()
            await refreshData()
        }

        // Data changed - refresh data
        if let dataType = dataType {
            subscribeToDataChanged(dataType: dataType, viewModelName: viewModelName) {
                await refreshData()
            }
        }
    }
}

// MARK: - ViewModel Event Subscription Protocol

/// Protocol for ViewModels that use standardized event subscriptions.
///
/// Provides a consistent interface for setting up event subscriptions.
///
/// Usage:
/// ```swift
/// class MyViewModel: EventSubscribable {
///     var viewModelName: String { "MyVM" }
///
///     func setupEventSubscriptions() {
///         subscribeToUserLogout { [weak self] in
///             await self?.clearCache()
///         }
///     }
/// }
/// ```
protocol EventSubscribable {
    /// Name of the ViewModel for logging purposes.
    var viewModelName: String { get }
}

extension EventSubscribable {

    /// Subscribe to userLogout event with automatic logging.
    func subscribeToUserLogout(handler: @escaping @MainActor () async -> Void) {
        EventSubscriptionHelper.subscribeToUserLogout(
            viewModelName: viewModelName,
            handler: handler
        )
    }

    /// Subscribe to onboardingCompleted event with automatic logging.
    func subscribeToOnboardingCompleted(handler: @escaping @MainActor () async -> Void) {
        EventSubscriptionHelper.subscribeToOnboardingCompleted(
            viewModelName: viewModelName,
            handler: handler
        )
    }

    /// Subscribe to dataChanged event with automatic logging.
    func subscribeToDataChanged(
        dataType: DataType,
        handler: @escaping @MainActor () async -> Void
    ) {
        EventSubscriptionHelper.subscribeToDataChanged(
            dataType: dataType,
            viewModelName: viewModelName,
            handler: handler
        )
    }

    /// Subscribe to any event with automatic logging.
    func subscribeToEvent(
        _ eventKey: String,
        handler: @escaping @MainActor () async -> Void
    ) {
        EventSubscriptionHelper.subscribe(
            for: eventKey,
            viewModelName: viewModelName,
            handler: handler
        )
    }
}
