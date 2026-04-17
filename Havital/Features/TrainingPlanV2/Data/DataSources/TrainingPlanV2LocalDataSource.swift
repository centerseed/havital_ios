import Foundation

// MARK: - TrainingPlanV2LocalDataSource Protocol
protocol TrainingPlanV2LocalDataSourceProtocol {
    // Plan Status Cache
    func getPlanStatus() -> PlanStatusV2Response?
    func savePlanStatus(_ status: PlanStatusV2Response)
    func isPlanStatusExpired() -> Bool
    func clearPlanStatus()

    // Background Refresh Cooldown
    func shouldRefresh(_ resource: CooldownResource) -> Bool
    func markRefreshed(_ resource: CooldownResource)
    func invalidateCooldown(_ resource: CooldownResource)

    // Plan Overview Cache
    func getOverview() -> PlanOverviewV2?
    func saveOverview(_ overview: PlanOverviewV2)
    func isOverviewExpired() -> Bool
    func clearOverview()

    // Weekly Plan Cache
    func getWeeklyPlan(week: Int) -> WeeklyPlanV2?
    func saveWeeklyPlan(_ plan: WeeklyPlanV2, week: Int)
    func isWeeklyPlanExpired(week: Int) -> Bool
    func clearWeeklyPlan(week: Int)
    func clearAllWeeklyPlans()

    // Weekly Summary Cache
    func getWeeklySummary(week: Int) -> WeeklySummaryV2?
    func saveWeeklySummary(_ summary: WeeklySummaryV2, week: Int)
    func isWeeklySummaryExpired(week: Int) -> Bool
    func clearWeeklySummary(week: Int)
    func clearAllWeeklySummaries()

    // Weekly Preview Cache
    func getWeeklyPreview(overviewId: String) -> WeeklyPreviewV2?
    func saveWeeklyPreview(_ preview: WeeklyPreviewV2, overviewId: String)
    func isWeeklyPreviewExpired(overviewId: String) -> Bool
    func clearWeeklyPreview(overviewId: String)

    // Utility
    func clearAll()
}

// MARK: - TrainingPlanV2LocalDataSource
/// Handles local caching of Training Plan V2 data
/// Data Layer - Pure cache management using UserDefaults
/// Supports TTL (Time-To-Live) for cache expiration
final class TrainingPlanV2LocalDataSource: TrainingPlanV2LocalDataSourceProtocol {

    // MARK: - Constants

    private enum Keys {
        static let planStatus = "training_plan_v2_plan_status_cache"
        static let overview = "training_plan_v2_overview_cache"
        static let weeklyPlanPrefix = "training_plan_v2_weekly_"
        static let weeklySummaryPrefix = "training_plan_v2_summary_"
        static let weeklyPreviewPrefix = "training_plan_v2_preview_"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let planStatus: TimeInterval = 3600          // 1 hour
        static let overview: TimeInterval = 3600            // 1 hour
        static let weeklyPlan: TimeInterval = 7200          // 2 hours
        static let weeklySummary: TimeInterval = 3600       // 1 hour
    }

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let clock: V2Clock

