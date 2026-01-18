import Foundation

// MARK: - ViewModel Data Loader
/// Unified helper for data loading operations in ViewModels.
///
/// This helper consolidates the repetitive data loading patterns found across ViewModels:
/// - TrainingPlanViewModel
/// - WorkoutListViewModel
/// - TargetFeatureViewModel
/// - UserProfileFeatureViewModel
///
/// ## Features
///
/// - **Automatic cancellation handling**: Filters out cancellation errors
/// - **ViewState management**: Updates ViewState enum properly
/// - **Loading state management**: Shows loading only when no cached data
/// - **Error mapping**: Converts errors to DomainError
///
/// ## Usage
///
/// ```swift
/// // In ViewModel:
/// @Published var state: ViewState<[Target]> = .loading
///
/// func loadTargets() async {
///     await ViewModelDataLoader.load(
///         state: &state,
///         fetch: { try await repository.getTargets() }
///     )
/// }
/// ```
enum ViewModelDataLoader {

    // MARK: - Basic Load

    /// Load data and update ViewState.
    ///
    /// - Parameters:
    ///   - state: Reference to the ViewState to update.
    ///   - showLoading: Whether to show loading state (default: true).
    ///   - fetch: Async closure to fetch data.
    ///   - onSuccess: Optional callback on successful load.
    ///   - onError: Optional callback on error (after cancellation filtering).
    @MainActor
    static func load<T>(
        state: inout ViewState<T>,
        showLoading: Bool = true,
        fetch: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((DomainError) -> Void)? = nil
    ) async {
        if showLoading {
            state = .loading
        }

        do {
            let data = try await fetch()
            state = .loaded(data)
            onSuccess?(data)
        } catch {
            // Filter cancellation errors
            if error.isCancellationError {
                Logger.debug("[ViewModelDataLoader] Task cancelled, ignoring")
                return
            }

            let domainError = error.toDomainError()
            state = .error(domainError)
            onError?(domainError)
        }
    }

    /// Load data with dual-track caching behavior (silent refresh when data exists).
    ///
    /// This variant:
    /// - Shows loading only when no existing data
    /// - On error with existing data, keeps showing old data
    ///
    /// - Parameters:
    ///   - state: Reference to the ViewState to update.
    ///   - fetch: Async closure to fetch data.
    ///   - onSuccess: Optional callback on successful load.
    @MainActor
    static func loadWithCache<T>(
        state: inout ViewState<T>,
        fetch: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil
    ) async {
        let hasData = state.data != nil

        // Only show loading when no data
        if !hasData {
            state = .loading
        }

        do {
            let data = try await fetch()
            state = .loaded(data)
            onSuccess?(data)
        } catch {
            // Filter cancellation errors
            if error.isCancellationError {
                Logger.debug("[ViewModelDataLoader] Task cancelled, ignoring")
                return
            }

            // If we have data, keep showing it (don't update to error state)
            if hasData {
                Logger.debug("[ViewModelDataLoader] Refresh failed but keeping cached data: \(error.localizedDescription)")
                return
            }

            state = .error(error.toDomainError())
        }
    }

    // MARK: - Load for Collections

    /// Load collection data with empty state handling.
    ///
    /// - Parameters:
    ///   - state: Reference to the ViewState to update.
    ///   - showLoading: Whether to show loading state (default: true).
    ///   - fetch: Async closure to fetch collection data.
    ///   - onSuccess: Optional callback on successful load.
    @MainActor
    static func loadCollection<T: Collection>(
        state: inout ViewState<T>,
        showLoading: Bool = true,
        fetch: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil
    ) async {
        if showLoading {
            state = .loading
        }

        do {
            let data = try await fetch()

            // Use normalized state for collections (empty collection -> .empty)
            if data.isEmpty {
                state = .empty
            } else {
                state = .loaded(data)
            }

            onSuccess?(data)
        } catch {
            // Filter cancellation errors
            if error.isCancellationError {
                Logger.debug("[ViewModelDataLoader] Task cancelled, ignoring")
                return
            }

            state = .error(error.toDomainError())
        }
    }

    // MARK: - Refresh Operations

    /// Refresh data (keep showing old data during refresh).
    ///
    /// - Parameters:
    ///   - state: Reference to the ViewState to update.
    ///   - fetch: Async closure to fetch data.
    ///   - onSuccess: Optional callback on successful refresh.
    @MainActor
    static func refresh<T>(
        state: inout ViewState<T>,
        fetch: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil
    ) async {
        await loadWithCache(state: &state, fetch: fetch, onSuccess: onSuccess)
    }

    // MARK: - Execute with Result

    /// Execute an operation and return Result (useful for mutations).
    ///
    /// This is for operations like create/update/delete where you need
    /// to handle success/failure but don't update ViewState.
    ///
    /// - Parameters:
    ///   - operation: Async closure to execute.
    ///   - onSuccess: Optional callback on success.
    ///   - onError: Optional callback on error.
    ///
    /// - Returns: True if operation succeeded, false otherwise.
    @MainActor
    static func execute<T>(
        operation: () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((DomainError) -> Void)? = nil
    ) async -> Bool {
        do {
            let result = try await operation()
            onSuccess?(result)
            return true
        } catch {
            // Filter cancellation errors
            if error.isCancellationError {
                Logger.debug("[ViewModelDataLoader] Task cancelled, ignoring")
                return false
            }

            let domainError = error.toDomainError()
            onError?(domainError)
            return false
        }
    }

    /// Execute an operation that returns Void.
    ///
    /// - Parameters:
    ///   - operation: Async closure to execute.
    ///   - onSuccess: Optional callback on success.
    ///   - onError: Optional callback on error.
    ///
    /// - Returns: True if operation succeeded, false otherwise.
    @MainActor
    static func executeVoid(
        operation: () async throws -> Void,
        onSuccess: (() -> Void)? = nil,
        onError: ((DomainError) -> Void)? = nil
    ) async -> Bool {
        do {
            try await operation()
            onSuccess?()
            return true
        } catch {
            // Filter cancellation errors
            if error.isCancellationError {
                Logger.debug("[ViewModelDataLoader] Task cancelled, ignoring")
                return false
            }

            let domainError = error.toDomainError()
            onError?(domainError)
            return false
        }
    }
}

// MARK: - ViewModel Loading State Helper

/// Helper for managing isLoading state in ViewModels.
///
/// Usage:
/// ```swift
/// await LoadingStateHelper.withLoading(&isLoading) {
///     await performOperation()
/// }
/// ```
enum LoadingStateHelper {

    /// Execute operation with automatic isLoading state management.
    ///
    /// - Parameters:
    ///   - isLoading: Reference to the loading state boolean.
    ///   - operation: Async closure to execute.
    @MainActor
    static func withLoading(
        _ isLoading: inout Bool,
        operation: () async -> Void
    ) async {
        isLoading = true
        await operation()
        isLoading = false
    }

    /// Execute throwing operation with automatic isLoading state management.
    ///
    /// - Parameters:
    ///   - isLoading: Reference to the loading state boolean.
    ///   - operation: Async throwing closure to execute.
    ///
    /// - Throws: Rethrows any error from the operation.
    @MainActor
    static func withLoadingThrowing<T>(
        _ isLoading: inout Bool,
        operation: () async throws -> T
    ) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        return try await operation()
    }
}
