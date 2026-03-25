import Foundation

// MARK: - TrainingPlanV2LocalDataSource Protocol
protocol TrainingPlanV2LocalDataSourceProtocol {
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
        static let overview = "training_plan_v2_overview_cache"
        static let weeklyPlanPrefix = "training_plan_v2_weekly_"
        static let weeklySummaryPrefix = "training_plan_v2_summary_"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let overview: TimeInterval = 3600            // 1 hour
        static let weeklyPlan: TimeInterval = 7200          // 2 hours
        static let weeklySummary: TimeInterval = 3600       // 1 hour
    }

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Configure encoders for Date handling
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
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

    // MARK: - Utility

    func clearAll() {
        clearOverview()
        clearAllWeeklyPlans()
        clearAllWeeklySummaries()
        Logger.info("[TrainingPlanV2LocalDS] All caches cleared")
    }
}