    /// In-memory cooldown timestamps keyed by resource.
    /// Uses TimeInterval (not Date) as value to comply with project constraints.
    private var cooldownTimestamps: [CooldownResource: TimeInterval] = [:]
    /// Guards `cooldownTimestamps` — Track B runs on `Task.detached`, reads happen on caller threads.
    private let cooldownLock = NSLock()

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard, clock: V2Clock = SystemV2Clock()) {
        self.defaults = defaults
        self.clock = clock
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Configure encoders for Date handling
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        CacheEventBus.shared.register(self)
    }

    // MARK: - Overview Cache

    func getPlanStatus() -> PlanStatusV2Response? {
        guard let data = defaults.data(forKey: Keys.planStatus) else {
            return nil
        }

        do {
            return try decoder.decode(PlanStatusV2Response.self, from: data)
        } catch {
            Logger.debug("[TrainingPlanV2LocalDS] Failed to decode plan status, clearing cache")
            clearPlanStatus()
            return nil
        }
    }

    func savePlanStatus(_ status: PlanStatusV2Response) {
        do {
            let data = try encoder.encode(status)
            defaults.set(data, forKey: Keys.planStatus)
            defaults.set(Date(), forKey: Keys.planStatus + Keys.timestampSuffix)
            Logger.debug("[TrainingPlanV2LocalDS] Plan status saved to cache")
        } catch {
            Logger.error("[TrainingPlanV2LocalDS] Failed to encode plan status: \(error)")
        }
    }

    func isPlanStatusExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.planStatus + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.planStatus
    }

    func clearPlanStatus() {
        defaults.removeObject(forKey: Keys.planStatus)
        defaults.removeObject(forKey: Keys.planStatus + Keys.timestampSuffix)
        Logger.debug("[TrainingPlanV2LocalDS] Plan status cache cleared")
    }

    // MARK: - Overview Cache

    func getOverview() -> PlanOverviewV2? {
        guard let data = defaults.data(forKey: Keys.overview) else {
            return nil
        }

        do {
            return try decoder.decode(PlanOverviewV2.self, from: data)
        } catch {
            Logger.debug("[TrainingPlanV2LocalDS] Failed to decode overview, clearing cache")
            clearOverview()
            return nil
        }
    }

    func saveOverview(_ overview: PlanOverviewV2) {
        do {
            let data = try encoder.encode(overview)
            defaults.set(data, forKey: Keys.overview)
            defaults.set(Date(), forKey: Keys.overview + Keys.timestampSuffix)
            Logger.debug("[TrainingPlanV2LocalDS] Overview saved to cache: \(overview.id)")
        } catch {
            Logger.error("[TrainingPlanV2LocalDS] Failed to encode overview: \(error)")
        }
    }

    func isOverviewExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: Keys.overview + Keys.timestampSuffix) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.overview
    }

    func clearOverview() {
        defaults.removeObject(forKey: Keys.overview)
        defaults.removeObject(forKey: Keys.overview + Keys.timestampSuffix)
        Logger.debug("[TrainingPlanV2LocalDS] Overview cache cleared")
    }

    // MARK: - Weekly Plan Cache

    func getWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        let key = Keys.weeklyPlanPrefix + "\(week)"
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklyPlanV2.self, from: data)
        } catch {
            Logger.debug("[TrainingPlanV2LocalDS] Failed to decode weekly plan for week \(week), clearing cache")
            clearWeeklyPlan(week: week)
            return nil
        }
    }

    func saveWeeklyPlan(_ plan: WeeklyPlanV2, week: Int) {
        do {
            let key = Keys.weeklyPlanPrefix + "\(week)"
            let data = try encoder.encode(plan)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.debug("[TrainingPlanV2LocalDS] Weekly plan saved to cache: week \(week)")
        } catch {
            Logger.error("[TrainingPlanV2LocalDS] Failed to encode weekly plan: \(error)")
        }
    }

    func isWeeklyPlanExpired(week: Int) -> Bool {
        let key = Keys.weeklyPlanPrefix + "\(week)" + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.weeklyPlan
    }

    func clearWeeklyPlan(week: Int) {
        let key = Keys.weeklyPlanPrefix + "\(week)"
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + Keys.timestampSuffix)
        Logger.debug("[TrainingPlanV2LocalDS] Weekly plan cache cleared for week \(week)")
    }

    func clearAllWeeklyPlans() {
        // Clear known weeks (1-52)
        for week in 1...52 {
            clearWeeklyPlan(week: week)
        }
        Logger.debug("[TrainingPlanV2LocalDS] All weekly plan caches cleared")
    }

    // MARK: - Weekly Summary Cache

    func getWeeklySummary(week: Int) -> WeeklySummaryV2? {
        let key = Keys.weeklySummaryPrefix + "\(week)"
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklySummaryV2.self, from: data)
        } catch {
            Logger.debug("[TrainingPlanV2LocalDS] Failed to decode weekly summary for week \(week), clearing cache")
            clearWeeklySummary(week: week)
            return nil
        }
    }

    func saveWeeklySummary(_ summary: WeeklySummaryV2, week: Int) {
        do {
            let key = Keys.weeklySummaryPrefix + "\(week)"
            let data = try encoder.encode(summary)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.debug("[TrainingPlanV2LocalDS] Weekly summary saved to cache: week \(week)")
        } catch {
            Logger.error("[TrainingPlanV2LocalDS] Failed to encode weekly summary: \(error)")
        }
    }

    func isWeeklySummaryExpired(week: Int) -> Bool {
        let key = Keys.weeklySummaryPrefix + "\(week)" + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.weeklySummary
    }

    func clearWeeklySummary(week: Int) {
        let key = Keys.weeklySummaryPrefix + "\(week)"
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + Keys.timestampSuffix)
        Logger.debug("[TrainingPlanV2LocalDS] Weekly summary cache cleared for week \(week)")
    }

    func clearAllWeeklySummaries() {
        // Clear known weeks (1-52)
        for week in 1...52 {
            clearWeeklySummary(week: week)
        }
        Logger.debug("[TrainingPlanV2LocalDS] All weekly summary caches cleared")
    }

    // MARK: - Weekly Preview Cache

    func getWeeklyPreview(overviewId: String) -> WeeklyPreviewV2? {
        let key = Keys.weeklyPreviewPrefix + overviewId
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklyPreviewV2.self, from: data)
        } catch {
            Logger.debug("[TrainingPlanV2LocalDS] Failed to decode weekly preview for \(overviewId), clearing cache")
            clearWeeklyPreview(overviewId: overviewId)
            return nil
        }
    }

    func saveWeeklyPreview(_ preview: WeeklyPreviewV2, overviewId: String) {
        do {
            let key = Keys.weeklyPreviewPrefix + overviewId
            let data = try encoder.encode(preview)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.debug("[TrainingPlanV2LocalDS] Weekly preview saved to cache: \(overviewId)")
        } catch {
            Logger.error("[TrainingPlanV2LocalDS] Failed to encode weekly preview: \(error)")
        }
    }

    func isWeeklyPreviewExpired(overviewId: String) -> Bool {
        let key = Keys.weeklyPreviewPrefix + overviewId + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.overview
    }

    func clearWeeklyPreview(overviewId: String) {
        let key = Keys.weeklyPreviewPrefix + overviewId
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + Keys.timestampSuffix)
        Logger.debug("[TrainingPlanV2LocalDS] Weekly preview cache cleared for \(overviewId)")
    }

    // MARK: - Utility

    func clearAll() {
        clearPlanStatus()
        clearOverview()
        clearAllWeeklyPlans()
        clearAllWeeklySummaries()
        clearAllWeeklyPreviews()
        Logger.info("[TrainingPlanV2LocalDS] All caches cleared")
    }

    // MARK: - Background Refresh Cooldown

    /// Returns true when the resource's cooldown has expired (or never been set),
    /// meaning a background refresh should be triggered.
    func shouldRefresh(_ resource: CooldownResource) -> Bool {
        cooldownLock.lock()
        let lastRefreshedInterval = cooldownTimestamps[resource]
        cooldownLock.unlock()
        guard let lastRefreshedInterval else { return true }
        let elapsed = clock.now().timeIntervalSince1970 - lastRefreshedInterval
        return elapsed >= resource.duration
    }

    /// Records a successful background refresh, starting the cooldown timer.
    func markRefreshed(_ resource: CooldownResource) {
        let now = clock.now().timeIntervalSince1970
        cooldownLock.lock()
        cooldownTimestamps[resource] = now
        cooldownLock.unlock()
        Logger.debug("[TrainingPlanV2LocalDS] Cooldown marked for \(resource)")
    }

    /// Clears the cooldown for a resource, so the next cache-hit will trigger a refresh.
    func invalidateCooldown(_ resource: CooldownResource) {
        cooldownLock.lock()
        cooldownTimestamps.removeValue(forKey: resource)
        cooldownLock.unlock()
        Logger.debug("[TrainingPlanV2LocalDS] Cooldown invalidated for \(resource)")
    }

    private func clearAllWeeklyPreviews() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(Keys.weeklyPreviewPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Cacheable Protocol Conformance
extension TrainingPlanV2LocalDataSource: Cacheable {

    var cacheIdentifier: String {
        return "TrainingPlanV2LocalDataSource"
    }

    func clearCache() {
        clearAll()
    }

    func getCacheSize() -> Int {
        var size = 0
        if let data = defaults.data(forKey: "training_plan_v2_plan_status_cache") { size += data.count }
        if let data = defaults.data(forKey: "training_plan_v2_overview_cache") { size += data.count }
        return size
    }

    func isExpired() -> Bool {
        return isPlanStatusExpired() && isOverviewExpired()
    }
}
