import Foundation

// MARK: - TrainingPlan Local DataSource
/// 負責本地緩存管理
/// Data Layer - 處理 UserDefaults 存取和過期檢查
final class TrainingPlanLocalDataSource {

    // MARK: - Constants
    private enum Keys {
        static let weeklyPlanPrefix = "weekly_plan_v2_"
        static let overview = "training_plan_overview_v2"
        static let planStatus = "plan_status_v2"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let weeklyPlan: TimeInterval = 7 * 24 * 60 * 60    // 7 天
        static let overview: TimeInterval = 24 * 60 * 60          // 24 小時
        static let planStatus: TimeInterval = 8 * 60 * 60         // 8 小時
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
    }

    // MARK: - Weekly Plan

    /// 獲取緩存的週計畫
    func getWeeklyPlan(planId: String) -> WeeklyPlan? {
        let key = Keys.weeklyPlanPrefix + planId
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try decoder.decode(WeeklyPlan.self, from: data)
        } catch {
            Logger.debug("[LocalDataSource] Failed to decode weekly plan: \(error.localizedDescription)")
            // 清除損壞的緩存
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: key + Keys.timestampSuffix)
            return nil
        }
    }

    /// 保存週計畫到緩存
    func saveWeeklyPlan(_ plan: WeeklyPlan, planId: String) {
        let key = Keys.weeklyPlanPrefix + planId

        do {
            let data = try encoder.encode(plan)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.debug("[LocalDataSource] Saved weekly plan: \(planId)")
        } catch {
            Logger.error("[LocalDataSource] Failed to save weekly plan: \(error.localizedDescription)")
        }
    }

    /// 檢查週計畫是否過期
    func isWeeklyPlanExpired(planId: String) -> Bool {
        let key = Keys.weeklyPlanPrefix + planId + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.weeklyPlan
    }

    /// 刪除週計畫緩存
    func removeWeeklyPlan(planId: String) {
        let key = Keys.weeklyPlanPrefix + planId
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + Keys.timestampSuffix)
    }

    // MARK: - Overview

    /// 獲取緩存的訓練概覽
    func getOverview() -> TrainingPlanOverview? {
        guard let data = defaults.data(forKey: Keys.overview) else { return nil }

        do {
            return try decoder.decode(TrainingPlanOverview.self, from: data)
        } catch {
            Logger.debug("[LocalDataSource] Failed to decode overview: \(error.localizedDescription)")
            defaults.removeObject(forKey: Keys.overview)
            defaults.removeObject(forKey: Keys.overview + Keys.timestampSuffix)
            return nil
        }
    }

    /// 保存訓練概覽到緩存
    func saveOverview(_ overview: TrainingPlanOverview) {
        do {
            let data = try encoder.encode(overview)
            defaults.set(data, forKey: Keys.overview)
            defaults.set(Date(), forKey: Keys.overview + Keys.timestampSuffix)
            Logger.debug("[LocalDataSource] Saved overview: \(overview.id)")
        } catch {
            Logger.error("[LocalDataSource] Failed to save overview: \(error.localizedDescription)")
        }
    }

    /// 檢查訓練概覽是否過期
    func isOverviewExpired() -> Bool {
        let key = Keys.overview + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.overview
    }

    /// 刪除訓練概覽緩存
    func removeOverview() {
        defaults.removeObject(forKey: Keys.overview)
        defaults.removeObject(forKey: Keys.overview + Keys.timestampSuffix)
    }

    // MARK: - Plan Status

    /// 獲取緩存的計畫狀態
    func getPlanStatus() -> PlanStatusResponse? {
        guard let data = defaults.data(forKey: Keys.planStatus) else { return nil }

        do {
            return try decoder.decode(PlanStatusResponse.self, from: data)
        } catch {
            Logger.debug("[LocalDataSource] Failed to decode plan status: \(error.localizedDescription)")
            defaults.removeObject(forKey: Keys.planStatus)
            defaults.removeObject(forKey: Keys.planStatus + Keys.timestampSuffix)
            return nil
        }
    }

    /// 保存計畫狀態到緩存
    func savePlanStatus(_ status: PlanStatusResponse) {
        do {
            let data = try encoder.encode(status)
            defaults.set(data, forKey: Keys.planStatus)
            defaults.set(Date(), forKey: Keys.planStatus + Keys.timestampSuffix)
            Logger.debug("[LocalDataSource] Saved plan status")
        } catch {
            Logger.error("[LocalDataSource] Failed to save plan status: \(error.localizedDescription)")
        }
    }

    /// 檢查計畫狀態是否過期
    func isPlanStatusExpired() -> Bool {
        let key = Keys.planStatus + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.planStatus
    }

    /// 刪除計畫狀態緩存
    func removePlanStatus() {
        defaults.removeObject(forKey: Keys.planStatus)
        defaults.removeObject(forKey: Keys.planStatus + Keys.timestampSuffix)
    }

    // MARK: - Cache Management

    /// 清除所有緩存
    func clearAll() {
        // 清除 overview
        removeOverview()

        // 清除 plan status
        removePlanStatus()

        // 清除所有 weekly plan
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(Keys.weeklyPlanPrefix) {
                defaults.removeObject(forKey: key)
            }
        }

        Logger.debug("[LocalDataSource] Cleared all training plan cache")
    }

    /// 獲取緩存大小（bytes）
    func getCacheSize() -> Int {
        var totalSize = 0

        // Overview
        if let data = defaults.data(forKey: Keys.overview) {
            totalSize += data.count
        }

        // Plan Status
        if let data = defaults.data(forKey: Keys.planStatus) {
            totalSize += data.count
        }

        // Weekly Plans
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(Keys.weeklyPlanPrefix), !key.hasSuffix(Keys.timestampSuffix) {
                if let data = defaults.data(forKey: key) {
                    totalSize += data.count
                }
            }
        }

        return totalSize
    }

    /// 清除過期緩存
    func clearExpiredCache() {
        var clearedCount = 0

        // 清除過期的 overview
        if isOverviewExpired() {
            removeOverview()
            clearedCount += 1
        }

        // 清除過期的 plan status
        if isPlanStatusExpired() {
            removePlanStatus()
            clearedCount += 1
        }

        // 清除過期的 weekly plans
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(Keys.weeklyPlanPrefix) && !key.hasSuffix(Keys.timestampSuffix) {
                let planId = String(key.dropFirst(Keys.weeklyPlanPrefix.count))
                if isWeeklyPlanExpired(planId: planId) {
                    removeWeeklyPlan(planId: planId)
                    clearedCount += 1
                }
            }
        }

        if clearedCount > 0 {
            Logger.debug("[LocalDataSource] Cleared \(clearedCount) expired cache entries")
        }
    }
}

// MARK: - Cacheable Conformance
extension TrainingPlanLocalDataSource: Cacheable {
    var cacheIdentifier: String { "training_plan_local" }

    func clearCache() {
        clearAll()
    }

    func isExpired() -> Bool {
        // 如果任一主要緩存過期，就認為整體過期
        return isOverviewExpired() || isPlanStatusExpired()
    }

    // Note: getCacheSize() is already defined in the main class at line 190
    // The Cacheable protocol requirement is satisfied by that implementation
}
