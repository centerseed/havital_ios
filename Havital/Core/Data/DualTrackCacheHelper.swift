import Foundation

// MARK: - Dual-Track Cache Helper
/// Unified helper for implementing dual-track caching strategy in Repository layer.
///
/// This helper consolidates the repetitive caching patterns found across repositories:
/// - TrainingPlanRepositoryImpl
/// - WorkoutRepositoryImpl
/// - TargetRepositoryImpl
/// - UserProfileRepositoryImpl
///
/// ## Dual-Track Caching Strategy
///
/// **Track A (Foreground)**: Return cached data immediately for fast UI display.
/// **Track B (Background)**: Refresh from API in background to keep data fresh.
///
/// ## Usage
///
/// ```swift
/// // In Repository implementation:
/// func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
///     return try await DualTrackCacheHelper.execute(
///         cacheKey: "weeklyPlan_\(planId)",
///         getCached: { localDataSource.getWeeklyPlan(planId: planId) },
///         isCacheExpired: { localDataSource.isWeeklyPlanExpired(planId: planId) },
///         fetchFromAPI: { try await remoteDataSource.getWeeklyPlan(planId: planId) },
///         saveToCache: { localDataSource.saveWeeklyPlan($0, planId: planId) }
///     )
/// }
/// ```
enum DualTrackCacheHelper {

    // MARK: - Main Execute Method

    /// Execute dual-track caching strategy.
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - getCached: Closure to retrieve cached data (returns nil if no cache).
    ///   - isCacheExpired: Closure to check if cache is expired.
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///   - onBackgroundRefreshComplete: Optional callback when background refresh completes.
    ///
    /// - Returns: Data from cache (if valid) or freshly fetched from API.
    /// - Throws: Error from API if no cache available and fetch fails.
    static func execute<T>(
        cacheKey: String,
        getCached: () -> T?,
        isCacheExpired: () -> Bool,
        fetchFromAPI: @escaping () async throws -> T,
        saveToCache: @escaping (T) -> Void,
        onBackgroundRefreshComplete: ((T) -> Void)? = nil
    ) async throws -> T {
        // Track A: Check local cache
        if let cached = getCached(), !isCacheExpired() {
            Logger.debug("[DualTrackCache] Cache hit: \(cacheKey)")

            // Track B: Background refresh
            backgroundRefresh(
                cacheKey: cacheKey,
                fetchFromAPI: fetchFromAPI,
                saveToCache: saveToCache,
                onComplete: onBackgroundRefreshComplete
            )

            return cached
        }

        // No cache or expired - fetch from API
        Logger.debug("[DualTrackCache] Cache miss: \(cacheKey), fetching from API")
        let data = try await fetchFromAPI()
        saveToCache(data)
        return data
    }

    /// Execute dual-track caching strategy for optional cache (uses isEmpty check for collections).
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - getCached: Closure to retrieve cached data (returns empty collection if no cache).
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///
    /// - Returns: Data from cache (if not empty) or freshly fetched from API.
    /// - Throws: Error from API if no cache available and fetch fails.
    static func executeForCollection<T: Collection>(
        cacheKey: String,
        getCached: () -> T,
        fetchFromAPI: @escaping () async throws -> T,
        saveToCache: @escaping (T) -> Void
    ) async throws -> T {
        let cached = getCached()

        // Track A: Check if cache has data
        if !cached.isEmpty {
            Logger.debug("[DualTrackCache] Collection cache hit: \(cacheKey), count: \(cached.count)")

            // Track B: Background refresh
            backgroundRefresh(
                cacheKey: cacheKey,
                fetchFromAPI: fetchFromAPI,
                saveToCache: saveToCache,
                onComplete: nil
            )

            return cached
        }

        // No cache - fetch from API
        Logger.debug("[DualTrackCache] Collection cache miss: \(cacheKey), fetching from API")
        let data = try await fetchFromAPI()
        saveToCache(data)
        return data
    }

    // MARK: - Force Refresh

    /// Force refresh data from API, bypassing cache.
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///
    /// - Returns: Freshly fetched data from API.
    /// - Throws: Error from API if fetch fails.
    static func forceRefresh<T>(
        cacheKey: String,
        fetchFromAPI: () async throws -> T,
        saveToCache: (T) -> Void
    ) async throws -> T {
        Logger.debug("[DualTrackCache] Force refresh: \(cacheKey)")
        let data = try await fetchFromAPI()
        saveToCache(data)
        return data
    }

    // MARK: - Background Refresh

    /// Execute background refresh for Track B.
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///   - onComplete: Optional callback when refresh completes successfully.
    private static func backgroundRefresh<T>(
        cacheKey: String,
        fetchFromAPI: @escaping () async throws -> T,
        saveToCache: @escaping (T) -> Void,
        onComplete: ((T) -> Void)?
    ) {
        Task.detached(priority: .background) {
            do {
                let data = try await fetchFromAPI()
                saveToCache(data)
                Logger.debug("[DualTrackCache] Background refresh success: \(cacheKey)")
                onComplete?(data)
            } catch {
                // Background refresh failure is non-critical - just log it
                Logger.debug("[DualTrackCache] Background refresh failed (non-critical): \(cacheKey) - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Event Publishing Helper

    /// Execute background refresh with event publishing.
    ///
    /// Use this when you need to notify the UI layer after background refresh.
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///   - eventType: DataType to publish via CacheEventBus after successful refresh.
    static func backgroundRefreshWithEvent<T>(
        cacheKey: String,
        fetchFromAPI: @escaping () async throws -> T,
        saveToCache: @escaping (T) -> Void,
        eventType: DataType
    ) {
        Task.detached(priority: .background) {
            do {
                let data = try await fetchFromAPI()
                saveToCache(data)
                Logger.debug("[DualTrackCache] Background refresh success: \(cacheKey)")

                // Publish event on main actor
                await MainActor.run {
                    CacheEventBus.shared.publish(.dataChanged(eventType))
                }
                Logger.debug("[DualTrackCache] Published event: dataChanged.\(eventType)")
            } catch {
                Logger.debug("[DualTrackCache] Background refresh failed (non-critical): \(cacheKey) - \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Convenience Extension for Repositories

extension DualTrackCacheHelper {

    /// Simplified execute for common Repository pattern.
    ///
    /// This variant is for cases where:
    /// - Cache expiration is managed internally by LocalDataSource
    /// - No special callback is needed after background refresh
    ///
    /// - Parameters:
    ///   - cacheKey: Unique identifier for logging purposes.
    ///   - getCached: Closure to retrieve cached data (returns nil if no cache or expired).
    ///   - fetchFromAPI: Async closure to fetch data from remote API.
    ///   - saveToCache: Closure to save fetched data to local cache.
    ///
    /// - Returns: Data from cache or freshly fetched from API.
    /// - Throws: Error from API if no cache available and fetch fails.
    static func executeSimple<T>(
        cacheKey: String,
        getCached: () -> T?,
        fetchFromAPI: @escaping () async throws -> T,
        saveToCache: @escaping (T) -> Void
    ) async throws -> T {
        return try await execute(
            cacheKey: cacheKey,
            getCached: getCached,
            isCacheExpired: { false }, // Expiration handled by getCached returning nil
            fetchFromAPI: fetchFromAPI,
            saveToCache: saveToCache,
            onBackgroundRefreshComplete: nil
        )
    }
}
