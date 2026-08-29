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
        /// 這批快取是誰寫的。讀之前先比對，對不上就整批丟掉。
        static let ownerUid = "training_plan_v2_cache_owner_uid"
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
    /// 快照的擁有者判定。注入是為了測試能演換帳號，正式路徑一律走
    /// `CurrentUserIdentity.uid`（含 demo 登入退路）。
    private let currentUserID: () -> String?

    /// In-memory cooldown timestamps keyed by resource.
    /// Uses TimeInterval (not Date) as value to comply with project constraints.
    private var cooldownTimestamps: [CooldownResource: TimeInterval] = [:]
    /// Guards `cooldownTimestamps` — Track B runs on `Task.detached`, reads happen on caller threads.
    private let cooldownLock = NSLock()

    // MARK: - Initialization

    init(
        defaults: UserDefaults = .standard,
        clock: V2Clock = SystemV2Clock(),
        currentUserID: @escaping () -> String? = CurrentUserIdentity.uid
    ) {
        self.defaults = defaults
        self.clock = clock
        self.currentUserID = currentUserID
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Configure encoders for Date handling
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // CacheEventBus registration moved to CacheRegistrationCoordinator (App layer)
    }

    // MARK: - 帳號隔離
    //
    // 這一組快取的 key 是靜態的、不帶 uid，而 `.dataChanged(.user)` 又刻意保留它
    // （`CacheEventBus.getRelatedCacheIdentifiers` 的 `preservedCaches`，修 relaunch 卡 loading）。
    // 兩者相加＝換帳號時如果 `.userLogout` 那條清空路徑沒跑到（清空失敗、或清空前就被讀），
    // B 帳號會讀到 A 帳號的課表。這裡蓋一個擁有者戳當第二道保險：
    // **讀之前先比對 uid，對不上就整批丟掉**，而不是靠「登出時一定會清乾淨」。
    //
    // 沒有 uid（尚未登入／auth 還沒恢復）時不讀也不寫 —— 來源不明的快取不進畫面。

    /// 這批快取是不是現在這個帳號寫的。不是就地清掉，並回 false。
    ///
    /// **沒有擁有者戳＝擁有者戳上線前寫下的 legacy 快取**：證明不了是誰的，就地清掉、
    /// 走網路重取（getter 回 nil → repository 打 API）。這是明確的一次性淘汰，
    /// 不是讓 legacy blob 靜默滯留（2026-08-29 外審）。
    private func isOwnedByCurrentUser() -> Bool {
        guard let uid = currentUserID() else { return false }
        guard let owner = defaults.string(forKey: Keys.ownerUid) else {
            if hasAnyCachedPayload() {
                Logger.info("[TrainingPlanV2LocalDS] legacy 快取無擁有者戳,整批丟棄改走網路")
                clearAll()
            }
            return false
        }
        guard owner == uid else {
            Logger.info("[TrainingPlanV2LocalDS] 快取擁有者不符,整批丟棄")
            clearAll()
            return false
        }
        return true
    }

    /// 任何一族快取有殘留就算有 payload。**只查 planStatus／overview 會漏掉 weekly
    /// 前綴族**：weekly-only 的 legacy blob 逃過清除，之後一次 save 蓋上現任 uid，
    /// 舊資料就變成可讀（2026-08-29 外審 D06）。
    private func hasAnyCachedPayload() -> Bool {
        if defaults.data(forKey: Keys.planStatus) != nil { return true }
        if defaults.data(forKey: Keys.overview) != nil { return true }
        let prefixes = [Keys.weeklyPlanPrefix, Keys.weeklySummaryPrefix, Keys.weeklyPreviewPrefix]
        return defaults.dictionaryRepresentation().keys.contains { key in
            prefixes.contains { key.hasPrefix($0) }
        }
    }

    /// 寫入時蓋上擁有者戳。沒有 uid 就不寫（呼叫端已先擋一次）。
    ///
    /// 蓋戳前若發現**無戳的 legacy 快取**，先整批清掉：否則第一個動作是 save 時
    /// （網路取回直接落地），戳一蓋上去，legacy 週資料就被「收養」成現任帳號可讀
    /// （2026-08-29 外審 D06 的 post-write 情境）。
    private func stampOwner() {
        guard let uid = currentUserID() else { return }
        if defaults.string(forKey: Keys.ownerUid) == nil, hasAnyCachedPayload() {
            Logger.info("[TrainingPlanV2LocalDS] save 前發現無戳 legacy 快取,先整批清掉再蓋戳")
            clearAll()
        }
        defaults.set(uid, forKey: Keys.ownerUid)
    }

    // MARK: - Overview Cache

    func getPlanStatus() -> PlanStatusV2Response? {
        guard isOwnedByCurrentUser() else { return nil }
        guard let data = defaults.data(forKey: Keys.planStatus) else {
            return nil
        }

        do {
            return try decoder.decode(PlanStatusV2Response.self, from: data)
        } catch {
            Logger.trace("[TrainingPlanV2LocalDS] Failed to decode plan status, clearing cache")
            clearPlanStatus()
            return nil
        }
    }

    func savePlanStatus(_ status: PlanStatusV2Response) {
        guard currentUserID() != nil else { return }
        stampOwner()
        do {
            let data = try encoder.encode(status)
            defaults.set(data, forKey: Keys.planStatus)
            defaults.set(Date(), forKey: Keys.planStatus + Keys.timestampSuffix)
            Logger.trace("[TrainingPlanV2LocalDS] Plan status saved to cache")
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
        Logger.trace("[TrainingPlanV2LocalDS] Plan status cache cleared")
    }

    // MARK: - Overview Cache

    func getOverview() -> PlanOverviewV2? {
        guard isOwnedByCurrentUser() else { return nil }
        guard let data = defaults.data(forKey: Keys.overview) else {
            return nil
        }

        do {
            return try decoder.decode(PlanOverviewV2.self, from: data)
        } catch {
            Logger.trace("[TrainingPlanV2LocalDS] Failed to decode overview, clearing cache")
            clearOverview()
            return nil
        }
    }

    func saveOverview(_ overview: PlanOverviewV2) {
        guard currentUserID() != nil else { return }
        stampOwner()
        do {
            let data = try encoder.encode(overview)
            defaults.set(data, forKey: Keys.overview)
            defaults.set(Date(), forKey: Keys.overview + Keys.timestampSuffix)
            Logger.trace("[TrainingPlanV2LocalDS] Overview saved to cache: \(overview.id)")
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
        Logger.trace("[TrainingPlanV2LocalDS] Overview cache cleared")
    }

    // MARK: - Weekly Plan Cache

    func getWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        guard isOwnedByCurrentUser() else { return nil }
        let key = Keys.weeklyPlanPrefix + "\(week)"
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklyPlanV2.self, from: data)
        } catch {
            Logger.trace("[TrainingPlanV2LocalDS] Failed to decode weekly plan for week \(week), clearing cache")
            clearWeeklyPlan(week: week)
            return nil
        }
    }

    func saveWeeklyPlan(_ plan: WeeklyPlanV2, week: Int) {
        guard currentUserID() != nil else { return }
        stampOwner()
        do {
            let key = Keys.weeklyPlanPrefix + "\(week)"
            let data = try encoder.encode(plan)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.trace("[TrainingPlanV2LocalDS] Weekly plan saved to cache: week \(week)")
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
        Logger.trace("[TrainingPlanV2LocalDS] Weekly plan cache cleared for week \(week)")
    }

    func clearAllWeeklyPlans() {
        // Clear known weeks (1-52)
        for week in 1...52 {
            clearWeeklyPlan(week: week)
        }
        Logger.trace("[TrainingPlanV2LocalDS] All weekly plan caches cleared")
    }

    // MARK: - Weekly Summary Cache

    func getWeeklySummary(week: Int) -> WeeklySummaryV2? {
        guard isOwnedByCurrentUser() else { return nil }
        let key = Keys.weeklySummaryPrefix + "\(week)"
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklySummaryV2.self, from: data)
        } catch {
            Logger.trace("[TrainingPlanV2LocalDS] Failed to decode weekly summary for week \(week), clearing cache")
            clearWeeklySummary(week: week)
            return nil
        }
    }

    func saveWeeklySummary(_ summary: WeeklySummaryV2, week: Int) {
        guard currentUserID() != nil else { return }
        stampOwner()
        do {
            let key = Keys.weeklySummaryPrefix + "\(week)"
            let data = try encoder.encode(summary)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.trace("[TrainingPlanV2LocalDS] Weekly summary saved to cache: week \(week)")
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
        Logger.trace("[TrainingPlanV2LocalDS] Weekly summary cache cleared for week \(week)")
    }

    func clearAllWeeklySummaries() {
        // Clear known weeks (1-52)
        for week in 1...52 {
            clearWeeklySummary(week: week)
        }
        Logger.trace("[TrainingPlanV2LocalDS] All weekly summary caches cleared")
    }

    // MARK: - Weekly Preview Cache

    func getWeeklyPreview(overviewId: String) -> WeeklyPreviewV2? {
        guard isOwnedByCurrentUser() else { return nil }
        let key = Keys.weeklyPreviewPrefix + overviewId
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(WeeklyPreviewV2.self, from: data)
        } catch {
            Logger.trace("[TrainingPlanV2LocalDS] Failed to decode weekly preview for \(overviewId), clearing cache")
            clearWeeklyPreview(overviewId: overviewId)
            return nil
        }
    }

    func saveWeeklyPreview(_ preview: WeeklyPreviewV2, overviewId: String) {
        guard currentUserID() != nil else { return }
        stampOwner()
        do {
            let key = Keys.weeklyPreviewPrefix + overviewId
            let data = try encoder.encode(preview)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.trace("[TrainingPlanV2LocalDS] Weekly preview saved to cache: \(overviewId)")
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
        Logger.trace("[TrainingPlanV2LocalDS] Weekly preview cache cleared for \(overviewId)")
    }

    // MARK: - Utility

    func clearAll() {
        defaults.removeObject(forKey: Keys.ownerUid)
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
        Logger.trace("[TrainingPlanV2LocalDS] Cooldown marked for \(resource)")
    }

    /// Clears the cooldown for a resource, so the next cache-hit will trigger a refresh.
    func invalidateCooldown(_ resource: CooldownResource) {
        cooldownLock.lock()
        cooldownTimestamps.removeValue(forKey: resource)
        cooldownLock.unlock()
        Logger.trace("[TrainingPlanV2LocalDS] Cooldown invalidated for \(resource)")
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
